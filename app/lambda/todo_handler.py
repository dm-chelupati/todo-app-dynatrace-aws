import json
import boto3
import os
from datetime import datetime
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return int(obj)
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    print(f"Event: {json.dumps(event)}")
    
    http_method = event['httpMethod']
    path = event['path']
    
    try:
        if http_method == 'GET' and path == '/todos':
            return get_todos()
        elif http_method == 'POST' and path == '/todos':
            return create_todo(json.loads(event['body']))
        elif http_method == 'PUT' and path.startswith('/todos/'):
            todo_id = path.split('/')[-1]
            return update_todo(todo_id, json.loads(event['body']))
        elif http_method == 'DELETE' and path.startswith('/todos/'):
            todo_id = path.split('/')[-1]
            return delete_todo(todo_id)
        else:
            return response(404, {'error': 'Not found'})
    except Exception as e:
        print(f"Error: {str(e)}")
        return response(500, {'error': str(e)})

def get_todos():
    result = table.scan()
    return response(200, result['Items'])

def create_todo(body):
    todo_id = str(int(datetime.now().timestamp() * 1000))
    item = {
        'id': todo_id,
        'title': body['title'],
        'completed': False,
        'createdAt': datetime.now().isoformat()
    }
    table.put_item(Item=item)
    print(f"Created todo: {todo_id}")
    return response(201, item)

def update_todo(todo_id, body):
    table.update_item(
        Key={'id': todo_id},
        UpdateExpression='SET completed = :c',
        ExpressionAttributeValues={':c': body['completed']}
    )
    print(f"Updated todo: {todo_id}")
    return response(200, {'id': todo_id, 'completed': body['completed']})

def delete_todo(todo_id):
    table.delete_item(Key={'id': todo_id})
    print(f"Deleted todo: {todo_id}")
    return response(200, {'message': 'Deleted'})

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
