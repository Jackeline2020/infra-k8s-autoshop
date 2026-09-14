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
    "kubectl apply" manualmente. Desde a reorganização pedida pelo professor,
    os manifestos da aplicação (Deployment, Service, HPA, ConfigMap, Secret,
    ServiceAccount) moraram para o repositório app-autoshop — por isso,
    antes do apply, exporte também o conteúdo deles (além do
    TF_VAR_migration_sql de sempre), lendo do app-autoshop como pasta irmã:

      export TF_VAR_migration_sql="$(cat ../../../app-autoshop/migrations/000001_init_schema.up.sql)"
      export TF_VAR_migration_sql_2="$(cat ../../../app-autoshop/migrations/000002_add_customer_status.up.sql)"
      export TF_VAR_deployment_yaml="$(cat ../../../app-autoshop/k8s/base/deployment.yaml)"
      export TF_VAR_service_yaml="$(cat ../../../app-autoshop/k8s/base/service.yaml)"
      export TF_VAR_hpa_yaml="$(cat ../../../app-autoshop/k8s/base/hpa.yaml)"
      export TF_VAR_configmap_yaml="$(cat ../../../app-autoshop/k8s/overlays/local/configmap.yaml)"
      export TF_VAR_secret_yaml="$(cat ../../../app-autoshop/k8s/overlays/local/secret.yaml)"
      export TF_VAR_serviceaccount_yaml="$(cat ../../../app-autoshop/k8s/overlays/local/serviceaccount.yaml)"

    Isso precisa ser feito na mesma sessão do terminal (Git Bash) onde você
    vai rodar o apply — as variáveis não ficam salvas entre sessões.

    O único passo manual que continua sendo necessário é carregar a imagem
    da API no cluster, porque o kind não compartilha o cache de imagens
    com o seu Docker host:

    1) Se ainda não tinha cluster (primeiro apply), rode só a criação do
       cluster antes de mais nada, sem o resto (evita o pod da API ficar
       em ImagePullBackOff antes da imagem existir):
         terraform apply -target="kind_cluster.autoshop"

    2) Buildar e carregar a imagem da API dentro do cluster (precisa do CLI
       "kind" instalado — winget install Kubernetes.kind — além do provider
       do Terraform). O build agora é feito a partir do app-autoshop:
         docker build -t autoshop-api:latest ../../../app-autoshop
         kind load docker-image autoshop-api:latest --name ${kind_cluster.autoshop.name}

    3) Exportar as variáveis TF_VAR_* acima e aplicar o resto (banco,
       config, aplicação, metrics-server). Primeira vez pode demorar mais —
       é um cluster novo, as imagens públicas ainda não foram baixadas nele:
         terraform apply

    4) Testar:
         curl http://localhost:30080/health

    Se você já tinha rodado um apply completo antes de carregar a imagem, o
    pod pode ter ficado preso em ImagePullBackOff — rode
    "kubectl rollout restart deployment/autoshop-api -n autoshop --kubeconfig ${kind_cluster.autoshop.kubeconfig_path}"
    depois do passo 2.
  EOT
}
