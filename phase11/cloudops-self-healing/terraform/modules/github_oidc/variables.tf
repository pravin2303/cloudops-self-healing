variable "project_name" {
  description = "Short project identifier used in resource names and tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "github_org" {
  description = "GitHub organization or username that owns the repository."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without the org prefix)."
  type        = string
}

variable "allowed_ref" {
  description = <<-EOT
    Restricts which git ref may assume this role, in the form
    "ref:refs/heads/<branch>". Only workflows running on this exact
    branch of this exact repository can obtain credentials.
  EOT
  type        = string
  default     = "ref:refs/heads/main"
}

variable "ecr_repository_arn" {
  description = "ECR repository ARN (from the ecr module) — scopes what this role can push to."
  type        = string
}

variable "create_oidc_provider" {
  description = <<-EOT
    AWS allows only ONE GitHub Actions OIDC provider per account. Set
    this to false (and the data source below will look up the existing
    one) if your account already has one registered from a prior
    project — trying to create a second will fail with
    EntityAlreadyExists.
  EOT
  type    = bool
  default = true
}

variable "tags" {
  description = "Additional tags applied to all resources in this module."
  type        = map(string)
  default     = {}
}
