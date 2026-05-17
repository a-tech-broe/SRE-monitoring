terraform {
  backend "s3" {
    bucket         = "your-org-terraform-state-prod"
    key            = "observability-platform/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "your-org-terraform-locks"
  }
}
