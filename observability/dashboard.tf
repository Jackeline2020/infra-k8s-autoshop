resource "newrelic_one_dashboard" "autoshop" {
  name        = "AutoShop - Fase 4"
  permissions = "public_read_only"

  # ---------------------------------------------------------------
  # Página 1: ordens de serviço e Saga (eventos de negócio)
  # ---------------------------------------------------------------
  page {
    name = "Ordens de serviço e Saga"

    widget_billboard {
      title  = "OS abertas (24 h)"
      row    = 1
      column = 1
      width  = 3
      height = 3
      nrql_query {
        query = "SELECT count(*) FROM OrderLifecycle WHERE eventName = 'order_created' SINCE 1 day ago"
      }
    }

    widget_billboard {
      title  = "OS finalizadas (24 h)"
      row    = 1
      column = 4
      width  = 3
      height = 3
      nrql_query {
        query = "SELECT count(*) FROM OrderLifecycle WHERE eventName = 'status_changed' AND `to` = 'finalizada' SINCE 1 day ago"
      }
    }

    widget_billboard {
      title  = "OS canceladas pela Saga (24 h)"
      row    = 1
      column = 7
      width  = 3
      height = 3
      nrql_query {
        query = "SELECT count(*) FROM OrderLifecycle WHERE eventName = 'status_changed' AND `to` = 'cancelada' SINCE 1 day ago"
      }
    }

    widget_billboard {
      title  = "Falhas no processamento (1 h)"
      row    = 1
      column = 10
      width  = 3
      height = 3
      nrql_query {
        query = "SELECT count(*) FROM OrderProcessingFailure SINCE 1 hour ago"
      }
    }

    widget_line {
      title  = "OS abertas por período"
      row    = 4
      column = 1
      width  = 6
      height = 3
      nrql_query {
        query = "SELECT count(*) FROM OrderLifecycle WHERE eventName = 'order_created' TIMESERIES SINCE 1 day ago"
      }
    }

    widget_bar {
      title  = "Tempo médio por status (minutos)"
      row    = 4
      column = 7
      width  = 6
      height = 3
      nrql_query {
        query = "SELECT average(durationMinutes) FROM OrderLifecycle WHERE eventName = 'status_duration' FACET status SINCE 7 days ago"
      }
    }

    widget_bar {
      title  = "Passos da Saga processados (por evento recebido)"
      row    = 7
      column = 1
      width  = 6
      height = 3
      nrql_query {
        query = "SELECT count(*) FROM OrderLifecycle WHERE eventName = 'saga_progress' FACET trigger SINCE 1 day ago"
      }
    }

    widget_pie {
      title  = "Situação da Saga após cada passo"
      row    = 7
      column = 7
      width  = 6
      height = 3
      nrql_query {
        query = "SELECT count(*) FROM OrderLifecycle WHERE eventName = 'saga_progress' FACET saga_status SINCE 1 day ago"
      }
    }

    widget_bar {
      title  = "Falhas por etapa"
      row    = 10
      column = 1
      width  = 6
      height = 3
      nrql_query {
        query = "SELECT count(*) FROM OrderProcessingFailure FACET step SINCE 1 day ago"
      }
    }

    widget_table {
      title  = "Últimos passos da Saga (rastreamento por correlation_id)"
      row    = 10
      column = 7
      width  = 6
      height = 3
      nrql_query {
        query = "SELECT timestamp, correlationId, orderId, trigger, step, saga_status FROM OrderLifecycle WHERE eventName = 'saga_progress' SINCE 1 day ago LIMIT 50"
      }
    }
  }

  # ---------------------------------------------------------------
  # Página 2: saúde dos 3 microsserviços (dados do agente APM)
  # ---------------------------------------------------------------
  page {
    name = "Microsserviços"

    widget_line {
      title  = "Tempo de resposta (ms)"
      row    = 1
      column = 1
      width  = 6
      height = 3
      nrql_query {
        query = "SELECT average(duration) * 1000 FROM Transaction WHERE appName IN (${local.apps_sql}) FACET appName TIMESERIES SINCE 3 hours ago"
      }
    }

    widget_line {
      title  = "Requisições por minuto"
      row    = 1
      column = 7
      width  = 6
      height = 3
      nrql_query {
        query = "SELECT rate(count(*), 1 minute) FROM Transaction WHERE appName IN (${local.apps_sql}) FACET appName TIMESERIES SINCE 3 hours ago"
      }
    }

    widget_line {
      title  = "Taxa de erro (%)"
      row    = 4
      column = 1
      width  = 6
      height = 3
      nrql_query {
        query = "SELECT percentage(count(*), WHERE error IS true) FROM Transaction WHERE appName IN (${local.apps_sql}) FACET appName TIMESERIES SINCE 3 hours ago"
      }
    }

    widget_table {
      title  = "Rotas mais lentas"
      row    = 4
      column = 7
      width  = 6
      height = 3
      nrql_query {
        query = "SELECT average(duration) * 1000 AS 'ms', count(*) FROM Transaction WHERE appName IN (${local.apps_sql}) FACET appName, name SINCE 3 hours ago LIMIT 15"
      }
    }
  }
}

output "dashboard_url" {
  description = "Link do dashboard no New Relic"
  value       = newrelic_one_dashboard.autoshop.permalink
}
