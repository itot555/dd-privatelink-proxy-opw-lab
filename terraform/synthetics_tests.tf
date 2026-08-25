#------------------------------------------------------------------------------
# Synthetics API tests（Private Location → CloudFront）
# DD_APP_KEY 必須。enable_synthetics_e2e_tests=false で作成スキップ。
#------------------------------------------------------------------------------

resource "datadog_synthetics_test" "pl_cloudfront_hello" {
  count = var.enable_synthetics_e2e_tests ? 1 : 0

  name    = "${local.project_name} PL — CloudFront /hello"
  type    = "api"
  subtype = "http"
  status  = var.synthetics_test_status
  message = "Private Location から CloudFront /hello の疎通監視"

  locations = [datadog_synthetics_private_location.main.id]

  tags = [
    "env:${var.dd_env}",
    "project:${local.project_name}",
    "component:synthetics",
    "check:hello",
  ]

  request_definition {
    method = "GET"
    url    = "https://${aws_cloudfront_distribution.main.domain_name}/hello"
  }

  assertion {
    type     = "statusCode"
    operator = "is"
    target   = "200"
  }

  assertion {
    type     = "responseTime"
    operator = "lessThan"
    target   = "10000"
  }

  options_list {
    tick_every = var.synthetics_test_tick_seconds

    retry {
      count    = 2
      interval = 300
    }

    monitor_options {
      renotify_interval = 0
    }
  }
}

resource "datadog_synthetics_test" "pl_distributed_trace" {
  count = var.enable_synthetics_e2e_tests ? 1 : 0

  name    = "${local.project_name} PL — Java→Python trace probe"
  type    = "api"
  subtype = "http"
  status  = var.synthetics_test_status
  message = "PL から /hello を叩き APM 分散トレース生成（分散トレース E2E 確認用）"

  locations = [datadog_synthetics_private_location.main.id]

  tags = [
    "env:${var.dd_env}",
    "project:${local.project_name}",
    "component:synthetics",
    "check:distributed-trace",
  ]

  request_definition {
    method = "GET"
    url    = "https://${aws_cloudfront_distribution.main.domain_name}/hello"
  }

  assertion {
    type     = "statusCode"
    operator = "is"
    target   = "200"
  }

  options_list {
    tick_every = var.synthetics_test_tick_seconds

    retry {
      count    = 1
      interval = 300
    }
  }
}
