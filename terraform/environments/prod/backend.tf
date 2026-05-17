terraform {
  backend "s3" {
    bucket         = "bathbucket31"
    key            = "observability-platform/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "dyning_table"
  }
}
