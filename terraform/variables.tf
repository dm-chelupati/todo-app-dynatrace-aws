variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "todo-app"
}

variable "dynatrace_url" {
  description = "Dynatrace environment URL"
  type        = string
}

variable "dynatrace_token" {
  description = "Dynatrace API token"
  type        = string
  sensitive   = true
}

variable "alert_email" {
  description = "Email for CloudWatch alerts"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token for DevOps Agent"
  type        = string
  sensitive   = true
}
