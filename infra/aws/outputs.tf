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
  description = "Colar este valor no Secret AWS_ROLE_ARN do repositório no GitHub, o workflow de CI/CD assume essa role via OIDC"
  value       = module.github_actions_role.arn
}

output "irsa_role_arn" {
  description = "Colar este valor no Secret IRSA_ROLE_ARN do repositório no GitHub, usado pelo pipeline para anotar a service account do pod da API"
  value       = module.irsa_autoshop_api.iam_role_arn
}

output "eks_node_security_group_id" {
  description = "Colar na variável eks_node_security_group_id do repositório infra-db — libera o RDS pra aceitar conexões vindas dos nodes do EKS"
  value       = module.eks.node_security_group_id
}
