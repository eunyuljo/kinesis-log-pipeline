#!/bin/bash

# ============================================================
# Kinesis 로그 중앙화 시스템 배포 스크립트
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "====================================<br/>===================================="
echo "Kinesis 로그 중앙화 시스템 배포"
echo "================================================================<br/>========"
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 사전 요구사항 확인
echo -e "${YELLOW}[1/5] 사전 요구사항 확인 중...${NC}"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}✗ Terraform이 설치되지 않았습니다.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Terraform 설치 확인${NC}"

if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI가 설치되지 않았습니다.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ AWS CLI 설치 확인${NC}"

# AWS 자격증명 확인
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}✗ AWS 자격증명이 설정되지 않았습니다.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ AWS 자격증명 확인${NC}"
echo ""

# 2. Terraform 변수 파일 확인
echo -e "${YELLOW}[2/5] Terraform 변수 파일 확인 중...${NC}"

if [ ! -f "${PROJECT_DIR}/terraform.tfvars" ]; then
    echo -e "${YELLOW}⚠ terraform.tfvars 파일이 없습니다. 예시 파일을 복사합니다.${NC}"
    cp "${PROJECT_DIR}/terraform.tfvars.example" "${PROJECT_DIR}/terraform.tfvars"
    echo -e "${YELLOW}terraform.tfvars 파일을 수정한 후 다시 실행하세요.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ terraform.tfvars 파일 존재${NC}"
echo ""

# 3. Lambda 함수 ZIP 파일 생성
echo -e "${YELLOW}[3/5] Lambda 함수 패키징 중...${NC}"

cd "${PROJECT_DIR}/lambda"
if [ -f "${PROJECT_DIR}/lambda_function.zip" ]; then
    rm "${PROJECT_DIR}/lambda_function.zip"
fi
zip -q "${PROJECT_DIR}/lambda_function.zip" index.py
echo -e "${GREEN}✓ Lambda 함수 ZIP 파일 생성 완료${NC}"
echo ""

# 4. Terraform 초기화
echo -e "${YELLOW}[4/5] Terraform 초기화 중...${NC}"

cd "${PROJECT_DIR}"
terraform init
echo -e "${GREEN}✓ Terraform 초기화 완료${NC}"
echo ""

# 5. Terraform 배포
echo -e "${YELLOW}[5/5] Terraform 배포 중...${NC}"

terraform plan -out=tfplan

echo ""
read -p "위 계획을 확인했습니다. 배포를 진행하시겠습니까? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${RED}배포가 취소되었습니다.${NC}"
    rm -f tfplan
    exit 0
fi

terraform apply tfplan
rm -f tfplan

echo ""
echo -e "${GREEN}=====================================================================${NC}"
echo -e "${GREEN}✓ 배포가 완료되었습니다!${NC}"
echo -e "${GREEN}=====================================================================${NC}"
echo ""

# 출력 값 표시
echo -e "${YELLOW}=== 배포 정보 ===${NC}"
terraform output
echo ""

echo -e "${YELLOW}=== 다음 단계 ===${NC}"
echo "1. On-Premise 서버에 Kinesis Agent 설치"
echo "2. terraform output kinesis_agent_access_key_id 로 액세스 키 확인"
echo "3. terraform output -raw kinesis_agent_secret_access_key 로 시크릿 키 확인"
echo "4. configs/kinesis-agent.json.template 파일을 On-Premise 서버로 복사"
echo "5. README.md의 'On-Premise 서버 설정' 섹션 참고"
echo ""

echo -e "${GREEN}상세 가이드는 README.md를 참고하세요.${NC}"
