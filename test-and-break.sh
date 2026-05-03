#!/bin/bash

# Todo App Testing & Network Failure Simulation

echo "=== Todo App Test & Network Failure Simulation ==="
echo ""

# Step 1: Get API endpoint
echo "Step 1: Getting API endpoint..."
cd terraform
API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null)

if [ -z "$API_ENDPOINT" ]; then
    echo "ERROR: Could not get API endpoint. Is terraform deployed?"
    echo "Run: cd terraform && terraform output api_endpoint"
    exit 1
fi

echo "API Endpoint: $API_ENDPOINT"
echo ""

# Step 2: Test Read (GET /todos)
echo "Step 2: Testing READ - Get all todos"
echo "Command: curl -X GET $API_ENDPOINT/todos"
curl -X GET "$API_ENDPOINT/todos"
echo ""
echo ""

# Step 3: Test Write (POST /todos)
echo "Step 3: Testing WRITE - Create new todo"
echo "Command: curl -X POST $API_ENDPOINT/todos -H 'Content-Type: application/json' -d '{\"title\": \"Test Todo\"}'"
curl -X POST "$API_ENDPOINT/todos" \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Todo from script"}'
echo ""
echo ""

# Step 4: Test Read again
echo "Step 4: Testing READ again - Verify todo was created"
curl -X GET "$API_ENDPOINT/todos"
echo ""
echo ""

# Step 5: Break networking - Remove DynamoDB VPC endpoint
echo "=== BREAKING NETWORKING LAYER ==="
echo ""
echo "Step 5: Removing DynamoDB VPC endpoint to break Lambda->DynamoDB connection"
echo ""

# Get VPC endpoint ID
VPC_ENDPOINT_ID=$(aws ec2 describe-vpc-endpoints \
  --filters "Name=service-name,Values=com.amazonaws.us-east-1.dynamodb" \
  --query 'VpcEndpoints[0].VpcEndpointId' \
  --output text)

if [ "$VPC_ENDPOINT_ID" != "None" ] && [ -n "$VPC_ENDPOINT_ID" ]; then
    echo "Found DynamoDB VPC Endpoint: $VPC_ENDPOINT_ID"
    echo "Deleting VPC endpoint..."
    aws ec2 delete-vpc-endpoints --vpc-endpoint-ids "$VPC_ENDPOINT_ID"
    echo "VPC endpoint deleted!"
    echo ""
    echo "Waiting 30 seconds for change to propagate..."
    sleep 30
else
    echo "No DynamoDB VPC endpoint found. Trying alternative: Block security group"
    
    # Get Lambda security group
    SG_ID=$(aws ec2 describe-security-groups \
      --filters "Name=group-name,Values=todo-app-lambda-sg" \
      --query 'SecurityGroups[0].GroupId' \
      --output text)
    
    if [ "$SG_ID" != "None" ] && [ -n "$SG_ID" ]; then
        echo "Found Lambda Security Group: $SG_ID"
        echo "Removing all egress rules..."
        aws ec2 revoke-security-group-egress \
          --group-id "$SG_ID" \
          --ip-permissions '[{"IpProtocol": "-1", "IpRanges": [{"CidrIp": "0.0.0.0/0"}]}]'
        echo "Security group egress blocked!"
    fi
fi

echo ""
echo "=== SIMULATING TRAFFIC TO BROKEN APP ==="
echo ""

# Step 6: Generate traffic to trigger errors
echo "Step 6: Sending 20 requests to trigger errors and Dynatrace alerts"
echo ""

for i in {1..20}; do
    echo "Request $i/20..."
    curl -X GET "$API_ENDPOINT/todos" -w "\nStatus: %{http_code}\n" -s
    sleep 2
done

echo ""
echo "=== TEST COMPLETE ==="
echo ""
echo "What happened:"
echo "1. ✅ Tested read/write to todo app (should have worked)"
echo "2. ❌ Broke networking layer (removed DynamoDB VPC endpoint or blocked security group)"
echo "3. 🔥 Generated 20 failed requests"
echo ""
echo "Expected results:"
echo "- Lambda will fail to connect to DynamoDB"
echo "- Errors logged to CloudWatch"
echo "- X-Ray traces show connection failures"
echo "- Dynatrace detects problem"
echo "- Dynatrace alert triggers"
echo "- DevOps Agent (when configured) analyzes and creates GitHub issue"
echo ""
echo "Check:"
echo "1. CloudWatch Logs: /aws/lambda/todo-app-api"
echo "2. X-Ray: https://console.aws.amazon.com/xray/home"
echo "3. Dynatrace: https://dhu66396.apps.dynatrace.com"
echo "4. CloudWatch Alarms: todo-app-lambda-errors"
echo ""
echo "To restore:"
echo "cd terraform && terraform apply"
