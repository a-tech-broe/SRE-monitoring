locals {
  oidc_sub = "${var.oidc_issuer_url}:sub"
  oidc_aud = "${var.oidc_issuer_url}:aud"
}

# ── Helper: IRSA assume-role policy factory ───────────────────────────────────

data "aws_iam_policy_document" "irsa_assume" {
  for_each = {
    prometheus     = "system:serviceaccount:monitoring:prometheus-sa"
    grafana        = "system:serviceaccount:monitoring:grafana-sa"
    loki           = "system:serviceaccount:monitoring:loki-sa"
    alb_controller = "system:serviceaccount:kube-system:aws-load-balancer-controller"
    ebs_csi        = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
  }

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = local.oidc_sub
      values   = [each.value]
    }

    condition {
      test     = "StringEquals"
      variable = local.oidc_aud
      values   = ["sts.amazonaws.com"]
    }
  }
}

# ── Prometheus IRSA (remote-write to AMP) ────────────────────────────────────

resource "aws_iam_role" "prometheus" {
  name               = "${var.cluster_name}-prometheus"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume["prometheus"].json
  tags               = var.tags
}

data "aws_iam_policy_document" "prometheus" {
  statement {
    sid     = "AMPRemoteWrite"
    actions = ["aps:RemoteWrite", "aps:GetSeries", "aps:GetLabels", "aps:GetMetricMetadata"]
    resources = [var.amp_workspace_arn]
  }
}

resource "aws_iam_role_policy" "prometheus" {
  name   = "amp-remote-write"
  role   = aws_iam_role.prometheus.id
  policy = data.aws_iam_policy_document.prometheus.json
}

# ── Grafana IRSA (query AMP + CloudWatch) ────────────────────────────────────

resource "aws_iam_role" "grafana" {
  name               = "${var.cluster_name}-grafana"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume["grafana"].json
  tags               = var.tags
}

data "aws_iam_policy_document" "grafana" {
  statement {
    sid     = "AMPQuery"
    actions = [
      "aps:QueryMetrics",
      "aps:GetSeries",
      "aps:GetLabels",
      "aps:GetMetricMetadata",
    ]
    resources = [var.amp_workspace_arn]
  }

  statement {
    sid     = "CloudWatchRead"
    actions = [
      "cloudwatch:GetMetricData",
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:DescribeAlarmsForMetric",
      "cloudwatch:DescribeAlarmHistory",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:ListTagsForResource",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "grafana" {
  name   = "grafana-datasources"
  role   = aws_iam_role.grafana.id
  policy = data.aws_iam_policy_document.grafana.json
}

# ── Loki IRSA (S3 chunk + ruler storage) ─────────────────────────────────────

resource "aws_iam_role" "loki" {
  name               = "${var.cluster_name}-loki"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume["loki"].json
  tags               = var.tags
}

data "aws_iam_policy_document" "loki" {
  statement {
    sid     = "LokiS3"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [var.loki_bucket_arn, "${var.loki_bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "loki" {
  name   = "loki-s3"
  role   = aws_iam_role.loki.id
  policy = data.aws_iam_policy_document.loki.json
}

# ── ALB Controller IRSA ───────────────────────────────────────────────────────

resource "aws_iam_role" "alb_controller" {
  name               = "${var.cluster_name}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume["alb_controller"].json
  tags               = var.tags
}

data "http" "alb_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "alb_controller" {
  name   = "${var.cluster_name}-alb-controller"
  policy = data.http.alb_policy.response_body
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

# ── EBS CSI Driver IRSA ───────────────────────────────────────────────────────

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.cluster_name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume["ebs_csi"].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
