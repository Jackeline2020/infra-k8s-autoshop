# IRSA da ao POD da API uma IAM role real, assumida atraves da sua service account do Kubernetes
module "irsa_autoshop_api" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "autoshop-api-irsa"

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["autoshop:autoshop-api"]
    }
  }
}

# credencial no secrets manager pra então abrir a conexão Postgres.
# aws_secretsmanager_secret.db não existe mais neste repositório (o RDS
# agora é do infra-db) — por isso o ARN vem de uma variável, colada
# manualmente a partir do output rds_secret_arn do infra-db.
resource "aws_iam_policy" "app_secrets_access" {
  name = "autoshop-api-secrets-access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.rds_secret_arn]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "irsa_secrets" {
  role       = module.irsa_autoshop_api.iam_role_name
  policy_arn = aws_iam_policy.app_secrets_access.arn
}
