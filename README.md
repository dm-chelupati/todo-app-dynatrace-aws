# Todo List Application

Serverless todo list app with AWS Lambda, DynamoDB, S3, and comprehensive Dynatrace observability.

## Architecture

- **Frontend**: S3 static website
- **API**: API Gateway + Lambda (Python)
- **Database**: DynamoDB
- **Logging**: CloudWatch → Dynatrace (structured JSON logs)
- **Metrics**: CloudWatch custom metrics → Dynatrace
- **Tracing**: AWS X-Ray (distributed tracing)
- **Alerts**: CloudWatch Alarms → SNS → Email + Dynatrace
- **IaC**: Terraform
- **CI/CD**: GitHub Actions

## Observability Features

### Logs Sent to Dynatrace
✅ All Lambda invocation logs (structured JSON)
✅ Request/response details with request IDs
✅ Error logs with stack traces
✅ DynamoDB operation logs
✅ Custom application events
✅ Log levels (INFO, ERROR, DEBUG)

### Metrics Sent to Dynatrace
✅ Lambda invocations, errors, duration, throttles
✅ Custom application metrics (request duration, count)
✅ DynamoDB read/write capacity
✅ API Gateway metrics
✅ CloudWatch alarm states

### Traces
✅ AWS X-Ray distributed tracing enabled
✅ End-to-end request tracing
✅ DynamoDB operation tracing
✅ Lambda cold start tracking

### Alerts
✅ Lambda errors (>5 in 5 minutes)
✅ Lambda high duration (>3 seconds)
✅ Lambda throttles (>10 in 5 minutes)
✅ DynamoDB system errors
✅ All alerts sent to email + Dynatrace

## Setup

### Prerequisites

- AWS Account
- Dynatrace Account
- GitHub Account
- Terraform installed locally

### Configuration

1. **Set GitHub Secrets** (Settings → Secrets and variables → Actions):
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `DYNATRACE_URL` (e.g., https://your-env.live.dynatrace.com)
   - `DYNATRACE_TOKEN` (API token with logs.ingest permission)
   - `ALERT_EMAIL` (email for CloudWatch alerts)

2. **Deploy Infrastructure**:
   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

3. **Deploy via GitHub Actions**:
   - Push to `main` branch
   - Workflow automatically deploys infrastructure and frontend

### Local Development

1. **Deploy manually**:
   ```bash
   cd terraform
   terraform init
   terraform apply \
     -var="dynatrace_url=YOUR_URL" \
     -var="dynatrace_token=YOUR_TOKEN" \
     -var="alert_email=YOUR_EMAIL"
   ```

2. **Get outputs**:
   ```bash
   terraform output api_endpoint
   terraform output s3_website_url
   ```

3. **Update frontend**:
   - Replace `API_GATEWAY_URL_PLACEHOLDER` in `frontend/index.html` with API endpoint
   - Upload to S3:
     ```bash
     aws s3 cp frontend/index.html s3://BUCKET_NAME/index.html
     ```

## Features

- ✅ Create, read, update, delete todos
- ✅ DynamoDB for persistence
- ✅ CloudWatch logs forwarded to Dynatrace
- ✅ CloudWatch alarms for Lambda errors
- ✅ SNS email notifications
- ✅ Infrastructure as Code (Terraform)
- ✅ CI/CD with GitHub Actions

## Monitoring

### Dynatrace
- **Logs**: All application logs with structured JSON format
- **Metrics**: Custom application metrics and CloudWatch metrics
- **Traces**: AWS X-Ray traces (configure Dynatrace AWS integration)
- **Alerts**: CloudWatch alarm notifications

### AWS CloudWatch
- **Dashboard**: `https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards`
- **X-Ray Traces**: `https://console.aws.amazon.com/xray/home`
- **Logs**: `/aws/lambda/todo-app-api`
- **Alarms**: Lambda errors, duration, throttles, DynamoDB errors

### Dynatrace Setup
1. Create API token with permissions:
   - `logs.ingest` - For log ingestion
   - `metrics.ingest` - For metrics ingestion
2. Configure AWS integration in Dynatrace for X-Ray traces
3. Set up log processing rules in Dynatrace UI
4. Create custom dashboards for todo app metrics

## API Endpoints

- `GET /todos` - List all todos
- `POST /todos` - Create todo (body: `{"title": "..."}`)
- `PUT /todos/{id}` - Update todo (body: `{"completed": true/false}`)
- `DELETE /todos/{id}` - Delete todo

## Cost Optimization

- DynamoDB: Pay-per-request billing
- Lambda: Free tier covers most usage
- S3: Minimal storage costs
- API Gateway: HTTP API (cheaper than REST)

## Cleanup

```bash
cd terraform
terraform destroy
```
