# AWS DevOps Agent Setup Guide

## Overview

AWS DevOps Agent automatically:
1. 🔍 Monitors CloudWatch Logs, X-Ray traces, and metrics
2. 🚨 Receives Dynatrace alert webhooks
3. 🤖 Analyzes root cause using AI
4. 🛠️ Suggests code fixes
5. 📝 Creates GitHub issues
6. 🔧 Creates PRs with fixes (optional)

## Architecture

```
Dynatrace Alert
    ↓
Webhook → API Gateway → Lambda Trigger
    ↓
AWS DevOps Agent
    ├─→ CloudWatch Logs (via AWS API)
    ├─→ X-Ray Traces (via AWS API)
    ├─→ CloudWatch Metrics (via AWS API)
    ├─→ DynamoDB Metrics (via AWS API)
    ├─→ Dynatrace Logs (via API)
    ├─→ GitHub Repo (code analysis)
    └─→ Create Issue/PR in GitHub
```

## Prerequisites

### 1. GitHub Personal Access Token
Create a token with these permissions:
- `repo` (full control)
- `workflow` (update workflows)
- `write:packages` (optional)

```bash
# Create token at: https://github.com/settings/tokens/new
# Save it securely
```

### 2. AWS DevOps Agent Subscription
AWS DevOps Agent requires Amazon Q Developer subscription:
- Individual: $19/month
- Team: $25/user/month

## Deployment

### 1. Add GitHub Token to Secrets

```bash
gh secret set GITHUB_TOKEN --body "ghp_your_token_here" --repo dm-chelupati/todo-app-dynatrace-aws
```

### 2. Update Terraform Variables

Add to `terraform/terraform.tfvars`:
```hcl
github_token = "ghp_your_token_here"
```

### 3. Deploy DevOps Agent

```bash
cd terraform
terraform init
terraform apply
```

### 4. Configure Dynatrace Webhook

Get webhook URL:
```bash
terraform output dynatrace_webhook_url
```

In Dynatrace:
1. Go to Settings → Integration → Problem notifications
2. Add custom integration
3. Set webhook URL: `<terraform_output>/webhook`
4. Set payload:
```json
{
  "ProblemID": "{ProblemID}",
  "ProblemTitle": "{ProblemTitle}",
  "State": "{State}",
  "ImpactedEntity": "{ImpactedEntity}",
  "ProblemURL": "{ProblemURL}",
  "Tags": "{Tags}"
}
```

## How It Works

### When Alert Triggers:

1. **Dynatrace sends webhook** → API Gateway → Lambda
2. **Lambda fetches context**:
   - Dynatrace logs for the problem
   - CloudWatch logs from affected Lambda
   - X-Ray traces for failed requests
   - CloudWatch metrics (errors, duration)
3. **DevOps Agent analyzes**:
   - Reviews application code
   - Identifies root cause
   - Generates fix suggestion
4. **Agent creates GitHub issue**:
   - Title: Alert name
   - Body: Root cause analysis + suggested fix
   - Labels: `bug`, `auto-generated`
5. **Optional: Agent creates PR**:
   - Branch: `fix/alert-{problem-id}`
   - Changes: Suggested code fix
   - Description: Explanation of fix

## Accessing Private VPC Resources

### DevOps Agent Can Access:

✅ **CloudWatch Logs** - Via AWS API (no VPC needed)
✅ **X-Ray Traces** - Via AWS API (no VPC needed)
✅ **CloudWatch Metrics** - Via AWS API (no VPC needed)
✅ **DynamoDB Metrics** - Via AWS API (no VPC needed)
✅ **Lambda Configuration** - Via AWS API (no VPC needed)

### For Direct VPC Access:

If you need DevOps Agent to query private resources directly:

```hcl
# Add Lambda proxy in VPC
resource "aws_lambda_function" "vpc_proxy" {
  # ... Lambda in VPC configuration
  
  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

# DevOps Agent calls this Lambda to access VPC resources
```

## Testing

### 1. Trigger Test Alert

```bash
# Manually trigger an error in the app
curl -X POST https://your-api-endpoint/todos \
  -H "Content-Type: application/json" \
  -d '{"title": null}'  # This will cause an error
```

### 2. Check DevOps Agent Activity

```bash
# View Lambda logs
aws logs tail /aws/lambda/todo-app-devops-agent-trigger --follow

# Check GitHub issues
gh issue list --repo dm-chelupati/todo-app-dynatrace-aws
```

### 3. Verify in Dynatrace

1. Go to Problems
2. Find the triggered problem
3. Check if webhook was sent
4. Verify DevOps Agent received it

## Configuration Options

### Agent Capabilities

Enable/disable features in `devops_agent.tf`:

```hcl
capabilities {
  log_analysis        = true   # Analyze CloudWatch logs
  trace_analysis      = true   # Analyze X-Ray traces
  metric_analysis     = true   # Analyze CloudWatch metrics
  code_fix_generation = true   # Generate code fixes
  issue_creation      = true   # Create GitHub issues
  pr_creation         = false  # Create PRs (set to true to enable)
}
```

### Alert Filtering

Modify `devops_agent_trigger.py` to filter alerts:

```python
# Only process critical alerts
if severity not in ['CRITICAL', 'ERROR']:
    return {'statusCode': 200, 'body': 'Alert ignored'}
```

## Costs

- **AWS DevOps Agent**: $19-25/month (Amazon Q subscription)
- **Lambda**: ~$0.20/1000 invocations
- **API Gateway**: ~$1/million requests
- **CloudWatch Logs**: ~$0.50/GB ingested

**Estimated Total**: $20-30/month

## Troubleshooting

### DevOps Agent Not Triggering

1. Check Lambda logs:
```bash
aws logs tail /aws/lambda/todo-app-devops-agent-trigger --follow
```

2. Verify webhook URL in Dynatrace
3. Check IAM permissions

### Agent Can't Access Resources

1. Verify IAM role has correct permissions
2. Check CloudWatch Logs exist
3. Verify X-Ray tracing is enabled

### No GitHub Issues Created

1. Check GitHub token permissions
2. Verify repository access
3. Check DevOps Agent logs

## Next Steps

1. ✅ Deploy infrastructure
2. ✅ Configure Dynatrace webhook
3. ✅ Test with sample alert
4. ✅ Review generated issues
5. ✅ Enable PR creation (optional)
6. ✅ Set up auto-merge for low-risk fixes (optional)
