#------------------------------------------------------------------------------
# Security Groups — Tenant VPC
#------------------------------------------------------------------------------

# ALB への HTTP は CloudFront 管理プレフィックスリストのみ許可する。
# 一部アカウントでは 0.0.0.0/0 ingress が自動 Revoke されるため、プレフィックスリストを使う。
data "aws_ec2_managed_prefix_list" "cloudfront_origin_facing" {
  provider = aws.us_east_1
  name     = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "alb" {
  provider    = aws.us_east_1
  vpc_id      = module.vpc_tenant.vpc_id
  name        = "${local.project_name}-tenant-alb-sg"
  description = "Internet-facing Application Load Balancer"

  ingress {
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront_origin_facing.id]
    description     = "HTTP from CloudFront origin-facing"
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.project_name}-tenant-alb-sg" })
}

resource "aws_security_group" "java" {
  provider    = aws.us_east_1
  vpc_id      = module.vpc_tenant.vpc_id
  name        = "${local.project_name}-tenant-java-sg"
  description = "Java EC2 + Synthetics Private Location Worker"

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = local.ssh_allowed_cidrs
    description = "SSH from allowed CIDRs"
  }

  ingress {
    protocol        = "tcp"
    from_port       = var.java_app_port
    to_port         = var.java_app_port
    security_groups = [aws_security_group.alb.id]
    description     = "Java API from ALB"
  }

  ingress {
    protocol    = "tcp"
    from_port   = var.java_app_port
    to_port     = var.java_app_port
    cidr_blocks = local.ssh_allowed_cidrs
    description = "Java API direct access from allowed CIDRs"
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.project_name}-tenant-java-sg" })
}

resource "aws_security_group" "frontend" {
  provider    = aws.us_east_1
  vpc_id      = module.vpc_tenant.vpc_id
  name        = "${local.project_name}-tenant-frontend-sg"
  description = "Frontend nginx EC2"

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = local.ssh_allowed_cidrs
    description = "SSH from allowed CIDRs"
  }

  ingress {
    protocol        = "tcp"
    from_port       = var.frontend_app_port
    to_port         = var.frontend_app_port
    security_groups = [aws_security_group.alb.id]
    description     = "HTTP from ALB"
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.project_name}-tenant-frontend-sg" })
}

resource "aws_security_group" "python" {
  provider    = aws.us_east_1
  vpc_id      = module.vpc_tenant.vpc_id
  name        = "${local.project_name}-tenant-python-sg"
  description = "Python EC2 + DBM Agent"

  ingress {
    protocol        = "tcp"
    from_port       = 22
    to_port         = 22
    security_groups = [aws_security_group.java.id]
    description     = "SSH from Java bastion"
  }

  ingress {
    protocol        = "tcp"
    from_port       = var.python_app_port
    to_port         = var.python_app_port
    security_groups = [aws_security_group.java.id]
    description     = "Python API from Java"
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.project_name}-tenant-python-sg" })
}

resource "aws_security_group" "database" {
  provider    = aws.us_east_1
  vpc_id      = module.vpc_tenant.vpc_id
  name        = "${local.project_name}-tenant-database-sg"
  description = "RDS PostgreSQL"

  ingress {
    protocol        = "tcp"
    from_port       = 5432
    to_port         = 5432
    security_groups = [aws_security_group.python.id]
    description     = "PostgreSQL access from Python EC2 only"
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.project_name}-tenant-database-sg" })
}

resource "aws_security_group" "tenant_proxy_endpoint" {
  provider    = aws.us_east_1
  vpc_id      = module.vpc_tenant.vpc_id
  name        = "${local.project_name}-tenant-proxy-ep-sg"
  description = "Interface VPC Endpoint for Tenant to Proxy PrivateLink"

  dynamic "ingress" {
    for_each = local.proxy_nlb_ports
    content {
      protocol  = "tcp"
      from_port = ingress.value
      to_port   = ingress.value
      security_groups = [
        aws_security_group.java.id,
        aws_security_group.python.id,
        aws_security_group.frontend.id,
      ]
      description = "Datadog proxy/OP traffic from Tenant Agents"
    }
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.project_name}-tenant-proxy-ep-sg" })
}
