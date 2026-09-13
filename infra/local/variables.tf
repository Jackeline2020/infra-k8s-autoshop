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
