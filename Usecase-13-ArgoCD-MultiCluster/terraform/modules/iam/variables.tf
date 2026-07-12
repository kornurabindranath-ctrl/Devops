variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}
variable "oidc_provider_arn" {
  type = string
}

variable "oidc_issuer_url" {
  type = string
}
