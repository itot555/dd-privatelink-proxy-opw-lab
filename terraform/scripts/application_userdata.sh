#!/usr/bin/env bash
set -euo pipefail

exec > >(tee /var/log/dd-lab-bootstrap.log | logger -t dd-lab-bootstrap -s 2>/dev/console) 2>&1

APP_ROLE="${APP_ROLE}"
APP_SERVICE="${APP_SERVICE}"
APP_VERSION="${APP_VERSION}"
AWS_REGION="${AWS_REGION}"
DD_ENV="${DD_ENV}"
DD_SITE="${DD_SITE}"
NLB_DNS_NAME="${NLB_DNS_NAME}"
PROJECT_NAME="${PROJECT_NAME}"
PROXY_PORT="${PROXY_PORT}"
OPW_LOGS_PORT="${OPW_LOGS_PORT}"
RDS_ENDPOINT="${RDS_ENDPOINT}"
DATABASE_NAME="${DATABASE_NAME}"
DATABASE_SECRET_ARN="${DATABASE_SECRET_ARN}"
DD_API_KEY_SECRET_ARN="${DD_API_KEY_SECRET_ARN}"
DATADOG_COMMON_CONFIG_B64="${DATADOG_COMMON_CONFIG_B64}"
DATADOG_COMMON_LOGS_CONFIG_B64="${DATADOG_COMMON_LOGS_CONFIG_B64}"
LOG_PERMISSIONS_SCRIPT_B64="${LOG_PERMISSIONS_SCRIPT_B64}"

export DEBIAN_FRONTEND=noninteractive
export AWS_DEFAULT_REGION="$AWS_REGION"

hostnamectl set-hostname "$PROJECT_NAME-$APP_ROLE"

apt-get update
apt-get install -y \
  acl auditd ca-certificates curl jq rsyslog unzip

systemctl enable --now auditd || true
systemctl enable --now rsyslog || true

if [[ "$APP_ROLE" == "java" ]]; then
  apt-get install -y docker.io maven openjdk-21-jdk
  systemctl enable --now docker
  INSTRUMENTATION_LIBRARY="java:1"
else
  apt-get install -y postgresql-client python3 python3-pip python3-venv
  INSTRUMENTATION_LIBRARY="python:4"
fi

curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
rm -rf /tmp/aws
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install --update

DD_API_KEY=$(aws secretsmanager get-secret-value \
  --secret-id "$DD_API_KEY_SECRET_ARN" \
  --query SecretString \
  --output text)

DD_API_KEY="$DD_API_KEY" \
DD_SITE="$DD_SITE" \
DD_APM_INSTRUMENTATION_ENABLED=host \
DD_APM_INSTRUMENTATION_LIBRARIES="$INSTRUMENTATION_LIBRARY" \
DD_ENV="$DD_ENV" \
  bash -c "$(curl -fsSL https://install.datadoghq.com/scripts/install_script_agent7.sh)"

printf '%s' "$DATADOG_COMMON_CONFIG_B64" \
  | base64 --decode >> /etc/datadog-agent/datadog.yaml

install -d /etc/datadog-agent/conf.d/common_logs.d
printf '%s' "$DATADOG_COMMON_LOGS_CONFIG_B64" \
  | base64 --decode > /etc/datadog-agent/conf.d/common_logs.d/conf.yaml

printf '%s' "$LOG_PERMISSIONS_SCRIPT_B64" \
  | base64 --decode > /usr/local/sbin/dd-lab-configure-log-permissions
chmod 0755 /usr/local/sbin/dd-lab-configure-log-permissions

cat >> /etc/datadog-agent/datadog.yaml <<EOF
secret_backend_command: /etc/datadog-agent/secret_backend.sh
EOF

cat > /etc/datadog-agent/secret_backend.sh <<'SECRET_BACKEND'
#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
SECRET=$(aws secretsmanager get-secret-value \
  --region "${AWS_REGION}" \
  --secret-id "${DATABASE_SECRET_ARN}" \
  --query SecretString \
  --output text)

RESULT="{}"
while IFS= read -r HANDLE; do
  case "$HANDLE" in
    dbm_password)
      VALUE=$(jq -r '.dbm_password' <<<"$SECRET")
      ;;
    *)
      VALUE=""
      ;;
  esac

  RESULT=$(jq \
    --arg handle "$HANDLE" \
    --arg value "$VALUE" \
    '. + {($handle): {"value": $value}}' <<<"$RESULT")
done < <(jq -r '.secrets[]' <<<"$INPUT")

printf '%s\n' "$RESULT"
SECRET_BACKEND

chown root:dd-agent /etc/datadog-agent/secret_backend.sh
chmod 0750 /etc/datadog-agent/secret_backend.sh

install -d -o ubuntu -g ubuntu /opt/dd-lab
aws s3 cp \
  "s3://${S3_BUCKET}/${APP_ARCHIVE_S3_KEY}" \
  /opt/dd-lab/application.zip
unzip -q /opt/dd-lab/application.zip -d /opt/dd-lab/application
chown -R ubuntu:ubuntu /opt/dd-lab/application

if [[ "$APP_ROLE" == "java" ]]; then
  install -d /var/log/dd-lab
  chown ubuntu:dd-agent /var/log/dd-lab
  chmod 0775 /var/log/dd-lab

  sudo -u ubuntu bash -lc "cd /opt/dd-lab/application && mvn -q -DskipTests package"

  PYTHON_PRIVATE_IP=""
  for attempt in $(seq 1 60); do
    PYTHON_PRIVATE_IP=$(aws ec2 describe-instances \
      --filters \
        "Name=tag:Project,Values=$PROJECT_NAME" \
        "Name=tag:Role,Values=python" \
        "Name=instance-state-name,Values=running" \
      --query 'Reservations[].Instances[].PrivateIpAddress | [0]' \
      --output text)
    if [[ -n "$PYTHON_PRIVATE_IP" && "$PYTHON_PRIVATE_IP" != "None" ]]; then
      break
    fi
    if [[ "$attempt" -eq 60 ]]; then
      echo "Python application instance was not discovered" >&2
      exit 1
    fi
    sleep 10
  done

  cat > /etc/default/dd-lab-java <<EOF
PYTHON_API_URL=http://$PYTHON_PRIVATE_IP:${PYTHON_APP_PORT}
SERVER_PORT=${JAVA_APP_PORT}
DD_SERVICE=$APP_SERVICE
DD_ENV=$DD_ENV
DD_VERSION=$APP_VERSION
DD_LOGS_INJECTION=true
DD_AGENT_HOST=127.0.0.1
EOF

  cat > /etc/systemd/system/dd-lab-java.service <<'EOF'
[Unit]
Description=dd-lab Java demo application
After=network-online.target datadog-agent.service
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
EnvironmentFile=/etc/default/dd-lab-java
WorkingDirectory=/opt/dd-lab/application
ExecStart=/usr/bin/java -jar /opt/dd-lab/application/target/dd-lab-java.jar
Restart=always
RestartSec=5
StandardOutput=append:/var/log/dd-lab/java-app.log
StandardError=append:/var/log/dd-lab/java-app.log

[Install]
WantedBy=multi-user.target
EOF

  install -d -m 0755 /etc/datadog-private-location
  aws secretsmanager get-secret-value \
    --secret-id "${PRIVATE_LOCATION_SECRET_ARN}" \
    --query SecretString \
    --output text > /etc/datadog-private-location/worker-config.json
  jq --arg proxy "http://${NLB_DNS_NAME}:${PROXY_PORT}" \
    '. + {proxyDatadog: $proxy, proxyEnableConnectTunnel: true}' \
    /etc/datadog-private-location/worker-config.json \
    > /etc/datadog-private-location/worker-config.json.tmp
  mv /etc/datadog-private-location/worker-config.json.tmp /etc/datadog-private-location/worker-config.json
  chmod 0644 /etc/datadog-private-location/worker-config.json

  docker pull "${PRIVATE_LOCATION_IMAGE}"
  docker rm -f datadog-private-location 2>/dev/null || true
  docker run -d \
    --name datadog-private-location \
    --restart unless-stopped \
    -e "DATADOG_WORKER_CONCURRENCY=${PRIVATE_LOCATION_CONCURRENCY}" \
    -v /etc/datadog-private-location/worker-config.json:/etc/datadog/synthetics-check-runner.json:ro \
    "${PRIVATE_LOCATION_IMAGE}" \
    --proxyEnableConnectTunnel=true

  systemctl daemon-reload
  systemctl enable --now dd-lab-java
else
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

  cat > /etc/default/dd-lab-python <<EOF
PORT=${PYTHON_APP_PORT}
DB_HOST=$RDS_ENDPOINT
DB_PORT=5432
DB_NAME=$DATABASE_NAME
DB_USER=$APP_USERNAME
DB_PASSWORD=$APP_PASSWORD
DD_SERVICE=$APP_SERVICE
DD_ENV=$DD_ENV
DD_VERSION=$APP_VERSION
DD_LOGS_INJECTION=true
DD_DBM_PROPAGATION_MODE=full
DD_AGENT_HOST=127.0.0.1
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
ExecStart=/opt/dd-lab/application/.venv/bin/ddtrace-run /opt/dd-lab/application/.venv/bin/python app.py
Restart=always
RestartSec=5
StandardOutput=append:/var/log/dd-lab/python-app.log
StandardError=append:/var/log/dd-lab/python-app.log

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now dd-lab-python
fi

chown -R root:dd-agent /etc/datadog-agent/conf.d
chmod 0640 /etc/datadog-agent/conf.d/common_logs.d/conf.yaml
/usr/local/sbin/dd-lab-configure-log-permissions || true
systemctl restart datadog-agent
touch /var/lib/dd-lab-bootstrap-complete
