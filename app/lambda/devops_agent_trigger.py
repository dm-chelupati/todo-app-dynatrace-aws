import json
import os
import boto3
import urllib3
from datetime import datetime

devops_agent = boto3.client('devops-agent')
http = urllib3.PoolManager()

DEVOPS_AGENT_ARN = os.environ['DEVOPS_AGENT_ARN']
GITHUB_REPO = os.environ['GITHUB_REPO']
DYNATRACE_URL = os.environ['DYNATRACE_URL'].rstrip('/')
DYNATRACE_TOKEN = os.environ['DYNATRACE_TOKEN']

def lambda_handler(event, context):
    """
    Receives Dynatrace webhook alerts and triggers AWS DevOps Agent
    """
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # Parse Dynatrace alert
        if 'body' in event:
            alert = json.loads(event['body'])
        else:
            alert = event
        
        problem_id = alert.get('ProblemID', 'unknown')
        problem_title = alert.get('ProblemTitle', 'Unknown Issue')
        severity = alert.get('State', 'OPEN')
        
        print(f"Processing Dynatrace alert: {problem_id} - {problem_title}")
        
        # Fetch detailed logs from Dynatrace
        logs = fetch_dynatrace_logs(problem_id)
        
        # Prepare context for DevOps Agent
        agent_context = {
            'alert': {
                'id': problem_id,
                'title': problem_title,
                'severity': severity,
                'timestamp': datetime.now().isoformat()
            },
            'logs': logs,
            'repository': GITHUB_REPO,
            'instructions': f"""
            Analyze this production alert from our todo application:
            
            Alert: {problem_title}
            Severity: {severity}
            
            Tasks:
            1. Analyze the logs and traces to identify root cause
            2. Review the application code in the repository
            3. Suggest a code fix to resolve the issue
            4. Create a GitHub issue with:
               - Root cause analysis
               - Suggested fix
               - Code changes needed
            5. If confident, create a PR with the fix
            
            Focus on:
            - Lambda function errors
            - DynamoDB throttling or errors
            - API Gateway issues
            - Performance degradation
            """
        }
        
        # Invoke DevOps Agent
        response = devops_agent.invoke_agent(
            AgentArn=DEVOPS_AGENT_ARN,
            Input=json.dumps(agent_context),
            SessionId=f"dynatrace-{problem_id}-{int(datetime.now().timestamp())}"
        )
        
        print(f"DevOps Agent invoked: {response}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'DevOps Agent triggered successfully',
                'problem_id': problem_id,
                'agent_session': response.get('SessionId')
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def fetch_dynatrace_logs(problem_id):
    """Fetch related logs from Dynatrace"""
    headers = {
        'Authorization': f'Api-Token {DYNATRACE_TOKEN}',
        'Content-Type': 'application/json'
    }
    
    try:
        # Query logs related to the problem
        response = http.request(
            'GET',
            f'{DYNATRACE_URL}/api/v2/logs/search',
            headers=headers,
            fields={
                'query': f'service.name:todo-app AND dt.problem_id:{problem_id}',
                'limit': '100'
            }
        )
        
        if response.status == 200:
            data = json.loads(response.data.decode('utf-8'))
            return data.get('results', [])
        else:
            print(f"Failed to fetch logs: {response.status}")
            return []
            
    except Exception as e:
        print(f"Error fetching Dynatrace logs: {str(e)}")
        return []
