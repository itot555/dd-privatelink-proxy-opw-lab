# Tenant VPC → Proxy VPC PrivateLink（VPC Endpoint Service + Interface Endpoint）

resource "aws_vpc_endpoint_service" "proxy" {
  provider = aws.us_east_1

  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.proxy.arn]

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-proxy-endpoint-service"
    Tier = "proxy"
  })
}

resource "aws_vpc_endpoint_service_allowed_principal" "tenant" {
  provider = aws.us_east_1

  vpc_endpoint_service_id = aws_vpc_endpoint_service.proxy.id
  principal_arn           = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
}

resource "aws_vpc_endpoint" "tenant_to_proxy" {
  provider = aws.us_east_1

  vpc_id              = module.vpc_tenant.vpc_id
  service_name        = aws_vpc_endpoint_service.proxy.service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc_tenant.private_subnets
  security_group_ids  = [aws_security_group.tenant_proxy_endpoint.id]
  private_dns_enabled = false

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-tenant-to-proxy"
    Tier = "tenant"
  })
}
