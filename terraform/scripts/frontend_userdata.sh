#!/bin/bash -e
set -e

exec > >(sudo tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

# bootstrap revision: ${BOOTSTRAP_REVISION}

AWS_REGION="${AWS_REGION}"
BOOTSTRAP_PREFIX="${BOOTSTRAP_PREFIX}"
DATADOG_COMMON_CONFIG_KEY="${DATADOG_COMMON_CONFIG_KEY}"
DD_API_KEY_SECRET_ARN="${DD_API_KEY_SECRET_ARN}"
DD_HOSTNAME="${DD_HOSTNAME}"
DD_ENV="${DD_ENV}"
DD_SITE="${DD_SITE}"
DD_VERSION="${DD_VERSION}"
FRONTEND_APP_PORT="${FRONTEND_APP_PORT}"
PROJECT_NAME="${PROJECT_NAME}"
S3_BUCKET="${S3_BUCKET}"
ENABLE_BANKING_DEMO="${ENABLE_BANKING_DEMO}"
BANKING_UI_ARCHIVE_S3_KEY="${BANKING_UI_ARCHIVE_S3_KEY}"
ENABLE_RUM="${ENABLE_RUM}"
RUM_APPLICATION_ID="${RUM_APPLICATION_ID}"
RUM_CLIENT_TOKEN="${RUM_CLIENT_TOKEN}"

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

install_nodejs() {
  echo "Installing Node.js 20 LTS..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
  node --version
  npm --version
}

hostnamectl set-hostname "$DD_HOSTNAME"

mkdir -p /home/ubuntu/.ssh
echo "${COMMON_PUBLIC_KEY}" >> /home/ubuntu/.ssh/authorized_keys
chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys

wait_for_apt
apt-get update
apt-get install -y acl auditd ca-certificates curl jq nginx rsyslog unzip
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

install -d /var/www/html

if [[ "$ENABLE_BANKING_DEMO" == "true" ]]; then
  echo "Building banking UI..."
  install_nodejs

  install -d /opt/dd-lab/banking-ui
  aws s3 cp "s3://${S3_BUCKET}/${BANKING_UI_ARCHIVE_S3_KEY}" /tmp/banking-ui.zip
  unzip -qo /tmp/banking-ui.zip -d /opt/dd-lab/banking-ui
  chown -R ubuntu:ubuntu /opt/dd-lab/banking-ui

  sudo -u ubuntu env \
    VITE_ENABLE_RUM="$ENABLE_RUM" \
    VITE_RUM_APPLICATION_ID="$RUM_APPLICATION_ID" \
    VITE_RUM_CLIENT_TOKEN="$RUM_CLIENT_TOKEN" \
    VITE_DD_SITE="$DD_SITE" \
    VITE_DD_ENV="$DD_ENV" \
    VITE_DD_VERSION="$DD_VERSION" \
    bash -lc 'cd /opt/dd-lab/banking-ui && npm ci && npm run build'

  rm -rf /var/www/html/*
  cp -a /opt/dd-lab/banking-ui/dist/. /var/www/html/

  cat > /etc/nginx/sites-available/default <<'NGINX_EOF'
server {
    listen __FRONTEND_PORT__ default_server;
    listen [::]:__FRONTEND_PORT__ default_server;
    root /var/www/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX_EOF
  sed -i "s/__FRONTEND_PORT__/$FRONTEND_APP_PORT/g" /etc/nginx/sites-available/default
else
  cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <title>${PROJECT_NAME} Frontend</title>
</head>
<body>
  <h1>${PROJECT_NAME}</h1>
  <p>nginx placeholder frontend.</p>
</body>
</html>
EOF

  sed -i "s/listen 80 default_server;/listen $FRONTEND_APP_PORT default_server;/" /etc/nginx/sites-available/default
  sed -i "s/listen \\[::\\]:80 default_server;/listen [::]:$FRONTEND_APP_PORT default_server;/" /etc/nginx/sites-available/default
fi

systemctl enable --now nginx

ENABLE_DDOT="false"
ENABLE_SSI="false"
export AWS_REGION DD_API_KEY_SECRET_ARN DD_SITE DD_ENV ENABLE_DDOT ENABLE_SSI
run_bootstrap_fetch

install -d /etc/datadog-agent/conf.d/frontend_logs.d
cat > /etc/datadog-agent/conf.d/frontend_logs.d/conf.yaml <<EOF
logs:
  - type: file
    path: /var/log/nginx/access.log
    service: ${PROJECT_NAME}-frontend
    source: nginx
  - type: file
    path: /var/log/nginx/error.log
    service: ${PROJECT_NAME}-frontend
    source: nginx
EOF

chown -R root:dd-agent /etc/datadog-agent/conf.d
chmod 0640 /etc/datadog-agent/conf.d/frontend_logs.d/conf.yaml
/usr/local/sbin/dd-lab-configure-log-permissions || true
systemctl restart datadog-agent
systemctl is-active datadog-agent

mark_bootstrap_complete
