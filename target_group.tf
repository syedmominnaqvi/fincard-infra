# Frontend Target Group
resource "aws_lb_target_group" "frontend" {
  name     = "${var.project_name}-frontend-tg-${var.environment}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  # Use this target_type for instances in an auto scaling group
  target_type = "instance"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-frontend-tg-${var.environment}"
  }
}

# Backend Target Group
resource "aws_lb_target_group" "backend" {
  name     = "${var.project_name}-backend-tg-${var.environment}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  # Use this target_type for instances in an auto scaling group
  target_type = "instance"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/health"  # Updated to use dedicated health check endpoint
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-backend-tg-${var.environment}"
  }
}

# Metabase Target Group
resource "aws_lb_target_group" "metabase" {
  name     = "${var.project_name}-metabase-tg-${var.environment}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  # Use this target_type for instances in an auto scaling group
  target_type = "instance"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/health"  # Updated to use dedicated health check endpoint
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-metabase-tg-${var.environment}"
  }
}