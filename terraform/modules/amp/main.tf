resource "aws_prometheus_workspace" "this" {
  alias = var.workspace_alias
  tags  = var.tags
}

resource "aws_prometheus_alert_manager_definition" "this" {
  count        = var.alert_manager_config != "" ? 1 : 0
  workspace_id = aws_prometheus_workspace.this.id
  definition   = var.alert_manager_config
}
