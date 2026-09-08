variable "project_name" {
  description = "Short project identifier used in resource names and tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (from the networking module)."
  type        = string
}

variable "public_subnet_ids" {
  description = "Map of AZ -> public subnet ID (from the networking module). The ALB spans all of these."
  type        = map(string)
}

variable "alb_security_group_id" {
  description = "Security group ID for the ALB (from the security module)."
  type        = string
}

variable "app_port" {
  description = "TCP port the application listens on (target group forwards here)."
  type        = number
  default     = 5000
}

variable "health_check_path" {
  description = "Path the ALB health check requests."
  type        = string
  default     = "/health"
}

variable "health_check_interval" {
  description = "Seconds between health checks."
  type        = number
  default     = 15
}

variable "health_check_timeout" {
  description = "Seconds to wait for a health check response before considering it failed."
  type        = number
  default     = 5
}

variable "healthy_threshold" {
  description = "Consecutive successful checks before a target is considered healthy."
  type        = number
  default     = 2
}

variable "unhealthy_threshold" {
  description = "Consecutive failed checks before a target is considered unhealthy."
  type        = number
  default     = 2
}

variable "deregistration_delay" {
  description = "Seconds the ALB waits for in-flight requests to finish before fully deregistering a target. Lowered from the AWS default (300s) to keep failure-simulation demos fast."
  type        = number
  default     = 30
}

variable "enable_https" {
  description = "Whether to create an HTTPS listener. Requires acm_certificate_arn to be set. Off by default (no domain/cert provisioned in this project by default)."
  type        = bool
  default     = false
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for the HTTPS listener. Required only if enable_https = true."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags applied to all resources in this module."
  type        = map(string)
  default     = {}
}
