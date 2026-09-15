# autenticacao do GitHub Actions na AWS via OIDC
variable "github_repository" {
  description = "Repositório GitHub autorizado a assumir a role de deploy (provisionamento do cluster)"
  type        = string
  default     = "Jackeline2020/infra-k8s-autoshop"
}

# Desde a reorganização pedida pelo professor, o repositório app-autoshop
# também precisa assumir essa role — é ele quem agora aplica os manifestos
# da aplicação (Deployment, Service, HPA, ConfigMap, Secret) diretamente no
# cluster EKS real, de forma independente deste repositório (que só
# provisiona o cluster em si). Os dois repositórios compartilham a mesma
# role porque os dois legitimamente precisam de acesso administrativo ao
# cluster — cada um autenticado via OIDC, sem nenhuma chave fixa.
variable "app_repository" {
  description = "Repositório GitHub (app-autoshop) autorizado a assumir a role de deploy da aplicação"
  type        = string
  default     = "Jackeline2020/app-autoshop"
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

  # push/merge na branch main de qualquer um dos dois repositórios pode
  # assumir essa role: infra-k8s-autoshop (provisiona o cluster) e
  # app-autoshop (faz deploy da aplicação nele).
  #
  # Curinga (*) entre owner/repo porque o GitHub passou a incluir o ID
  # numérico do owner e do repositório no "sub" do token OIDC
  # (ex: "repo:Jackeline2020@65305616/app-autoshop@1367964021:ref:...",
  # em vez do formato clássico "repo:Jackeline2020/app-autoshop:ref:..."),
  # e o StringLike precisa casar com os dois formatos.
  subjects = [
    "repo:${replace(var.github_repository, "/", "*/")}*:ref:refs/heads/main",
    "repo:${replace(var.app_repository, "/", "*/")}*:ref:refs/heads/main",
  ]

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
