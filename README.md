# FinCard Infrastructure

This repository contains Terraform code to deploy the FinCard application infrastructure on AWS.

## Overview

The infrastructure includes:
- Frontend EC2 instances
- Backend EC2 instances
- Metabase analytics instance
- PostgreSQL RDS instance
- MySQL RDS instance
- Application Load Balancer
- Security Groups
- Route53 DNS records

## EC2 Bootstrap Architecture

The deployment uses a bootstrap architecture to handle large initialization scripts:

1. **S3 Storage**: Large scripts are stored in an S3 bucket with versioning enabled.
   - MySQL dummy data SQL script
   - Metabase setup script
   - MySQL loader script
   - Nginx configuration
   - Bootstrap scripts

2. **Bootstrap Script**: The EC2 user data contains a minimal bootstrap script that:
   - Installs essential packages
   - Downloads larger scripts from S3 with retry logic
   - Sets up SSH tunnels to databases
   - Executes the downloaded scripts in the proper sequence

3. **Version Control**: All scripts are versioned using:
   - S3 bucket versioning
   - Content-based ETags
   - Version metadata on objects

4. **IAM Permissions**: EC2 instances have IAM permissions to access the S3 bucket.

This approach ensures that the EC2 user data remains well under the 16KB limit while maintaining all functionality.

## Planned Improvements

### AWS SSM Parameter Store Integration (Planned)

Plans for managing sensitive configuration values using AWS SSM Parameter Store:

1. **Secure Parameters**: All sensitive values (passwords, connection strings, API keys) to be stored as SecureString parameters.

2. **Hierarchical Structure**: Parameters to be organized using a hierarchical structure:
   - `/{project_name}/{environment}/postgres/*`
   - `/{project_name}/{environment}/mysql/*`
   - `/{project_name}/{environment}/api/*`
   - `/{project_name}/{environment}/metabase/*`

3. **IAM Permissions**: EC2 instances to have limited IAM permissions to access only the parameters they need.

4. **Benefits**:
   - No hardcoded credentials in scripts or user data
   - Centralized credential management
   - Audit trail for parameter access
   - Easy credential rotation without infrastructure changes

## Database Connectivity

The infrastructure uses SSH tunnels for secure database access:

1. **SSH Tunnels**: Each EC2 instance:
   - Generates a local SSH key pair
   - Creates tunnels to both PostgreSQL and MySQL RDS instances
   - Forwards local ports to the database ports
   - Includes cron jobs to ensure tunnels stay active

2. **Connection Testing**: The setup includes:
   - Functions to test both tunneled and direct database connections
   - Automatic fallback from tunnel to direct connection if needed
   - Database existence verification and automatic creation

3. **Connection Scripts**: Helper scripts are created for easy database access:
   - `connect_postgres.sh` for PostgreSQL via SSH tunnel
   - `connect_mysql.sh` for MySQL via SSH tunnel
   - `connect_mysql_direct.sh` for direct MySQL connection

## Nginx Configuration

The Metabase instance uses Nginx as a reverse proxy with the following features:

1. **Robust Configuration**:
   - Default server configuration to catch all requests
   - Proper proxy headers for WebSocket support
   - Health check endpoint for ALB

2. **Validation and Fallback**:
   - Nginx configuration is validated before applying
   - Fallback to minimal working configuration if validation fails

3. **Error Handling**:
   - Improved error logging and diagnostics
   - Graceful handling of proxy errors

## Usage

1. Copy `terraform.tfvars.example` to `terraform.tfvars` and configure variables.
2. Run `terraform init` to initialize.
3. Run `terraform plan` to preview changes.
4. Run `terraform apply` to deploy the infrastructure.

## Notes

- All database credentials are passed to EC2 instances securely via the launch template.
- SSH tunnels are used for database access from EC2 instances.
- Metabase automatically configures itself with MySQL sample data.
- Error handling and retry mechanisms are implemented for all critical operations.