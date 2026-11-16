output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Comando para apontar o kubectl local para este cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "github_actions_role_arn" {
  description = "Secret AWS_ROLE_ARN dos repositórios que fazem deploy: o pipeline assume essa role via OIDC"
  value       = module.github_actions_role.arn
}

output "irsa_role_arns" {
  description = "Secret IRSA_ROLE_ARN de cada repositório de serviço (anota a service account do pod)"
  value       = { for svc, m in module.irsa : svc => m.iam_role_arn }
}

output "queue_urls" {
  description = "Filas da Saga"
  value       = { for q, r in aws_sqs_queue.this : q => r.url }
}

output "eks_node_security_group_id" {
  description = "Variável eks_node_security_group_id das stacks os/ e billing/ do infra-db-autoshop: libera os bancos RDS para os nodes do EKS"
  value       = module.eks.node_security_group_id
}
