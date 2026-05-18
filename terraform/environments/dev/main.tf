provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  env  = "dev"
  name = "observability-${local.env}"

  common_tags = {
    Environment = local.env
    Project     = "observability-platform"
    ManagedBy   = "terraform"
    Repo        = "SRE-monitoring"
  }
}

module "networking" {
  source = "../../modules/networking"

  name         = local.name
  cluster_name = local.name
  vpc_cidr     = "10.10.0.0/16"
  azs          = ["us-east-1a", "us-east-1b", "us-east-1c"]

  private_subnet_cidrs = ["10.10.0.0/19", "10.10.32.0/19", "10.10.64.0/19"]
  public_subnet_cidrs  = ["10.10.96.0/24", "10.10.97.0/24", "10.10.98.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true  # cost-saving for dev

  tags = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name    = local.name
  cluster_version = "1.30"
  vpc_id          = module.networking.vpc_id
  subnet_ids      = module.networking.private_subnet_ids
  control_plane_subnet_ids = module.networking.private_subnet_ids

  node_groups = {
    monitoring = {
      instance_types = ["m6i.xlarge"]
      capacity_type  = "ON_DEMAND"
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      labels = {
        role = "monitoring"
      }
    }
  }

  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = ["0.0.0.0/0"] # dev testing only — revert before prod

  # aws-ebs-csi-driver is managed as a standalone resource below so its
  # IRSA role ARN can be wired in without creating a module cycle.
  cluster_addons = {
    coredns    = ""
    kube-proxy = ""
    vpc-cni    = ""
  }

  tags = local.common_tags
}

module "amp" {
  source = "../../modules/amp"

  workspace_alias = "${local.name}-metrics"
  tags            = local.common_tags
}

resource "aws_s3_bucket" "loki" {
  bucket        = "${local.name}-loki-chunks-${var.aws_account_id}"
  force_destroy = true
  tags          = local.common_tags
}

resource "aws_s3_bucket_versioning" "loki" {
  bucket = aws_s3_bucket.loki.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "loki" {
  bucket                  = aws_s3_bucket.loki.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id

  rule {
    id     = "expire-old-chunks"
    status = "Enabled"
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
    expiration { days = 30 }
  }
}

module "iam" {
  source = "../../modules/iam"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.oidc_issuer_url
  amp_workspace_arn = module.amp.workspace_arn
  loki_bucket_arn   = aws_s3_bucket.loki.arn

  tags = local.common_tags
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = module.iam.ebs_csi_role_arn
  resolve_conflicts_on_update = "OVERWRITE"
  tags                     = local.common_tags
}

module "grafana" {
  source = "../../modules/grafana"

  workspace_name   = "${local.name}-grafana-ws"
  amp_workspace_id = module.amp.workspace_id

  admin_users = [
    {
      username     = "parah"
      display_name = "Jen Rill"
      given_name   = "Jen"
      family_name  = "Rill"
      email        = "jen4rill@live.com"
    }
  ]

  tags = local.common_tags
}
