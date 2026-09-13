output "cluster_name" {
  description = "Nome do cluster kind criado"
  value       = kind_cluster.autoshop.name
}

output "kubeconfig_path" {
  description = "Caminho do kubeconfig gerado pelo Terraform para este cluster"
  value       = kind_cluster.autoshop.kubeconfig_path
}

output "next_steps" {
  description = "O que fazer depois do terraform apply"
  value       = <<-EOT
    O Terraform já cria o cluster E aplica todos os manifestos (namespace,
    banco, config, aplicação, metrics-server) — não precisa mais rodar
    "kubectl apply" manualmente. O único passo manual é carregar a imagem
    da API no cluster, porque o kind não compartilha o cache de imagens
    com o seu Docker host:

    1) Se ainda não tinha cluster (primeiro apply), rode só a criação do
       cluster antes de mais nada, sem o resto (evita o pod da API ficar
       em ImagePullBackOff antes da imagem existir):
         terraform apply -target="kind_cluster.autoshop"

    2) Buildar e carregar a imagem da API dentro do cluster (precisa do CLI
       "kind" instalado — winget install Kubernetes.kind — além do provider
       do Terraform):
         docker build -t autoshop-api:latest ../..
         kind load docker-image autoshop-api:latest --name ${kind_cluster.autoshop.name}

    3) Aplicar o resto (banco, config, aplicação, metrics-server). Primeira
       vez pode demorar mais — é um cluster novo, as imagens públicas ainda
       não foram baixadas nele:
         terraform apply

    4) Testar:
         curl http://localhost:30080/health

    Se você já tinha rodado um apply completo antes de carregar a imagem, o
    pod pode ter ficado preso em ImagePullBackOff — rode
    "kubectl rollout restart deployment/autoshop-api -n autoshop --kubeconfig ${kind_cluster.autoshop.kubeconfig_path}"
    depois do passo 2.
  EOT
}
