#------------------------------------------------------------------------------
# ap-northeast-1 ネットワーク基盤（optional）
#
# - enable_ap_northeast_1_network = true  : VPC + SG + Cross-Region PrivateLink
# - enable_ap_northeast_1_compute = true: 上記に加え EC2/NLB 等（未実装・次フェーズ）
#
# Cross-Region PrivateLink 参考:
# https://docs.datadoghq.com/agent/guide/private-link/?tab=crossregionprivatelinkendpoints&site=us
#------------------------------------------------------------------------------

module "vpc_ap_northeast_1" {
  count = var.enable_ap_northeast_1_network ? 1 : 0

  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.6.1"

  providers = {
    aws = aws.ap_northeast_1
  }

  name = "${local.project_name}-apne1-vpc"
  cidr = var.vpc_cidr_ap_northeast_1

  azs             = slice(data.aws_availability_zones.ap_northeast_1.names, 0, 2)
  private_subnets = [cidrsubnet(var.vpc_cidr_ap_northeast_1, 8, 1), cidrsubnet(var.vpc_cidr_ap_northeast_1, 8, 2)]
  public_subnets  = [cidrsubnet(var.vpc_cidr_ap_northeast_1, 8, 101), cidrsubnet(var.vpc_cidr_ap_northeast_1, 8, 102)]

  # コンピュート未デプロイ時は NAT を作らず、PrivateLink 待機だけにする（NAT 料金回避）
  enable_nat_gateway   = var.enable_ap_northeast_1_compute
  single_nat_gateway   = true
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = local.common_tags
}

resource "aws_security_group" "vpc_endpoints_ap_northeast_1" {
  count = var.enable_ap_northeast_1_network ? 1 : 0

  provider    = aws.ap_northeast_1
  vpc_id      = module.vpc_ap_northeast_1[0].vpc_id
  name        = "${local.project_name}-apne1-vpc-endpoints-sg"
  description = "Datadog Cross-Region PrivateLink endpoints"

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = [module.vpc_ap_northeast_1[0].vpc_cidr_block]
    description = "HTTPS access from VPC"
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.project_name}-apne1-vpc-endpoints-sg" })
}

resource "aws_vpc_endpoint" "datadog_ap_northeast_1" {
  for_each = var.enable_ap_northeast_1_network ? var.dd_privatelink_services : {}

  provider = aws.ap_northeast_1

  vpc_id              = module.vpc_ap_northeast_1[0].vpc_id
  service_name        = each.value.service_name
  service_region      = "us-east-1"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc_ap_northeast_1[0].private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints_ap_northeast_1[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-apne1-dd-${each.key}"
  })

  depends_on = [aws_vpc_endpoint.datadog_us_east_1]
}
