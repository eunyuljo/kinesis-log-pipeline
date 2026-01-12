#!/bin/bash

# ============================================================
# Kinesis 로그 중앙화 시스템 제거 스크립트
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 색상 정의
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}=====================================================================${NC}"
echo -e "${RED}경고: 모든 AWS 리소스가 삭제됩니다!${NC}"
echo -e "${RED}=====================================================================${NC}"
echo ""

cd "${PROJECT_DIR}"

# S3 버킷 이름 가져오기
BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")

if [ -n "${BUCKET_NAME}" ]; then
    echo -e "${YELLOW}S3 버킷 (${BUCKET_NAME})에 저장된 모든 로그가 삭제됩니다.${NC}"
    echo ""
fi

read -p "정말로 모든 리소스를 삭제하시겠습니까? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "취소되었습니다."
    exit 0
fi

# S3 버킷 비우기 (Terraform destroy 전에 필요)
if [ -n "${BUCKET_NAME}" ]; then
    echo ""
    echo "S3 버킷 비우는 중..."
    aws s3 rm s3://${BUCKET_NAME} --recursive || true

    # 버전이 있는 경우 모든 버전 삭제
    aws s3api list-object-versions \
        --bucket ${BUCKET_NAME} \
        --query 'Versions[].{Key:Key,VersionId:VersionId}' \
        --output text | \
        while read key versionId; do
            aws s3api delete-object \
                --bucket ${BUCKET_NAME} \
                --key "$key" \
                --version-id "$versionId" 2>/dev/null || true
        done
fi

echo ""
echo "Terraform destroy 실행 중..."
terraform destroy

echo ""
echo -e "${YELLOW}모든 리소스가 삭제되었습니다.${NC}"
