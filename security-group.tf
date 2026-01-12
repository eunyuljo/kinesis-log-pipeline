# ============================================================
# Security Group for On-Premise EC2
# ============================================================

resource "aws_security_group" "onpremise_ec2" {
  name        = "${var.project_name}-${var.environment}-onpremise-ec2-sg"
  description = "Security group for on-premise simulation EC2"
  vpc_id      = aws_vpc.main.id

  # Egress: 모든 아웃바운드 트래픽 허용 (Kinesis, SSM 등)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  # Ingress: HTTPS (Kinesis Agent 모니터링용, 선택사항)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "HTTPS from VPC"
  }


  tags = {
    Name = "${var.project_name}-${var.environment}-onpremise-ec2-sg"
  }
}
