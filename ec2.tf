# ============================================================
# EC2 Instance - On-Premise Simulation
# ============================================================

# Amazon Linux 2023 AMI 조회
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# IAM Role for EC2 (SSM + Kinesis Agent)
resource "aws_iam_role" "onpremise_ec2_role" {
  name = "${var.project_name}-${var.environment}-onpremise-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-onpremise-ec2-role"
  }
}

# SSM 관리 권한 연결
resource "aws_iam_role_policy_attachment" "onpremise_ssm" {
  role       = aws_iam_role.onpremise_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Kinesis Firehose 쓰기 권한 (EC2 인스턴스용)
resource "aws_iam_role_policy" "onpremise_kinesis" {
  name = "${var.project_name}-${var.environment}-onpremise-kinesis"
  role = aws_iam_role.onpremise_ec2_role.id

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
        Resource = aws_kinesis_firehose_delivery_stream.log_stream.arn
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "AWSKinesisAgent"
          }
        }
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "onpremise_ec2" {
  name = "${var.project_name}-${var.environment}-onpremise-ec2-profile"
  role = aws_iam_role.onpremise_ec2_role.name

  tags = {
    Name = "${var.project_name}-${var.environment}-onpremise-ec2-profile"
  }
}

# User Data Script for Kinesis Agent Installation
data "template_file" "user_data" {
  template = file("${path.module}/user-data/install-kinesis-agent.sh")

  vars = {
    firehose_stream_name = aws_kinesis_firehose_delivery_stream.log_stream.name
    region               = var.region
    environment          = var.environment
    project_name         = var.project_name
  }
}

# EC2 Instance
resource "aws_instance" "onpremise_server" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.ec2_instance_type
  # TGW 아키텍처: Private Subnet, IGW 아키텍처: Public Subnet
  subnet_id              = var.enable_tgw_architecture ? aws_subnet.private[0].id : aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.onpremise_ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.onpremise_ec2.name

  user_data = data.template_file.user_data.rendered

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.project_name}-${var.environment}-onpremise-root"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 강제
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-onpremise-server"
    Description = "On-Premise server simulation for Kinesis logging"
    OS          = "Amazon Linux 2023"
  }

  lifecycle {
    ignore_changes = [
      ami,
      user_data
    ]
  }
}

# CloudWatch Alarm - EC2 Status Check
resource "aws_cloudwatch_metric_alarm" "onpremise_ec2_status" {
  alarm_name          = "${var.project_name}-${var.environment}-onpremise-ec2-status"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors EC2 status check"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.onpremise_server.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-status-alarm"
  }
}
