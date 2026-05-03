# Simplified AWS DevOps Agent Configuration
# No API Gateway, EventBridge, or Lambda needed!

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "github_repo_owner" {
  description = "GitHub repository owner"
  type        = string
  default     = "dm-chelupati"
}

variable "github_repo_name" {
  description = "GitHub repository name"
  type        = string
  default     = "todo-app-dynatrace-aws"
}

# IAM Role for DevOps Agent
resource "aws_iam_role" "devops_agent_role" {
  name = "${var.project_name}-devops-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "devops-agent.amazonaws.com"
      }
    }]
  })
}

# IAM Policy for DevOps Agent to access ALL resources
resource "aws_iam_role_policy" "devops_agent_policy" {
  name = "${var.project_name}-devops-agent-policy"
  role = aws_iam_role.devops_agent_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:*",
          "xray:*",
          "cloudwatch:*",
          "dynamodb:Describe*",
          "dynamodb:Get*",
          "dynamodb:Query",
          "dynamodb:Scan",
          "lambda:Get*",
          "lambda:List*",
          "ec2:Describe*",
          "apigateway:GET"
        ]
        Resource = "*"
      }
    ]
  })
}

# AWS DevOps Agent - Native Configuration
resource "aws_devops_agent" "main" {
  name        = "${var.project_name}-agent"
  description = "DevOps agent for todo app - monitors, diagnoses, and fixes issues automatically"
  
  role_arn = aws_iam_role.devops_agent_role.arn

  # GitHub Integration
  source_control {
    type  = "GITHUB"
    owner = var.github_repo_owner
    repo  = var.github_repo_name
    token = var.github_token
  }

  # What the agent can do
  capabilities {
    log_analysis        = true  # Analyze CloudWatch logs
    trace_analysis      = true  # Analyze X-Ray traces
    metric_analysis     = true  # Analyze CloudWatch metrics
    code_fix_generation = true  # Generate code fixes
    issue_creation      = true  # Create GitHub issues
    pr_creation         = true  # Create PRs with fixes
  }

  # What to monitor (Native AWS integrations)
  monitoring_sources {
    # CloudWatch Logs
    cloudwatch_logs = [
      "/aws/lambda/${var.project_name}-api",
      "/aws/lambda/${var.project_name}-dynatrace-forwarder"
    ]
    
    # X-Ray Traces
    xray_traces = true
    
    # CloudWatch Metrics
    cloudwatch_metrics = [
      {
        namespace = "AWS/Lambda"
        dimensions = {
          FunctionName = "${var.project_name}-api"
        }
      },
      {
        namespace = "AWS/DynamoDB"
        dimensions = {
          TableName = aws_dynamodb_table.todos.name
        }
      },
      {
        namespace = "AWS/ApiGateway"
        dimensions = {
          ApiName = "${var.project_name}-api"
        }
      },
      {
        namespace = "TodoApp"  # Custom metrics
      }
    ]
    
    # CloudWatch Alarms (Native trigger!)
    cloudwatch_alarms = [
      aws_cloudwatch_metric_alarm.lambda_errors.alarm_name,
      aws_cloudwatch_metric_alarm.lambda_duration.alarm_name,
      aws_cloudwatch_metric_alarm.lambda_throttles.alarm_name,
      aws_cloudwatch_metric_alarm.dynamodb_errors.alarm_name
    ]
  }

  # Dynatrace Integration (if supported natively)
  external_monitoring {
    dynatrace {
      url   = var.dynatrace_url
      token = var.dynatrace_token
      
      # What to fetch from Dynatrace
      fetch_logs    = true
      fetch_metrics = true
      fetch_traces  = true
    }
  }

  # Agent behavior
  automation_rules {
    # Auto-create issues for all errors
    rule {
      name        = "auto-issue-on-error"
      description = "Create GitHub issue when errors detected"
      
      trigger {
        type = "ALARM"
        alarm_states = ["ALARM"]
      }
      
      action {
        type = "CREATE_ISSUE"
        severity_threshold = "ERROR"
      }
    }
    
    # Auto-create PR for known fixes
    rule {
      name        = "auto-pr-on-known-fix"
      description = "Create PR when agent has high confidence fix"
      
      trigger {
        type = "ALARM"
        alarm_states = ["ALARM"]
      }
      
      action {
        type = "CREATE_PR"
        confidence_threshold = 0.8  # Only if 80%+ confident
        require_approval = true
      }
    }
  }

  # Agent instructions
  instructions = <<-EOT
    You are monitoring a serverless todo application with the following architecture:
    - Frontend: S3 static website
    - API: Lambda + API Gateway
    - Database: DynamoDB
    - Monitoring: CloudWatch + X-Ray + Dynatrace
    
    When analyzing issues:
    1. Check CloudWatch logs for Lambda errors
    2. Review X-Ray traces for performance issues
    3. Check DynamoDB metrics for throttling
    4. Review Dynatrace logs for additional context
    5. Analyze the code in the GitHub repository
    6. Identify root cause
    7. Suggest a fix with code changes
    8. Create a GitHub issue with detailed analysis
    9. If confident (>80%), create a PR with the fix
    
    Common issues to watch for:
    - Lambda timeout errors
    - DynamoDB throttling
    - API Gateway 5xx errors
    - Null pointer exceptions
    - Missing error handling
    - Performance degradation
  EOT

  tags = {
    Name        = "${var.project_name}-devops-agent"
    Environment = "production"
  }
}

# Outputs
output "devops_agent_arn" {
  description = "DevOps Agent ARN"
  value       = aws_devops_agent.main.arn
}

output "devops_agent_console_url" {
  description = "DevOps Agent Console URL"
  value       = "https://console.aws.amazon.com/devops-agent/home?region=${var.aws_region}#/agents/${aws_devops_agent.main.id}"
}
