import json
import boto3
import base64
import gzip
import time
from datetime import datetime

# CloudWatch Logs 클라이언트
logs_client = boto3.client('logs')

def handler(event, context):
    """
    Firehose에서 전달된 데이터를 CloudWatch Logs로 전송하고
    빈 레코드를 반환하여 S3 저장 방지
    """
    import os

    # 환경 변수에서 로그 그룹 이름 가져오기
    log_group_name = os.environ.get('LOG_GROUP_NAME', '/aws/kinesis/application-logs')
    log_stream_name = "firehose-delivery"  # 기존 Terraform 생성 스트림 사용

    # Firehose 응답용 레코드 리스트
    output_records = []

    try:
        # 로그 그룹과 스트림은 이미 Terraform으로 생성되어 있음
        # 별도 생성 과정 불필요

        # 이벤트에서 레코드 처리
        log_events = []

        for record in event.get('records', []):
            record_id = record['recordId']

            try:
                # Base64 디코딩
                data = base64.b64decode(record['data']).decode('utf-8')

                # JSON 파싱 시도 (이미 변환된 데이터인 경우)
                try:
                    log_data = json.loads(data)
                    message = json.dumps(log_data, ensure_ascii=False)
                except json.JSONDecodeError:
                    # 원본 로그 텍스트인 경우
                    message = data.strip()

                if message:  # 빈 메시지 제외
                    log_events.append({
                        'timestamp': int(time.time() * 1000),
                        'message': message
                    })

                # 성공한 레코드는 빈 데이터로 응답 (S3 저장 방지)
                output_records.append({
                    'recordId': record_id,
                    'result': 'Ok',
                    'data': base64.b64encode(b'').decode('utf-8')  # 빈 데이터
                })

            except Exception as e:
                print(f"Error processing record {record_id}: {e}")
                # 실패한 레코드는 ProcessingFailed로 응답
                output_records.append({
                    'recordId': record_id,
                    'result': 'ProcessingFailed'
                })
                continue

        # CloudWatch Logs로 전송
        if log_events:
            # 시간 순 정렬
            log_events.sort(key=lambda x: x['timestamp'])

            try:
                # 시퀀스 토큰 가져오기
                response = logs_client.describe_log_streams(
                    logGroupName=log_group_name,
                    logStreamNamePrefix=log_stream_name
                )

                sequence_token = None
                if response['logStreams']:
                    sequence_token = response['logStreams'][0].get('uploadSequenceToken')

                # 로그 이벤트 전송 (최대 10,000개씩)
                batch_size = 10000

                for i in range(0, len(log_events), batch_size):
                    batch = log_events[i:i + batch_size]

                    put_args = {
                        'logGroupName': log_group_name,
                        'logStreamName': log_stream_name,
                        'logEvents': batch
                    }

                    if sequence_token:
                        put_args['sequenceToken'] = sequence_token

                    response = logs_client.put_log_events(**put_args)
                    sequence_token = response.get('nextSequenceToken')  # 다음 배치용

                    print(f"Successfully sent {len(batch)} log events to CloudWatch Logs")

            except Exception as e:
                print(f"Error sending to CloudWatch Logs: {e}")
                # CloudWatch 전송 실패 시 모든 레코드를 ProcessingFailed로 변경
                for record in output_records:
                    record['result'] = 'ProcessingFailed'

        print(f"Processed {len(log_events)} log events to CloudWatch Logs: {log_group_name}")

        # Firehose 형식에 맞는 응답 반환
        return {
            'records': output_records
        }

    except Exception as e:
        print(f"Error in CloudWatch Logs sender: {e}")
        # 전체 실패 시 모든 레코드를 ProcessingFailed로 응답
        return {
            'records': [
                {
                    'recordId': record['recordId'],
                    'result': 'ProcessingFailed'
                }
                for record in event.get('records', [])
            ]
        }