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

variable "admin_users" {
  description = "Users to create in IAM Identity Center and assign Admin role in Grafana"
  type = list(object({
    username     = string
    display_name = string
    given_name   = string
    family_name  = string
    email        = string
  }))
  default = []
}

variable "editor_users" {
  description = "Users to create in IAM Identity Center and assign Editor role in Grafana"
  type = list(object({
    username     = string
    display_name = string
    given_name   = string
    family_name  = string
    email        = string
  }))
  default = []
}

variable "admin_group_ids" {
  description = "Existing IAM Identity Center group IDs to assign the Admin role in Grafana"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {dev-environment = "true"}
}
