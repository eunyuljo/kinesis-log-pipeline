variable "project_name" {
  description = "프로젝트 이름"
  type        = string
  default     = "centralized-logs"
}

variable "environment" {
  description = "환경 (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "s3_log_retention_days" {
  description = "S3에 저장된 로그 보관 기간 (일)"
  type        = number
  default     = 90
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch Logs 보관 기간 (일)"
  type        = number
  default     = 7
}

variable "firehose_buffer_size" {
  description = "Firehose 버퍼 크기 (MB)"
  type        = number
  default     = 5
}

variable "firehose_buffer_interval" {
  description = "Firehose 버퍼 간격 (초)"
  type        = number
  default     = 300
}

variable "ec2_instance_type" {
  description = "On-Premise 시뮬레이션 EC2 인스턴스 타입"
  type        = string
  default     = "t3.small"
}

variable "enable_vpc_endpoints" {
  description = "VPC Endpoint 활성화 (Private 연결, 인터넷 경유 안 함)"
  type        = bool
  default     = false # 기본값: 비활성화 (Internet Gateway 사용)
}

variable "enable_tgw_architecture" {
  description = "Transit Gateway 아키텍처 활성화 (엔터프라이즈급 On-Premise 시뮬레이션)"
  type        = bool
  default     = false # 기본값: 비활성화 (단일 VPC + Internet Gateway, 테스트용)
}


variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Purpose   = "Centralized Logging"
  }
}
