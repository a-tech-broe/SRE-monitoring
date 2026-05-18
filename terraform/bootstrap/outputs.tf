output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "ci_role_arns" {
  description = "ARN of each CI role — add these to GitHub Secrets as AWS_ROLE_DEV / AWS_ROLE_STAGING / AWS_ROLE_PROD"
  value       = { for env, role in aws_iam_role.ci : env => role.arn }
}
