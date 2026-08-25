#!/usr/bin/env bash
# S3 から bootstrap アーティファクトを取得し Datadog Agent インストール用 env を設定する
set -euo pipefail

: "${S3_BUCKET:?S3_BUCKET is required}"
: "${BOOTSTRAP_PREFIX:?BOOTSTRAP_PREFIX is required}"
: "${DATADOG_COMMON_CONFIG_KEY:?DATADOG_COMMON_CONFIG_KEY is required}"

fetch_bootstrap() {
  aws s3 cp "s3://${S3_BUCKET}/${BOOTSTRAP_PREFIX}/${1}" "${2}"
}

fetch_bootstrap "install_datadog_agent.sh" /tmp/install_datadog_agent.sh
chmod 0755 /tmp/install_datadog_agent.sh
aws s3 cp "s3://${S3_BUCKET}/${DATADOG_COMMON_CONFIG_KEY}" /tmp/datadog-common.yaml
fetch_bootstrap "datadog-common-logs.yaml" /tmp/datadog-common-logs.yaml
fetch_bootstrap "configure_log_permissions.sh" /tmp/configure_log_permissions.sh
chmod 0755 /tmp/configure_log_permissions.sh

export DATADOG_COMMON_CONFIG_FILE=/tmp/datadog-common.yaml
export DATADOG_COMMON_LOGS_CONFIG_FILE=/tmp/datadog-common-logs.yaml
export LOG_PERMISSIONS_SCRIPT_FILE=/tmp/configure_log_permissions.sh

if [[ "${ENABLE_DDOT:-false}" == "true" ]]; then
  fetch_bootstrap "datadog-ddot.yaml" /tmp/datadog-ddot.yaml
  fetch_bootstrap "otel-config.yaml" /tmp/otel-config.yaml
  export DATADOG_DDOT_CONFIG_FILE=/tmp/datadog-ddot.yaml
  export OTEL_CONFIG_FILE=/tmp/otel-config.yaml
fi

/tmp/install_datadog_agent.sh
