data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_ssoadmin_instances" "this" {}

locals {
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}

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

# ── IAM Identity Center user provisioning ─────────────────────────────────────

resource "aws_identitystore_user" "admins" {
  for_each          = { for u in var.admin_users : u.username => u }
  identity_store_id = local.identity_store_id

  display_name = each.value.display_name
  user_name    = each.value.username

  name {
    given_name  = each.value.given_name
    family_name = each.value.family_name
  }

  emails {
    value   = each.value.email
    type    = "work"
    primary = true
  }
}

resource "aws_identitystore_user" "editors" {
  for_each          = { for u in var.editor_users : u.username => u }
  identity_store_id = local.identity_store_id

  display_name = each.value.display_name
  user_name    = each.value.username

  name {
    given_name  = each.value.given_name
    family_name = each.value.family_name
  }

  emails {
    value   = each.value.email
    type    = "work"
    primary = true
  }
}

# ── Workspace role assignments ─────────────────────────────────────────────────

locals {
  all_admin_user_ids  = [for u in aws_identitystore_user.admins : u.user_id]
  all_editor_user_ids = [for u in aws_identitystore_user.editors : u.user_id]
}

resource "aws_grafana_role_association" "admins_users" {
  count        = length(local.all_admin_user_ids) > 0 ? 1 : 0
  role         = "ADMIN"
  user_ids     = local.all_admin_user_ids
  workspace_id = aws_grafana_workspace.this.id
}

resource "aws_grafana_role_association" "admins_groups" {
  count        = length(var.admin_group_ids) > 0 ? 1 : 0
  role         = "ADMIN"
  group_ids    = var.admin_group_ids
  workspace_id = aws_grafana_workspace.this.id
}

resource "aws_grafana_role_association" "editors_users" {
  count        = length(local.all_editor_user_ids) > 0 ? 1 : 0
  role         = "EDITOR"
  user_ids     = local.all_editor_user_ids
  workspace_id = aws_grafana_workspace.this.id
}
