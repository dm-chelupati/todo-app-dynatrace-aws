# Dynatrace Alert Filtering for DevOps Agent

## Problem: Too Many Alerts

Without filtering, DevOps Agent would be triggered for:
- ❌ Every minor issue
- ❌ Known problems
- ❌ Maintenance windows
- ❌ Non-critical warnings
- ❌ Transient errors

## Solution: Multi-Layer Filtering

### Layer 1: Dynatrace Alerting Profile (BEST)

Filter alerts BEFORE sending to DevOps Agent.

#### Create Custom Alerting Profile

**In Dynatrace Console:**

1. **Settings** → **Alerting** → **Alerting profiles**
2. Click **Add alerting profile**
3. Name: `DevOps Agent - Critical Only`

#### Configuration:

```yaml
Profile Name: DevOps Agent - Critical Only

# Severity Rules
Severity filters:
  - ERROR (include)
  - CRITICAL (include)
  - RESOURCE_CONTENTION (include)
  - PERFORMANCE (exclude unless critical)
  - AVAILABILITY (include)
  - CUSTOM_ALERT (include)
  - INFO (exclude)

# Service Filters
Management zone filters:
  - Include: "Production"
  - Include: "todo-app"
  - Exclude: "Development"
  - Exclude: "Testing"

# Problem Type Filters
Problem type:
  - Include: "Error"
  - Include: "Slowdown" (if duration > 5 min)
  - Include: "Resource exhaustion"
  - Exclude: "Infrastructure" (unless critical)

# Entity Filters
Impacted entities:
  - Include: AWS Lambda functions with tag "monitored:true"
  - Include: DynamoDB tables with tag "production:true"
  - Exclude: Test resources

# Time-based Filters
Delay notification:
  - Wait 2 minutes before sending (filters transient issues)
  
Send resolved notifications:
  - No (don't spam when fixed)

# Tag-based Filters
Required tags:
  - service:todo-app
  - environment:production

Excluded tags:
  - maintenance:true
  - known-issue:true
  - ignore-alerts:true
```

#### Apply to Webhook:

1. **Settings** → **Integration** → **Problem notifications**
2. Find your **AWS DevOps Agent** webhook
3. **Alerting profile**: Select `DevOps Agent - Critical Only`
4. **Save**

### Layer 2: Dynatrace Problem Filters

**Advanced filtering in webhook configuration:**

```json
{
  "filter": {
    "severityLevel": ["ERROR", "CRITICAL"],
    "impactLevel": ["SERVICES", "APPLICATION"],
    "managementZones": ["Production"],
    "tags": [
      {
        "context": "ENVIRONMENT",
        "key": "service",
        "value": "todo-app"
      }
    ],
    "excludeTags": [
      {
        "key": "maintenance"
      },
      {
        "key": "known-issue"
      }
    ]
  }
}
```

### Layer 3: DevOps Agent Configuration

Add filtering logic in the agent itself:

<function_calls>
<invoke name="fsReplace">
<parameter name="diffs">[{"newStr": "  # Webhook endpoint for Dynatrace\n  webhook {\n    enabled = true\n    authentication {\n      type = \"TOKEN\"\n      token_secret_arn = aws_secretsmanager_secret.webhook_token.arn\n    }\n    \n    # Agent-side filtering\n    filters {\n      # Only process specific severities\n      severity_levels = [\"ERROR\", \"CRITICAL\"]\n      \n      # Only process specific problem types\n      problem_types = [\n        \"ERROR_EVENT\",\n        \"SLOWDOWN\",\n        \"RESOURCE_EXHAUSTION\",\n        \"AVAILABILITY_EVENT\"\n      ]\n      \n      # Minimum impact level\n      min_impact_level = \"SERVICES\"\n      \n      # Required tags\n      required_tags = {\n        \"service\" = \"todo-app\"\n        \"environment\" = \"production\"\n      }\n      \n      # Excluded tags\n      excluded_tags = [\n        \"maintenance\",\n        \"known-issue\",\n        \"ignore-alerts\"\n      ]\n      \n      # Rate limiting\n      rate_limit {\n        max_alerts_per_hour = 10\n        max_alerts_per_day  = 50\n      }\n      \n      # Deduplication\n      deduplication {\n        enabled = true\n        window_minutes = 30  # Don't process same problem within 30 min\n      }\n    }\n  }", "oldStr": "  # Webhook endpoint for Dynatrace\n  webhook {\n    enabled = true\n    authentication {\n      type = \"TOKEN\"\n      token_secret_arn = aws_secretsmanager_secret.webhook_token.arn\n    }\n  }"}]