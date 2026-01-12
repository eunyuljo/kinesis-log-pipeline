# 빠른 시작 가이드 (5분 완성)

Kinesis 로그 중앙화 시스템을 빠르게 시작하는 가이드입니다.

## 📦 1단계: AWS 리소스 배포 (2분)

```bash
cd centralized-logs-on-aws  # 또는 프로젝트를 클론한 디렉터리로 이동

# 변수 파일 생성
cp terraform.tfvars.example terraform.tfvars

# 필요 시 수정
vi terraform.tfvars

# 자동 배포 스크립트 실행
./scripts/deploy.sh
```

## 🔑 2단계: 자격증명 확인 (1분)

```bash
# 액세스 키 저장
export AWS_ACCESS_KEY_ID=$(terraform output -raw kinesis_agent_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(terraform output -raw kinesis_agent_secret_access_key)
export FIREHOSE_STREAM=$(terraform output -raw firehose_stream_name)

# 확인
echo "Access Key: $AWS_ACCESS_KEY_ID"
echo "Stream Name: $FIREHOSE_STREAM"
```

## 🖥️ 3단계: On-Premise 서버 설정 (2분)

### 옵션 A: 로컬 EC2 인스턴스에서 테스트

```bash
# Kinesis Agent 설치
sudo yum install -y aws-kinesis-agent

# 자격증명 설정
sudo mkdir -p /root/.aws
sudo tee /root/.aws/credentials > /dev/null <<EOF
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOF
sudo chmod 600 /root/.aws/credentials

# Agent 설정
sudo cp configs/kinesis-agent.json.template /etc/aws-kinesis/agent.json

# Stream 이름 업데이트
sudo sed -i "s/centralized-logs-dev-log-stream/${FIREHOSE_STREAM}/g" /etc/aws-kinesis/agent.json

# 테스트 로그 디렉토리 생성
sudo mkdir -p /var/log/application

# Agent 시작
sudo service aws-kinesis-agent start
```

### 옵션 B: 원격 서버

```bash
# 설정 파일을 원격 서버로 복사
scp configs/kinesis-agent.json.template user@remote-server:/tmp/

# SSH로 원격 서버 접속 후 위 명령어 실행
```

## 🧪 4단계: 테스트 (1분)

```bash
# 테스트 로그 생성
cat << 'EOF' | sudo tee -a /var/log/application/test.log
2024-01-09 10:00:00 [INFO] Application started
2024-01-09 10:00:01 [ERROR] Test error message
2024-01-09 10:00:02 [WARN] Test warning message
EOF

# Agent 로그 확인 (성공 메시지를 확인하세요)
sudo tail -f /var/log/aws-kinesis-agent/aws-kinesis-agent.log
```

**성공 메시지 예시:**
```
(FileTailer[...]) Retrieved 3 records from file
(FirehoseEmitter) Successfully published 3 records to Firehose
```

## ✅ 5단계: 확인 (5-10분 대기)

### S3 확인

```bash
# S3 버킷 확인 (5-10분 후)
aws s3 ls s3://$(terraform output -raw s3_bucket_name)/logs/ --recursive

# 파일 다운로드 및 내용 확인
aws s3 cp s3://$(terraform output -raw s3_bucket_name)/logs/year=2024/month=01/day=09/hour=10/xxx.gz - | gunzip
```

### CloudWatch Logs 확인

```bash
# 최근 로그 확인
aws logs tail $(terraform output -raw cloudwatch_log_group_name) --follow
```

### 브라우저에서 확인

```bash
# CloudWatch Console URL 출력
echo "https://console.aws.amazon.com/cloudwatch/home?region=ap-northeast-2#logsV2:log-groups"
```

---

## 🎉 완료!

이제 On-Premise 서버의 모든 로그가 AWS로 자동 전송됩니다!

### 다음 단계

- [README.md](README.md) - 상세 가이드
- CloudWatch에서 대시보드 생성
- 알람 설정 커스터마이징
- S3에서 로그 분석

---

## 🗑️ 리소스 정리

```bash
# 모든 AWS 리소스 삭제
./scripts/destroy.sh
```

---

## ❓ 문제 해결

### SSM 접속이 안됨

**원인**: SSM Agent 설치 완료까지 2-3분 소요

```bash
# 인스턴스 상태 확인
aws ec2 describe-instance-status --instance-ids $(terraform output -raw ec2_instance_id)

# SSM 등록 상태 확인 (2-3분 대기)
aws ssm describe-instance-information --query 'InstanceInformationList[?InstanceId==`$(terraform output -raw ec2_instance_id)`]'

# 접속 재시도
aws ssm start-session --target $(terraform output -raw ec2_instance_id)
```

### Agent가 시작되지 않음

```bash
# 서비스 상태 확인
sudo systemctl status amazon-ssm-agent
sudo systemctl status aws-kinesis-agent

# 로그 확인
sudo cat /var/log/aws-kinesis-agent/aws-kinesis-agent.log

# 설정 파일 검증
sudo cat /etc/aws-kinesis/agent.json | python -m json.tool

# Agent 재시작
sudo systemctl restart aws-kinesis-agent
```

### 로그가 전송되지 않음

```bash
# 파일 권한 확인
ls -la /var/log/application/

# AWS 연결 테스트
curl https://firehose.ap-northeast-2.amazonaws.com

# IAM 자격증명 확인
aws sts get-caller-identity
```

추가적인 트러블슈팅은 [README.md](README.md#트러블슈팅) 참고하세요.
