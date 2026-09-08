variable "project_name" {
  description = "Short project identifier used in resource names and tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "aws_region" {
  description = "AWS region (used in dashboard widget config)."
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch Logs group name for application logs."
  type        = string
}

variable "log_retention_days" {
  description = "How many days to retain application logs."
  type        = number
  default     = 14
}

variable "alb_arn_suffix" {
  description = "ALB arn_suffix (from the alb module) — used as a CloudWatch metric dimension."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group arn_suffix (from the alb module) — used as a CloudWatch metric dimension."
  type        = string
}

variable "asg_name" {
  description = "Auto Scaling Group name (from the autoscaling module)."
  type        = string
}

variable "alert_email" {
  description = "Email address to subscribe to alarm notifications. Leave empty to skip email subscription."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags applied to all resources in this module."
  type        = map(string)
  default     = {}
}
