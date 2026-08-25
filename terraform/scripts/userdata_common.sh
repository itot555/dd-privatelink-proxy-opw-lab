#!/usr/bin/env bash
# EC2 userdata から source する共通関数（S3 bootstrap/ にも配置）
set -euo pipefail

wait_for_outbound() {
  echo "Waiting for outbound HTTPS connectivity..."
  for attempt in $(seq 1 60); do
    if curl -fsS --max-time 5 https://aws.amazon.com >/dev/null 2>&1; then
      echo "Outbound connectivity OK (attempt ${attempt})"
      return 0
    fi
    sleep 5
  done
  echo "ERROR: outbound connectivity unavailable after 5 minutes" >&2
  exit 1
}

run_bootstrap_fetch() {
  : "${S3_BUCKET:?S3_BUCKET is required}"
  : "${BOOTSTRAP_PREFIX:?BOOTSTRAP_PREFIX is required}"
  : "${DATADOG_COMMON_CONFIG_KEY:?DATADOG_COMMON_CONFIG_KEY is required}"
  : "${DD_API_KEY_SECRET_ARN:?DD_API_KEY_SECRET_ARN is required}"
  : "${DD_SITE:?DD_SITE is required}"

  # 子プロセス（bootstrap_fetch.sh / install_datadog_agent.sh）へ渡す
  export S3_BUCKET BOOTSTRAP_PREFIX DATADOG_COMMON_CONFIG_KEY
  export AWS_REGION="${AWS_REGION:-us-east-1}"
  export AWS_DEFAULT_REGION="$AWS_REGION"
  export DD_API_KEY_SECRET_ARN DD_SITE
  export DD_ENV="${DD_ENV:-}"
  export ENABLE_DDOT="${ENABLE_DDOT:-false}"
  export ENABLE_SSI="${ENABLE_SSI:-false}"
  export SSI_LIBRARIES="${SSI_LIBRARIES:-}"

  echo "Installing Datadog Agent via bootstrap bundle (s3://${S3_BUCKET}/${BOOTSTRAP_PREFIX}/)"
  aws s3 cp "s3://${S3_BUCKET}/${BOOTSTRAP_PREFIX}/bootstrap_fetch.sh" /tmp/bootstrap_fetch.sh
  chmod 0755 /tmp/bootstrap_fetch.sh
  /tmp/bootstrap_fetch.sh
  echo "Datadog Agent bootstrap script finished"
}

mark_bootstrap_complete() {
  touch /tmp/bootstrap-complete
  touch /var/lib/dd-lab-bootstrap-complete
  echo "Bootstrapping complete."
}
