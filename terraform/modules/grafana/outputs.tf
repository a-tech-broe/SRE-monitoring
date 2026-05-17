output "workspace_id" {
  description = "Amazon Managed Grafana workspace ID"
  value       = aws_grafana_workspace.this.id
}

output "workspace_endpoint" {
  description = "Grafana workspace URL"
  value       = "https://${aws_grafana_workspace.this.endpoint}"
}

output "workspace_arn" {
  description = "Grafana workspace ARN"
  value       = aws_grafana_workspace.this.arn
}
