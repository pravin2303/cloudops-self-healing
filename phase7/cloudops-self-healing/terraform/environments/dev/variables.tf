variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short project identifier used in resource names and tags."
  type        = string
  default     = "cloudops"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Map of AZ -> CIDR block for public subnets."
  type        = map(string)
  default = {
    "us-east-1a" = "10.0.0.0/24"
    "us-east-1b" = "10.0.1.0/24"
  }
}

variable "private_subnet_cidrs" {
  description = "Map of AZ -> CIDR block for private subnets."
  type        = map(string)
  default = {
    "us-east-1a" = "10.0.10.0/24"
    "us-east-1b" = "10.0.11.0/24"
  }
}

variable "single_nat_gateway" {
  description = "Use one shared NAT Gateway instead of one per AZ (cost saving for dev)."
  type        = bool
  default     = true
}

variable "app_port" {
  description = "TCP port the application listens on."
  type        = number
  default     = 5000
}

variable "health_check_path" {
  description = "Path the ALB health check requests."
  type        = string
  default     = "/health"
}

variable "instance_type" {
  description = "EC2 instance type for application instances."
  type        = string
  default     = "t3.micro"
}

variable "app_image_tag" {
  description = "Immutable ECR image tag to deploy. Must already exist in ECR (see Phase 5)."
  type        = string
  default     = "phase5"
}
