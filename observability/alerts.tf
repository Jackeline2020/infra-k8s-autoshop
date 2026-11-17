resource "newrelic_alert_policy" "autoshop" {
  name                = "AutoShop - Fase 4"
  incident_preference = "PER_CONDITION_AND_TARGET"
}

# Qualquer falha no processamento de uma OS (validação, transição de status,
# gravação) abre um incidente.
resource "newrelic_nrql_alert_condition" "falhas_os" {
  account_id                   = var.account_id
  policy_id                    = newrelic_alert_policy.autoshop.id
  type                         = "static"
  name                         = "Falhas no processamento de OS"
  description                  = "Eventos OrderProcessingFailure registrados pelo OS Service"
  enabled                      = true
  violation_time_limit_seconds = 86400
  aggregation_window           = 60
  # Eventos raros: a janela fecha por tempo (event_timer), sem depender de
  # novos eventos chegarem depois (como no event_flow)
  aggregation_method = "event_timer"
  aggregation_timer  = 60

  nrql {
    query = "SELECT count(*) FROM OrderProcessingFailure"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 60
    threshold_occurrences = "at_least_once"
  }
}

# Um serviço deixou de responder a um passo da Saga dentro do prazo e a OS
# foi cancelada com compensação.
resource "newrelic_nrql_alert_condition" "saga_prazo" {
  account_id                   = var.account_id
  policy_id                    = newrelic_alert_policy.autoshop.id
  type                         = "static"
  name                         = "OS cancelada por prazo esgotado na Saga"
  description                  = "Execution ou Billing não respondeu a um comando dentro do prazo"
  enabled                      = true
  violation_time_limit_seconds = 86400
  aggregation_window           = 60
  # Eventos raros: a janela fecha por tempo (event_timer), sem depender de
  # novos eventos chegarem depois (como no event_flow)
  aggregation_method = "event_timer"
  aggregation_timer  = 60

  nrql {
    query = "SELECT count(*) FROM OrderLifecycle WHERE eventName = 'saga_progress' AND trigger = 'saga_timeout'"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 60
    threshold_occurrences = "at_least_once"
  }
}

# Taxa de erro alta em qualquer um dos 3 serviços (um incidente por serviço).
resource "newrelic_nrql_alert_condition" "taxa_erro" {
  account_id                   = var.account_id
  policy_id                    = newrelic_alert_policy.autoshop.id
  type                         = "static"
  name                         = "Taxa de erro acima de 5%"
  description                  = "Percentual de requisições com erro por microsserviço"
  enabled                      = true
  violation_time_limit_seconds = 86400
  aggregation_window           = 300
  aggregation_method           = "event_flow"
  aggregation_delay            = 120

  nrql {
    query = "SELECT percentage(count(*), WHERE error IS true) FROM Transaction WHERE appName IN (${local.apps_sql}) FACET appName"
  }

  critical {
    operator              = "above"
    threshold             = 5
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}

# Notificação por e-mail para os incidentes da política
resource "newrelic_notification_destination" "email" {
  account_id = var.account_id
  name       = "AutoShop - e-mail"
  type       = "EMAIL"

  property {
    key   = "email"
    value = var.alert_email
  }
}

resource "newrelic_notification_channel" "email" {
  account_id     = var.account_id
  name           = "AutoShop - e-mail"
  type           = "EMAIL"
  destination_id = newrelic_notification_destination.email.id
  product        = "IINT"

  property {
    key   = "subject"
    value = "[AutoShop] {{ issueTitle }}"
  }
}

resource "newrelic_workflow" "autoshop" {
  name                  = "AutoShop - alertas"
  muting_rules_handling = "NOTIFY_ALL_ISSUES"

  issues_filter {
    name = "Política AutoShop"
    type = "FILTER"

    predicate {
      attribute = "labels.policyIds"
      operator  = "EXACTLY_MATCHES"
      values    = [newrelic_alert_policy.autoshop.id]
    }
  }

  destination {
    channel_id = newrelic_notification_channel.email.id
  }
}
