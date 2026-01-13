# ============================================================
# IAM Roles and Policies for Kinesis Firehose
# ============================================================

# Kinesis Firehose용 IAM 역할
resource "aws_iam_role" "firehose_role" {
  name = "${var.project_name}-${var.environment}-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-firehose-role"
  }
}

# Firehose → S3 쓰기 권한
resource "aws_iam_role_policy" "firehose_s3_policy" {
  name = "${var.project_name}-${var.environment}-firehose-s3"
  role = aws_iam_role.firehose_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.log_storage.arn,
          "${aws_s3_bucket.log_storage.arn}/*"
        ]
      }
    ]
  })
}

# Firehose → CloudWatch Logs 쓰기 권한
resource "aws_iam_role_policy" "firehose_cloudwatch_policy" {
  name = "${var.project_name}-${var.environment}-firehose-cloudwatch"
  role = aws_iam_role.firehose_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.application_logs.arn,
          "${aws_cloudwatch_log_group.application_logs.arn}:*"
        ]
      }
    ]
  })
}

# Firehose → Lambda 호출 권한
resource "aws_iam_role_policy" "firehose_lambda_policy" {
  name = "${var.project_name}-${var.environment}-firehose-lambda"
  role = aws_iam_role.firehose_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          "${aws_lambda_function.log_transformer.arn}:*",
          "${aws_lambda_function.cloudwatch_sender.arn}:*"
        ]
      }
    ]
  })
}

# ============================================================
# IAM User for On-Premise Kinesis Agent
# ============================================================

# On-Premise 서버의 Kinesis Agent용 IAM 사용자
resource "aws_iam_user" "kinesis_agent" {
  name = "${var.project_name}-${var.environment}-kinesis-agent"
  path = "/service/"

  tags = {
    Name        = "${var.project_name}-${var.environment}-kinesis-agent"
    Description = "IAM user for on-premise Kinesis Agent"
  }
}

# Kinesis Agent용 액세스 키 생성
resource "aws_iam_access_key" "kinesis_agent" {
  user = aws_iam_user.kinesis_agent.name
}

# Kinesis Agent → Firehose 쓰기 권한
resource "aws_iam_user_policy" "kinesis_agent_policy" {
  name = "${var.project_name}-${var.environment}-agent-policy"
  user = aws_iam_user.kinesis_agent.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch",
          "firehose:DescribeDeliveryStream"
        ]
        Resource = [
          aws_kinesis_firehose_delivery_stream.log_stream.arn,
          aws_kinesis_firehose_delivery_stream.cloudwatch_stream.arn
        ]
      }
    ]
  })
}
