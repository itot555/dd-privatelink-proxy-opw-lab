# Datadog US1 PrivateLink — Proxy VPC のみ（Tenant からは Proxy 経由で送信）

resource "aws_vpc_endpoint" "datadog_us_east_1" {
  for_each = var.dd_privatelink_services

  provider = aws.us_east_1

  vpc_id              = module.vpc_proxy.vpc_id
  service_name        = each.value.service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc_proxy.private_subnets
  security_group_ids  = [aws_security_group.proxy_vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-proxy-dd-${each.key}"
    Tier = "proxy"
  })
}
