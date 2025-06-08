# Frontend Launch Template
resource "aws_launch_template" "frontend" {
  name_prefix            = "${var.project_name}-frontend-lt-"
  image_id               = var.ami_id
  instance_type          = var.ec2_instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.frontend.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(
    templatefile("${path.module}/frontend_userdata.sh", {})
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-frontend-${var.environment}"
      Role = "frontend"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Backend Launch Template
resource "aws_launch_template" "backend" {
  name_prefix            = "${var.project_name}-backend-lt-"
  image_id               = var.ami_id
  instance_type          = var.ec2_instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.backend.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(
    templatefile("${path.module}/backend_userdata.sh", {
      postgres_host       = aws_db_instance.postgres.address
      postgres_port       = var.postgres_port
      postgres_db_name    = var.postgres_db_name
      postgres_username   = var.postgres_username
      postgres_password   = var.postgres_password
      mysql_host          = aws_db_instance.mysql.address
      mysql_port          = var.mysql_port
      mysql_db_name       = var.mysql_db_name
      mysql_username      = var.mysql_username
      mysql_password      = var.mysql_password
    })
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-backend-${var.environment}"
      Role = "backend"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Metabase Launch Template
resource "aws_launch_template" "metabase" {
  name_prefix            = "${var.project_name}-metabase-lt-"
  image_id               = var.ami_id
  instance_type          = var.ec2_instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.metabase.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(
    templatefile("${path.module}/metabase_userdata.sh", {
      postgres_host       = aws_db_instance.postgres.address
      postgres_port       = var.postgres_port
      postgres_db_name    = var.postgres_db_name
      postgres_username   = var.postgres_username
      postgres_password   = var.postgres_password
      mysql_host          = aws_db_instance.mysql.address
      mysql_port          = var.mysql_port
      mysql_db_name       = var.mysql_db_name
      mysql_username      = var.mysql_username
      mysql_password      = var.mysql_password
      s3_bucket_name      = aws_s3_bucket.scripts.id
      script_version      = local.script_version
    })
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-metabase-${var.environment}"
      Role = "metabase"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# IAM Role and Instance Profile
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile-${var.environment}"
  role = aws_iam_role.ec2_role.name
}

# Frontend Auto Scaling Group
resource "aws_autoscaling_group" "frontend" {
  name                = "${var.project_name}-frontend-asg-${var.environment}"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity
  vpc_zone_identifier = aws_subnet.private.*.id
  target_group_arns   = [aws_lb_target_group.frontend.arn]
  depends_on = [aws_nat_gateway.main]

  launch_template {
    id      = aws_launch_template.frontend.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-frontend-${var.environment}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "frontend"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Backend Auto Scaling Group
resource "aws_autoscaling_group" "backend" {
  name                = "${var.project_name}-backend-asg-${var.environment}"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity
  vpc_zone_identifier = aws_subnet.private.*.id
  target_group_arns   = [aws_lb_target_group.backend.arn]

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-backend-${var.environment}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "backend"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Metabase Auto Scaling Group
resource "aws_autoscaling_group" "metabase" {
  name                = "${var.project_name}-metabase-asg-${var.environment}"
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = aws_subnet.private.*.id
  target_group_arns   = [aws_lb_target_group.metabase.arn]

  launch_template {
    id      = aws_launch_template.metabase.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-metabase-${var.environment}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "metabase"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}