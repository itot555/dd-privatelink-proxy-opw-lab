#!/bin/bash -e
set -e

exec > >(sudo tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

# bootstrap revision: ${BOOTSTRAP_REVISION}

APP_SERVICE="${APP_SERVICE}"
APP_VERSION="${APP_VERSION}"
AWS_REGION="${AWS_REGION}"
BOOTSTRAP_PREFIX="${BOOTSTRAP_PREFIX}"
DATADOG_COMMON_CONFIG_KEY="${DATADOG_COMMON_CONFIG_KEY}"
DATABASE_NAME="${DATABASE_NAME}"
DATABASE_SECRET_ARN="${DATABASE_SECRET_ARN}"
DD_API_KEY_SECRET_ARN="${DD_API_KEY_SECRET_ARN}"
DD_ENV="${DD_ENV}"
DD_SITE="${DD_SITE}"
DD_HOSTNAME="${DD_HOSTNAME}"
ENABLE_DDOT="${ENABLE_DDOT}"
PROJECT_NAME="${PROJECT_NAME}"
PYTHON_APP_PORT="${PYTHON_APP_PORT}"
RDS_ENDPOINT="${RDS_ENDPOINT}"
S3_BUCKET="${S3_BUCKET}"
APP_ARCHIVE_S3_KEY="${APP_ARCHIVE_S3_KEY}"
ENABLE_BANKING_DEMO="${ENABLE_BANKING_DEMO}"
DEMO_BANK_PASSWORD="${DEMO_BANK_PASSWORD}"

export DEBIAN_FRONTEND=noninteractive
export AWS_DEFAULT_REGION="$AWS_REGION"

wait_for_apt() {
  echo "Waiting for apt connectivity..."
  for attempt in $(seq 1 60); do
    if apt-get update -qq >/dev/null 2>&1; then
      echo "apt connectivity OK (attempt $${attempt})"
      return 0
    fi
    sleep 5
  done
  echo "ERROR: apt-get update failed after 5 minutes" >&2
  exit 1
}

hostnamectl set-hostname "$DD_HOSTNAME"
mkdir -p /var/log/dd-lab

mkdir -p /home/ubuntu/.ssh
echo "${COMMON_PUBLIC_KEY}" >> /home/ubuntu/.ssh/authorized_keys
chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys

wait_for_apt
apt-get update
apt-get install -y acl auditd ca-certificates curl jq postgresql-client python3 python3-pip python3-venv rsyslog unzip
systemctl enable --now auditd || true
systemctl enable --now rsyslog || true

curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
rm -rf /tmp/aws
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install --update

aws s3 cp "s3://${S3_BUCKET}/${BOOTSTRAP_PREFIX}/userdata_common.sh" /tmp/userdata_common.sh
chmod 0755 /tmp/userdata_common.sh
# shellcheck source=/dev/null
source /tmp/userdata_common.sh

wait_for_outbound

ENABLE_SSI="false"
export AWS_REGION DD_API_KEY_SECRET_ARN DD_SITE DD_ENV ENABLE_DDOT ENABLE_SSI
run_bootstrap_fetch

cat >> /etc/datadog-agent/datadog.yaml <<EOF
secret_backend_command: /etc/datadog-agent/secret_backend.sh
EOF

cat > /etc/datadog-agent/secret_backend.sh <<SECRET_BACKEND
#!/usr/bin/env bash
set -euo pipefail

INPUT=\$(cat)
SECRET=\$(aws secretsmanager get-secret-value \
  --region "${AWS_REGION}" \
  --secret-id "${DATABASE_SECRET_ARN}" \
  --query SecretString \
  --output text)

RESULT="{}"
while IFS= read -r HANDLE; do
  case "\$HANDLE" in
    dbm_password)
      VALUE=\$(jq -r '.dbm_password' <<<"\$SECRET")
      ;;
    *)
      VALUE=""
      ;;
  esac

  RESULT=\$(jq \
    --arg handle "\$HANDLE" \
    --arg value "\$VALUE" \
    '. + {(\$handle): {"value": \$value}}' <<<"\$RESULT")
done < <(jq -r '.secrets[]' <<<"\$INPUT")

printf '%s\n' "\$RESULT"
SECRET_BACKEND

chown root:dd-agent /etc/datadog-agent/secret_backend.sh
chmod 0750 /etc/datadog-agent/secret_backend.sh

install -d -o ubuntu -g ubuntu /opt/dd-lab
aws s3 cp "s3://${S3_BUCKET}/${APP_ARCHIVE_S3_KEY}" /opt/dd-lab/application.zip
unzip -q /opt/dd-lab/application.zip -d /opt/dd-lab/application
chown -R ubuntu:ubuntu /opt/dd-lab/application

DB_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "$DATABASE_SECRET_ARN" \
  --query SecretString \
  --output text)

ADMIN_USERNAME=$(jq -r '.admin_username' <<<"$DB_SECRET")
ADMIN_PASSWORD=$(jq -r '.admin_password' <<<"$DB_SECRET")
APP_USERNAME=$(jq -r '.app_username' <<<"$DB_SECRET")
APP_PASSWORD=$(jq -r '.app_password' <<<"$DB_SECRET")
DBM_USERNAME=$(jq -r '.dbm_username' <<<"$DB_SECRET")
DBM_PASSWORD=$(jq -r '.dbm_password' <<<"$DB_SECRET")

export PGPASSWORD="$ADMIN_PASSWORD"
for attempt in $(seq 1 60); do
  if pg_isready -h "$RDS_ENDPOINT" -p 5432 -U "$ADMIN_USERNAME" -d "$DATABASE_NAME"; then
    break
  fi
  if [[ "$attempt" -eq 60 ]]; then
    echo "RDS PostgreSQL did not become ready" >&2
    exit 1
  fi
  sleep 10
done

psql \
  -h "$RDS_ENDPOINT" \
  -U "$ADMIN_USERNAME" \
  -d "$DATABASE_NAME" \
  -v ON_ERROR_STOP=1 \
  -v app_username="$APP_USERNAME" \
  -v app_password="$APP_PASSWORD" \
  -v dbm_username="$DBM_USERNAME" \
  -v dbm_password="$DBM_PASSWORD" <<'SQL'
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE SCHEMA IF NOT EXISTS datadog;

SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'app_username', :'app_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'app_username') \gexec

SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'dbm_username', :'dbm_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'dbm_username') \gexec

SELECT format('ALTER ROLE %I INHERIT', :'dbm_username') \gexec
SELECT format('GRANT pg_monitor TO %I', :'dbm_username') \gexec
SELECT format('GRANT USAGE ON SCHEMA public, datadog TO %I', :'dbm_username') \gexec

CREATE OR REPLACE FUNCTION datadog.explain_statement(
  l_query TEXT,
  OUT explain JSON
)
RETURNS SETOF JSON AS
$$
DECLARE
  curs REFCURSOR;
  plan JSON;
BEGIN
  SET TRANSACTION READ ONLY;
  OPEN curs FOR EXECUTE pg_catalog.concat('EXPLAIN (FORMAT JSON) ', l_query);
  FETCH curs INTO plan;
  CLOSE curs;
  RETURN QUERY SELECT plan;
END;
$$
LANGUAGE plpgsql
RETURNS NULL ON NULL INPUT
SECURITY DEFINER;

CREATE TABLE IF NOT EXISTS demo_items (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

SELECT format(
  'GRANT CONNECT ON DATABASE %I TO %I',
  current_database(),
  :'app_username'
) \gexec
SELECT format('GRANT USAGE ON SCHEMA public TO %I', :'app_username') \gexec
SELECT format('GRANT SELECT, INSERT, UPDATE, DELETE ON demo_items TO %I', :'app_username') \gexec
SELECT format('GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO %I', :'app_username') \gexec
SQL

%{ if enable_banking_demo ~}
echo "Applying banking demo schema..."
psql \
  -h "$RDS_ENDPOINT" \
  -U "$ADMIN_USERNAME" \
  -d "$DATABASE_NAME" \
  -v ON_ERROR_STOP=1 \
  -v app_username="$APP_USERNAME" \
  -v demo_bank_password="$DEMO_BANK_PASSWORD" <<'BANKING_SQL'
${banking_schema_sql}
BANKING_SQL
%{ endif ~}

install -d /etc/datadog-agent/conf.d/postgres.d
cat > /etc/datadog-agent/conf.d/postgres.d/conf.yaml <<EOF
init_config:

instances:
  - dbm: true
    host: $RDS_ENDPOINT
    port: 5432
    username: $DBM_USERNAME
    password: ENC[dbm_password]
    dbname: $DATABASE_NAME
    aws:
      instance_endpoint: $RDS_ENDPOINT
      region: $AWS_REGION
    tags:
      - dbinstanceidentifier:$PROJECT_NAME
      - env:$DD_ENV
EOF

install -d /var/log/dd-lab
chown ubuntu:dd-agent /var/log/dd-lab
chmod 0775 /var/log/dd-lab

sudo -u ubuntu python3 -m venv /opt/dd-lab/application/.venv
sudo -u ubuntu /opt/dd-lab/application/.venv/bin/pip install -q \
  -r /opt/dd-lab/application/requirements.txt
sudo -u ubuntu /opt/dd-lab/application/.venv/bin/opentelemetry-bootstrap -a install

cat > /etc/default/dd-lab-python <<EOF
PORT=$PYTHON_APP_PORT
DB_HOST=$RDS_ENDPOINT
DB_PORT=5432
DB_NAME=$DATABASE_NAME
DB_USER=$APP_USERNAME
DB_PASSWORD=$APP_PASSWORD
OTEL_SERVICE_NAME=$APP_SERVICE
OTEL_SERVICE_VERSION=$APP_VERSION
OTEL_ENV=$DD_ENV
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=$DD_ENV,service.version=$APP_VERSION
OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4317
OTEL_EXPORTER_OTLP_PROTOCOL=grpc
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp
OTEL_PROPAGATORS=tracecontext,baggage
OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED=true
ENABLE_BANKING_DEMO=$ENABLE_BANKING_DEMO
EOF
chmod 0600 /etc/default/dd-lab-python

cat > /etc/systemd/system/dd-lab-python.service <<'EOF'
[Unit]
Description=dd-lab Python demo application
After=network-online.target datadog-agent.service
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
EnvironmentFile=/etc/default/dd-lab-python
WorkingDirectory=/opt/dd-lab/application
ExecStart=/opt/dd-lab/application/.venv/bin/opentelemetry-instrument /opt/dd-lab/application/.venv/bin/python app.py
Restart=always
RestartSec=5
StandardOutput=append:/var/log/dd-lab/python-app.log
StandardError=append:/var/log/dd-lab/python-app.log

[Install]
WantedBy=multi-user.target
EOF

chown -R root:dd-agent /etc/datadog-agent/conf.d
chmod 0640 /etc/datadog-agent/conf.d/common_logs.d/conf.yaml
systemctl daemon-reload
systemctl enable --now dd-lab-python
systemctl restart datadog-agent
systemctl is-active datadog-agent

mark_bootstrap_complete
