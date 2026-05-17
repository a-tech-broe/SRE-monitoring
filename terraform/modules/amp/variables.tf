variable "workspace_alias" {
  description = "Human-readable alias for the AMP workspace"
  type        = string
}

variable "alert_manager_config" {
  description = "Alert manager definition YAML for AMP"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
