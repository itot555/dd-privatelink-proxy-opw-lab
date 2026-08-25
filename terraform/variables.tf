#------------------------------------------------------------------------------
# Datadog
#------------------------------------------------------------------------------

variable "dd_api_key" {
  description = "Datadog API Key（us-east-1 Secrets Managerへ保存する）"
  type        = string
  sensitive   = true
}

variable "dd_site" {
  description = "Datadog Site（例: datadoghq.com、ap1.datadoghq.com）"
  type        = string
  default     = "datadoghq.com"
}

variable "dd_env" {
  description = "Datadog unified service taggingのenv"
  type        = string
  default     = "dd-lab"
}

variable "dd_version" {
  description = "Demo applicationに付与するDatadog version"
  type        = string
  default     = "1.0.0"
}

# US1 (datadoghq.com) 向け AWS PrivateLink VPC Endpoint Service 一覧。
# us-east-1 にネイティブ提供されているエンドポイントサービスを参照する。
#
# 値は必ず以下の公式ドキュメントの「VPC Endpoint Service IDs」表と照合してから
# terraform apply すること:
# https://docs.datadoghq.com/agent/guide/private-link/?tab=crossregionprivatelinkendpoints&site=us
variable "dd_privatelink_services" {
  description = "Datadog US1 PrivateLink VPC Endpoint Service一覧（キー: 用途ラベル）"
  type = map(object({
    service_name = string
    description  = string
  }))
  default = {
    logs_agent_intake = {
      service_name = "com.amazonaws.vpce.us-east-1.vpce-svc-025a56b9187ac1f63"
      description  = "Logs - Agent HTTP intake (agent-http-intake.logs.datadoghq.com)"
    }
    logs_user_intake = {
      service_name = "com.amazonaws.vpce.us-east-1.vpce-svc-0e36256cb6172439d"
      description  = "Logs - User HTTP intake (http-intake.logs.datadoghq.com)"
    }
    api_synthetics = {
      service_name = "com.amazonaws.vpce.us-east-1.vpce-svc-07895350fd0109264"
      description  = "API + Synthetics (api.datadoghq.com, synthetics.datadoghq.com)"
    }
    metrics = {
      service_name = "com.amazonaws.vpce.us-east-1.vpce-svc-09a8006e245d1e7b8"
      description  = "Metrics (metrics.agent.datadoghq.com)"
    }
    containers = {
      service_name = "com.amazonaws.vpce.us-east-1.vpce-svc-0ad5fb9e71f85fe99"
      description  = "Containers / Orchestrator (orchestrator.datadoghq.com)"
    }
    process = {
      service_name = "com.amazonaws.vpce.us-east-1.vpce-svc-0ed1f789ac6b0bde1"
      description  = "Process (process.datadoghq.com)"
    }
    profiling = {
      service_name = "com.amazonaws.vpce.us-east-1.vpce-svc-022ae36a7b2472029"
      description  = "Profiling (intake.profile.datadoghq.com)"
    }
    traces = {
      service_name = "com.amazonaws.vpce.us-east-1.vpce-svc-0ee865cd1c0a7ba32"
      description  = "Traces / APM + Data Observability (trace.agent.datadoghq.com, data-obs-intake.datadoghq.com)"
    }
    database_monitoring = {
      service_name = "com.amazonaws.vpce.us-east-1.vpce-svc-0ce70d55ec4af8501"
      description  = "Database Monitoring (dbm-metrics-intake.datadoghq.com)"
    }
    remote_configuration = {
      service_name = "com.amazonaws.vpce.us-east-1.vpce-svc-01f21309e507e3b1d"
      description  = "Remote Configuration (config.datadoghq.com)"
    }
    webhooks = {
      service_name = "com.amazonaws.vpce.us-east-1.vpce-svc-02bee2072b5c3c226"
      description  = "Webhooks (webhook-intake.datadoghq.com, webhooks-http-intake.logs.datadoghq.com)"
    }
    otlp = {
      service_name = "com.amazonaws.vpce.us-east-1.vpce-svc-00192e92115cbcc75"
      description  = "OTLP / OpAMP (*.integrations.otlp.datadoghq.com, opamp.datadoghq.com, otlp.datadoghq.com)"
    }
    mcp = {
      service_name = "com.amazonaws.vpce.us-east-1.vpce-svc-058a75ceea85a9175"
      description  = "MCP (mcp.datadoghq.com)"
    }
    platform_intake = {
      service_name = "com.amazonaws.vpce.us-east-1.vpce-svc-0b3292e3efce2a445"
      description  = <<-EOT
        Platform intake群 (agenthealth-intake, ci-intake, cicodescan-intake,
        citestcov-intake, citestcycle-intake, cloudplatform-intake,
        contimage-intake, contlcycle-intake, cws-intake, debugger-intake,
        error-tracking-intake, event-management-intake, event-platform-intake,
        feed-intake, instrumentation-telemetry-intake, kubeops-intake,
        llmobs-intake, ndm-intake, ndmflow-intake, netpath-intake,
        ocimetrics-intake, resources-intake, sbom-intake, sds-intake,
        sentry-intake, snmp-traps-intake, softinv-intake の各*.datadoghq.com)
      EOT
    }
    rum = {
      service_name = "com.amazonaws.vpce.us-east-1.vpce-svc-0a3b2d86676122d8d"
      description  = "RUM (iam-rum-intake.datadoghq.com, rum-http-intake.logs.datadoghq.com, rum.browser-intake-datadoghq.com)"
    }
    network_devices = {
      service_name = "com.amazonaws.vpce.us-east-1.vpce-svc-05e3bfec4501e714d"
      description  = "Network Device Monitoring (network-devices.datadoghq.com)"
    }
  }
}

#------------------------------------------------------------------------------
# Network
#------------------------------------------------------------------------------

variable "enable_ap_northeast_1_network" {
  description = <<-EOT
    ap-northeast-1 にネットワーク基盤（VPC、Security Group、Cross-Region PrivateLink）を作成する。
    Interface VPC Endpoint は AZ ごとに時間課金が発生するため、検証不要時は false を推奨する。
  EOT
  type        = bool
  default     = false
}

variable "enable_ap_northeast_1_compute" {
  description = <<-EOT
    ap-northeast-1 にコンピュートリソース（EC2、NLB、ALB、CloudFront、RDS 等）を作成する。
    enable_ap_northeast_1_network = true が前提。普段の Lab では false のままにする。
  EOT
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_ap_northeast_1_compute || var.enable_ap_northeast_1_network
    error_message = "enable_ap_northeast_1_compute を true にする場合は enable_ap_northeast_1_network も true にしてください。"
  }
}

variable "vpc_cidr_us_east_1" {
  description = "us-east-1 Tenant VPCのCIDR"
  type        = string
  default     = "10.100.0.0/16"
}

variable "vpc_cidr_proxy_us_east_1" {
  description = "us-east-1 Proxy VPC（Squid/OP/Datadog PrivateLink）のCIDR"
  type        = string
  default     = "10.110.0.0/16"
}

variable "vpc_cidr_ap_northeast_1" {
  description = "ap-northeast-1 VPCのCIDR（enable_ap_northeast_1_network = true 時のみ使用）"
  type        = string
  default     = "10.101.0.0/16"
}

variable "allowed_ip" {
  description = "Java/Frontend EC2へのSSHおよびJava API直接アクセスを許可するCIDR"
  type        = list(string)
  sensitive   = true
}

variable "office_ip" {
  description = "オフィスからのアクセスを許可するCIDR"
  type        = list(string)
  sensitive   = true
}

#------------------------------------------------------------------------------
# Project
#------------------------------------------------------------------------------

variable "environment" {
  description = "AWS resource tagへ付与するenvironment"
  type        = string
  default     = "sandbox"
}

variable "owner" {
  description = "AWS resource tagへ付与するowner。個人情報を含む場合はterraform.tfvarsで指定する"
  type        = string
  default     = ""
}

variable "extra_tags" {
  description = "AWS resource に追加する任意タグ。個人情報は Git 管理外の terraform.tfvars で指定する"
  type        = map(string)
  default     = {}
}

variable "project_name" {
  description = <<-EOT
    AWS resource name prefix。空文字の場合は dd- に英小文字 3 文字を付与する（例: dd-k7m）。
    ALB/NLB/Target Group 名は 32 文字上限のため、最大 12 文字。
    RDS identifier にも使うため、末尾ハイフンと連続ハイフンは不可。
    出典: https://docs.aws.amazon.com/elasticloadbalancing/latest/APIReference/API_CreateLoadBalancer.html
  EOT
  type        = string
  default     = ""

  validation {
    condition = var.project_name == "" || (
      length(var.project_name) <= 12 &&
      can(regex("^[a-z][a-z0-9]*(-[a-z0-9]+)*$", var.project_name))
    )
    error_message = "project_name は空（自動: dd- + 英小文字3文字）か、先頭が英小文字で最大 12 文字（英小文字・数字・ハイフン、末尾ハイフンと連続ハイフンは不可）にしてください。"
  }
}

#------------------------------------------------------------------------------
# EC2
#------------------------------------------------------------------------------

variable "application_instance_type" {
  description = "Java/Python Application EC2のinstance type"
  type        = string
  default     = "t3.medium"
}

variable "frontend_instance_type" {
  description = "Frontend (nginx) EC2のinstance type"
  type        = string
  default     = "t3.small"
}

variable "application_volume_size" {
  description = "Java/Python/Frontend EC2 root volume size（GiB）"
  type        = number
  default     = 20

  validation {
    condition     = var.application_volume_size >= 16
    error_message = "application_volume_size must be at least 16 GiB."
  }
}

variable "enable_force_destroy" {
  description = "Sandbox向け: terraform destroy 時に S3 バケット等を確実に削除できるよう force_destroy を有効化する"
  type        = bool
  default     = true
}

variable "java_ssi_libraries" {
  description = "Java EC2 の SSI ライブラリ指定（例: java:1）"
  type        = string
  default     = "java:1"
}

variable "enable_java_ssi" {
  description = "Java EC2 で Datadog Agent SSI（Single Step Instrumentation）を有効化する"
  type        = bool
  default     = true
}

variable "proxy_instance_count" {
  description = <<-EOT
    Squid Proxy EC2 台数。1 以上を指定する。
    Private Subnet 数を超える場合は AZ 内で round-robin 配置する。
  EOT
  type        = number
  default     = 1

  validation {
    condition     = var.proxy_instance_count >= 1 && var.proxy_instance_count <= 10
    error_message = "proxy_instance_count は 1 から 10 の範囲で指定してください。"
  }
}

variable "opw_instance_count" {
  description = <<-EOT
    OPW EC2 台数。1 以上を指定する。
    Private Subnet 数を超える場合は AZ 内で round-robin 配置する。
  EOT
  type        = number
  default     = 1

  validation {
    condition     = var.opw_instance_count >= 1 && var.opw_instance_count <= 10
    error_message = "opw_instance_count は 1 から 10 の範囲で指定してください。"
  }
}

variable "enable_ddot_collector" {
  description = "Datadog Agent 内蔵 DDOT Collector を有効化する（Python EC2 の OTel SDK 向け）"
  type        = bool
  default     = true
}

variable "proxy_instance_type" {
  description = "Sandbox用Squid Proxy EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "proxy_volume_size" {
  description = "Squid Proxy EC2 root volume size（GiB）"
  type        = number
  default     = 12
}

variable "opw_instance_type" {
  description = "Sandbox用OPW EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "opw_volume_size" {
  description = "OPW EC2 root volume size（GiB）"
  type        = number
  default     = 20
}

variable "java_app_port" {
  description = "Java demo applicationのlisten port"
  type        = number
  default     = 8080
}

variable "python_app_port" {
  description = "Python demo applicationのlisten port"
  type        = number
  default     = 8000
}

variable "frontend_app_port" {
  description = "Frontend nginxのlisten port"
  type        = number
  default     = 80
}

variable "proxy_port" {
  description = "Squid ProxyとNLB listenerのport"
  type        = number
  default     = 3128
}

variable "opw_logs_port" {
  description = "OPW Logs pipeline（Datadog Agent source）とNLB listenerのport"
  type        = number
  default     = 8282
}

variable "opw_metrics_port" {
  description = "OPW Metrics pipelineのホスト待受port（OP Worker内部用）。Agent MetricsはNLB:3128 Squid経由のためNLBリスナーは作成しない"
  type        = number
  default     = 8383
}

variable "opw_traces_port" {
  description = "OPW Traces pipelineとNLB listenerのport"
  type        = number
  default     = 8484
}

variable "opw_pipeline_id" {
  description = "Datadogで作成済みのOPW Logs pipeline ID。未設定の場合OPW Workerインストールをスキップする"
  type        = string
  default     = ""
}

variable "enable_opw_logs" {
  description = "Agent logs を OPW（NLB:8282）経由にする。false なら Squid :3128 経由（安全デフォルト）"
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_opw_logs || var.opw_pipeline_id != ""
    error_message = "enable_opw_logs=true の場合、opw_pipeline_id を設定してください。"
  }
}

variable "opw_pipeline_id_metrics" {
  description = "Datadogで作成済みのOPW Metrics pipeline ID。未設定の場合Metrics OPWをスキップする"
  type        = string
  default     = ""
}

variable "enable_opw_traces" {
  description = <<-EOT
    true の場合、Agent APM/Traces を OPW（NLB:8484）経由にする。
    opw_pipeline_id_traces 設定と OPW :8484 待受（op-traces Worker）が必須。
    既定は false のまま Squid :3128 経由とする。
  EOT
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_opw_traces || var.opw_pipeline_id_traces != ""
    error_message = "enable_opw_traces=true の場合、opw_pipeline_id_traces を設定してください。"
  }
}

variable "opw_pipeline_id_traces" {
  description = "Datadogで作成済みのOPW Traces pipeline ID。未設定の場合Traces OPW Workerインストールをスキップする"
  type        = string
  default     = ""
}

#------------------------------------------------------------------------------
# RDS
#------------------------------------------------------------------------------

variable "database_instance_class" {
  description = "Sandbox RDS PostgreSQLのDB instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "database_name" {
  description = "Demo application用PostgreSQL database名"
  type        = string
  default     = "demodb"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,62}$", var.database_name))
    error_message = "database_name must start with a lowercase letter and contain only lowercase letters, numbers, and underscores."
  }
}

variable "postgres_admin_username" {
  description = "RDS PostgreSQL master username"
  type        = string
  default     = "dbadmin"
}

variable "postgres_app_username" {
  description = "Demo application用PostgreSQL username"
  type        = string
  default     = "dbapp"
}

variable "postgres_dbm_username" {
  description = "Datadog DBM用PostgreSQL username"
  type        = string
  default     = "datadog"
}

variable "postgres_engine_version" {
  description = "RDS PostgreSQL major engine version"
  type        = string
  default     = "17"

  validation {
    condition     = startswith(var.postgres_engine_version, "17")
    error_message = "This configuration currently supports PostgreSQL 17 only."
  }
}

#------------------------------------------------------------------------------
# Banking demo（削除時は enable_banking_demo=false または本ブロックごと除去）
#------------------------------------------------------------------------------

variable "enable_banking_demo" {
  description = "ネットバンキング demo API/DB/UI を有効化する。false で demo なしの構成に戻せる"
  type        = bool
  default     = true
}

variable "demo_bank_password" {
  description = "デモログインパスワード（Sandbox: Java span/log マスク検証用）。terraform.tfvars で必ず指定する"
  type        = string
  sensitive   = true
}

variable "enable_rum" {
  description = "React SPA に Datadog RUM Browser SDK を組み込む（applicationId/clientToken が必要）"
  type        = bool
  default     = false
}

variable "rum_application_id" {
  description = "Datadog RUM Application ID（Git 管理外 tfvars 推奨）"
  type        = string
  sensitive   = true
  default     = ""
}

variable "rum_client_token" {
  description = "Datadog RUM Client Token（Git 管理外 tfvars 推奨）"
  type        = string
  sensitive   = true
  default     = ""
}

#------------------------------------------------------------------------------
# Synthetics
#------------------------------------------------------------------------------

variable "private_location_concurrency" {
  description = "Java EC2上のSynthetics Private Location Worker concurrency"
  type        = number
  default     = 1

  validation {
    condition     = var.private_location_concurrency >= 1
    error_message = "private_location_concurrency must be at least 1."
  }
}

variable "private_location_image" {
  description = "Synthetics Private Location Worker container image（userdata で proxy/権限を設定）"
  type        = string
  default     = "datadog/synthetics-private-location-worker:latest"
}

variable "private_location_team" {
  description = "Private Locationへteam tagとして付与するDatadog Team handle。terraform.tfvars で自組織の handle を指定する"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9_-]*$", var.private_location_team))
    error_message = "private_location_team must be a valid lowercase Datadog Team handle."
  }
}

#------------------------------------------------------------------------------
# Synthetics E2E（Private Location API tests）
#------------------------------------------------------------------------------

variable "enable_synthetics_e2e_tests" {
  description = "Datadog Synthetics API テスト（Private Location → CloudFront）を Terraform で作成する"
  type        = bool
  default     = true
}

variable "synthetics_test_tick_seconds" {
  description = "Synthetics API テストの実行間隔（秒）。Sandbox default 900（15 分）"
  type        = number
  default     = 900

  validation {
    condition     = var.synthetics_test_tick_seconds >= 60
    error_message = "synthetics_test_tick_seconds must be at least 60."
  }
}

variable "synthetics_test_status" {
  description = "Synthetics テストの status（live または paused）"
  type        = string
  default     = "live"

  validation {
    condition     = contains(["live", "paused"], var.synthetics_test_status)
    error_message = "synthetics_test_status must be live or paused."
  }
}
