import json
import os
import urllib3
from datetime import datetime

http = urllib3.PoolManager()
DYNATRACE_URL = os.environ['DYNATRACE_URL'].rstrip('/')
DYNATRACE_TOKEN = os.environ['DYNATRACE_TOKEN']

def lambda_handler(event, context):
    """Forward CloudWatch metrics to Dynatrace"""
    
    metrics = []
    
    for record in event.get('Records', []):
        try:
            message = json.loads(record['Sns']['Message'])
            
            metric_data = {
                'timestamp': int(datetime.now().timestamp() * 1000),
                'dimensions': {
                    'aws.region': os.environ['AWS_REGION'],
                    'cloud.provider': 'aws',
                    'service.name': 'todo-app'
                }
            }
            
            if 'AlarmName' in message:
                metric_data['metric.name'] = message['AlarmName']
                metric_data['metric.value'] = 1
                metric_data['dimensions']['alarm.state'] = message.get('NewStateValue', 'UNKNOWN')
            
            metrics.append(metric_data)
            
        except Exception as e:
            print(f"Error processing record: {str(e)}")
    
    if metrics:
        send_metrics_to_dynatrace(metrics)
    
    return {'statusCode': 200}

def send_metrics_to_dynatrace(metrics):
    headers = {
        'Authorization': f'Api-Token {DYNATRACE_TOKEN}',
        'Content-Type': 'application/json'
    }
    
    try:
        response = http.request(
            'POST',
            f'{DYNATRACE_URL}/api/v2/metrics/ingest',
            body=json.dumps({'metrics': metrics}),
            headers=headers
        )
        print(f"Sent {len(metrics)} metrics to Dynatrace: {response.status}")
    except Exception as e:
        print(f"Error sending metrics to Dynatrace: {str(e)}")
