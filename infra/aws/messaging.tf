# Filas da Saga (ADR-006). Cada fila tem uma DLQ: depois de 5 tentativas
# sem sucesso, a mensagem sai da fila principal para análise.
locals {
  queues = ["execution-commands", "billing-commands", "os-events"]
}

resource "aws_sqs_queue" "dlq" {
  for_each = toset(local.queues)

  name                      = "${each.key}-dlq"
  message_retention_seconds = 1209600 # 14 dias
  tags                      = { Project = "autoshop" }
}

resource "aws_sqs_queue" "this" {
  for_each = toset(local.queues)

  name                       = each.key
  visibility_timeout_seconds = 30
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[each.key].arn
    maxReceiveCount     = 5
  })
  tags = { Project = "autoshop" }
}
