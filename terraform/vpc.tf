# Tenant VPC — アプリ、ALB、CloudFront、RDS、Tenant→Proxy Interface EP

module "vpc_tenant" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.6.1"

  providers = {
    aws = aws.us_east_1
  }

  name = "${local.project_name}-tenant-vpc"
  cidr = var.vpc_cidr_us_east_1

  azs             = slice(data.aws_availability_zones.us_east_1.names, 0, 2)
  private_subnets = [cidrsubnet(var.vpc_cidr_us_east_1, 8, 1), cidrsubnet(var.vpc_cidr_us_east_1, 8, 2)]
  public_subnets  = [cidrsubnet(var.vpc_cidr_us_east_1, 8, 101), cidrsubnet(var.vpc_cidr_us_east_1, 8, 102)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Tier = "tenant" })
}
