variable "image" {
  description = "Referência completa da imagem publicada"
  type        = string
}

variable "ghcr_username" {
  description = "Usuário do GitHub Container Registry, usado só pra criar o imagePullSecret do cluster efêmero"
  type        = string
}

variable "ghcr_token" {
  description = "Token de leitura do GHCR (secrets.GITHUB_TOKEN da própria execução, expira junto com o workflow)"
  type        = string
  sensitive   = true
}

variable "migration_sql" {
  description = "Conteúdo do arquivo migrations/000001_init_schema.up.sql, que mora no repositório app-autoshop. O workflow (ci-cd.yml) baixa esse arquivo via API do GitHub e passa aqui via TF_VAR_migration_sql antes do apply — não dá pra usar file() porque o arquivo não existe neste repositório."
  type        = string
  sensitive   = true
}

variable "migration_sql_2" {
  description = "Conteúdo do arquivo migrations/000002_add_customer_status.up.sql do app-autoshop (mesma lógica do migration_sql acima). Aplicado depois de migration_sql, na mesma ordem numérica."
  type        = string
  sensitive   = true
}

# --- Manifestos da aplicação ---
# Mesma lógica do migration_sql acima: a partir da reorganização pedida
# pelo professor, esses manifestos passaram a ser versionados no
# app-autoshop. O workflow baixa cada um via API do GitHub e injeta aqui.
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
