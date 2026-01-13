# Kinesis를 통한 로그 중앙화 시스템

AWS Kinesis Data Firehose를 사용하여 로그를 중앙 집중식으로 수집, 저장 및 모니터링하는 **간단하고 경제적인** 시스템입니다.

## 📋 목차

- [아키텍처 개요](#아키텍처-개요)
- [주요 기능](#주요-기능)
- [사전 요구사항](#사전-요구사항)
- [빠른 시작](#빠른-시작)
- [모니터링](#모니터링)
- [비용](#비용)

---

## 🏗️ 아키텍처 개요

**학습 및 테스트에 최적화된 단순한 구조**

```
┌─────────────────────────────────────────────────────────────┐
│                  VPC (10.0.0.0/16)                          │
│              On-Premise 환경 시뮬레이션                        │
│                                                             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Public Subnet (10.0.1.0/24)                           │ │
│  │                                                        │ │
│  │  ┌──────────────────────────────────────┐              │ │
│  │  │  EC2 Instance (Amazon Linux 2023)    │              │ │
│  │  │  ┌────────────────────────────────┐  │              │ │
│  │  │  │  Application Logs              │  │              │ │
│  │  │  │  /var/log/application/*.log    │  │              │ │
│  │  │  └──────────┬─────────────────────┘  │              │ │
│  │  │             ↓                        │              │ │
│  │  │  ┌──────────────────────────────────┐  │              │ │
│  │  │  │  Kinesis Agent (자동 설치)        │  │              │ │
│  │  │  │  - IAM Role 기반 인증             │  │              │ │
│  │  │  │  - SSM Agent                    │  │               │ │
│  │  │  └──────────┬──────────────────────┘  │               │ │
│  │  └─────────────┼─────────────────────────┘               │ │
│  └────────────────┼─────────────────────────────────────────┘ │
│                   │ Internet Gateway (HTTPS)                  │
└───────────────────┼───────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────┐
│                    AWS Services                             │
│                                                             │
│     Kinesis Firehose → Lambda → S3 + CloudWatch Logs        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 🔑 핵심 특징

- ✅ **단순하고 경제적**: 단일 VPC + Public Subnet (~$30/월)
- ✅ **빠른 배포**: 3-5분 완성
- ✅ **학습 최적화**: 이해하기 쉬운 구조
- ✅ **안전한 연결**: IAM Role + HTTPS 암호화

---

## ✨ 주요 기능

### AWS 리소스

- **VPC + Public Subnet**: 간단한 네트워크 구조
- **EC2 Instance**: Amazon Linux 2023, Kinesis Agent 자동 설치
- **Kinesis Data Firehose**: 실시간 로그 스트리밍
- **S3 Bucket**: 압축 저장, 라이프사이클 정책 (90일 자동 삭제)
- **CloudWatch Logs**: 실시간 모니터링 (7일 보관)
- **Lambda**: 로그 파싱 및 JSON 변환
- **IAM**: 최소 권한 원칙

### 보안

- S3 버킷 암호화 (AES-256)
- S3 퍼블릭 액세스 완전 차단
- IAM Role 기반 접근 제어
- HTTPS 암호화 통신

---

## 📦 사전 요구사항

- AWS CLI 설치 및 구성
- Terraform >= 1.0
- AWS 계정 및 적절한 권한

---

## 🚀 빠른 시작

### 1단계: 배포 (3분)

```bash
# 프로젝트 디렉터리로 이동
cd centralized-logs-on-aws

# 변수 파일 생성
cp terraform.tfvars.example terraform.tfvars

# 자동 배포
./scripts/deploy.sh
```

### 2단계: 확인 (1분)

```bash
# 배포된 리소스 확인
terraform output

# EC2에 접속 (SSM Session Manager - 2-3분 후 가능)
aws ssm start-session --target $(terraform output -raw ec2_instance_id)
```

**참고**: SSM Session Manager 접속은 EC2 부팅 완료 후 2-3분 정도 소요됩니다.

### 3단계: 테스트 (1분)

```bash
# EC2 인스턴스 내에서 테스트 로그 생성
echo "$(date) [INFO] Test log from EC2" | sudo tee -a /var/log/application/test.log

# Kinesis Agent 상태 확인
sudo systemctl status aws-kinesis-agent

# Agent 로그 확인 (성공 메시지 확인)
sudo tail -f /var/log/aws-kinesis-agent/aws-kinesis-agent.log
```

---

## 📊 모니터링

### CloudWatch에서 로그 확인

```bash
# 로그 그룹 확인
aws logs describe-log-groups --log-group-name-prefix "/aws/kinesis"

# 실시간 로그 보기
aws logs tail $(terraform output -raw cloudwatch_log_group_name) --follow
```

### S3에서 저장된 로그 확인

```bash
# S3 버킷 내용 확인 (5-10분 후)
aws s3 ls s3://$(terraform output -raw s3_bucket_name)/logs/ --recursive

# 로그 파일 다운로드 및 확인
aws s3 cp s3://$(terraform output -raw s3_bucket_name)/logs/year=2024/month=01/day=09/hour=10/xxx.gz - | gunzip
```

---

## 🧪 시스템 테스트 명령어

### 1. 기본 상태 확인

```bash
# Terraform 출력 확인
terraform output

# EC2 인스턴스 상태 확인
aws ec2 describe-instances --instance-ids $(terraform output -raw ec2_instance_id) --query 'Reservations[].Instances[].State.Name'

# S3 버킷 존재 확인
aws s3 ls s3://$(terraform output -raw s3_bucket_name)

# CloudWatch 로그 그룹 확인
aws logs describe-log-groups --log-group-name-prefix "/aws/kinesis"
```

### 2. Kinesis Agent 상태 확인

```bash
# EC2에 접속 후 실행
aws ssm start-session --target $(terraform output -raw ec2_instance_id)

# Agent 상태 확인
sudo systemctl status aws-kinesis-agent

# Agent 설정 확인
sudo cat /etc/aws-kinesis/agent.json | python -m json.tool

# Agent 로그 실시간 확인
sudo tail -f /var/log/aws-kinesis-agent/aws-kinesis-agent.log
```

### 3. 기본 로그 생성 테스트

```bash
# 단일 테스트 로그 생성
echo "$(date) [INFO] Basic test log from EC2" | sudo tee -a /var/log/application/test.log

# 여러 로그 생성
for i in {1..10}; do
  echo "$(date) [TEST-$i] Multiple test logs for verification" | sudo tee -a /var/log/application/test.log
  sleep 1
done

# 로그 파일 확인
tail -20 /var/log/application/test.log
```

### 4. 대용량 로그 테스트 ⚡

```bash
# 50개 배치 테스트 (1MB 버퍼 채우기용)
echo "=== Starting 50-log batch test ===" | sudo tee -a /var/log/application/test.log
for i in {1..50}; do
  echo "$(date) [BATCH-TEST-$i] Large batch of test logs to fill buffer quickly - $(date +%s%N)" | sudo tee -a /var/log/application/test.log
done
echo "=== Completed 50-log batch test ===" | sudo tee -a /var/log/application/test.log

# 100개 성능 테스트 (타이밍 측정)
echo "=== Starting 100-log performance test ===" | sudo tee -a /var/log/application/test.log
start_time=$(date +%s)
for i in {1..100}; do
  echo "$(date) [PERF-TEST-$i] Performance testing log entry - Timestamp: $(date +%s%N)" | sudo tee -a /var/log/application/test.log
done
end_time=$(date +%s)
duration=$((end_time - start_time))
echo "=== Performance test completed in $duration seconds ===" | sudo tee -a /var/log/application/test.log

# 연속 로그 스트림 테스트 (30초간)
echo "=== Starting continuous log stream test ===" | sudo tee -a /var/log/application/test.log
timeout 30s bash -c 'i=1; while true; do echo "$(date) [STREAM-$i] Continuous stream log entry" | sudo tee -a /var/log/application/test.log; i=$((i+1)); sleep 0.5; done'
echo "=== Continuous stream test completed ===" | sudo tee -a /var/log/application/test.log
```

### 5. S3 저장 확인

```bash
# 30초 후 S3 확인 (버퍼링 대기)
sleep 30
aws s3 ls s3://$(terraform output -raw s3_bucket_name)/logs/ --recursive

# 최신 로그 파일 다운로드 및 확인
latest_file=$(aws s3 ls s3://$(terraform output -raw s3_bucket_name)/logs/ --recursive | sort | tail -n 1 | awk '{print $4}')
aws s3 cp s3://$(terraform output -raw s3_bucket_name)/$latest_file - | gunzip | head -10

# S3에 저장된 로그 수 확인
aws s3api list-objects-v2 --bucket $(terraform output -raw s3_bucket_name) --prefix "logs/" --query 'KeyCount'
```

### 6. CloudWatch Logs 실시간 확인

```bash
# 실시간 로그 스트림 확인
aws logs tail $(terraform output -raw cloudwatch_log_group_name) --follow

# 특정 시간대 로그 확인 (최근 10분)
aws logs filter-log-events \
  --log-group-name $(terraform output -raw cloudwatch_log_group_name) \
  --start-time $(date -d "10 minutes ago" +%s)000 \
  --query 'events[].message'

# 로그 개수 확인
aws logs describe-metric-filters \
  --log-group-name $(terraform output -raw cloudwatch_log_group_name)
```

### 7. Lambda 함수 모니터링

```bash
# S3 변환 Lambda 로그 확인
aws logs tail /aws/lambda/$(terraform output -raw project_name)-$(terraform output -raw environment)-log-transformer --follow

# CloudWatch 전송 Lambda 로그 확인
aws logs tail /aws/lambda/$(terraform output -raw project_name)-$(terraform output -raw environment)-cloudwatch-sender --follow

# Lambda 실행 통계 확인
aws logs filter-log-events \
  --log-group-name /aws/lambda/$(terraform output -raw project_name)-$(terraform output -raw environment)-log-transformer \
  --filter-pattern "REPORT"
```

### 8. Firehose 스트림 상태

```bash
# Firehose 스트림 상태 확인
aws firehose describe-delivery-stream --delivery-stream-name $(terraform output -raw project_name)-$(terraform output -raw environment)-log-stream

# Firehose CloudWatch 스트림 상태 확인
aws firehose describe-delivery-stream --delivery-stream-name $(terraform output -raw project_name)-$(terraform output -raw environment)-cloudwatch-stream

# Firehose 메트릭 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/Kinesis/Firehose \
  --metric-name DeliveryToS3.Records \
  --dimensions Name=DeliveryStreamName,Value=$(terraform output -raw project_name)-$(terraform output -raw environment)-log-stream \
  --start-time $(date -d "1 hour ago" --iso-8601) \
  --end-time $(date --iso-8601) \
  --period 300 \
  --statistics Sum
```

### 9. 버퍼링 테스트

```bash
# 빠른 버퍼 채우기 (1MB/30초 설정 확인)
echo "=== Testing buffer limits (1MB/30sec) ===" | sudo tee -a /var/log/application/test.log
for i in {1..20}; do
  # 긴 로그 메시지로 버퍼 빠르게 채우기
  msg="$(date) [BUFFER-TEST-$i] $(printf '=%.0s' {1..100}) Large message to fill buffer quickly"
  echo "$msg" | sudo tee -a /var/log/application/test.log
done

# 30초 대기 후 S3 확인
echo "Waiting 30 seconds for buffer flush..."
sleep 30
aws s3 ls s3://$(terraform output -raw s3_bucket_name)/logs/ --recursive | tail -5
```

### 10. 종합 시스템 검증

```bash
# 전체 시스템 헬스체크
echo "=== System Health Check Started ===" | sudo tee -a /var/log/application/test.log

# 1. Agent 동작 확인
if sudo systemctl is-active --quiet aws-kinesis-agent; then
  echo "✅ Kinesis Agent is running" | sudo tee -a /var/log/application/test.log
else
  echo "❌ Kinesis Agent is not running" | sudo tee -a /var/log/application/test.log
fi

# 2. 테스트 로그 생성
for i in {1..5}; do
  echo "$(date) [HEALTH-CHECK-$i] System verification log entry" | sudo tee -a /var/log/application/test.log
done

# 3. 1분 후 결과 확인
sleep 60

# 4. CloudWatch 확인
echo "CloudWatch Logs (최근 5개):"
aws logs filter-log-events \
  --log-group-name $(terraform output -raw cloudwatch_log_group_name) \
  --start-time $(date -d "2 minutes ago" +%s)000 \
  --query 'events[-5:].message' \
  --output text

# 5. S3 확인
echo "S3 Storage (최신 파일):"
aws s3 ls s3://$(terraform output -raw s3_bucket_name)/logs/ --recursive | tail -3

echo "=== System Health Check Completed ===" | sudo tee -a /var/log/application/test.log
```

---

## 💰 비용

### 예상 월간 비용: ~$30

| 서비스 | 항목 | 비용 (USD) |
|--------|------|-----------|
| **EC2** | t3.small (24/7) | $13.14 |
| **Kinesis Firehose** | 데이터 수집 (300GB/월) | $5.40 |
| **S3** | 저장 + Glacier 전환 | $3.10 |
| **CloudWatch Logs** | 수집 + 저장 (7일) | $3.25 |
| **Lambda** | 로그 변환 (10만 건) | $0.02 |
| **기타** | 데이터 전송, VPC 등 | $5.09 |
| **총합** | | **~$30/월** |

### 💡 추가 구성 옵션

현재 구성이 테스트 목적에 최적화되어 있습니다. 더 복잡한 엔터프라이즈 구성이 필요한 경우에는 별도의 Transit Gateway나 VPC Endpoints 모듈을 추가하실 수 있습니다.

---

## 🔧 트러블슈팅

### Agent가 시작되지 않음

```bash
# 로그 확인
sudo cat /var/log/aws-kinesis-agent/aws-kinesis-agent.log

# Agent 재시작
sudo systemctl restart aws-kinesis-agent

# 설정 파일 검증
sudo cat /etc/aws-kinesis/agent.json | python -m json.tool
```

### 로그가 전송되지 않음

```bash
# AWS 연결 확인
curl https://firehose.ap-northeast-2.amazonaws.com

# IAM 권한 확인
aws sts get-caller-identity

# 로그 파일 권한 확인
ls -la /var/log/application/
```

---

## 🗑️ 리소스 정리

```bash
# 모든 AWS 리소스 삭제
./scripts/destroy.sh

# 또는 수동으로
terraform destroy
```

---

## 📚 추가 문서

- [QUICKSTART.md](QUICKSTART.md) - 더 상세한 빠른 시작 가이드
- [CHANGELOG.md](CHANGELOG.md) - 변경 이력

---

## 📝 라이센스

MIT License# kinesis-log-pipeline
