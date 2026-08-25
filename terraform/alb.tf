resource "aws_lb" "public" {
  provider           = aws.us_east_1
  name               = "${local.project_name}-use1-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc_tenant.public_subnets

  tags = merge(local.common_tags, { Name = "${local.project_name}-use1-alb" })
}

resource "aws_lb_target_group" "frontend" {
  provider    = aws.us_east_1
  name        = "${local.project_name}-use1-tg-frontend"
  port        = var.frontend_app_port
  protocol    = "HTTP"
  vpc_id      = module.vpc_tenant.vpc_id
  target_type = "instance"

  health_check {
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = "/"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = merge(local.common_tags, { Name = "${local.project_name}-use1-tg-frontend" })
}

resource "aws_lb_target_group" "java" {
  provider    = aws.us_east_1
  name        = "${local.project_name}-use1-tg-java"
  port        = var.java_app_port
  protocol    = "HTTP"
  vpc_id      = module.vpc_tenant.vpc_id
  target_type = "instance"

  health_check {
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = "/hello"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = merge(local.common_tags, { Name = "${local.project_name}-use1-tg-java" })
}

resource "aws_lb_target_group_attachment" "frontend" {
  provider         = aws.us_east_1
  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = aws_instance.frontend.id
  port             = var.frontend_app_port
}

resource "aws_lb_target_group_attachment" "java" {
  provider         = aws.us_east_1
  target_group_arn = aws_lb_target_group.java.arn
  target_id        = aws_instance.java.id
  port             = var.java_app_port
}

resource "aws_lb_listener" "http" {
  provider          = aws.us_east_1
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_listener_rule" "java_api" {
  provider     = aws.us_east_1
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.java.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

resource "aws_lb_listener_rule" "java_hello" {
  provider     = aws.us_east_1
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.java.arn
  }

  condition {
    path_pattern {
      values = ["/hello*"]
    }
  }
}
