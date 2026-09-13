module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids

  # true = o endpoint da API do cluster é acessível pela internet, em produção, restringir isso a uma VPN/rede privada
  cluster_endpoint_public_access = true

  # Sem isso, quem roda o apply não ganha acesso automático de kubectl no cluster criado
  enable_cluster_creator_admin_permissions = true

  # o pod da API assume uma IAM role real via service account, sem nenhuma chave de acesso estática
  enable_irsa = true

  eks_managed_node_groups = {
    autoshop_nodes = {
      instance_types = [var.node_instance_type]
      desired_size   = var.node_desired_size
      min_size       = var.node_min_size
      max_size       = var.node_max_size
    }
  }

  # "access entry" = role usada pelo GitHub Actions pode administrar o cluster via kubectl
  access_entries = {
    github_actions = {
      principal_arn = module.github_actions_role.arn

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
}
