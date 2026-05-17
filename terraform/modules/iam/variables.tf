variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for the cluster"
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL without https:// prefix"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "amp_workspace_arn" {
  description = "ARN of the Amazon Managed Prometheus workspace"
  type        = string
}

variable "loki_bucket_arn" {
  description = "ARN of the S3 bucket used by Loki for chunk storage"
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
