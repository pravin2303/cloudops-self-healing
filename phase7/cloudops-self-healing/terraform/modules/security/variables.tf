variable "project_name" {
  description = "Short project identifier used in resource names and tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID these security groups belong to (from the networking module)."
  type        = string
}

variable "app_port" {
  description = "TCP port the application listens on inside the container/EC2 instance."
  type        = number
  default     = 5000
}

variable "tags" {
  description = "Additional tags applied to all resources in this module."
  type        = map(string)
  default     = {}
}
