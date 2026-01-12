# 변경 이력

## 2024-01-12

### 테스트 최적화를 위한 대대적 단순화

**변경 사항:**
- 복잡한 Transit Gateway 아키텍처 제거
- VPC Endpoints 관련 구성 제거
- 과도한 문서들 정리
- 기본 구성을 단순 VPC 구조로 변경

**제거된 파일들:**
- `transit-gateway.tf`, `vpc-services-hub.tf`, `vpc-endpoints.tf`
- `REAL-ONPREMISE-GUIDE.md`, `DEPLOYMENT.md`, `TESTING.md`

**이유:**
- 테스트 및 학습 목적에 최적화
- 비용 절감 (~$177/월 → ~$30/월, 85% 절약)
- 이해하기 쉬운 구조 제공
- 빠른 배포 시간 (3-5분)

**영향:**
- 이전: 복잡한 엔터프라이즈 구성 (높은 비용)
- 변경 후: 단순한 Public Subnet 구성 (경제적)
- 핵심 로그 중앙화 기능은 모두 유지

---

## 2024-01-09

### VPC Endpoint 기본 비활성화

**변경 사항:**
- `enable_vpc_endpoints` 기본값을 `true` → `false`로 변경
- Internet Gateway를 통한 연결을 기본값으로 설정

**이유:**
- 대부분의 경우 Internet + HTTPS로 충분
- 비용 효율적인 기본 구성 제공

**영향:**
- 이전: VPC Endpoint를 통한 Private 연결 (추가 비용)
- 변경 후: Internet Gateway를 통한 연결 (비용 절감)
- 트래픽은 HTTPS로 암호화되어 안전

---

## 초기 릴리스

### 주요 기능

- Kinesis Data Firehose 기반 로그 수집
- S3 장기 저장 (압축, 라이프사이클 정책)
- CloudWatch Logs 실시간 모니터링
- Lambda 로그 변환
- EC2 기반 On-Premise 시뮬레이션
- SSM Session Manager 지원

### 아키텍처

- VPC + Public Subnet (단순화됨)
- EC2 Instance (Amazon Linux 2023)
- Kinesis Data Firehose
- S3 Bucket
- CloudWatch Logs
- Lambda Function
- IAM Roles

### 문서

- README.md - 전체 가이드
- QUICKSTART.md - 빠른 시작
- CHANGELOG.md - 변경 이력