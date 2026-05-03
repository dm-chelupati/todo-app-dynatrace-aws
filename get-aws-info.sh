#!/bin/bash

echo "=== AWS Account Information ==="
echo ""

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $ACCOUNT_ID"
echo ""

# Get current IAM user/role
IDENTITY=$(aws sts get-caller-identity --query Arn --output text)
echo "Current Identity: $IDENTITY"
echo ""

echo "=== IAM Access Keys ==="
echo ""
echo "To create new access keys for your IAM user:"
echo "1. Go to: https://console.aws.amazon.com/iam/home#/users"
echo "2. Select your user"
echo "3. Go to 'Security credentials' tab"
echo "4. Click 'Create access key'"
echo ""
echo "OR run this command if you have permissions:"
echo "aws iam create-access-key --user-name YOUR_USERNAME"
echo ""

echo "=== Lambda Functions ==="
aws lambda list-functions --query 'Functions[*].[FunctionName,Runtime,VpcConfig.VpcId]' --output table
echo ""

echo "=== DynamoDB Tables ==="
aws dynamodb list-tables --query 'TableNames' --output table
echo ""

echo "=== S3 Buckets ==="
aws s3 ls
echo ""

echo "=== VPC Information ==="
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,CidrBlock,IsDefault]' --output table
echo ""

echo "=== API Gateway APIs ==="
aws apigatewayv2 get-apis --query 'Items[*].[Name,ApiEndpoint,ProtocolType]' --output table
echo ""

echo "=== CloudWatch Log Groups ==="
aws logs describe-log-groups --query 'logGroups[*].logGroupName' --output table
echo ""

echo "=== X-Ray Traces ==="
echo "X-Ray Console: https://console.aws.amazon.com/xray/home?region=us-east-1#/traces"
echo ""

echo "=== To get AWS Access Keys ==="
echo "Run: aws configure"
echo "Or check: cat ~/.aws/credentials"
