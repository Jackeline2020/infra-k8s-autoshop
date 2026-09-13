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
