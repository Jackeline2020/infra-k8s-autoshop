# Autenticação do GitHub Actions na AWS via OIDC: cada repositório de
# serviço faz o deploy dos próprios manifestos no cluster a partir da
# branch main, sem nenhuma chave fixa.

# modulos oficiais da comunidade Terraform
module "github_oidc_provider" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider"
  version = "~> 5.0"
}

module "github_actions_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  version = "~> 5.0"

  name = "autoshop-github-actions"

  # Curinga (*) entre owner/repo porque o GitHub pode incluir o ID
  # numérico do owner e do repositório no "sub" do token OIDC
  # (ex.: "repo:Jackeline2020@65305616/app-autoshop@1367964021:ref:...").
  subjects = [
    for repo in var.deploy_repositories :
    "repo:${var.github_owner}*/${repo}*:ref:refs/heads/main"
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
