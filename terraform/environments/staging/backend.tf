terraform {
  backend "s3" {
    bucket         = "your-org-terraform-state-staging"
    key            = "observability-platform/staging/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "your-org-terraform-locks"
  }
}
