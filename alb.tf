# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public.*.id

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb-${var.environment}"
  }
}

# Frontend Listener - HTTP (redirect to HTTPS)
resource "aws_lb_listener" "frontend_http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Redirect all HTTP traffic to HTTPS
  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Frontend Listener (Default - root domain) - HTTPS
resource "aws_lb_listener" "frontend_https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = aws_acm_certificate_validation.main.certificate_arn
  depends_on        = [aws_acm_certificate_validation.main]

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# Backend Listener Rule (api.domain.com) - HTTPS
resource "aws_lb_listener_rule" "backend_https" {
  listener_arn = aws_lb_listener.frontend_https.arn
  priority     = 100

  condition {
    host_header {
      values = ["api.${var.domain_name}"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# Metabase Listener Rule (bi.domain.com) - HTTPS
resource "aws_lb_listener_rule" "metabase_https" {
  listener_arn = aws_lb_listener.frontend_https.arn
  priority     = 200

  condition {
    host_header {
      values = ["bi.${var.domain_name}"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.metabase.arn
  }
}

# SSL/TLS termination is now handled at the ALB level using ACM certificates
# EC2 instances will receive HTTP traffic from the ALB