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
  # t3.medium não é elegível pro Free Tier nesta conta — t3.micro é (ver
  # aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true).
  default     = "t3.micro"
}

variable "node_desired_size" {
  description = "Quantidade inicial de nodes"
  type        = number
  # t3.micro tem um limite baixo de pods por node (limitação de ENI/rede da
  # AWS, não de CPU/memória) — 2 nodes mal cabem os 2 pods da aplicação em
  # regime normal, e travam ("Too many pods") assim que um rolling update
  # precisa de capacidade extra temporária. 3 dá folga sem sair do Free Tier.
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

variable "rds_secret_arn" {
  description = "ARN do secret do RDS no Secrets Manager — output rds_secret_arn do repositório infra-db. Colar aqui (via -var ou TF_VAR_rds_secret_arn) depois do primeiro apply do infra-db. Mesmo padrão manual já usado para IRSA_ROLE_ARN."
  type        = string
}
