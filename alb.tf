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

# Frontend Listener (Default - root domain) - HTTP
resource "aws_lb_listener" "frontend_http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Forward to target group instead of redirecting to HTTPS
  # We'll handle SSL termination at the EC2 instance level with Let's Encrypt
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# Backend Listener Rule (api.domain.com) - HTTP
resource "aws_lb_listener_rule" "backend_http" {
  listener_arn = aws_lb_listener.frontend_http.arn
  priority     = 100

  condition {
    host_header {
      values = ["api.${var.domain_name}"]
    }
  }

  # Forward to target group instead of redirecting to HTTPS
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# Metabase Listener Rule (bi.domain.com) - HTTP
resource "aws_lb_listener_rule" "metabase_http" {
  listener_arn = aws_lb_listener.frontend_http.arn
  priority     = 200

  condition {
    host_header {
      values = ["bi.${var.domain_name}"]
    }
  }

  # Forward to target group instead of redirecting to HTTPS
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.metabase.arn
  }
}

# Note: HTTPS listener has been removed since we're handling SSL at the EC2 instance level
# with Let's Encrypt. This simplifies the ALB configuration and avoids the need for 
# certificates at the ALB level.