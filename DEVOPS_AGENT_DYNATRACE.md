# AWS DevOps Agent with Dynatrace Webhook

## Architecture

```
Dynatrace Alert
    ↓
Webhook (POST)
    ↓
AWS DevOps Agent Webhook Endpoint (native)
    ↓
DevOps Agent
    ├─→ Fetch Dynatrace problem details
    ├─→ Read CloudWatch Logs
    ├─→ Read X-Ray Traces
    ├─→ Analyze code in GitHub
    ├─→ Root cause analysis
    └─→ Create GitHub Issue + PR
```

## Setup

### 1. Deploy DevOps Agent

```bash
# Add GitHub token
gh secret set GITHUB_TOKEN --body "ghp_your_token" --repo dm-chelupati/todo-app-dynatrace-aws

# Deploy
cd terraform
terraform init
terraform apply

# Get webhook URL and token
terraform output devops_agent_webhook_url
terraform output devops_agent_webhook_token
```

### 2. Configure Dynatrace Webhook

#### In Dynatrace Console:

1. Go to **Settings** → **Integration** → **Problem notifications**
2. Click **Add notification**
3. Select **Custom integration**
4. Configure:

**Name**: `AWS DevOps Agent`

**Webhook URL**: 
```
<terraform output devops_agent_webhook_url>
```

**Authentication**:
- Type: `Bearer token`
- Token: `<terraform output devops_agent_webhook_token>`

**Custom payload**:
```json
{
  "ProblemID": "{ProblemID}",
  "ProblemTitle": "{ProblemTitle}",
  "ProblemDetails": "{ProblemDetailsText}",
  "ProblemURL": "{ProblemURL}",
  "State": "{State}",
  "ProblemSeverity": "{ProblemSeverity}",
  "ImpactedEntity": "{ImpactedEntity}",
  "ImpactedEntityNames": "{ImpactedEntityNames}",
  "Tags": "{Tags}",
  "ProblemImpact": "{ProblemImpact}",
  "RootCauseEntity": "{RootCauseEntity}"
}
```

**Alerting profile**: Select `Default` or create custom

5. Click **Save**

### 3. Test Integration

#### Trigger a test alert:

```bash
# Cause an error in the app
curl -X POST https://your-api-endpoint/todos \
  -H "Content-Type: application/json" \
  -d '{"title": null}'
```

#### Verify:

1. **Dynatrace**: Check if problem was created
2. **Dynatrace**: Check if webhook was sent (Settings → Integration → Problem notifications → View sent notifications)
3. **GitHub**: Check if issue was created
4. **GitHub**: Check if PR was created (if agent was confident)

## How It Works

### When Dynatrace Alert Fires:

1. **Dynatrace sends webhook** to DevOps Agent endpoint
2. **DevOps Agent receives**:
   - Problem ID
   - Problem title
   - Severity
   - Impacted entities
   - Root cause entity
3. **Agent fetches additional context**:
   - Dynatrace logs via API
   - CloudWatch logs for affected Lambda
   - X-Ray traces for failed requests
   - CloudWatch metrics
4. **Agent analyzes**:
   - Reviews code in GitHub
   - Correlates logs, traces, metrics
   - Identifies root cause
   - Generates fix suggestion
5. **Agent creates GitHub issue**:
   - Title: Dynatrace problem title
   - Body: Full analysis + fix
   - Labels: `bug`, `dynatrace-alert`, severity
6. **Agent creates PR** (if confident):
   - Branch: `fix/dynatrace-{problem-id}`
   - Code changes
   - Tests
   - Links to issue

## Accessing Private VPC Resources

**YES!** DevOps Agent accesses private resources via AWS APIs:

- ✅ CloudWatch Logs from Lambda in VPC
- ✅ X-Ray traces from Lambda in VPC
- ✅ DynamoDB metrics
- ✅ Lambda configuration
- ✅ VPC information

No VPC deployment needed - uses IAM permissions.

## Alert Filtering

### In Dynatrace:

Create alerting profile to only send specific alerts:

1. **Settings** → **Alerting** → **Alerting profiles**
2. **Create profile**: `DevOps Agent Alerts`
3. **Configure rules**:
   - Severity: `Error` and `Critical` only
   - Services: `todo-app-api`
   - Problem type: `Error`, `Slowdown`, `Resource`
4. **Apply to notification**: Select this profile in webhook config

### Example Filters:

**Only Lambda errors**:
```
Problem type: Error
Impacted entity: AWS Lambda function
Tags: service:todo-app
```

**Only critical issues**:
```
Severity: Critical
Impact: Service
```

**Exclude known issues**:
```
NOT Tags: known-issue
NOT Tags: maintenance
```

## Webhook Payload Examples

### Error Alert:
```json
{
  "ProblemID": "P-12345",
  "ProblemTitle": "Increased error rate on todo-app-api",
  "State": "OPEN",
  "ProblemSeverity": "ERROR",
  "ImpactedEntity": "AWS_LAMBDA_FUNCTION-1234567890",
  "RootCauseEntity": "AWS_LAMBDA_FUNCTION-1234567890"
}
```

### Performance Alert:
```json
{
  "ProblemID": "P-67890",
  "ProblemTitle": "Response time degradation on todo-app-api",
  "State": "OPEN",
  "ProblemSeverity": "PERFORMANCE",
  "ImpactedEntity": "AWS_LAMBDA_FUNCTION-1234567890"
}
```

## DevOps Agent Response

### GitHub Issue Created:
```markdown
# Increased error rate on todo-app-api

**Dynatrace Problem**: P-12345
**Severity**: ERROR
**Status**: OPEN

## Root Cause Analysis

Lambda function `todo-app-api` is throwing NullPointerException when 
processing POST /todos requests with null title field.

## Affected Code

File: `app/lambda/todo_handler.py`
Line: 45

## Logs
[CloudWatch Logs showing error]
[X-Ray trace showing failure]

## Suggested Fix

Add null check before processing title:

\`\`\`python
def create_todo(body):
    if not body.get('title'):
        return response(400, {'error': 'Title is required'})
    # ... rest of code
\`\`\`

## PR Created
#123 - Fix null title validation
```

## Costs

- **AWS DevOps Agent**: $19/month (Amazon Q Developer)
- **Secrets Manager**: $0.40/month (webhook token)
- **API calls**: Minimal (~$0.01/month)

**Total**: ~$20/month

## Advantages

✅ **Direct integration** - Dynatrace → DevOps Agent (no middleware)
✅ **Native webhook** - AWS DevOps Agent has built-in endpoint
✅ **Secure** - Token-based authentication
✅ **Simple** - No Lambda, API Gateway, EventBridge
✅ **Fast** - Direct trigger, no polling
✅ **Rich context** - Agent fetches all related data

## Troubleshooting

### Webhook not received:

```bash
# Check Dynatrace sent notifications
# Settings → Integration → Problem notifications → Sent notifications

# Check DevOps Agent logs
aws logs tail /aws/devops-agent/todo-app-agent --follow
```

### Agent not creating issues:

```bash
# Check agent status
aws devops-agent get-agent --agent-id <agent-id>

# Check GitHub token permissions
gh auth status

# Verify IAM permissions
aws iam get-role-policy --role-name todo-app-devops-agent-role --policy-name todo-app-devops-agent-policy
```

### Agent can't access resources:

```bash
# Verify IAM permissions
aws iam simulate-principal-policy \
  --policy-source-arn <agent-role-arn> \
  --action-names logs:GetLogEvents xray:GetTraceSummaries
```
