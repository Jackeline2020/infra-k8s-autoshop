output "kubeconfig_path" {
  description = "Kubeconfig do cluster efêmero, usado pelos passos seguintes do workflow (kubectl wait, rollout status)"
  value       = kind_cluster.ci.kubeconfig_path
}
