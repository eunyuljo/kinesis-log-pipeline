# ============================================================
# Outputs
# ============================================================

output "s3_bucket_name" {
  description = "로그가 저장되는 S3 버킷 이름"
  value       = aws_s3_bucket.log_storage.id
}

output "s3_bucket_arn" {
  description = "S3 버킷 ARN"
  value       = aws_s3_bucket.log_storage.arn
}

output "firehose_stream_name" {
  description = "Kinesis Firehose 스트림 이름"
  value       = aws_kinesis_firehose_delivery_stream.log_stream.name
}

output "firehose_stream_arn" {
  description = "Kinesis Firehose 스트림 ARN"
  value       = aws_kinesis_firehose_delivery_stream.log_stream.arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch 로그 그룹 이름"
  value       = aws_cloudwatch_log_group.application_logs.name
}

output "kinesis_agent_access_key_id" {
  description = "On-Premise Kinesis Agent용 액세스 키 ID"
  value       = aws_iam_access_key.kinesis_agent.id
  sensitive   = false
}

output "kinesis_agent_secret_access_key" {
  description = "On-Premise Kinesis Agent용 시크릿 액세스 키"
  value       = aws_iam_access_key.kinesis_agent.secret
  sensitive   = true
}

output "region" {
  description = "AWS 리전"
  value       = var.region
}

output "ec2_instance_id" {
  description = "On-Premise 시뮬레이션 EC2 인스턴스 ID"
  value       = aws_instance.onpremise_server.id
}

output "ec2_public_ip" {
  description = "EC2 인스턴스 Public IP"
  value       = aws_instance.onpremise_server.public_ip
}

output "ec2_private_ip" {
  description = "EC2 인스턴스 Private IP"
  value       = aws_instance.onpremise_server.private_ip
}

output "ssm_connect_command" {
  description = "SSM으로 EC2 접속하는 명령어"
  value       = "aws ssm start-session --target ${aws_instance.onpremise_server.id} --region ${var.region}"
}

output "setup_instructions" {
  description = "On-Premise 서버 설정 가이드"
  value       = <<-EOT

  ╔══════════════════════════════════════════════════════════════╗
  ║  Kinesis 로그 중앙화 시스템 배포 완료!                       ║
  ╚══════════════════════════════════════════════════════════════╝

  📦 배포된 리소스:
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  • Firehose Stream: ${aws_kinesis_firehose_delivery_stream.log_stream.name}
  • S3 Bucket: ${aws_s3_bucket.log_storage.id}
  • CloudWatch Log Group: ${aws_cloudwatch_log_group.application_logs.name}
  • EC2 Instance: ${aws_instance.onpremise_server.id}
  • Region: ${var.region}

  🖥️  On-Premise 시뮬레이션 EC2 접속:
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1. SSM Session Manager로 접속 (추천):
     aws ssm start-session --target ${aws_instance.onpremise_server.id} --region ${var.region}

  2. Kinesis Agent 상태 확인:
     sudo systemctl status aws-kinesis-agent

  3. Agent 로그 확인:
     sudo tail -f /var/log/aws-kinesis-agent/aws-kinesis-agent.log

  4. 테스트 로그 생성:
     echo "$(date) [INFO] Test log from EC2" | sudo tee -a /var/log/application/test.log

  5. 샘플 로그 생성기 시작 (선택사항):
     sudo systemctl start sample-log-generator
     sudo systemctl enable sample-log-generator

  📊 모니터링:
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  • S3 확인 (5-10분 대기):
    aws s3 ls s3://${aws_s3_bucket.log_storage.id}/logs/ --recursive

  • CloudWatch Logs 확인:
    aws logs tail ${aws_cloudwatch_log_group.application_logs.name} --follow

  ══════════════════════════════════════════════════════════════
  💡 Kinesis Agent는 자동으로 설치되어 실행 중입니다!
  ══════════════════════════════════════════════════════════════
  EOT
}

# ============================================================
# 아키텍처 정보 Outputs
# ============================================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "architecture_type" {
  description = "사용 중인 아키텍처 타입"
  value       = "Internet Gateway (Simple & Cost-Effective)"
}

output "estimated_monthly_cost" {
  description = "예상 월간 비용 (USD)"
  value       = "~$30 (테스트/학습용 최적화)"
}
