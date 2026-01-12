terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = merge(

      var.tags,
      {
        Environment = var.environment
        Project     = var.project_name
      }
    )
  }
}

# 현재 AWS 계정 정보 가져오기
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
