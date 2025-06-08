variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name, e.g. dev, stage, prod"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "fincard"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets"
  type        = list(string)
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

# EC2 Variables
variable "ec2_instance_type" {
  description = "EC2 instance type (free tier eligible)"
  type        = string
  default     = "t2.micro"  # Changed to t2.micro for free tier
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (Amazon Linux 2)"
  type        = string
  default     = "ami-06e275de60164ac29" # Amazon Linux 2 in us-west-2, update for other regions
  # For production, use the SSM parameter reference:
  # default = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = "mnaqvi-aws"  # Using the existing key
}

# Domain name variables
variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "jenkins-devops.store"
}

# PostgreSQL RDS Variables
variable "postgres_instance_class" {
  description = "PostgreSQL RDS instance class (free tier eligible)"
  type        = string
  default     = "db.t3.micro"  # t3.micro is free tier eligible
}

variable "postgres_db_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "fincard"
}

variable "postgres_username" {
  description = "Username for the PostgreSQL database"
  type        = string
  default     = "postgres"
}

variable "postgres_password" {
  description = "Password for the PostgreSQL database"
  type        = string
  default     = "FinCard123!"
}

variable "postgres_port" {
  description = "Port for the PostgreSQL database"
  type        = number
  default     = 5432
}

# MySQL RDS Variables
variable "mysql_instance_class" {
  description = "MySQL RDS instance class (free tier eligible)"
  type        = string
  default     = "db.t3.micro"  # t3.micro is free tier eligible
}

variable "mysql_db_name" {
  description = "Name of the MySQL database"
  type        = string
  default     = "fincard_mysql"
}

variable "mysql_username" {
  description = "Username for the MySQL database"
  type        = string
  default     = "admin"
}

variable "mysql_password" {
  description = "Password for the MySQL database"
  type        = string
  default     = "FinCard123!"
}

variable "mysql_port" {
  description = "Port for the MySQL database"
  type        = number
  default     = 3306
}

# ACM Certificate variables
variable "ssl_policy" {
  description = "SSL policy for HTTPS listeners"
  type        = string
  default     = "ELBSecurityPolicy-2016-08"
}

variable "db_storage" {
  description = "Storage size for the database in GB (minimum for free tier)"
  type        = number
  default     = 20  # Free tier includes 20GB of storage
}

# Metabase Variables
variable "metabase_db_user" {
  description = "Username for the Metabase database"
  type        = string
  default     = "metabase"
}

variable "metabase_db_password" {
  description = "Password for the Metabase database"
  type        = string
  default     = "FinCard123!"
}

# Auto Scaling Group Variables
variable "asg_min_size" {
  description = "Minimum size of the auto scaling group"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum size of the auto scaling group"
  type        = number
  default     = 3
}

variable "asg_desired_capacity" {
  description = "Desired capacity of the auto scaling group"
  type        = number
  default     = 1
}

# This SSL policy is already defined above at line 128