"""
Kinesis Firehose Lambda Transformer
로그 데이터를 파싱하고 변환하는 Lambda 함수
"""

import base64
import json
import gzip
from datetime import datetime


def handler(event, context):
    """
    Kinesis Firehose에서 전달받은 레코드를 변환

    Args:
        event: Firehose에서 전달한 이벤트
        context: Lambda 컨텍스트

    Returns:
        변환된 레코드 리스트
    """
    output = []

    for record in event['records']:
        try:
            # Base64 디코딩
            payload = base64.b64decode(record['data'])

            # 로그 라인 파싱
            log_line = payload.decode('utf-8').strip()

            # JSON 형태로 변환 (로그 포맷에 따라 수정 필요)
            transformed_data = transform_log(log_line)

            # JSON을 문자열로 변환하고 개행 추가 (S3 저장 시 한 줄씩 저장)
            output_data = json.dumps(transformed_data) + '\n'

            # Base64 인코딩
            encoded_data = base64.b64encode(output_data.encode('utf-8')).decode('utf-8')

            output.append({
                'recordId': record['recordId'],
                'result': 'Ok',
                'data': encoded_data
            })

        except Exception as e:
            # 변환 실패 시 원본 데이터 그대로 전달
            print(f"Error processing record: {str(e)}")
            output.append({
                'recordId': record['recordId'],
                'result': 'ProcessingFailed',
                'data': record['data']
            })

    return {'records': output}


def transform_log(log_line):
    """
    로그 라인을 구조화된 JSON으로 변환

    Args:
        log_line: 원본 로그 라인

    Returns:
        구조화된 로그 딕셔너리
    """
    # 이미 JSON 형태인 경우
    try:
        log_data = json.loads(log_line)
        log_data['@timestamp'] = datetime.utcnow().isoformat()
        return log_data
    except json.JSONDecodeError:
        pass

    # 일반 텍스트 로그인 경우 - 파싱 로직 구현
    # 예시: "2024-01-09 10:30:45 [ERROR] Application error: message"
    log_dict = {
        '@timestamp': datetime.utcnow().isoformat(),
        'message': log_line,
        'level': extract_log_level(log_line),
        'source': 'on-premise'
    }

    # 타임스탬프 추출 시도
    timestamp = extract_timestamp(log_line)
    if timestamp:
        log_dict['log_timestamp'] = timestamp

    return log_dict


def extract_log_level(log_line):
    """로그 레벨 추출 (ERROR, WARN, INFO, DEBUG 등)"""
    log_line_upper = log_line.upper()

    levels = ['ERROR', 'FATAL', 'WARN', 'WARNING', 'INFO', 'DEBUG', 'TRACE']
    for level in levels:
        if f'[{level}]' in log_line_upper or f'{level}:' in log_line_upper:
            return level

    return 'INFO'


def extract_timestamp(log_line):
    """로그 라인에서 타임스탬프 추출 (간단한 예시)"""
    import re

    # ISO 8601 형식: 2024-01-09T10:30:45
    iso_pattern = r'\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}'
    match = re.search(iso_pattern, log_line)

    if match:
        return match.group(0).replace(' ', 'T')

    return None
