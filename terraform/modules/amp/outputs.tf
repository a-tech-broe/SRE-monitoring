output "workspace_id" {
  description = "AMP workspace ID"
  value       = aws_prometheus_workspace.this.id
}

output "workspace_arn" {
  description = "AMP workspace ARN"
  value       = aws_prometheus_workspace.this.arn
}

output "remote_write_url" {
  description = "Remote write endpoint for Prometheus"
  value       = "${aws_prometheus_workspace.this.prometheus_endpoint}api/v1/remote_write"
}

output "query_url" {
  description = "Query endpoint for Grafana"
  value       = aws_prometheus_workspace.this.prometheus_endpoint
}
