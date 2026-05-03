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
