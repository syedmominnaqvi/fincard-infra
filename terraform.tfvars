# AWS Configuration
aws_region = "us-west-2"
environment = "prod"
project_name = "fincard"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

# EC2 Configuration
ec2_instance_type = "t2.micro"
ami_id = "ami-06e275de60164ac29"  # Amazon Linux 2 in us-west-2
key_name = "mnaqvi-aws"  # Using the existing key

# Domain Name
domain_name = "jenkins-devops.store"

# SSL/TLS Configuration
ssl_policy = "ELBSecurityPolicy-2016-08"

# PostgreSQL RDS Configuration
postgres_instance_class = "db.t3.micro"
postgres_db_name = "fincard"
postgres_username = "postgres"
postgres_password = "FinCard123!"
postgres_port = 5432

# MySQL RDS Configuration
mysql_instance_class = "db.t3.micro"
mysql_db_name = "fincard_mysql"
mysql_username = "admin"
mysql_password = "FinCard123!"
mysql_port = 3306

# Database Storage
db_storage = 20

# Metabase Configuration
metabase_db_user = "metabase"
metabase_db_password = "FinCard123!"

# Auto Scaling Group Configuration
asg_min_size = 1
asg_max_size = 3
asg_desired_capacity = 1