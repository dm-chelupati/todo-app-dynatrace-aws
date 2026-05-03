# AWS DevOps Agent - Simplified Setup

## Overview

AWS DevOps Agent **natively integrates** with:
- ✅ CloudWatch Logs, Metrics, Alarms
- ✅ X-Ray Traces
- ✅ GitHub
- ✅ Dynatrace (via API)

**NO need for:**
- ❌ API Gateway
- ❌ EventBridge
- ❌ Lambda triggers
- ❌ Custom webhooks

## How It Works

```
CloudWatch Alarm triggers
    ↓
AWS DevOps Agent (native integration)
    ├─→ Reads CloudWatch Logs
    ├─→ Reads X-Ray Traces
    ├─→ Reads CloudWatch Metrics
    ├─→ Fetches Dynatrace logs (API)
    ├─→ Analyzes code in GitHub
    ├─→ Identifies root cause
    └─→ Creates GitHub Issue + PR
```

## Setup

### 1. Create GitHub Token

```bash
# Go to: https://github.com/settings/tokens/new
# Permissions needed:
# - repo (full control)
# - workflow

# Add to GitHub Secrets
gh secret set GITHUB_TOKEN --body "ghp_your_token" --repo dm-chelupati/todo-app-dynatrace-aws
```

### 2. Deploy

```bash
cd terraform
terraform init
terraform apply
```

That's it! No webhook configuration needed.

## What Gets Monitored

### Native AWS Monitoring:
- **CloudWatch Logs**: `/aws/lambda/todo-app-*`
- **X-Ray Traces**: All Lambda traces
- **CloudWatch Metrics**: Lambda, DynamoDB, API Gateway
- **CloudWatch Alarms**: All 4 alarms we created

### Dynatrace Integration:
- **Logs**: Fetched via Dynatrace API
- **Metrics**: Fetched via Dynatrace API
- **Traces**: Fetched via Dynatrace API

## When Agent Triggers

### Automatic Triggers:
1. **CloudWatch Alarm goes to ALARM state**
   - Lambda errors > 5
   - Lambda duration > 3s
   - Lambda throttles > 10
   - DynamoDB errors > 5

2. **Agent Actions**:
   - Fetches logs from CloudWatch + Dynatrace
   - Analyzes X-Ray traces
   - Reviews code in GitHub
   - Identifies root cause
   - Creates GitHub issue with analysis
   - If >80% confident: Creates PR with fix

## Accessing Private VPC Resources

### DevOps Agent Can Access:

✅ **CloudWatch Logs** - Native AWS API
✅ **X-Ray Traces** - Native AWS API
✅ **CloudWatch Metrics** - Native AWS API
✅ **DynamoDB Metrics** - Native AWS API
✅ **Lambda Config** - Native AWS API
✅ **VPC Info** - Native AWS API (read-only)

**No VPC deployment needed!** Agent uses IAM permissions to access everything.

## Configuration

### Enable/Disable Features

Edit `terraform/devops_agent_simple.tf`:

```hcl
capabilities {
  log_analysis        = true   # Analyze logs
  trace_analysis      = true   # Analyze traces
  metric_analysis     = true   # Analyze metrics
  code_fix_generation = true   # Generate fixes
  issue_creation      = true   # Create issues
  pr_creation         = true   # Create PRs (set false to disable)
}
```

### Automation Rules

```hcl
automation_rules {
  rule {
    name = "auto-issue-on-error"
    trigger {
      type = "ALARM"
      alarm_states = ["ALARM"]
    }
    action {
      type = "CREATE_ISSUE"
    }
  }
  
  rule {
    name = "auto-pr-on-known-fix"
    trigger {
      type = "ALARM"
    }
    action {
      type = "CREATE_PR"
      confidence_threshold = 0.8  # Only if 80%+ confident
    }
  }
}
```

## Testing

### 1. Trigger an Error

```bash
# Cause a Lambda error
curl -X POST https://your-api-endpoint/todos \
  -H "Content-Type: application/json" \
  -d '{"title": null}'
```

### 2. Watch Agent Work

```bash
# Check CloudWatch Alarms
aws cloudwatch describe-alarms --alarm-names todo-app-lambda-errors

# Check GitHub Issues
gh issue list --repo dm-chelupati/todo-app-dynatrace-aws

# View Agent Activity
aws devops-agent get-agent-activity --agent-id <agent-id>
```

### 3. Review Results

Agent will create:
1. **GitHub Issue** with:
   - Root cause analysis
   - Relevant logs and traces
   - Suggested fix
   - Code changes needed

2. **GitHub PR** (if confident):
   - Branch: `fix/alarm-<timestamp>`
   - Code changes
   - Tests (if applicable)
   - Description of fix

## Costs

- **AWS DevOps Agent**: $19/month (Amazon Q Developer Individual)
- **CloudWatch**: Existing costs (no additional)
- **X-Ray**: Existing costs (no additional)
- **API calls**: Minimal (~$0.01/month)

**Total**: ~$19/month

## Advantages of Native Integration

✅ **No custom code** - No Lambda, API Gateway, EventBridge
✅ **Automatic triggers** - CloudWatch Alarms directly trigger agent
✅ **Built-in retry** - AWS handles failures
✅ **Secure** - IAM-based access, no public endpoints
✅ **Simpler** - Less infrastructure to manage
✅ **Cost-effective** - No additional Lambda/API Gateway costs

## Next Steps

1. ✅ Create GitHub token
2. ✅ Deploy infrastructure
3. ✅ Test with sample error
4. ✅ Review generated issues/PRs
5. ✅ Adjust automation rules as needed
