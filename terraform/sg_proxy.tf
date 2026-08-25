#------------------------------------------------------------------------------
# Security Groups — Proxy VPC
#------------------------------------------------------------------------------

resource "aws_security_group" "proxy_vpc_endpoints" {
  provider    = aws.us_east_1
  vpc_id      = module.vpc_proxy.vpc_id
  name        = "${local.project_name}-proxy-dd-endpoints-sg"
  description = "Datadog PrivateLink endpoints in Proxy VPC"

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = [module.vpc_proxy.vpc_cidr_block]
    description = "HTTPS access from Proxy VPC"
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.project_name}-proxy-dd-endpoints-sg" })
}

resource "aws_security_group" "proxy_nlb" {
  provider    = aws.us_east_1
  vpc_id      = module.vpc_proxy.vpc_id
  name        = "${local.project_name}-proxy-nlb-sg"
  description = "Internal NLB for Squid/OPW in Proxy VPC"

  dynamic "ingress" {
    for_each = local.proxy_nlb_ports
    content {
      protocol    = "tcp"
      from_port   = ingress.value
      to_port     = ingress.value
      cidr_blocks = [module.vpc_tenant.vpc_cidr_block, module.vpc_proxy.vpc_cidr_block]
      description = "Tenant/Proxy VPC to NLB"
    }
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.project_name}-proxy-nlb-sg" })
}

resource "aws_security_group" "proxy" {
  provider    = aws.us_east_1
  vpc_id      = module.vpc_proxy.vpc_id
  name        = "${local.project_name}-proxy-squid-sg"
  description = "Squid Proxy EC2 in Proxy VPC"

  ingress {
    protocol        = "tcp"
    from_port       = 22
    to_port         = 22
    security_groups = [aws_security_group.java.id]
    description     = "SSH from Tenant Java bastion via VPC Peering"
  }

  ingress {
    protocol        = "tcp"
    from_port       = var.proxy_port
    to_port         = var.proxy_port
    security_groups = [aws_security_group.proxy_nlb.id]
    description     = "Squid traffic from Proxy NLB"
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.project_name}-proxy-squid-sg" })
}

resource "aws_security_group" "opw" {
  provider    = aws.us_east_1
  vpc_id      = module.vpc_proxy.vpc_id
  name        = "${local.project_name}-proxy-opw-sg"
  description = "Observability Pipelines Worker EC2 in Proxy VPC"

  ingress {
    protocol        = "tcp"
    from_port       = 22
    to_port         = 22
    security_groups = [aws_security_group.java.id]
    description     = "SSH from Tenant Java bastion via VPC Peering"
  }

  dynamic "ingress" {
    for_each = [var.opw_logs_port, var.opw_traces_port]
    content {
      protocol        = "tcp"
      from_port       = ingress.value
      to_port         = ingress.value
      security_groups = [aws_security_group.proxy_nlb.id]
      description     = "OPW traffic from Proxy NLB"
    }
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.project_name}-proxy-opw-sg" })
}
