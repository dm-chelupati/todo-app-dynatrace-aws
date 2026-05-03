# AWS DevOps Agent Configuration

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

# IAM Policy for DevOps Agent to access resources
resource "aws_iam_role_policy" "devops_agent_policy" {
  name = "${var.project_name}-devops-agent-policy"
  role = aws_iam_role.devops_agent_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:GetTraceSummaries",
          "xray:GetTraceGraph",
          "xray:GetServiceGraph",
          "xray:BatchGetTraces"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:DescribeAlarms"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.todos.arn
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:ListFunctions"
        ]
        Resource = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.project_name}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
      }
    ]
  })
}

# EventBridge Rule for Dynatrace Webhooks
resource "aws_cloudwatch_event_rule" "dynatrace_alert" {
  name        = "${var.project_name}-dynatrace-alert"
  description = "Capture Dynatrace alerts"

  event_pattern = jsonencode({
    source      = ["aws.partner/dynatrace.com"]
    detail-type = ["Dynatrace Problem"]
  })
}

# Lambda to process Dynatrace webhooks and trigger DevOps Agent
resource "aws_lambda_function" "devops_agent_trigger" {
  filename         = data.archive_file.devops_agent_trigger_zip.output_path
  function_name    = "${var.project_name}-devops-agent-trigger"
  role            = aws_iam_role.devops_agent_trigger_role.arn
  handler         = "devops_agent_trigger.lambda_handler"
  runtime         = "python3.11"
  source_code_hash = data.archive_file.devops_agent_trigger_zip.output_base64sha256
  timeout          = 60

  environment {
    variables = {
      DEVOPS_AGENT_ARN = aws_devops_agent.main.arn
      GITHUB_REPO      = "${var.github_repo_owner}/${var.github_repo_name}"
      DYNATRACE_URL    = var.dynatrace_url
      DYNATRACE_TOKEN  = var.dynatrace_token
    }
  }
}

data "archive_file" "devops_agent_trigger_zip" {
  type        = "zip"
  source_file = "../app/lambda/devops_agent_trigger.py"
  output_path = "devops_agent_trigger.zip"
}

resource "aws_iam_role" "devops_agent_trigger_role" {
  name = "${var.project_name}-devops-agent-trigger-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "devops_agent_trigger_policy" {
  name = "${var.project_name}-devops-agent-trigger-policy"
  role = aws_iam_role.devops_agent_trigger_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "devops-agent:InvokeAgent",
          "devops-agent:GetAgentStatus"
        ]
        Resource = aws_devops_agent.main.arn
      }
    ]
  })
}

# API Gateway for Dynatrace Webhook
resource "aws_apigatewayv2_api" "dynatrace_webhook" {
  name          = "${var.project_name}-dynatrace-webhook"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "dynatrace_webhook_integration" {
  api_id           = aws_apigatewayv2_api.dynatrace_webhook.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.devops_agent_trigger.invoke_arn
}

resource "aws_apigatewayv2_route" "dynatrace_webhook_route" {
  api_id    = aws_apigatewayv2_api.dynatrace_webhook.id
  route_key = "POST /webhook"
  target    = "integrations/${aws_apigatewayv2_integration.dynatrace_webhook_integration.id}"
}

resource "aws_apigatewayv2_stage" "dynatrace_webhook_stage" {
  api_id      = aws_apigatewayv2_api.dynatrace_webhook.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "dynatrace_webhook_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.devops_agent_trigger.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.dynatrace_webhook.execution_arn}/*/*"
}

# AWS DevOps Agent
resource "aws_devops_agent" "main" {
  name        = "${var.project_name}-agent"
  description = "DevOps agent for todo app monitoring and auto-remediation"
  
  role_arn = aws_iam_role.devops_agent_role.arn

  source_control {
    type  = "GITHUB"
    owner = var.github_repo_owner
    repo  = var.github_repo_name
    token = var.github_token
  }

  capabilities {
    log_analysis        = true
    trace_analysis      = true
    metric_analysis     = true
    code_fix_generation = true
    issue_creation      = true
    pr_creation         = true
  }

  monitoring_sources {
    cloudwatch_logs = [
      "/aws/lambda/${var.project_name}-api"
    ]
    
    xray_traces = true
    
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
      }
    ]
  }

  tags = {
    Name = "${var.project_name}-devops-agent"
  }
}

# Outputs
output "devops_agent_arn" {
  description = "DevOps Agent ARN"
  value       = aws_devops_agent.main.arn
}

output "dynatrace_webhook_url" {
  description = "Dynatrace webhook URL"
  value       = "${aws_apigatewayv2_api.dynatrace_webhook.api_endpoint}/webhook"
}
