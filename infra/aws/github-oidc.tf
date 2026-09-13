# autenticacao do GitHub Actions na AWS via OIDC
variable "github_repository" {
  description = "Repositório GitHub autorizado a assumir a role de deploy"
  type        = string
  default     = "Jackeline2020/infra-k8s-autoshop"
}

# modulos oficiais da comunidade Terraform
module "github_oidc_provider" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider"
  version = "~> 5.0"
}

module "github_actions_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  version = "~> 5.0"

  name = "autoshop-github-actions"

  # push/merge na branch main do repositorio configurado pode assumir essa role
  subjects = ["repo:${var.github_repository}:ref:refs/heads/main"]

  policies = {
    eks_access = aws_iam_policy.eks_deploy.arn
  }
}

# permissao minima necessaria
resource "aws_iam_policy" "eks_deploy" {
  name = "autoshop-eks-deploy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = module.eks.cluster_arn
    }]
  })
}
