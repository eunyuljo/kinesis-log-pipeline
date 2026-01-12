# ============================================================
# Kinesis Data Firehose Delivery Stream
# ============================================================

resource "aws_kinesis_firehose_delivery_stream" "log_stream" {
  name        = "${var.project_name}-${var.environment}-log-stream"
  destination = "extended_s3"

  # S3 대상 설정
  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.log_storage.arn

    # S3 저장 경로 지정 (연도/월/일/시간별 파티셔닝)
    prefix              = "logs/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "errors/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/!{firehose:error-output-type}/"

    # 버퍼링 설정 (성능 최적화)
    buffering_size     = var.firehose_buffer_size     # MB 단위
    buffering_interval = var.firehose_buffer_interval # 초 단위

    # 압축 설정 (비용 절감)
    compression_format = "GZIP"

    # CloudWatch Logs 로깅 설정
    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose_logs.name
      log_stream_name = aws_cloudwatch_log_stream.firehose_s3_delivery.name
    }

    # 데이터 처리 설정 (선택사항)
    processing_configuration {
      enabled = true

      processors {
        type = "Lambda"
        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = "${aws_lambda_function.log_transformer.arn}:$LATEST"
        }
      }
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-firehose"
    Description = "Kinesis Firehose for centralized logging from on-premise"
  }
}

# Firehose 자체 로깅을 위한 CloudWatch 로그 그룹
resource "aws_cloudwatch_log_group" "firehose_logs" {
  name              = "/aws/kinesisfirehose/${var.project_name}-${var.environment}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-firehose-logs"
  }
}

resource "aws_cloudwatch_log_stream" "firehose_s3_delivery" {
  name           = "S3Delivery"
  log_group_name = aws_cloudwatch_log_group.firehose_logs.name
}

# ============================================================
# Lambda Function for Log Transformation (선택사항)
# ============================================================

# Lambda 실행 역할
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Lambda 기본 실행 권한 연결
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda 함수 - 로그 변환/파싱
resource "aws_lambda_function" "log_transformer" {
  filename      = "lambda_function.zip"
  function_name = "${var.project_name}-${var.environment}-log-transformer"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 60

  environment {
    variables = {
      ENVIRONMENT = var.environment
      PROJECT     = var.project_name
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-log-transformer"
  }
}

# Firehose가 Lambda를 호출할 수 있는 권한
resource "aws_lambda_permission" "allow_firehose" {
  statement_id  = "AllowExecutionFromFirehose"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_transformer.function_name
  principal     = "firehose.amazonaws.com"
  source_arn    = aws_kinesis_firehose_delivery_stream.log_stream.arn
}
