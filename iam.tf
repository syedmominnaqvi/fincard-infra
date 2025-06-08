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

# Attach the S3 access policy to the EC2 role
resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}