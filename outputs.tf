# VPC Outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets"
  value       = aws_subnet.public.*.id
}

output "private_subnet_ids" {
  description = "The IDs of the private subnets"
  value       = aws_subnet.private.*.id
}

# Load Balancer Outputs
output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "The canonical hosted zone ID of the ALB"
  value       = aws_lb.main.zone_id
}

# Target Group Outputs
output "frontend_target_group_arn" {
  description = "The ARN of the frontend target group"
  value       = aws_lb_target_group.frontend.arn
}

output "backend_target_group_arn" {
  description = "The ARN of the backend target group"
  value       = aws_lb_target_group.backend.arn
}

output "metabase_target_group_arn" {
  description = "The ARN of the Metabase target group"
  value       = aws_lb_target_group.metabase.arn
}

# Auto Scaling Group Outputs
output "frontend_asg_name" {
  description = "The name of the frontend Auto Scaling Group"
  value       = aws_autoscaling_group.frontend.name
}

output "backend_asg_name" {
  description = "The name of the backend Auto Scaling Group"
  value       = aws_autoscaling_group.backend.name
}

output "metabase_asg_name" {
  description = "The name of the Metabase Auto Scaling Group"
  value       = aws_autoscaling_group.metabase.name
}

# RDS Outputs
output "postgres_rds_endpoint" {
  description = "The connection endpoint for the PostgreSQL RDS instance"
  value       = aws_db_instance.postgres.endpoint
}

output "postgres_rds_address" {
  description = "The hostname of the PostgreSQL RDS instance"
  value       = aws_db_instance.postgres.address
}

output "mysql_rds_endpoint" {
  description = "The connection endpoint for the MySQL RDS instance"
  value       = aws_db_instance.mysql.endpoint
}

output "mysql_rds_address" {
  description = "The hostname of the MySQL RDS instance"
  value       = aws_db_instance.mysql.address
}

# Route53 Outputs
output "domain_name" {
  description = "The domain name for the application"
  value       = var.domain_name
}

output "api_domain_name" {
  description = "The API subdomain name"
  value       = "api.${var.domain_name}"
}

output "metabase_domain_name" {
  description = "The Metabase subdomain name"
  value       = "bi.${var.domain_name}"
}

# ACM Certificate Outputs
output "acm_certificate_arn" {
  description = "The ARN of the ACM certificate"
  value       = aws_acm_certificate.main.arn
}

output "acm_certificate_validation_arn" {
  description = "The ARN of the validated ACM certificate"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

# Application URLs
output "frontend_url" {
  description = "URL for the frontend application"
  value       = "https://${var.domain_name}"
}

output "backend_url" {
  description = "URL for the backend API"
  value       = "https://api.${var.domain_name}"
}

output "metabase_url" {
  description = "URL for the Metabase BI tool"
  value       = "https://bi.${var.domain_name}"
}

# SSH Tunnel Commands
output "ssh_tunnel_postgres_command" {
  description = "Command to create SSH tunnel to PostgreSQL RDS"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem -N -L 5433:${aws_db_instance.postgres.address}:${var.postgres_port} ec2-user@<EC2_PUBLIC_IP>"
}

output "ssh_tunnel_mysql_command" {
  description = "Command to create SSH tunnel to MySQL RDS"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem -N -L 3307:${aws_db_instance.mysql.address}:${var.mysql_port} ec2-user@<EC2_PUBLIC_IP>"
}