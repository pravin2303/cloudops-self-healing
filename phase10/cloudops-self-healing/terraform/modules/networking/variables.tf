variable "project_name" {
  description = "Short project identifier used in resource names and tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment name (e.g. dev, staging, prod)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Map of Availability Zone -> CIDR block for public subnets."
  type        = map(string)
}

variable "private_subnet_cidrs" {
  description = "Map of Availability Zone -> CIDR block for private subnets."
  type        = map(string)
}

variable "single_nat_gateway" {
  description = <<-EOT
    If true, provisions one NAT Gateway shared by all private subnets
    (lower cost, single point of failure for outbound traffic).
    If false, provisions one NAT Gateway per AZ (higher availability,
    roughly double the NAT cost).
  EOT
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags applied to all resources in this module."
  type        = map(string)
  default     = {}
}
