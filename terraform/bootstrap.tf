#------------------------------------------------------------------------------
# EC2 userdata 16KB 制限回避: bootstrap スクリプト / Agent 設定を S3 へ配置
# apply 時に EC2 IAM ロール経由で取得する
#------------------------------------------------------------------------------

locals {
  bootstrap_prefix = "${local.project_name}/bootstrap"
}

resource "aws_s3_object" "bootstrap_userdata_common" {
  provider = aws.us_east_1
  bucket   = aws_s3_bucket.app_artifacts.id
  key      = "${local.bootstrap_prefix}/userdata_common.sh"
  source   = "${path.module}/scripts/userdata_common.sh"
  etag     = filemd5("${path.module}/scripts/userdata_common.sh")
}

resource "aws_s3_object" "bootstrap_fetch" {
  provider = aws.us_east_1
  bucket   = aws_s3_bucket.app_artifacts.id
  key      = "${local.bootstrap_prefix}/bootstrap_fetch.sh"
  source   = "${path.module}/scripts/bootstrap_fetch.sh"
  etag     = filemd5("${path.module}/scripts/bootstrap_fetch.sh")
}

resource "aws_s3_object" "bootstrap_install_datadog_agent" {
  provider = aws.us_east_1
  bucket   = aws_s3_bucket.app_artifacts.id
  key      = "${local.bootstrap_prefix}/install_datadog_agent.sh"
  source   = "${path.module}/scripts/install_datadog_agent.sh"
  etag     = filemd5("${path.module}/scripts/install_datadog_agent.sh")
}

resource "aws_s3_object" "bootstrap_configure_log_permissions" {
  provider = aws.us_east_1
  bucket   = aws_s3_bucket.app_artifacts.id
  key      = "${local.bootstrap_prefix}/configure_log_permissions.sh"
  source   = "${path.module}/scripts/configure_log_permissions.sh"
  etag     = filemd5("${path.module}/scripts/configure_log_permissions.sh")
}

resource "aws_s3_object" "bootstrap_datadog_common_logs" {
  provider = aws.us_east_1
  bucket   = aws_s3_bucket.app_artifacts.id
  key      = "${local.bootstrap_prefix}/datadog-common-logs.yaml"
  content = templatefile("${path.module}/templates/datadog-common-logs.yaml.tftpl", {
    project_name = local.project_name
  })
  etag = md5(templatefile("${path.module}/templates/datadog-common-logs.yaml.tftpl", {
    project_name = local.project_name
  }))
}

resource "aws_s3_object" "bootstrap_datadog_ddot" {
  count    = var.enable_ddot_collector ? 1 : 0
  provider = aws.us_east_1
  bucket   = aws_s3_bucket.app_artifacts.id
  key      = "${local.bootstrap_prefix}/datadog-ddot.yaml"
  content  = templatefile("${path.module}/templates/datadog-ddot.yaml.tftpl", {})
  etag     = md5(templatefile("${path.module}/templates/datadog-ddot.yaml.tftpl", {}))
}

resource "aws_s3_object" "bootstrap_otel_config" {
  count    = var.enable_ddot_collector ? 1 : 0
  provider = aws.us_east_1
  bucket   = aws_s3_bucket.app_artifacts.id
  key      = "${local.bootstrap_prefix}/otel-config.yaml"
  content = templatefile("${path.module}/templates/otel-config.yaml.tftpl", {
    project_name = local.project_name
  })
  etag = md5(templatefile("${path.module}/templates/otel-config.yaml.tftpl", {
    project_name = local.project_name
  }))
}

resource "aws_s3_object" "bootstrap_datadog_common_java" {
  provider = aws.us_east_1
  bucket   = aws_s3_bucket.app_artifacts.id
  key      = "${local.bootstrap_prefix}/datadog-common-java.yaml"
  content = templatefile("${path.module}/templates/datadog-common.yaml.tftpl", {
    dd_env            = var.dd_env
    hostname          = local.dd_hostname_java
    datadog_proxy_dns = local.tenant_datadog_proxy_dns
    enable_opw_logs   = var.enable_opw_logs
    enable_opw_traces = var.enable_opw_traces
    opw_logs_port     = var.opw_logs_port
    opw_traces_port   = var.opw_traces_port
    project_name      = local.project_name
    proxy_port        = var.proxy_port
    rds_endpoint      = aws_db_instance.main.address
    role              = "java"
  })
  etag = md5(templatefile("${path.module}/templates/datadog-common.yaml.tftpl", {
    dd_env            = var.dd_env
    hostname          = local.dd_hostname_java
    datadog_proxy_dns = local.tenant_datadog_proxy_dns
    enable_opw_logs   = var.enable_opw_logs
    enable_opw_traces = var.enable_opw_traces
    opw_logs_port     = var.opw_logs_port
    opw_traces_port   = var.opw_traces_port
    project_name      = local.project_name
    proxy_port        = var.proxy_port
    rds_endpoint      = aws_db_instance.main.address
    role              = "java"
  }))
}

resource "aws_s3_object" "bootstrap_datadog_common_python" {
  provider = aws.us_east_1
  bucket   = aws_s3_bucket.app_artifacts.id
  key      = "${local.bootstrap_prefix}/datadog-common-python.yaml"
  content = templatefile("${path.module}/templates/datadog-common.yaml.tftpl", {
    dd_env            = var.dd_env
    hostname          = local.dd_hostname_python
    datadog_proxy_dns = local.tenant_datadog_proxy_dns
    enable_opw_logs   = var.enable_opw_logs
    enable_opw_traces = var.enable_opw_traces
    opw_logs_port     = var.opw_logs_port
    opw_traces_port   = var.opw_traces_port
    project_name      = local.project_name
    proxy_port        = var.proxy_port
    rds_endpoint      = aws_db_instance.main.address
    role              = "python"
  })
  etag = md5(templatefile("${path.module}/templates/datadog-common.yaml.tftpl", {
    dd_env            = var.dd_env
    hostname          = local.dd_hostname_python
    datadog_proxy_dns = local.tenant_datadog_proxy_dns
    enable_opw_logs   = var.enable_opw_logs
    enable_opw_traces = var.enable_opw_traces
    opw_logs_port     = var.opw_logs_port
    opw_traces_port   = var.opw_traces_port
    project_name      = local.project_name
    proxy_port        = var.proxy_port
    rds_endpoint      = aws_db_instance.main.address
    role              = "python"
  }))
}

resource "aws_s3_object" "bootstrap_datadog_common_frontend" {
  provider = aws.us_east_1
  bucket   = aws_s3_bucket.app_artifacts.id
  key      = "${local.bootstrap_prefix}/datadog-common-frontend.yaml"
  content = templatefile("${path.module}/templates/datadog-common.yaml.tftpl", {
    dd_env            = var.dd_env
    hostname          = local.dd_hostname_frontend
    datadog_proxy_dns = local.tenant_datadog_proxy_dns
    enable_opw_logs   = var.enable_opw_logs
    enable_opw_traces = var.enable_opw_traces
    opw_logs_port     = var.opw_logs_port
    opw_traces_port   = var.opw_traces_port
    project_name      = local.project_name
    proxy_port        = var.proxy_port
    rds_endpoint      = aws_db_instance.main.address
    role              = "frontend"
  })
  etag = md5(templatefile("${path.module}/templates/datadog-common.yaml.tftpl", {
    dd_env            = var.dd_env
    hostname          = local.dd_hostname_frontend
    datadog_proxy_dns = local.tenant_datadog_proxy_dns
    enable_opw_logs   = var.enable_opw_logs
    enable_opw_traces = var.enable_opw_traces
    opw_logs_port     = var.opw_logs_port
    opw_traces_port   = var.opw_traces_port
    project_name      = local.project_name
    proxy_port        = var.proxy_port
    rds_endpoint      = aws_db_instance.main.address
    role              = "frontend"
  }))
}

resource "aws_s3_object" "bootstrap_datadog_common_proxy" {
  for_each = local.proxy_subnet_map

  provider = aws.us_east_1
  bucket   = aws_s3_bucket.app_artifacts.id
  key      = "${local.bootstrap_prefix}/datadog-common-proxy-${each.key}.yaml"
  content = templatefile("${path.module}/templates/datadog-common.yaml.tftpl", {
    dd_env            = var.dd_env
    hostname          = local.dd_hostname_squid[each.key]
    datadog_proxy_dns = local.proxy_datadog_proxy_dns
    enable_opw_logs   = false
    enable_opw_traces = false
    opw_logs_port     = var.opw_logs_port
    opw_traces_port   = var.opw_traces_port
    project_name      = local.project_name
    proxy_port        = var.proxy_port
    rds_endpoint      = "unused.local"
    role              = "proxy"
  })
  etag = md5(templatefile("${path.module}/templates/datadog-common.yaml.tftpl", {
    dd_env            = var.dd_env
    hostname          = local.dd_hostname_squid[each.key]
    datadog_proxy_dns = local.proxy_datadog_proxy_dns
    enable_opw_logs   = false
    enable_opw_traces = false
    opw_logs_port     = var.opw_logs_port
    opw_traces_port   = var.opw_traces_port
    project_name      = local.project_name
    proxy_port        = var.proxy_port
    rds_endpoint      = "unused.local"
    role              = "proxy"
  }))
}

resource "aws_s3_object" "bootstrap_datadog_common_opw" {
  for_each = local.opw_subnet_map

  provider = aws.us_east_1
  bucket   = aws_s3_bucket.app_artifacts.id
  key      = "${local.bootstrap_prefix}/datadog-common-opw-${each.key}.yaml"
  content = templatefile("${path.module}/templates/datadog-common.yaml.tftpl", {
    dd_env            = var.dd_env
    hostname          = local.dd_hostname_opw[each.key]
    datadog_proxy_dns = local.proxy_datadog_proxy_dns
    enable_opw_logs   = false
    enable_opw_traces = false
    opw_logs_port     = var.opw_logs_port
    opw_traces_port   = var.opw_traces_port
    project_name      = local.project_name
    proxy_port        = var.proxy_port
    rds_endpoint      = "unused.local"
    role              = "opw"
  })
  etag = md5(templatefile("${path.module}/templates/datadog-common.yaml.tftpl", {
    dd_env            = var.dd_env
    hostname          = local.dd_hostname_opw[each.key]
    datadog_proxy_dns = local.proxy_datadog_proxy_dns
    enable_opw_logs   = false
    enable_opw_traces = false
    opw_logs_port     = var.opw_logs_port
    opw_traces_port   = var.opw_traces_port
    project_name      = local.project_name
    proxy_port        = var.proxy_port
    rds_endpoint      = "unused.local"
    role              = "opw"
  }))
}
