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
