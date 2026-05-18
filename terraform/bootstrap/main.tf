# GitHub Actions OIDC provider thumbprint
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = {
    Name      = "github-actions-oidc"
    ManagedBy = "terraform"
    Repo      = "${var.github_org}/${var.github_repo}"
  }
}

locals {
  environments = ["dev", "prod"]

  # Allows any ref (branch or PR) in the repo to assume the role.
  # Workflow logic restricts apply to main; plan runs on PRs.
  github_sub = "repo:${var.github_org}/${var.github_repo}:*"
}

data "aws_iam_policy_document" "github_actions_assume" {
  for_each = toset(local.environments)

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.github_sub]
    }
  }
}

resource "aws_iam_role" "ci" {
  for_each = toset(local.environments)

  name               = "observability-${each.key}-ci"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume[each.key].json

  tags = {
    Environment = each.key
    ManagedBy   = "terraform"
    Repo        = "${var.github_org}/${var.github_repo}"
  }
}

data "aws_iam_policy_document" "ci_permissions" {
  statement {
    sid    = "EC2"
    effect = "Allow"
    actions = [
      "ec2:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "EKS"
    effect  = "Allow"
    actions = ["eks:*"]
    resources = ["*"]
  }

  statement {
    sid    = "IAM"
    effect = "Allow"
    actions = [
      "iam:*Role*",
      "iam:*Policy*",
      "iam:*InstanceProfile*",
      "iam:*OpenIDConnectProvider*",
      "iam:GetUser",
      "iam:ListUsers",
      "iam:PassRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:TagPolicy",
      "iam:UntagPolicy",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "S3BucketManagement"
    effect = "Allow"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:DeleteBucketWebsite",
      "s3:GetAccelerateConfiguration",
      "s3:GetBucketAcl",
      "s3:GetBucketCORS",
      "s3:GetBucketLocation",
      "s3:GetBucketLogging",
      "s3:GetBucketNotification",
      "s3:GetBucketObjectLockConfiguration",
      "s3:GetBucketOwnershipControls",
      "s3:GetBucketPolicy",
      "s3:GetBucketPolicyStatus",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketRequestPayment",
      "s3:GetBucketTagging",
      "s3:GetBucketVersioning",
      "s3:GetBucketWebsite",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:ListAllMyBuckets",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:ListBucketVersions",
      "s3:PutBucketAcl",
      "s3:PutBucketCORS",
      "s3:PutBucketLogging",
      "s3:PutBucketNotification",
      "s3:PutBucketObjectLockConfiguration",
      "s3:PutBucketOwnershipControls",
      "s3:PutBucketPolicy",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketRequestPayment",
      "s3:PutBucketTagging",
      "s3:PutBucketVersioning",
      "s3:PutBucketWebsite",
      "s3:PutEncryptionConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:PutReplicationConfiguration",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "S3ObjectAccess"
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListMultipartUploadParts",
      "s3:PutObject",
    ]
    # Scoped to Terraform state bucket and Loki chunk buckets only.
    # Prevents this role from reading arbitrary S3 data in the account.
    resources = [
      "arn:aws:s3:::bathbucket31",
      "arn:aws:s3:::bathbucket31/*",
      "arn:aws:s3:::observability-*",
      "arn:aws:s3:::observability-*/*",
    ]
  }

  statement {
    sid     = "DynamoDB"
    effect  = "Allow"
    actions = ["dynamodb:*"]
    resources = ["*"]
  }

  statement {
    sid     = "KMS"
    effect  = "Allow"
    actions = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatch"
    effect = "Allow"
    actions = [
      "logs:*",
      "cloudwatch:*",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "AMP"
    effect  = "Allow"
    actions = ["aps:*"]
    resources = ["*"]
  }

  statement {
    sid     = "Grafana"
    effect  = "Allow"
    actions = ["grafana:*"]
    resources = ["*"]
  }

  statement {
    sid    = "SSO"
    effect = "Allow"
    actions = [
      "sso:*",
      "sso-admin:*",
      "identitystore:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "STS"
    effect = "Allow"
    actions = [
      "sts:GetCallerIdentity",
      "sts:AssumeRole",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ci" {
  for_each = toset(local.environments)

  name   = "observability-ci-permissions"
  role   = aws_iam_role.ci[each.key].name
  policy = data.aws_iam_policy_document.ci_permissions.json
}
