variable "project_name" {
  description = "Short project identifier used in resource names and tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "aws_region" {
  description = "AWS region (needed inside user-data for ECR login)."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "ec2_security_group_id" {
  description = "Security group ID for application instances (from the security module)."
  type        = string
}

variable "ecr_repository_url" {
  description = "Full ECR repository URL (from the ecr module) — used to pull the image."
  type        = string
}

variable "ecr_repository_arn" {
  description = "ECR repository ARN (from the ecr module) — used to scope the IAM pull policy."
  type        = string
}

variable "image_tag" {
  description = "Immutable image tag to pull and run (e.g. a git SHA or version tag). Never \"latest\"."
  type        = string
}

variable "app_port" {
  description = "TCP port the application listens on."
  type        = number
  default     = 5000
}

variable "root_volume_size_gb" {
  description = "Size of the encrypted root EBS volume, in GB."
  type        = number
  default     = 8
}

variable "log_group_name" {
  description = "CloudWatch Logs group name the application container ships logs to."
  type        = string
}

variable "tags" {
  description = "Additional tags applied to all resources in this module."
  type        = map(string)
  default     = {}
}
