# Deployment Instructions

## ✅ Configuration Complete

All secrets have been configured in GitHub:
- ✅ AWS_ACCESS_KEY_ID
- ✅ AWS_SECRET_ACCESS_KEY  
- ✅ DYNATRACE_URL: https://dhu66396.apps.dynatrace.com
- ✅ DYNATRACE_TOKEN
- ✅ ALERT_EMAIL: deepthichelupati@gmail.com

## 🔒 Private Networking Architecture

### VPC Configuration
- **VPC CIDR**: 10.0.0.0/16
- **Private Subnets**: 
  - 10.0.1.0/24 (us-east-1a)
  - 10.0.2.0/24 (us-east-1b)
- **No Internet Gateway**: Fully private
- **VPC Endpoints**:
  - DynamoDB Gateway Endpoint (no data charges)
  - S3 Gateway Endpoint (no data charges)

### Security Features
- ✅ Lambda functions in private subnets
- ✅ DynamoDB accessed via VPC endpoint (no internet)
- ✅ S3 accessed via VPC endpoint (no internet)
- ✅ CloudWatch logs via AWS PrivateLink
- ✅ X-Ray via AWS PrivateLink
- ✅ Security groups restrict all inbound traffic
- ✅ Only necessary outbound traffic allowed

### Public Access Points
- ✅ API Gateway (public endpoint for frontend)
- ✅ S3 static website (public for frontend hosting)

All backend resources (Lambda, DynamoDB) are private and never exposed to internet.

## 🚀 Deploy Now

### Option 1: GitHub Actions (Recommended)
```bash
# Trigger deployment
gh workflow run deploy.yml --repo dm-chelupati/todo-app-dynatrace-aws
```

### Option 2: Manual Deployment
```bash
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
```

## 📊 After Deployment

### Access Your App
1. Get S3 website URL: `terraform output s3_website_url`
2. Get API endpoint: `terraform output api_endpoint`
3. Update frontend with API URL and upload to S3

### View Monitoring
- **Dynatrace**: https://dhu66396.apps.dynatrace.com
  - Search logs: `service.name:todo-app`
  - View metrics: Custom namespace `TodoApp`
- **CloudWatch Dashboard**: Check terraform outputs
- **X-Ray Traces**: Check terraform outputs

### Verify Private Networking
```bash
# Check Lambda VPC config
aws lambda get-function-configuration --function-name todo-app-api

# Check VPC endpoints
aws ec2 describe-vpc-endpoints

# Check security groups
aws ec2 describe-security-groups --filters "Name=group-name,Values=todo-app-lambda-sg"
```

## 🔐 AWS Credentials Used
- **Access Key ID**: AKIAU6ZBBJVI3YHPQ4P3
- **Region**: us-east-1

## 📧 Alerts
You'll receive email alerts for:
- Lambda errors (>5 in 5 min)
- Lambda high duration (>3 sec)
- Lambda throttles (>10 in 5 min)
- DynamoDB errors

Confirm SNS subscription in your email: deepthichelupati@gmail.com
