output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "amp_remote_write_url" {
  value = module.amp.remote_write_url
}

output "amp_query_url" {
  value = module.amp.query_url
}

output "grafana_endpoint" {
  value = module.grafana.workspace_endpoint
}

output "loki_bucket" {
  value = aws_s3_bucket.loki.bucket
}

output "prometheus_irsa_arn" {
  value = module.iam.prometheus_role_arn
}

output "grafana_irsa_arn" {
  value = module.iam.grafana_role_arn
}

output "loki_irsa_arn" {
  value = module.iam.loki_role_arn
}

output "alb_controller_irsa_arn" {
  value = module.iam.alb_controller_role_arn
}
