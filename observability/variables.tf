variable "account_id" {
  description = "ID da conta do New Relic"
  type        = number
}

variable "api_key" {
  description = "User API key do New Relic (tipo USER, começa com NRAK-)"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Região da conta do New Relic (US ou EU)"
  type        = string
  default     = "US"
}

variable "alert_email" {
  description = "E-mail que recebe as notificações dos alertas"
  type        = string
}
