output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.api.api_endpoint
}

output "s3_website_url" {
  description = "S3 website URL"
  value       = aws_s3_bucket_website_configuration.frontend.website_endpoint
}

output "dynamodb_table" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.todos.name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.todo_app.dashboard_name}"
}

output "xray_traces_url" {
  description = "X-Ray Traces URL"
  value       = "https://console.aws.amazon.com/xray/home?region=${var.aws_region}#/traces"
}
