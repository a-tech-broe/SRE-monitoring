data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── Workspace execution role ──────────────────────────────────────────────────
# Required when account_access_type = "CURRENT_ACCOUNT"

data "aws_iam_policy_document" "grafana_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["grafana.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "workspace" {
  name               = "${var.workspace_name}-workspace-role"
  assume_role_policy = data.aws_iam_policy_document.grafana_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "grafana_cloudwatch" {
  role       = aws_iam_role.workspace.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonGrafanaCloudWatchAccess"
}

data "aws_iam_policy_document" "grafana_amp" {
  statement {
    sid = "AMPQueryAccess"
    actions = [
      "aps:QueryMetrics",
      "aps:GetSeries",
      "aps:GetLabels",
      "aps:GetMetricMetadata",
      "aps:ListWorkspaces",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "grafana_amp" {
  name   = "amp-query"
  role   = aws_iam_role.workspace.id
  policy = data.aws_iam_policy_document.grafana_amp.json
}

# ── Workspace ─────────────────────────────────────────────────────────────────

resource "aws_grafana_workspace" "this" {
  name                     = var.workspace_name
  account_access_type      = var.account_access_type
  authentication_providers = var.authentication_providers
  permission_type          = var.permission_type
  data_sources             = var.data_sources
  role_arn                 = aws_iam_role.workspace.arn

  tags = var.tags
}

resource "aws_grafana_workspace_api_key" "admin" {
  key_name        = "terraform-provisioner"
  key_role        = "ADMIN"
  seconds_to_live = 3600
  workspace_id    = aws_grafana_workspace.this.id
}
