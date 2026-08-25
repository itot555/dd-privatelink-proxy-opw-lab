#------------------------------------------------------------------------------
# apply 後の確認手順（Datadog PrivateLink verification_steps / Squid / OPW step* 準拠）
# 主 output: terraform output verification_steps
#------------------------------------------------------------------------------

output "verification_steps" {
  description = "apply 後の疎通確認手順（terraform output verification_steps で表示）"
  value       = <<-EOT

    ============================================================
    ${local.project_name} — apply 後の確認手順
    ============================================================

    詳細 runbook:
      terraform output ssh_access_guide
      terraform output step1_troubleshoot_bootstrap
      terraform output step2_verify_apps
      terraform output step3_verify_datadog_agent
      terraform output step5_synthetics_e2e
      terraform output step5_dbm_correlation_checklist

    ── 1. SSH 接続 ───────────────────────────────────────────
    # Java bastion（Public）
    ssh -i ${local.ssh_key_path} ubuntu@${aws_instance.java.public_ip}

    # Python（Java 経由 ProxyJump）
    ssh -i ${local.ssh_key_path} -J ubuntu@${aws_instance.java.public_ip} ubuntu@${aws_instance.python.private_ip}

    # Squid / OPW（Java 経由 + VPC Peering）
    ssh -i ${local.ssh_key_path} -J ubuntu@${aws_instance.java.public_ip} ubuntu@${values(aws_instance.proxy)[0].private_ip}
    ssh -i ${local.ssh_key_path} -J ubuntu@${aws_instance.java.public_ip} ubuntu@${values(aws_instance.opw)[0].private_ip}

    秘密鍵: ${local.ssh_key_path}

    ── 0. bootstrap 失敗時（最初に確認） ─────────────────────
    # 全 EC2 共通ログ: /var/log/user-data.log
    sudo tail -100 /var/log/user-data.log
    ls -la /tmp/bootstrap-complete

    # Agent サービス
    sudo systemctl status datadog-agent --no-pager
    sudo tail -50 /var/log/datadog/agent.log

    # userdata 再実行が必要な場合（bootstrap 修正後）:
    #   terraform apply -replace=aws_instance.java
    #   terraform apply -replace=aws_instance.python  等

    ── 2. PrivateLink DNS（Squid/OPW 上で実行） ───────────────
    dig +short api.${var.dd_site}
    dig +short agent-http-intake.logs.${var.dd_site}
    dig +short trace.agent.${var.dd_site}
    # 10.x 等のプライベート IP が返れば OK

    ── 3. Datadog Agent ──────────────────────────────────────
    sudo datadog-agent status
    # Tenant Agent proxy: http://${local.tenant_datadog_proxy_dns}:${var.proxy_port}
    # OP traces: http://${local.tenant_datadog_proxy_dns}:${var.opw_traces_port}
    # OP logs:   http://${local.tenant_datadog_proxy_dns}:${var.opw_logs_port}

    ── 4. アプリ疎通（CloudFront） ───────────────────────────
    curl -sS "https://${aws_cloudfront_distribution.main.domain_name}/hello"
    curl -sS -X POST "https://${aws_cloudfront_distribution.main.domain_name}/api/items?name=terraform"

    # banking demo（enable_banking_demo=true 時）
    TOKEN=$(curl -sS -X POST "https://${aws_cloudfront_distribution.main.domain_name}/api/auth/login" \\
      -H "Content-Type: application/json" \\
      -d '{"loginId":"demo_user","password":"<demo_bank_password>"}' | jq -r .token)
    curl -sS -H "Authorization: Bearer $TOKEN" "https://${aws_cloudfront_distribution.main.domain_name}/api/accounts/balance"
    # Browser: https://${aws_cloudfront_distribution.main.domain_name}/ （React SPA）

    ── 5. Squid ログ（Proxy VPC） ────────────────────────────
    sudo tail -f /var/log/squid/access.log

    ── 6. Synthetics Private Location（Java EC2） ─────────────
    sudo docker logs -f datadog-private-location
    # Location ID: ${datadog_synthetics_private_location.main.id}
    # Synthetics API tests: terraform output synthetics_test_public_ids
    # Runbook: terraform output step5_synthetics_e2e

    ============================================================
  EOT
}

output "step5_synthetics_e2e" {
  description = "Synthetics PL テスト + 分散トレース E2E 手順"
  value       = <<-EOT

    ===== STEP 5: Synthetics E2E =====

    ## 前提
    - export DD_API_KEY / DD_APP_KEY（terraform apply 時）
    - enable_synthetics_e2e_tests = true（default）
    - Java EC2 上 PL Worker: sudo docker ps --filter name=datadog-private-location

    ## Synthetics API テスト（Terraform 管理）
    Private Location ID: ${datadog_synthetics_private_location.main.id}
%{if var.enable_synthetics_e2e_tests~}
    Tests:
      - ${datadog_synthetics_test.pl_cloudfront_hello[0].name}
      - ${datadog_synthetics_test.pl_distributed_trace[0].name}
    URL: https://${aws_cloudfront_distribution.main.domain_name}/hello
    間隔: ${var.synthetics_test_tick_seconds}s

    Datadog UI:
      Synthetics > Tests > 上記テストが Location「${local.project_name}-private-location」で green
      または Monitor Status から確認
%{else~}
    （enable_synthetics_e2e_tests=false のため Terraform テスト未作成）
%{endif~}

    ## 分散トレース E2E（手動確認）
    1. Synthetics テスト実行後（または curl /hello）、Trace Explorer を開く:
       service:${local.application_services.java} env:${var.dd_env}
    2. 最新 trace で span 階層を確認:
       ${local.application_services.java} GET /hello
         └─ ${local.application_services.python} （Python /api/items）
            └─ postgres / database span（DBM 連携）
    3. 単一 trace_id で Java → Python → DB まで繋がっていること

    参考: https://docs.datadoghq.com/tracing/trace_explorer/

    ## PL Worker トラブルシュート
    ssh -i ${local.ssh_key_path} ubuntu@${aws_instance.java.public_ip}

    # 正常: STATUS=Up（Restarting ならクラッシュループ）
    sudo docker ps -a --filter name=datadog-private-location

    # EACCES → config 権限（uid 501 が読めること）
    ls -la /etc/datadog-private-location/worker-config.json
    # 期待: -rw-r--r-- (0644)、ディレクトリ drwxr-xr-x (0755)

    # Squid 経由 Datadog 接続（proxyEnableConnectTunnel 必須）
    # https://docs.datadoghq.com/synthetics/private_locations/configuration/?tab=docker#proxy-configuration
    sudo docker logs --tail 100 datadog-private-location
    curl -sS "https://${aws_cloudfront_distribution.main.domain_name}/hello"
  EOT
}

output "step5_dbm_correlation_checklist" {
  description = "DBM query sample と APM span の相関チェックリスト"
  value       = <<-EOT

    ===== STEP 5b: DBM ↔ APM 相関チェックリスト =====

    1. /hello または Synthetics 実行でトラフィック生成
    2. Datadog > APM > Traces:
       service:${local.application_services.python} env:${var.dd_env}
    3. postgres 関連 span を開き、DBM タブ / 「View in DBM」リンクを確認
    4. Datadog > DBM > Databases > 対象 RDS インスタンス
    5. Query samples で直近クエリを選択 → 「View trace」で同一 trace に遷移できること
    6. タグ相関: env=${var.dd_env}, service=${local.application_services.python}

    RDS は Private Subnet。DBM Agent は Python EC2 から直接接続。

    参考:
      https://docs.datadoghq.com/database_monitoring/connect_dbm_and_apm/
      https://docs.datadoghq.com/database_monitoring/query_metrics/
  EOT
}

output "ssh_access_guide" {
  description = "各サーバーへの SSH アクセス方法（Java bastion 経由で Proxy/OPW へ ProxyJump）"
  value       = <<-EOT

    ===== SSH アクセス方法 =====

    秘密鍵: ${local.ssh_key_path}

    ## Java EC2（bastion / Private Location）
    ssh -i ${local.ssh_key_path} ubuntu@${aws_instance.java.public_ip}

    ## Frontend EC2
    ssh -i ${local.ssh_key_path} ubuntu@${aws_instance.frontend.public_ip}

    ## Python EC2（Java 経由）
    ssh -i ${local.ssh_key_path} -J ubuntu@${aws_instance.java.public_ip} ubuntu@${aws_instance.python.private_ip}

    ## Squid Proxy EC2（Java 経由 + VPC Peering）
%{for key, instance in aws_instance.proxy~}
    ssh -i ${local.ssh_key_path} -J ubuntu@${aws_instance.java.public_ip} ubuntu@${instance.private_ip}  # squid-${key}
%{endfor~}

    ## OPW EC2（Java 経由 + VPC Peering）
%{for key, instance in aws_instance.opw~}
    ssh -i ${local.ssh_key_path} -J ubuntu@${aws_instance.java.public_ip} ubuntu@${instance.private_ip}  # opw-${key}
%{endfor~}

    ※ Proxy VPC の Private IP は EC2 再作成（-replace）で変わる。最新は:
       terraform output opw_ssh_commands
       terraform output proxy_ssh_commands

    ## SSM Session Manager（SSH 不可時）
    aws ssm start-session --target ${aws_instance.java.id} --region us-east-1
  EOT
}

output "java_ssh_command" {
  description = "Java EC2 への SSH コマンド"
  value       = "ssh -i ${local.ssh_key_path} ubuntu@${aws_instance.java.public_ip}"
}

output "python_ssh_commands" {
  description = "Python EC2 への SSH コマンド（Java bastion 経由）"
  value = {
    python = "ssh -i ${local.ssh_key_path} -J ubuntu@${aws_instance.java.public_ip} ubuntu@${aws_instance.python.private_ip}"
  }
}

output "proxy_ssh_commands" {
  description = "Squid EC2 への SSH コマンド（Java bastion 経由）"
  value = {
    for key, instance in aws_instance.proxy :
    key => "ssh -i ${local.ssh_key_path} -J ubuntu@${aws_instance.java.public_ip} ubuntu@${instance.private_ip}"
  }
}

output "opw_ssh_commands" {
  description = "OPW EC2 への SSH コマンド（Java bastion 経由）"
  value = {
    for key, instance in aws_instance.opw :
    key => "ssh -i ${local.ssh_key_path} -J ubuntu@${aws_instance.java.public_ip} ubuntu@${instance.private_ip}"
  }
}

output "step1_troubleshoot_bootstrap" {
  description = "ステップ1: bootstrap / Datadog Agent 起動失敗のトラブルシュート"
  value       = <<-EOT

    ===== STEP 1: bootstrap トラブルシュート =====

    ## 共通（全 EC2）
    sudo tail -100 /var/log/user-data.log
    sudo cloud-init status --wait
    ls -la /tmp/bootstrap-complete /var/lib/dd-lab-bootstrap-complete

    ## Datadog Agent
    sudo systemctl status datadog-agent --no-pager
    sudo journalctl -u datadog-agent -n 100 --no-pager
    sudo tail -100 /var/log/datadog/agent.log
    sudo datadog-agent status

    ## Java (${aws_instance.java.public_ip})
    ssh -i ${local.ssh_key_path} ubuntu@${aws_instance.java.public_ip}
    sudo systemctl status dd-lab-java datadog-agent --no-pager
    sudo docker ps -a --filter name=datadog-private-location
    # PL Worker Restarting + EACCES → ls -la /etc/datadog-private-location/worker-config.json（0644 期待）
    sudo docker logs --tail 30 datadog-private-location

    ## Python (${aws_instance.python.private_ip} via bastion)
    ssh -i ${local.ssh_key_path} -J ubuntu@${aws_instance.java.public_ip} ubuntu@${aws_instance.python.private_ip}
    sudo systemctl status dd-lab-python datadog-agent --no-pager

    ## Squid
    ssh -i ${local.ssh_key_path} -J ubuntu@${aws_instance.java.public_ip} ubuntu@${values(aws_instance.proxy)[0].private_ip}
    sudo systemctl status squid datadog-agent --no-pager

    ## OPW
    ssh -i ${local.ssh_key_path} -J ubuntu@${aws_instance.java.public_ip} ubuntu@${values(aws_instance.opw)[0].private_ip}
    sudo systemctl status op-logs op-traces datadog-agent --no-pager
    sudo journalctl -u op-logs -n 100 --no-pager
    sudo journalctl -u op-traces -n 100 --no-pager

    bootstrap 修正後に EC2 を再作成する例:
      cd terraform
      terraform apply -replace=aws_instance.java -replace=aws_instance.python
  EOT
}

output "step2_verify_apps" {
  description = "ステップ2: アプリケーション疎通確認"
  value       = <<-EOT

    ===== STEP 2: アプリ疎通確認 =====

    ## CloudFront（HTTPS）
    curl -sS "https://${aws_cloudfront_distribution.main.domain_name}/"
    curl -sS "https://${aws_cloudfront_distribution.main.domain_name}/hello"
    curl -sS -X POST "https://${aws_cloudfront_distribution.main.domain_name}/api/items?name=terraform"
    curl -sS "https://${aws_cloudfront_distribution.main.domain_name}/timeout"
    curl -sS "https://${aws_cloudfront_distribution.main.domain_name}/error"

    ## ALB 直（HTTP）
    curl -sS "http://${aws_lb.public.dns_name}/hello"
  EOT
}

output "step3_verify_datadog_agent" {
  description = "ステップ3: Datadog Agent / テレメトリ経路確認"
  value       = <<-EOT

    ===== STEP 3: Datadog Agent 確認 =====

    ## Tenant（Java / Python / Frontend）
    grep -E '^(proxy:|observability_pipelines_worker:|  traces:|  logs:|  http:|  url:)' /etc/datadog-agent/datadog.yaml

    期待値:
      proxy.http  → http://${local.tenant_datadog_proxy_dns}:${var.proxy_port}
      OP traces   → http://${local.tenant_datadog_proxy_dns}:${var.opw_traces_port}
      OP logs     → http://${local.tenant_datadog_proxy_dns}:${var.opw_logs_port}

    sudo datadog-agent status

    ## Squid（Proxy VPC）
    ssh -i ${local.ssh_key_path} -J ubuntu@${aws_instance.java.public_ip} ubuntu@${values(aws_instance.proxy)[0].private_ip}
    sudo datadog-agent status
    sudo tail -20 /var/log/squid/access.log

    Datadog UI:
      Infrastructure: ${local.dd_hostname_java} / ${local.dd_hostname_python} / ${local.dd_hostname_frontend} / squid / opw
      terraform output dd_hostnames で一覧表示
      APM: ${local.application_services.java} → ${local.application_services.python} → postgres
  EOT
}

output "step4_opw_logs_cutover" {
  description = "ステップ4（任意）: Fleet Automation で OPW ログ経路を有効化"
  value       = <<-EOT

    ===== STEP 4: OPW ログ切替（Fleet Automation）=====

    Datadog UI > Fleet Automation > Configure Agents
    対象: ${local.project_name}-java / ${local.project_name}-python
    datadog.yaml で以下を true に:

      observability_pipelines_worker:
        logs:
          enabled: true

    ロールバック: enabled: false
  EOT
}
