variable "cluster_name" {
  description = "Nome do cluster kind criado localmente"
  type        = string
  default     = "autoshop-local"
}

variable "migration_sql" {
  description = "Conteúdo do arquivo migrations/000001_init_schema.up.sql, que mora no repositório app-autoshop (clonado como pasta irmã desta, ex: ../../../app-autoshop). Não dá pra usar file() direto porque o arquivo não existe neste repositório — passe o conteúdo via TF_VAR_migration_sql antes do apply (ver infra/README.md)."
  type        = string
  sensitive   = true
}

variable "migration_sql_2" {
  description = "Conteúdo do arquivo migrations/000002_add_customer_status.up.sql do app-autoshop (mesma lógica do migration_sql acima). Aplicado depois de migration_sql, na mesma ordem numérica."
  type        = string
  sensitive   = true
}

# --- Manifestos da aplicação ---
# A partir da reorganização pedida pelo professor, os manifestos Kubernetes
# da aplicação (Deployment, Service, HPA, ConfigMap, Secret, ServiceAccount)
# passaram a ser versionados no repositório app-autoshop, não mais aqui —
# este repositório só cuida do cluster em si (Terraform provisiona cluster,
# node, rede, add-ons). Pra continuar testando localmente com um único
# "terraform apply", o conteúdo desses arquivos é lido do app-autoshop
# (pasta irmã) e passado via TF_VAR_*, mesmo padrão do migration_sql acima.
variable "deployment_yaml" {
  description = "Conteúdo de k8s/base/deployment.yaml do repositório app-autoshop."
  type        = string
}

variable "service_yaml" {
  description = "Conteúdo de k8s/base/service.yaml do repositório app-autoshop."
  type        = string
}

variable "hpa_yaml" {
  description = "Conteúdo de k8s/base/hpa.yaml do repositório app-autoshop."
  type        = string
}

variable "configmap_yaml" {
  description = "Conteúdo de k8s/overlays/local/configmap.yaml do repositório app-autoshop."
  type        = string
}

variable "secret_yaml" {
  description = "Conteúdo de k8s/overlays/local/secret.yaml do repositório app-autoshop."
  type        = string
  sensitive   = true
}

variable "serviceaccount_yaml" {
  description = "Conteúdo de k8s/overlays/local/serviceaccount.yaml do repositório app-autoshop."
  type        = string
}
