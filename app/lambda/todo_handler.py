import json
import boto3
import os
import time
from datetime import datetime
from decimal import Decimal
from aws_xray_sdk.core import xray_recorder
from aws_xray_sdk.core import patch_all

patch_all()

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])
cloudwatch = boto3.client('cloudwatch')

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return int(obj)
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    start_time = time.time()
    request_id = context.request_id
    
    print(json.dumps({
        'level': 'INFO',
        'message': 'Request received',
        'request_id': request_id,
        'event': event,
        'timestamp': datetime.now().isoformat()
    }))
    
    http_method = event['httpMethod']
    path = event['path']
    
    try:
        if http_method == 'GET' and path == '/todos':
            result = get_todos()
        elif http_method == 'POST' and path == '/todos':
            result = create_todo(json.loads(event['body']))
        elif http_method == 'PUT' and path.startswith('/todos/'):
            todo_id = path.split('/')[-1]
            result = update_todo(todo_id, json.loads(event['body']))
        elif http_method == 'DELETE' and path.startswith('/todos/'):
            todo_id = path.split('/')[-1]
            result = delete_todo(todo_id)
        else:
            result = response(404, {'error': 'Not found'})
        
        duration = (time.time() - start_time) * 1000
        send_metrics(http_method, path, result['statusCode'], duration)
        
        print(json.dumps({
            'level': 'INFO',
            'message': 'Request completed',
            'request_id': request_id,
            'method': http_method,
            'path': path,
            'status_code': result['statusCode'],
            'duration_ms': duration,
            'timestamp': datetime.now().isoformat()
        }))
        
        return result
        
    except Exception as e:
        duration = (time.time() - start_time) * 1000
        send_metrics(http_method, path, 500, duration)
        
        print(json.dumps({
            'level': 'ERROR',
            'message': 'Request failed',
            'request_id': request_id,
            'method': http_method,
            'path': path,
            'error': str(e),
            'duration_ms': duration,
            'timestamp': datetime.now().isoformat()
        }))
        
        return response(500, {'error': str(e)})

@xray_recorder.capture('get_todos')
def get_todos():
    print(json.dumps({'level': 'INFO', 'message': 'Fetching all todos', 'timestamp': datetime.now().isoformat()}))
    result = table.scan()
    print(json.dumps({'level': 'INFO', 'message': f'Retrieved {len(result["Items"])} todos', 'timestamp': datetime.now().isoformat()}))
    return response(200, result['Items'])

@xray_recorder.capture('create_todo')
def create_todo(body):
    todo_id = str(int(datetime.now().timestamp() * 1000))
    item = {
        'id': todo_id,
        'title': body['title'],
        'completed': False,
        'createdAt': datetime.now().isoformat()
    }
    print(json.dumps({'level': 'INFO', 'message': 'Creating todo', 'todo_id': todo_id, 'title': body['title'], 'timestamp': datetime.now().isoformat()}))
    table.put_item(Item=item)
    print(json.dumps({'level': 'INFO', 'message': 'Todo created successfully', 'todo_id': todo_id, 'timestamp': datetime.now().isoformat()}))
    return response(201, item)

@xray_recorder.capture('update_todo')
def update_todo(todo_id, body):
    print(json.dumps({'level': 'INFO', 'message': 'Updating todo', 'todo_id': todo_id, 'completed': body['completed'], 'timestamp': datetime.now().isoformat()}))
    table.update_item(
        Key={'id': todo_id},
        UpdateExpression='SET completed = :c',
        ExpressionAttributeValues={':c': body['completed']}
    )
    print(json.dumps({'level': 'INFO', 'message': 'Todo updated successfully', 'todo_id': todo_id, 'timestamp': datetime.now().isoformat()}))
    return response(200, {'id': todo_id, 'completed': body['completed']})

@xray_recorder.capture('delete_todo')
def delete_todo(todo_id):
    print(json.dumps({'level': 'INFO', 'message': 'Deleting todo', 'todo_id': todo_id, 'timestamp': datetime.now().isoformat()}))
    table.delete_item(Key={'id': todo_id})
    print(json.dumps({'level': 'INFO', 'message': 'Todo deleted successfully', 'todo_id': todo_id, 'timestamp': datetime.now().isoformat()}))
    return response(200, {'message': 'Deleted'})

def send_metrics(method, path, status_code, duration):
    try:
        cloudwatch.put_metric_data(
            Namespace='TodoApp',
            MetricData=[
                {
                    'MetricName': 'RequestDuration',
                    'Value': duration,
                    'Unit': 'Milliseconds',
                    'Dimensions': [
                        {'Name': 'Method', 'Value': method},
                        {'Name': 'Path', 'Value': path},
                        {'Name': 'StatusCode', 'Value': str(status_code)}
                    ]
                },
                {
                    'MetricName': 'RequestCount',
                    'Value': 1,
                    'Unit': 'Count',
                    'Dimensions': [
                        {'Name': 'Method', 'Value': method},
                        {'Name': 'StatusCode', 'Value': str(status_code)}
                    ]
                }
            ]
        )
    except Exception as e:
        print(json.dumps({'level': 'ERROR', 'message': 'Failed to send metrics', 'error': str(e), 'timestamp': datetime.now().isoformat()}))

def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type'
        },
        'body': json.dumps(body, cls=DecimalEncoder)
    }
