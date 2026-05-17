terraform {
  backend "s3" {
    bucket         = "your-org-terraform-state-dev"
    key            = "observability-platform/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "your-org-terraform-locks"
  }
}
