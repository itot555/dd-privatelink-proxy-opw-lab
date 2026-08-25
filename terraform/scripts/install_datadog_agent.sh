#!/usr/bin/env bash
# 共通 Datadog Agent インストール（optional: SSI / DDOT）
# 設定ファイルは S3 から取得したローカルパスを指定する
set -euo pipefail

: "${AWS_REGION:?AWS_REGION is required}"
: "${DD_API_KEY_SECRET_ARN:?DD_API_KEY_SECRET_ARN is required}"
: "${DD_SITE:?DD_SITE is required}"
: "${DATADOG_COMMON_CONFIG_FILE:?DATADOG_COMMON_CONFIG_FILE is required}"
: "${DATADOG_COMMON_LOGS_CONFIG_FILE:?DATADOG_COMMON_LOGS_CONFIG_FILE is required}"
: "${LOG_PERMISSIONS_SCRIPT_FILE:?LOG_PERMISSIONS_SCRIPT_FILE is required}"

ENABLE_DDOT="${ENABLE_DDOT:-false}"
ENABLE_SSI="${ENABLE_SSI:-false}"
SSI_LIBRARIES="${SSI_LIBRARIES:-}"
DD_ENV="${DD_ENV:-}"

export AWS_DEFAULT_REGION="$AWS_REGION"

DD_API_KEY=$(aws secretsmanager get-secret-value \
  --secret-id "$DD_API_KEY_SECRET_ARN" \
  --query SecretString \
  --output text)

INSTALL_ENV=(DD_API_KEY="$DD_API_KEY" DD_SITE="$DD_SITE" DD_AGENT_MAJOR_VERSION=7)

if [[ -n "$DD_ENV" ]]; then
  INSTALL_ENV+=(DD_ENV="$DD_ENV")
fi

if [[ "$ENABLE_DDOT" == "true" ]]; then
  INSTALL_ENV+=(DD_OTELCOLLECTOR_ENABLED=true)
fi

if [[ "$ENABLE_SSI" == "true" ]]; then
  INSTALL_ENV+=(
    DD_APM_INSTRUMENTATION_ENABLED=host
    DD_APM_INSTRUMENTATION_LIBRARIES="$SSI_LIBRARIES"
  )
fi

env "${INSTALL_ENV[@]}" bash -c "$(curl -fsSL https://install.datadoghq.com/scripts/install_script_agent7.sh)"

cat "$DATADOG_COMMON_CONFIG_FILE" >> /etc/datadog-agent/datadog.yaml

if [[ "$ENABLE_DDOT" == "true" ]]; then
  if [[ -n "${DATADOG_DDOT_CONFIG_FILE:-}" && -f "$DATADOG_DDOT_CONFIG_FILE" ]]; then
    cat "$DATADOG_DDOT_CONFIG_FILE" >> /etc/datadog-agent/datadog.yaml
  fi

  if [[ -n "${OTEL_CONFIG_FILE:-}" && -f "$OTEL_CONFIG_FILE" ]]; then
    cp "$OTEL_CONFIG_FILE" /etc/datadog-agent/otel-config.yaml
    chmod 0640 /etc/datadog-agent/otel-config.yaml
    chown root:dd-agent /etc/datadog-agent/otel-config.yaml
  fi
fi

install -d /etc/datadog-agent/conf.d/common_logs.d
cp "$DATADOG_COMMON_LOGS_CONFIG_FILE" /etc/datadog-agent/conf.d/common_logs.d/conf.yaml

cp "$LOG_PERMISSIONS_SCRIPT_FILE" /usr/local/sbin/dd-lab-configure-log-permissions
chmod 0755 /usr/local/sbin/dd-lab-configure-log-permissions

chown -R root:dd-agent /etc/datadog-agent/conf.d
chmod 0640 /etc/datadog-agent/conf.d/common_logs.d/conf.yaml
/usr/local/sbin/dd-lab-configure-log-permissions || true

systemctl restart datadog-agent

if [[ "$ENABLE_DDOT" == "true" ]]; then
  for attempt in $(seq 1 30); do
    if datadog-agent status 2>/dev/null | grep -q "OTel Agent"; then
      break
    fi
    if [[ "$attempt" -eq 30 ]]; then
      echo "DDOT Collector did not become ready" >&2
      exit 1
    fi
    sleep 5
  done
fi
