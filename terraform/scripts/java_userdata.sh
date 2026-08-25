#!/bin/bash -e
# Java EC2 — Tenant Public Subnet（Synthetics Private Location Worker 同居）
set -e

exec > >(sudo tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

# bootstrap revision: ${BOOTSTRAP_REVISION}

APP_SERVICE="${APP_SERVICE}"
APP_VERSION="${APP_VERSION}"
AWS_REGION="${AWS_REGION}"
BASTION_SSH_SECRET_ARN="${BASTION_SSH_SECRET_ARN}"
BOOTSTRAP_PREFIX="${BOOTSTRAP_PREFIX}"
DATADOG_COMMON_CONFIG_KEY="${DATADOG_COMMON_CONFIG_KEY}"
DATABASE_SECRET_ARN="${DATABASE_SECRET_ARN}"
DD_API_KEY_SECRET_ARN="${DD_API_KEY_SECRET_ARN}"
DD_ENV="${DD_ENV}"
DD_SITE="${DD_SITE}"
DD_HOSTNAME="${DD_HOSTNAME}"
JAVA_APP_PORT="${JAVA_APP_PORT}"
PROXY_ENDPOINT_DNS="${PROXY_ENDPOINT_DNS}"
PRIVATE_LOCATION_CONCURRENCY="${PRIVATE_LOCATION_CONCURRENCY}"
PRIVATE_LOCATION_IMAGE="${PRIVATE_LOCATION_IMAGE}"
PRIVATE_LOCATION_SECRET_ARN="${PRIVATE_LOCATION_SECRET_ARN}"
PROJECT_NAME="${PROJECT_NAME}"
PROXY_PORT="${PROXY_PORT}"
PYTHON_APP_PORT="${PYTHON_APP_PORT}"
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
apt-get install -y acl auditd ca-certificates curl jq rsyslog unzip docker.io maven openjdk-21-jdk
systemctl enable --now auditd || true
systemctl enable --now rsyslog || true
systemctl enable --now docker

curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
rm -rf /tmp/aws
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install --update

aws s3 cp "s3://${S3_BUCKET}/${BOOTSTRAP_PREFIX}/userdata_common.sh" /tmp/userdata_common.sh
chmod 0755 /tmp/userdata_common.sh
# shellcheck source=/dev/null
source /tmp/userdata_common.sh

wait_for_outbound

aws secretsmanager get-secret-value \
  --secret-id "$BASTION_SSH_SECRET_ARN" \
  --query SecretString \
  --output text > /home/ubuntu/.ssh/id_rsa
chmod 600 /home/ubuntu/.ssh/id_rsa
chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa

ENABLE_DDOT="false"
ENABLE_SSI="${ENABLE_JAVA_SSI}"
SSI_LIBRARIES="${SSI_LIBRARIES}"
export AWS_REGION DD_API_KEY_SECRET_ARN DD_SITE DD_ENV ENABLE_SSI SSI_LIBRARIES ENABLE_DDOT
run_bootstrap_fetch

install -d -o ubuntu -g ubuntu /opt/dd-lab
aws s3 cp "s3://${S3_BUCKET}/${APP_ARCHIVE_S3_KEY}" /opt/dd-lab/application.zip
unzip -q /opt/dd-lab/application.zip -d /opt/dd-lab/application
chown -R ubuntu:ubuntu /opt/dd-lab/application

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
PYTHON_API_URL=http://$PYTHON_PRIVATE_IP:$PYTHON_APP_PORT
SERVER_PORT=$JAVA_APP_PORT
DD_SERVICE=$APP_SERVICE
DD_ENV=$DD_ENV
DD_VERSION=$APP_VERSION
DD_LOGS_INJECTION=true
DD_AGENT_HOST=127.0.0.1
BANKING_DEMO_ENABLED=$ENABLE_BANKING_DEMO
DEMO_BANK_PASSWORD=$DEMO_BANK_PASSWORD
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

# PL Worker コンテナは非 root（uid 501）で動作するため、config は world-readable にする
# （0600 だと EACCES → Restarting ループになる）
install -d -m 0755 /etc/datadog-private-location
aws secretsmanager get-secret-value \
  --secret-id "$PRIVATE_LOCATION_SECRET_ARN" \
  --query SecretString \
  --output text > /etc/datadog-private-location/worker-config.json
# Squid 等の HTTP forward proxy 経由では CONNECT トンネルが必須
# https://docs.datadoghq.com/synthetics/private_locations/configuration/?tab=docker#proxy-configuration
jq --arg proxy "http://${PROXY_ENDPOINT_DNS}:${PROXY_PORT}" \
  '. + {proxyDatadog: $proxy, proxyEnableConnectTunnel: true}' \
  /etc/datadog-private-location/worker-config.json \
  > /etc/datadog-private-location/worker-config.json.tmp
mv /etc/datadog-private-location/worker-config.json.tmp /etc/datadog-private-location/worker-config.json
chmod 0644 /etc/datadog-private-location/worker-config.json

docker pull "$PRIVATE_LOCATION_IMAGE"
docker rm -f datadog-private-location 2>/dev/null || true
docker run -d \
  --name datadog-private-location \
  --restart unless-stopped \
  -e "DATADOG_WORKER_CONCURRENCY=$PRIVATE_LOCATION_CONCURRENCY" \
  -v /etc/datadog-private-location/worker-config.json:/etc/datadog/synthetics-check-runner.json:ro \
  "$PRIVATE_LOCATION_IMAGE" \
  --proxyEnableConnectTunnel=true

chown -R root:dd-agent /etc/datadog-agent/conf.d
chmod 0640 /etc/datadog-agent/conf.d/common_logs.d/conf.yaml
/usr/local/sbin/dd-lab-configure-log-permissions || true
systemctl daemon-reload
systemctl enable --now dd-lab-java
systemctl restart datadog-agent
systemctl is-active datadog-agent

mark_bootstrap_complete
