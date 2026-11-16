# Observabilidade (New Relic) em Terraform

Dashboards e alertas do New Relic versionados, em vez de configurados
manualmente pela interface.

| Arquivo | Conteúdo |
|---|---|
| `dashboard.tf` | Dashboard **AutoShop - Fase 4** com duas páginas: **Ordens de serviço e Saga** (OS abertas, finalizadas e canceladas, tempo médio por status, passos da Saga, falhas por etapa, rastreamento por `correlation_id`) e **Microsserviços** (tempo de resposta, requisições por minuto, taxa de erro e rotas mais lentas dos 3 serviços) |
| `alerts.tf` | Política **AutoShop - Fase 4** com 3 condições: falhas no processamento de OS, OS cancelada por prazo esgotado na Saga e taxa de erro acima de 5% em qualquer serviço; notificação por e-mail |

Os dados vêm de duas fontes já instrumentadas nos serviços:

- **Eventos de negócio** do OS Service: `OrderLifecycle` (abertura da OS,
  mudanças de status, tempo em cada status e cada passo da Saga) e
  `OrderProcessingFailure` (falhas, com a etapa).
- **APM** dos 3 serviços (`autoshop-api`, `autoshop-execution`,
  `autoshop-billing`): evento `Transaction`.

## Aplicar

Pré-requisitos: Terraform >= 1.5 e uma **User API key** do New Relic
(menu do usuário → API keys → tipo USER, começa com `NRAK-`).

```bash
cd observability
terraform init
terraform apply \
  -var="account_id=<ID da conta>" \
  -var="api_key=<NRAK-...>" \
  -var="alert_email=<e-mail>"
```

A saída `dashboard_url` traz o link do dashboard. Para remover:
`terraform destroy` com as mesmas variáveis.
