provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  env  = "prod"
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
  vpc_cidr     = "10.30.0.0/16"
  azs          = ["us-east-1a", "us-east-1b", "us-east-1c"]

  private_subnet_cidrs = ["10.30.0.0/19", "10.30.32.0/19", "10.30.64.0/19"]
  public_subnet_cidrs  = ["10.30.96.0/24", "10.30.97.0/24", "10.30.98.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = false

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
      instance_types = ["m6i.4xlarge"]
      capacity_type  = "ON_DEMAND"
      min_size       = 3
      max_size       = 9
      desired_size   = 3
      labels         = { role = "monitoring" }
    }
    monitoring-spot = {
      instance_types = ["m6i.4xlarge", "m5.4xlarge", "m5a.4xlarge"]
      capacity_type  = "SPOT"
      min_size       = 0
      max_size       = 6
      desired_size   = 0
      labels         = { role = "monitoring-spot" }
      taints = [{
        key    = "monitoring-spot"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    }
  }

  endpoint_private_access = true
  endpoint_public_access  = false
  tags                    = local.common_tags
}

module "amp" {
  source = "../../modules/amp"

  workspace_alias = "${local.name}-metrics"
  tags            = local.common_tags
}

resource "aws_s3_bucket" "loki" {
  bucket = "${local.name}-loki-chunks-${var.aws_account_id}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "loki" {
  bucket = aws_s3_bucket.loki.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" }
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
    expiration { days = 90 }
  }
}

module "iam" {
  source = "../../modules/iam"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.oidc_issuer_url
  aws_account_id    = var.aws_account_id
  aws_region        = var.aws_region
  amp_workspace_arn = module.amp.workspace_arn
  loki_bucket_arn   = aws_s3_bucket.loki.arn

  tags = local.common_tags
}

module "grafana" {
  source = "../../modules/grafana"

  workspace_name   = "${local.name}-grafana"
  amp_workspace_id = module.amp.workspace_id
  tags             = local.common_tags
}
