# AWS リソース名の接頭辞。未指定時は dd- + 英小文字 3 文字。
# ALB / NLB / Target Group は 32 文字上限のため、接頭辞は最大 12 文字。
# 出典: https://docs.aws.amazon.com/elasticloadbalancing/latest/APIReference/API_CreateLoadBalancer.html
# random_string: https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string

resource "random_string" "project_suffix" {
  length  = 3
  upper   = false
  lower   = true
  numeric = false
  special = false
}

locals {
  project_name = var.project_name != "" ? var.project_name : "dd-${random_string.project_suffix.result}"
}
