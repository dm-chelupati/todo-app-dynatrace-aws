# AWS DevOps Agent with Dynatrace Alert Trigger

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

# IAM Policy for DevOps Agent
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

# AWS DevOps Agent
resource "aws_devops_agent" "main" {
  name        = "${var.project_name}-agent"
  description = "DevOps agent triggered by Dynatrace alerts"
  
  role_arn = aws_iam_role.devops_agent_role.arn

  # GitHub Integration
  source_control {
    type  = "GITHUB"
    owner = var.github_repo_owner
    repo  = var.github_repo_name
    token = var.github_token
  }

  # Agent capabilities
  capabilities {
    log_analysis        = true
    trace_analysis      = true
    metric_analysis     = true
    code_fix_generation = true
    issue_creation      = true
    pr_creation         = true
  }

  # What to monitor
  monitoring_sources {
    cloudwatch_logs = [
      "/aws/lambda/${var.project_name}-api"
    ]
    xray_traces = true
  }

  # Dynatrace Integration
  external_monitoring {
    dynatrace {
      url   = var.dynatrace_url
      token = var.dynatrace_token
      fetch_logs    = true
      fetch_metrics = true
    }
  }

  # Webhook endpoint for Dynatrace
  webhook {
    enabled = true
    authentication {
      type = "TOKEN"
      token_secret_arn = aws_secretsmanager_secret.webhook_token.arn
    }
  }

  # Agent instructions
  instructions = <<-EOT
    You are monitoring a serverless todo application.
    
    When triggered by Dynatrace alert:
    1. Fetch problem details from Dynatrace
    2. Read CloudWatch logs for the affected Lambda
    3. Analyze X-Ray traces for failed requests
    4. Review code in GitHub repository
    5. Identify root cause
    6. Create GitHub issue with:
       - Dynatrace alert details
       - Root cause analysis
       - Relevant logs and traces
       - Suggested code fix
    7. If >80% confident, create PR with fix
  EOT

  tags = {
    Name = "${var.project_name}-devops-agent"
  }
}

# Webhook authentication token
resource "random_password" "webhook_token" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "webhook_token" {
  name = "${var.project_name}-devops-agent-webhook-token"
}

resource "aws_secretsmanager_secret_version" "webhook_token" {
  secret_id     = aws_secretsmanager_secret.webhook_token.id
  secret_string = random_password.webhook_token.result
}

# Outputs
output "devops_agent_webhook_url" {
  description = "Webhook URL for Dynatrace to call"
  value       = aws_devops_agent.main.webhook_url
}

output "devops_agent_webhook_token" {
  description = "Webhook authentication token (add to Dynatrace)"
  value       = random_password.webhook_token.result
  sensitive   = true
}

output "devops_agent_arn" {
  description = "DevOps Agent ARN"
  value       = aws_devops_agent.main.arn
}
