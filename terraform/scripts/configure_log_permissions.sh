#!/usr/bin/env bash
set -euo pipefail

warn() {
  printf 'WARNING: %s\n' "$*" >&2
}

# Ubuntuの標準ログはgroup権限で読み取る。役割によって存在しないgroupは許容する。
for log_group in adm systemd-journal proxy; do
  if ! usermod -a -G "$log_group" dd-agent; then
    warn "dd-agentを${log_group} groupへ追加できませんでした。処理を継続します。"
  fi
done

# 全サーバーで同じパスを対象にする。存在しないパスやdefault ACLを設定できない
# 通常ファイルではsetfaclが失敗するが、個別のwarningだけを残して処理を継続する。
log_paths=(
  /var/log/syslog
  /var/log/auth.log
  /var/log/kern.log
  /var/log/audit
  /var/log/cloud-init.log
  /var/log/cloud-init-output.log
  /var/log/dd-lab
  /var/log/squid
  /var/log/journal
)

for log_path in "${log_paths[@]}"; do
  if ! setfacl -R -m u:dd-agent:rX "$log_path"; then
    warn "${log_path}へdd-agentの読み取りACLを設定できませんでした。処理を継続します。"
  fi

  if ! setfacl -R -d -m u:dd-agent:rX "$log_path"; then
    warn "${log_path}へdd-agentのdefault ACLを設定できませんでした。処理を継続します。"
  fi
done

exit 0
