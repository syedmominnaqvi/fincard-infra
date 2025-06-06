# Create DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-db-subnet-group-${var.environment}"
  description = "DB subnet group for ${var.project_name} ${var.environment}"
  subnet_ids  = aws_subnet.private.*.id

  tags = {
    Name = "${var.project_name}-db-subnet-group-${var.environment}"
  }
}

# Create PostgreSQL RDS instance
resource "aws_db_instance" "postgres" {
  identifier              = "${var.project_name}-postgres-${var.environment}"
  allocated_storage       = var.db_storage
  storage_type            = "gp2"
  engine                  = "postgres"
  engine_version          = "14.18"  # Updated to latest supported version
  instance_class          = var.postgres_instance_class
  username                = var.postgres_username
  password                = var.postgres_password
  parameter_group_name    = "default.postgres14"  # Match the engine version
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.postgres_rds.id]
  multi_az                = false
  publicly_accessible     = false
  skip_final_snapshot     = true
  backup_retention_period = 7
  apply_immediately       = true
  port                    = var.postgres_port

  # Create initial database
  db_name = var.postgres_db_name

  # Enable encryption
  storage_encrypted = true

  # Enable auto minor version upgrades
  auto_minor_version_upgrade = true

  # Maintenance window
  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  # Disable Performance Insights as it might not be supported
  performance_insights_enabled = false

  # Disable deletion protection for easier cleanup in dev/test environments
  # Set to true for production
  deletion_protection = false

  tags = {
    Name = "${var.project_name}-postgres-db-${var.environment}"
  }
}

# Create MySQL RDS instance
resource "aws_db_instance" "mysql" {
  identifier              = "${var.project_name}-mysql-${var.environment}"
  allocated_storage       = var.db_storage
  storage_type            = "gp2"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = var.mysql_instance_class
  username                = var.mysql_username
  password                = var.mysql_password
  parameter_group_name    = "default.mysql8.0"
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.mysql_rds.id]
  multi_az                = false
  publicly_accessible     = false
  skip_final_snapshot     = true
  backup_retention_period = 7
  apply_immediately       = true
  port                    = var.mysql_port

  # Create initial database
  db_name = var.mysql_db_name

  # Enable encryption
  storage_encrypted = true

  # Enable auto minor version upgrades
  auto_minor_version_upgrade = true

  # Maintenance window
  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  # Disable Performance Insights as it might not be supported
  performance_insights_enabled = false

  # Disable deletion protection for easier cleanup in dev/test environments
  # Set to true for production
  deletion_protection = false

  tags = {
    Name = "${var.project_name}-mysql-db-${var.environment}"
  }
}