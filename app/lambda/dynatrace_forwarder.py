import json
import gzip
import base64
import os
import urllib3

http = urllib3.PoolManager()
DYNATRACE_URL = os.environ['DYNATRACE_URL']
DYNATRACE_TOKEN = os.environ['DYNATRACE_TOKEN']

def lambda_handler(event, context):
    data = json.loads(gzip.decompress(base64.b64decode(event['awslogs']['data'])))
    
    for log_event in data['logEvents']:
        payload = {
            'timestamp': log_event['timestamp'],
            'log.source': data['logGroup'],
            'content': log_event['message'],
            'aws.region': os.environ['AWS_REGION']
        }
        
        headers = {
            'Authorization': f'Api-Token {DYNATRACE_TOKEN}',
            'Content-Type': 'application/json'
        }
        
        try:
            response = http.request(
                'POST',
                f'{DYNATRACE_URL}/api/v2/logs/ingest',
                body=json.dumps(payload),
                headers=headers
            )
            print(f"Sent log to Dynatrace: {response.status}")
        except Exception as e:
            print(f"Error sending to Dynatrace: {str(e)}")
    
    return {'statusCode': 200}
