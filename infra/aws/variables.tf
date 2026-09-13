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
  default     = "1.30"
}

variable "node_instance_type" {
  description = "Tipo de instância EC2 usada pelos nodes do cluster"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Quantidade inicial de nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Mínimo de nodes (o HPA escala pods; isso aqui escala máquinas, caso os pods não caibam mais nos nodes existentes)"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Máximo de nodes"
  type        = number
  default     = 6
}

variable "rds_secret_arn" {
  description = "ARN do secret do RDS no Secrets Manager — output rds_secret_arn do repositório infra-db. Colar aqui (via -var ou TF_VAR_rds_secret_arn) depois do primeiro apply do infra-db. Mesmo padrão manual já usado para IRSA_ROLE_ARN."
  type        = string
}
