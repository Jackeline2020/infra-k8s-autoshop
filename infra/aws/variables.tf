variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string
  default     = "autoshop-eks"
}

variable "cluster_version" {
  description = "Versão do Kubernetes no EKS"
  type        = string
  # 1.30 não tem mais AMI gerenciada suportada pro node group (a AWS vai
  # descontinuando versões antigas) — 1.36 é a Standard Support atual.
  default     = "1.36"
}

variable "node_instance_type" {
  description = "Tipo de instância EC2 usada pelos nodes do cluster"
  type        = string
  # t3.small comporta 11 pods por node (o t3.micro só 4, limite de rede da
  # AWS): cabem os 3 serviços, o mock de pagamento, os jobs de migration e
  # o agente do New Relic.
  default = "t3.small"
}

variable "node_desired_size" {
  description = "Quantidade inicial de nodes"
  type        = number
  default     = 3
}

variable "node_min_size" {
  description = "Mínimo de nodes (o HPA escala pods; isso aqui escala máquinas, caso os pods não caibam mais nos nodes existentes)"
  type        = number
  default     = 3
}

variable "node_max_size" {
  description = "Máximo de nodes"
  type        = number
  default     = 6
}

variable "github_owner" {
  description = "Dono dos repositórios no GitHub"
  type        = string
  default     = "Jackeline2020"
}

variable "deploy_repositories" {
  description = "Repositórios autorizados a fazer deploy no cluster a partir da branch main (via OIDC, sem chave fixa)"
  type        = list(string)
  default = [
    "infra-k8s-autoshop",
    "app-autoshop",
    "execution-autoshop",
    "billing-autoshop",
    "payment-mock-autoshop",
  ]
}
