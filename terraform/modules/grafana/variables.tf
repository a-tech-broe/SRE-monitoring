variable "workspace_name" {
  description = "Name of the Amazon Managed Grafana workspace"
  type        = string
}

variable "account_access_type" {
  description = "CURRENT_ACCOUNT or ORGANIZATION"
  type        = string
  default     = "CURRENT_ACCOUNT"
}

variable "authentication_providers" {
  description = "Auth providers: AWS_SSO and/or SAML"
  type        = list(string)
  default     = ["AWS_SSO"]
}

variable "permission_type" {
  description = "SERVICE_MANAGED or CUSTOMER_MANAGED"
  type        = string
  default     = "SERVICE_MANAGED"
}

variable "data_sources" {
  description = "List of data source types to enable"
  type        = list(string)
  default     = ["PROMETHEUS", "CLOUDWATCH", "XRAY"]
}

variable "amp_workspace_id" {
  description = "AMP workspace ID to wire as the default Prometheus data source"
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
