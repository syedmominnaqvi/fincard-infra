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
- AWS SSM Parameter Store

## EC2 Bootstrap Architecture

The Metabase deployment uses a bootstrap architecture to handle large initialization scripts:

1. **S3 Storage**: Large scripts are stored in an S3 bucket with versioning enabled.
   - MySQL dummy data SQL script
   - Metabase setup script
   - MySQL loader script
   - Nginx configuration

2. **Bootstrap Script**: The EC2 user data contains a minimal bootstrap script that:
   - Installs essential packages
   - Sets up SSH tunnels to databases
   - Downloads larger scripts from S3 with retry logic
   - Executes the downloaded scripts in the proper sequence
   - Retrieves sensitive configuration from SSM Parameter Store

3. **Version Control**: All scripts are versioned using:
   - S3 bucket versioning
   - Content-based ETags
   - Version metadata on objects

4. **IAM Permissions**: EC2 instances have IAM permissions to access the S3 bucket and SSM Parameter Store.

This approach ensures that the EC2 user data remains well under the 16KB limit while maintaining all functionality.

## AWS SSM Parameter Store Integration

Sensitive configuration values are managed using AWS SSM Parameter Store:

1. **Secure Parameters**: All sensitive values (passwords, connection strings, API keys) are stored as SecureString parameters.

2. **Hierarchical Structure**: Parameters are organized using a hierarchical structure:
   - `/{project_name}/{environment}/postgres/*`
   - `/{project_name}/{environment}/mysql/*`
   - `/{project_name}/{environment}/api/*`
   - `/{project_name}/{environment}/metabase/*`

3. **IAM Permissions**: EC2 instances have limited IAM permissions to access only the parameters they need.

4. **Benefits**:
   - No hardcoded credentials in scripts or user data
   - Centralized credential management
   - Audit trail for parameter access
   - Easy credential rotation without infrastructure changes

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

- All database credentials are stored in SSM Parameter Store.
- SSH tunnels are used for database access from EC2 instances.
- Metabase automatically configures itself with MySQL sample data.
- Error handling and retry mechanisms are implemented for all critical operations.