# Proxy VPC Internal NLB — Squid / OPW 4 ポート分岐

resource "aws_lb" "proxy" {
  provider           = aws.us_east_1
  name               = "${local.project_name}-proxy-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = module.vpc_proxy.private_subnets
  security_groups    = [aws_security_group.proxy_nlb.id]

  enable_cross_zone_load_balancing = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-proxy-nlb"
    Tier = "proxy"
  })
}

resource "aws_lb_target_group" "proxy_squid" {
  provider    = aws.us_east_1
  name        = "${local.project_name}-proxy-tg-squid"
  port        = var.proxy_port
  protocol    = "TCP"
  vpc_id      = module.vpc_proxy.vpc_id
  target_type = "instance"

  preserve_client_ip = false

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 10
  }

  tags = merge(local.common_tags, { Name = "${local.project_name}-proxy-tg-squid" })
}

resource "aws_lb_listener" "proxy_squid" {
  provider          = aws.us_east_1
  load_balancer_arn = aws_lb.proxy.arn
  port              = var.proxy_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.proxy_squid.arn
  }
}

resource "aws_lb_target_group_attachment" "proxy_squid" {
  for_each = aws_instance.proxy

  provider         = aws.us_east_1
  target_group_arn = aws_lb_target_group.proxy_squid.arn
  target_id        = each.value.id
  port             = var.proxy_port
}

resource "aws_lb_target_group" "opw_logs" {
  provider    = aws.us_east_1
  name        = "${local.project_name}-proxy-tg-opw-logs"
  port        = var.opw_logs_port
  protocol    = "TCP"
  vpc_id      = module.vpc_proxy.vpc_id
  target_type = "instance"

  preserve_client_ip = false

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 10
  }

  tags = merge(local.common_tags, { Name = "${local.project_name}-proxy-tg-opw-logs" })
}

resource "aws_lb_listener" "opw_logs" {
  provider          = aws.us_east_1
  load_balancer_arn = aws_lb.proxy.arn
  port              = var.opw_logs_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.opw_logs.arn
  }
}

resource "aws_lb_target_group_attachment" "opw_logs" {
  for_each = aws_instance.opw

  provider         = aws.us_east_1
  target_group_arn = aws_lb_target_group.opw_logs.arn
  target_id        = each.value.id
  port             = var.opw_logs_port
}

resource "aws_lb_target_group" "opw_traces" {
  provider    = aws.us_east_1
  name        = "${local.project_name}-proxy-tg-opw-traces"
  port        = var.opw_traces_port
  protocol    = "TCP"
  vpc_id      = module.vpc_proxy.vpc_id
  target_type = "instance"

  preserve_client_ip = false

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 10
  }

  tags = merge(local.common_tags, { Name = "${local.project_name}-proxy-tg-opw-traces" })
}

resource "aws_lb_listener" "opw_traces" {
  provider          = aws.us_east_1
  load_balancer_arn = aws_lb.proxy.arn
  port              = var.opw_traces_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.opw_traces.arn
  }
}

resource "aws_lb_target_group_attachment" "opw_traces" {
  for_each = aws_instance.opw

  provider         = aws.us_east_1
  target_group_arn = aws_lb_target_group.opw_traces.arn
  target_id        = each.value.id
  port             = var.opw_traces_port
}
