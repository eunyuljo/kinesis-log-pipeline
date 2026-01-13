#!/bin/bash

# ============================================================
# Kinesis Agent 자동 설치 스크립트 (Amazon Linux 2023)
# ============================================================

set -e

# 로그 파일 설정
LOGFILE="/var/log/kinesis-agent-setup.log"
exec > >(tee -a $LOGFILE)
exec 2>&1

echo "=========================================="
echo "Kinesis Agent 설치 시작"
echo "Timestamp: $(date)"
echo "=========================================="

# 1. 시스템 업데이트
echo "[1/6] 시스템 패키지 업데이트 중..."
dnf update -y

# 2. 필수 패키지 설치
echo "[2/6] 필수 패키지 설치 중..."
dnf install -y \
    java-17-amazon-corretto \
    jq \
    wget

# 3. Kinesis Agent 설치
echo "[3/6] Kinesis Agent 설치 중..."
dnf install -y aws-kinesis-agent

# 4. 로그 디렉토리 생성
echo "[4/6] 로그 디렉토리 생성 중..."
mkdir -p /var/log/application
chmod 755 /var/log/application

# 5. Kinesis Agent 설정 파일 생성
echo "[5/6] Kinesis Agent 설정 파일 생성 중..."
cat > /etc/aws-kinesis/agent.json <<'EOF'
{
  "cloudwatch.emitMetrics": true,
  "cloudwatch.endpoint": "monitoring.${region}.amazonaws.com",
  "firehose.endpoint": "firehose.${region}.amazonaws.com",

  "flows": [
    {
      "filePattern": "/var/log/application/*.log",
      "deliveryStream": "${firehose_stream_name}",
      "initialPosition": "END_OF_FILE",
      "maxBufferAgeMillis": 60000,
      "maxBufferSizeRecords": 500,
      "maxBufferSizeBytes": 1048576,
      "minTimeBetweenFilePollsMillis": 1000
    },
    {
      "filePattern": "/var/log/application/*.log",
      "deliveryStream": "${cloudwatch_stream_name}",
      "initialPosition": "END_OF_FILE",
      "maxBufferAgeMillis": 60000,
      "maxBufferSizeRecords": 500,
      "maxBufferSizeBytes": 1048576,
      "minTimeBetweenFilePollsMillis": 1000
    },
    {
      "filePattern": "/var/log/messages",
      "deliveryStream": "${firehose_stream_name}",
      "initialPosition": "END_OF_FILE",
      "maxBufferAgeMillis": 120000,
      "dataProcessingOptions": [
        {
          "optionName": "SINGLELINE"
        }
      ]
    },
    {
      "filePattern": "/var/log/messages",
      "deliveryStream": "${cloudwatch_stream_name}",
      "initialPosition": "END_OF_FILE",
      "maxBufferAgeMillis": 120000,
      "dataProcessingOptions": [
        {
          "optionName": "SINGLELINE"
        }
      ]
    },
    {
      "filePattern": "/var/log/secure",
      "deliveryStream": "${firehose_stream_name}",
      "initialPosition": "END_OF_FILE",
      "maxBufferAgeMillis": 120000
    },
    {
      "filePattern": "/var/log/secure",
      "deliveryStream": "${cloudwatch_stream_name}",
      "initialPosition": "END_OF_FILE",
      "maxBufferAgeMillis": 120000
    }
  ]
}
EOF

# 6. SSM Agent 설치 및 활성화 (Amazon Linux 2023)
echo "[6/7] SSM Agent 설치 및 활성화 중..."

# SSM Agent 설치
echo "  - SSM Agent 패키지 설치..."
dnf install -y amazon-ssm-agent

# 서비스 활성화 및 시작
echo "  - SSM Agent 서비스 활성화..."
systemctl enable amazon-ssm-agent

echo "  - SSM Agent 서비스 시작..."
systemctl start amazon-ssm-agent

# SSM Agent 상태 확인 및 대기
echo "  - SSM Agent 상태 확인..."
sleep 10
systemctl status amazon-ssm-agent --no-pager

# SSM 등록 대기 (최대 30초)
echo "  - SSM 등록 대기 중..."
for i in {1..6}; do
    if systemctl is-active amazon-ssm-agent >/dev/null 2>&1; then
        echo "  - SSM Agent 정상 실행 중 (시도 $i/6)"
        break
    else
        echo "  - SSM Agent 시작 대기... (시도 $i/6)"
        sleep 5
    fi
done

# 7. Kinesis Agent 서비스 시작
echo "[7/7] Kinesis Agent 서비스 시작 중..."

echo "  - Kinesis Agent 서비스 활성화..."
systemctl enable aws-kinesis-agent

echo "  - Kinesis Agent 서비스 시작..."
systemctl start aws-kinesis-agent

# 상태 확인 및 대기
echo "  - Kinesis Agent 상태 확인..."
sleep 10
systemctl status aws-kinesis-agent --no-pager

# Kinesis Agent 실행 상태 확인 (최대 30초)
echo "  - Kinesis Agent 실행 상태 확인 중..."
for i in {1..6}; do
    if systemctl is-active aws-kinesis-agent >/dev/null 2>&1; then
        echo "  - Kinesis Agent 정상 실행 중 (시도 $i/6)"
        break
    else
        echo "  - Kinesis Agent 시작 대기... (시도 $i/6)"
        systemctl start aws-kinesis-agent
        sleep 5
    fi
done

# 초기 테스트 로그 생성
echo "[INFO] $(date) - Kinesis Agent installed successfully" >> /var/log/application/test.log
echo "[INFO] $(date) - Project: ${project_name}" >> /var/log/application/test.log
echo "[INFO] $(date) - Environment: ${environment}" >> /var/log/application/test.log
echo "[INFO] $(date) - Firehose Stream: ${firehose_stream_name}" >> /var/log/application/test.log

# 샘플 로그 생성 스크립트 작성
cat > /usr/local/bin/generate-sample-logs.sh <<'SCRIPT'
#!/bin/bash
# 샘플 로그 생성 스크립트

LOG_FILE="/var/log/application/sample-app.log"
LOG_LEVELS=("INFO" "DEBUG" "WARN" "ERROR" "FATAL")

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    LEVEL=$${LOG_LEVELS[$RANDOM % $${#LOG_LEVELS[@]}]}
    MESSAGE="Sample log message - Random number: $RANDOM"

    echo "$TIMESTAMP [$LEVEL] $MESSAGE" >> $LOG_FILE

    # ERROR나 FATAL일 경우 추가 정보
    if [[ "$LEVEL" == "ERROR" ]] || [[ "$LEVEL" == "FATAL" ]]; then
        echo "$TIMESTAMP [$LEVEL] Stack trace: at com.example.Main.process(Main.java:42)" >> $LOG_FILE
    fi

    sleep 5
done
SCRIPT

chmod +x /usr/local/bin/generate-sample-logs.sh

# 샘플 로그 생성 서비스 생성 (선택사항)
cat > /etc/systemd/system/sample-log-generator.service <<'SERVICE'
[Unit]
Description=Sample Log Generator
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/generate-sample-logs.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

# 샘플 로그 생성기는 기본적으로 비활성화 (필요 시 수동으로 활성화)
# systemctl enable sample-log-generator
# systemctl start sample-log-generator

echo "=========================================="
echo "설치 완료 - 최종 상태 확인"
echo "=========================================="

echo ""
echo "📊 서비스 상태 확인:"
echo "  - SSM Agent:"
systemctl is-active amazon-ssm-agent && echo "    ✅ 정상 실행" || echo "    ❌ 실행 중단"

echo "  - Kinesis Agent:"
systemctl is-active aws-kinesis-agent && echo "    ✅ 정상 실행" || echo "    ❌ 실행 중단"

echo ""
echo "=========================================="
echo "🎉 로그 중앙화 시스템 설치 완료!"
echo "=========================================="
echo ""
echo "📋 확인 명령어:"
echo "  sudo systemctl status amazon-ssm-agent"
echo "  sudo systemctl status aws-kinesis-agent"
echo "  sudo tail -f /var/log/aws-kinesis-agent/aws-kinesis-agent.log"
echo "  sudo tail -f /var/log/application/test.log"
echo ""
echo "🔧 샘플 로그 생성기 (선택사항):"
echo "  sudo systemctl start sample-log-generator"
echo "  sudo systemctl enable sample-log-generator"
echo ""
echo "💡 SSM Session Manager 접속이 2-3분 후 가능합니다."
echo ""
