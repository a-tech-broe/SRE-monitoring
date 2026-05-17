data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_grafana_workspace" "this" {
  name                     = var.workspace_name
  account_access_type      = var.account_access_type
  authentication_providers = var.authentication_providers
  permission_type          = var.permission_type
  data_sources             = var.data_sources

  tags = var.tags
}

resource "aws_grafana_workspace_api_key" "admin" {
  key_name        = "terraform-provisioner"
  key_role        = "ADMIN"
  seconds_to_live = 3600
  workspace_id    = aws_grafana_workspace.this.id
}
