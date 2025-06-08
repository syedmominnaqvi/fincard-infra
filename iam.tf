# S3 access policy for EC2 instances
resource "aws_iam_policy" "s3_access" {
  name        = "${var.project_name}-s3-access-policy-${var.environment}"
  description = "Policy to allow EC2 instances to access S3 scripts bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.scripts.arn,
          "${aws_s3_bucket.scripts.arn}/*",
        ]
      },
    ]
  })
}

# SSM Parameter Store access policy
resource "aws_iam_policy" "ssm_parameter_access" {
  name        = "${var.project_name}-ssm-parameter-access-${var.environment}"
  description = "Policy to allow EC2 instances to access SSM parameters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/*"
        ]
      },
      {
        Action = [
          "kms:Decrypt"
        ]
        Effect = "Allow"
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Attach the S3 access policy to the EC2 role
resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# Attach the SSM Parameter Store access policy to the EC2 role
resource "aws_iam_role_policy_attachment" "ssm_parameter_access_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ssm_parameter_access.arn
}