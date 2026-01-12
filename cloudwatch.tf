# ============================================================
# CloudWatch Logs for Real-time Monitoring
# ============================================================

# CloudWatch 로그 그룹 생성
resource "aws_cloudwatch_log_group" "application_logs" {
  name              = "/aws/kinesis/${var.project_name}-${var.environment}/application"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = {
    Name        = "${var.project_name}-${var.environment}-application-logs"
    Description = "Application logs from on-premise servers"
  }
}

# CloudWatch 로그 스트림 생성
resource "aws_cloudwatch_log_stream" "firehose_stream" {
  name           = "firehose-delivery"
  log_group_name = aws_cloudwatch_log_group.application_logs.name
}

# CloudWatch 메트릭 필터 - 에러 로그 카운트
resource "aws_cloudwatch_log_metric_filter" "error_count" {
  name           = "${var.project_name}-error-count"
  log_group_name = aws_cloudwatch_log_group.application_logs.name
  pattern        = "[ERROR]"

  metric_transformation {
    name      = "ErrorCount"
    namespace = "${var.project_name}/${var.environment}"
    value     = "1"
  }
}

# CloudWatch 알람 - 에러 로그 급증 감지
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${var.project_name}-${var.environment}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ErrorCount"
  namespace           = "${var.project_name}/${var.environment}"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "This metric monitors error log count"
  treat_missing_data  = "notBreaching"

  tags = {
    Name = "${var.project_name}-${var.environment}-error-alarm"
  }
}
