output "prometheus_role_arn" {
  description = "IRSA role ARN for Prometheus"
  value       = aws_iam_role.prometheus.arn
}

output "grafana_role_arn" {
  description = "IRSA role ARN for Grafana"
  value       = aws_iam_role.grafana.arn
}

output "loki_role_arn" {
  description = "IRSA role ARN for Loki"
  value       = aws_iam_role.loki.arn
}

output "alb_controller_role_arn" {
  description = "IRSA role ARN for the AWS Load Balancer Controller"
  value       = aws_iam_role.alb_controller.arn
}

output "ebs_csi_role_arn" {
  description = "IRSA role ARN for the EBS CSI driver"
  value       = aws_iam_role.ebs_csi.arn
}

