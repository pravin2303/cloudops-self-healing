variable "project_name" {
  description = "Short project identifier used in resource names and tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "image_tag_mutability" {
  description = <<-EOT
    IMMUTABLE prevents a tag from ever being overwritten once pushed —
    forces every deployment to use a genuinely unique tag (e.g. a git
    SHA), which is what makes it possible to know exactly which build
    is running at any time. MUTABLE allows tag reuse (e.g. repeatedly
    pushing "latest"), which is easier for quick experiments but loses
    that guarantee.
  EOT
  type        = string
  default     = "IMMUTABLE"
}

variable "untagged_image_expiry_days" {
  description = "Days after which untagged (dangling) images are expired."
  type        = number
  default     = 7
}

variable "max_tagged_images" {
  description = "Maximum number of tagged images to retain before the oldest are expired."
  type        = number
  default     = 10
}

variable "tags" {
  description = "Additional tags applied to all resources in this module."
  type        = map(string)
  default     = {}
}
