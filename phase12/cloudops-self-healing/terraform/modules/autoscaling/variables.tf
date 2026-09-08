variable "project_name" {
  description = "Short project identifier used in resource names and tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "launch_template_id" {
  description = "Launch Template ID (from the compute module)."
  type        = string
}

variable "private_subnet_ids" {
  description = "Map of AZ -> private subnet ID (from the networking module). Instances launch here."
  type        = map(string)
}

variable "target_group_arn" {
  description = "Target Group ARN (from the alb module). Instances register here."
  type        = string
}

variable "min_size" {
  description = "Minimum number of instances."
  type        = number
  default     = 2
}

variable "desired_capacity" {
  description = "Desired number of instances under normal conditions."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances under scale-out."
  type        = number
  default     = 4
}

variable "health_check_grace_period" {
  description = <<-EOT
    Seconds after instance launch before the ASG starts acting on ELB
    health check failures. Must be long enough for the bootstrap
    script (Docker install + ECR pull + container start) to finish.
  EOT
  type        = number
  default     = 90
}

variable "cpu_target_value" {
  description = "Target average CPU utilization (%) the scaling policy tries to maintain."
  type        = number
  default     = 60
}

variable "tags" {
  description = "Additional tags applied to all resources in this module and propagated to launched instances."
  type        = map(string)
  default     = {}
}
