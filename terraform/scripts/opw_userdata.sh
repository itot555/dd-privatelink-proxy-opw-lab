#!/bin/bash -e
set -e

exec > >(sudo tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

# bootstrap revision: ${BOOTSTRAP_REVISION}

AWS_REGION="${AWS_REGION}"
BOOTSTRAP_PREFIX="${BOOTSTRAP_PREFIX}"
DATADOG_COMMON_CONFIG_KEY="${DATADOG_COMMON_CONFIG_KEY}"
DD_API_KEY_SECRET_ARN="${DD_API_KEY_SECRET_ARN}"
DD_HOSTNAME="${DD_HOSTNAME}"
DD_OP_PIPELINE_ID="${DD_OP_PIPELINE_ID}"
DD_OP_TRACES_PIPELINE_ID="${DD_OP_TRACES_PIPELINE_ID}"
DD_SITE="${DD_SITE}"
OPW_LOGS_PORT="${OPW_LOGS_PORT}"
OPW_TRACES_PORT="${OPW_TRACES_PORT}"
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

install_opw_worker_unit() {
  local unit_name="$1"
  local pipeline_id="$2"
  local listen_port="$3"
  local description="$4"
  local after_unit="$5"
  local data_dir="/var/lib/$${unit_name}"
  local env_file="/etc/default/$${unit_name}"

  if [[ -z "$pipeline_id" ]]; then
    echo "pipeline_id が未設定のため $${unit_name} Worker をスキップします"
    return 0
  fi

  if ! id observability-pipelines-worker >/dev/null 2>&1; then
    echo "observability-pipelines-worker ユーザーが存在しないため $${unit_name} をスキップします" >&2
    return 1
  fi

  install -d -o observability-pipelines-worker -g observability-pipelines-worker "$data_dir"

  cat > "$env_file" <<EOF
DD_API_KEY=$DD_API_KEY
DD_OP_PIPELINE_ID=$pipeline_id
DD_SITE=$DD_SITE
DD_OP_SOURCE_DATADOG_AGENT_ADDRESS=0.0.0.0:$listen_port
DD_OP_DATA_DIR=$data_dir
EOF
  chmod 640 "$env_file"

  cat > "/lib/systemd/system/$${unit_name}.service" <<EOF
[Unit]
Description=$description
Documentation=https://docs.datadoghq.com/observability_pipelines/
After=network-online.target $${after_unit}
Wants=network-online.target

[Service]
User=observability-pipelines-worker
Group=observability-pipelines-worker
ExecStart=/usr/bin/observability-pipelines-worker run
Restart=always
AmbientCapabilities=CAP_NET_BIND_SERVICE
EnvironmentFile=-$env_file

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable "$unit_name"
  systemctl restart "$unit_name"
}

install_opw_logs_worker() {
  install_opw_worker_unit \
    "op-logs" \
    "$1" \
    "$2" \
    "Observability Pipelines Worker (Logs)" \
    ""
}

install_opw_traces_worker() {
  install_opw_worker_unit \
    "op-traces" \
    "$1" \
    "$2" \
    "Observability Pipelines Worker (Traces)" \
    "op-logs.service"
}

hostnamectl set-hostname "$DD_HOSTNAME"

mkdir -p /home/ubuntu/.ssh
echo "${COMMON_PUBLIC_KEY}" >> /home/ubuntu/.ssh/authorized_keys
chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys

wait_for_apt
apt-get update
apt-get install -y acl auditd ca-certificates curl jq rsyslog unzip
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

DD_API_KEY=$(aws secretsmanager get-secret-value \
  --secret-id "$DD_API_KEY_SECRET_ARN" \
  --query SecretString \
  --output text)

if [[ -z "$DD_OP_PIPELINE_ID" ]]; then
  echo "DD_OP_PIPELINE_ID が未設定のため OPW Logs Worker インストールをスキップします"
else
  DD_API_KEY="$DD_API_KEY" \
  DD_OP_PIPELINE_ID="$DD_OP_PIPELINE_ID" \
  DD_SITE="$DD_SITE" \
    bash -c "$(curl -fsSL https://install.datadoghq.com/scripts/install_script_op_worker2.sh)"

  # パッケージ既定の observability-pipelines-worker は op-logs に置き換える
  systemctl disable --now observability-pipelines-worker 2>/dev/null || true
  install_opw_logs_worker "$DD_OP_PIPELINE_ID" "$OPW_LOGS_PORT"
fi

install_opw_traces_worker "$DD_OP_TRACES_PIPELINE_ID" "$OPW_TRACES_PORT"

ENABLE_DDOT="false"
ENABLE_SSI="false"
export AWS_REGION DD_API_KEY_SECRET_ARN DD_SITE ENABLE_DDOT ENABLE_SSI
run_bootstrap_fetch

systemctl is-active datadog-agent || true
systemctl is-active op-logs || true
systemctl is-active op-traces || true

mark_bootstrap_complete
