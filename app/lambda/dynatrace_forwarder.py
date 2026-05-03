import json
import gzip
import base64
import os
import urllib3
from datetime import datetime

http = urllib3.PoolManager()
DYNATRACE_URL = os.environ['DYNATRACE_URL'].rstrip('/')
DYNATRACE_TOKEN = os.environ['DYNATRACE_TOKEN']

def lambda_handler(event, context):
    data = json.loads(gzip.decompress(base64.b64decode(event['awslogs']['data'])))
    
    log_group = data['logGroup']
    log_stream = data['logStream']
    
    print(f"Processing {len(data['logEvents'])} log events from {log_group}")
    
    logs_batch = []
    for log_event in data['logEvents']:
        try:
            message = log_event['message']
            
            # Try to parse structured JSON logs
            try:
                parsed_message = json.loads(message)
                log_level = parsed_message.get('level', 'INFO')
                log_content = parsed_message.get('message', message)
            except:
                log_level = 'INFO'
                log_content = message
            
            log_entry = {
                'timestamp': log_event['timestamp'],
                'log.source': log_group,
                'log.stream': log_stream,
                'content': log_content,
                'severity': log_level,
                'aws.region': os.environ['AWS_REGION'],
                'cloud.provider': 'aws',
                'service.name': 'todo-app',
                'dt.source_entity': f"AWS_LAMBDA_FUNCTION:{log_group.split('/')[-1]}"
            }
            
            # Add custom attributes if structured log
            if isinstance(parsed_message, dict):
                for key, value in parsed_message.items():
                    if key not in ['level', 'message', 'timestamp']:
                        log_entry[f'custom.{key}'] = str(value)
            
            logs_batch.append(log_entry)
            
        except Exception as e:
            print(f"Error parsing log event: {str(e)}")
    
    # Send logs in batch to Dynatrace
    if logs_batch:
        send_to_dynatrace(logs_batch)
    
    return {'statusCode': 200, 'body': json.dumps({'processed': len(logs_batch)})}

def send_to_dynatrace(logs):
    headers = {
        'Authorization': f'Api-Token {DYNATRACE_TOKEN}',
        'Content-Type': 'application/json; charset=utf-8'
    }
    
    try:
        response = http.request(
            'POST',
            f'{DYNATRACE_URL}/api/v2/logs/ingest',
            body=json.dumps(logs),
            headers=headers
        )
        
        if response.status == 200 or response.status == 204:
            print(f"Successfully sent {len(logs)} logs to Dynatrace")
        else:
            print(f"Dynatrace API returned status {response.status}: {response.data.decode('utf-8')}")
            
    except Exception as e:
        print(f"Error sending to Dynatrace: {str(e)}")
        raise
