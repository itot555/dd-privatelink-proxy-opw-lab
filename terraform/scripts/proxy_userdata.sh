#!/bin/bash -e
set -e

exec > >(sudo tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

# bootstrap revision: ${BOOTSTRAP_REVISION}

AWS_REGION="${AWS_REGION}"
BOOTSTRAP_PREFIX="${BOOTSTRAP_PREFIX}"
DATADOG_COMMON_CONFIG_KEY="${DATADOG_COMMON_CONFIG_KEY}"
DD_API_KEY_SECRET_ARN="${DD_API_KEY_SECRET_ARN}"
DD_HOSTNAME="${DD_HOSTNAME}"
DD_SITE="${DD_SITE}"
PROXY_PORT="${PROXY_PORT}"
S3_BUCKET="${S3_BUCKET}"

export AWS_DEFAULT_REGION="$AWS_REGION"
export DEBIAN_FRONTEND=noninteractive

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

mkdir -p /home/ubuntu/.ssh
echo "${COMMON_PUBLIC_KEY}" >> /home/ubuntu/.ssh/authorized_keys
chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys

wait_for_apt
apt-get update
apt-get install -y acl auditd ca-certificates curl jq rsyslog squid unzip
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

# https://docs.datadoghq.com/agent/configuration/proxy_squid/?tab=linux
cat > /etc/squid/squid.conf <<EOF
http_port 0.0.0.0:$PROXY_PORT

acl local src 127.0.0.1/32
acl manager proto cache_object
acl SSL_ports port 443
acl CONNECT method CONNECT
acl Datadog dstdomain .$DD_SITE

http_access allow local manager
http_access deny manager
http_access deny CONNECT !SSL_ports
http_access allow Datadog
http_access deny all

access_log stdio:/var/log/squid/access.log
cache_log /var/log/squid/cache.log
EOF

systemctl enable --now squid
usermod -a -G proxy dd-agent || true

ENABLE_DDOT="false"
ENABLE_SSI="false"
export AWS_REGION DD_API_KEY_SECRET_ARN DD_SITE ENABLE_DDOT ENABLE_SSI
run_bootstrap_fetch

install -d /etc/datadog-agent/conf.d/squid.d
cat > /etc/datadog-agent/conf.d/squid.d/conf.yaml <<EOF
init_config:

instances:
  - name: $DD_HOSTNAME
    host: localhost
    port: $PROXY_PORT
EOF

chown -R root:dd-agent /etc/datadog-agent/conf.d
chmod 0640 \
  /etc/datadog-agent/conf.d/common_logs.d/conf.yaml \
  /etc/datadog-agent/conf.d/squid.d/conf.yaml
/usr/local/sbin/dd-lab-configure-log-permissions || true
systemctl restart datadog-agent
systemctl is-active datadog-agent

mark_bootstrap_complete
