# IRSA: cada serviço roda com uma role IAM própria, assumida pela service
# account do pod, sem chave de acesso fixa. Cada role só enxerga as filas
# e tabelas do próprio serviço.

data "aws_caller_identity" "current" {}

locals {
  namespace = "autoshop"
  dynamodb_table_arn_prefix = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/autoshop-"

  # serviço => permissões
  services = {
    "autoshop-api" = {
      consume = ["os-events"]
      publish = ["execution-commands", "billing-commands"]
      dynamo  = false
    }
    "autoshop-execution" = {
      consume = ["execution-commands"]
      publish = ["os-events"]
      dynamo  = true
    }
    "autoshop-billing" = {
      consume = ["billing-commands"]
      publish = ["os-events"]
      dynamo  = false
    }
  }
}

module "irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  for_each  = local.services
  role_name = "${each.key}-irsa"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.namespace}:${each.key}"]
    }
  }
}

resource "aws_iam_role_policy" "service" {
  for_each = local.services

  name = "${each.key}-access"
  role = module.irsa[each.key].iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid      = "ConsumirComandosOuEventos"
          Effect   = "Allow"
          Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility", "sqs:GetQueueUrl", "sqs:GetQueueAttributes"]
          Resource = [for q in each.value.consume : aws_sqs_queue.this[q].arn]
        },
        {
          Sid      = "Publicar"
          Effect   = "Allow"
          Action   = ["sqs:SendMessage", "sqs:GetQueueUrl", "sqs:GetQueueAttributes"]
          Resource = [for q in each.value.publish : aws_sqs_queue.this[q].arn]
        },
      ],
      each.value.dynamo ? [
        {
          Sid    = "TabelasDoExecution"
          Effect = "Allow"
          Action = [
            "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem",
            "dynamodb:Query", "dynamodb:Scan", "dynamodb:ConditionCheckItem",
          ]
          Resource = ["${local.dynamodb_table_arn_prefix}*"]
        },
      ] : []
    )
  })
}
