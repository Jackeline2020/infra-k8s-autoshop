# Cluster efêmero: sobe dentro do próprio runner do GitHub Actions, existe
# só durante essa execução do pipeline, e morre com a VM do runner no final do job.
resource "kind_cluster" "ci" {
  name           = "autoshop-ci"
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      extra_port_mappings {
        container_port = 30080
        host_port       = 30080
      }
    }
  }
}

# kind_cluster fica "ready" assim que o node está Ready, mas etcd/apiserver/
# coredns ainda estão subindo — aplicar tudo de imediato nesse momento é o
# que causava "client rate limiter Wait ... context deadline exceeded" no
# runner (poucos recursos). Essa pausa dá tempo do control plane estabilizar
# antes da primeira leva de kubectl_manifest.
resource "time_sleep" "wait_for_cluster" {
  create_duration = "30s"
  depends_on      = [kind_cluster.ci]
}

# --- Namespace ---
# Único manifesto de "ambiente" que continua pertencendo a este repositório
# (não ao app-autoshop) — é infraestrutura do cluster, não da aplicação.
resource "kubectl_manifest" "namespace" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Namespace"
    metadata   = { name = "autoshop" }
  })
  depends_on = [time_sleep.wait_for_cluster]
}

# --- Credencial pra puxar a imagem do GHCR ---
# O cluster efêmero não tem a imagem em cache local (diferente do
# infra/local, que usa "kind load") — aqui ela precisa ser puxada de
# verdade do GHCR pela rede, então o node precisa de credencial.
resource "kubectl_manifest" "ghcr_pull_secret" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "ghcr-pull-secret"
      namespace = "autoshop"
    }
    type = "kubernetes.io/dockerconfigjson"
    data = {
      ".dockerconfigjson" = base64encode(jsonencode({
        auths = {
          "ghcr.io" = {
            username = var.ghcr_username
            password = var.ghcr_token
            auth     = base64encode("${var.ghcr_username}:${var.ghcr_token}")
          }
        }
      }))
    }
  })
  depends_on = [kubectl_manifest.namespace]
}

# --- Config e Secret da aplicação ---
# Conteúdo vem de k8s/overlays/local/{configmap,secret,serviceaccount}.yaml
# do repositório app-autoshop, baixado pelo workflow via API do GitHub (ver
# .github/workflows/ci-cd.yml) — desde a reorganização pedida pelo
# professor, esses manifestos são versionados lá, não aqui.
resource "kubectl_manifest" "configmap" {
  yaml_body  = var.configmap_yaml
  depends_on = [kubectl_manifest.namespace]
}

resource "kubectl_manifest" "secret" {
  yaml_body  = var.secret_yaml
  depends_on = [kubectl_manifest.namespace]
}

resource "kubectl_manifest" "serviceaccount" {
  yaml_body  = var.serviceaccount_yaml
  depends_on = [kubectl_manifest.namespace, kubectl_manifest.ghcr_pull_secret]
}

# --- Banco de dados: Postgres dentro do cluster ---
# Substituto descartável do RDS real, só pra este teste efêmero — não é a
# aplicação, é infraestrutura de teste do próprio ambiente kind.
data "kubectl_file_documents" "postgres_local" {
  content = file("${path.module}/postgres-local.yaml")
}

resource "kubectl_manifest" "postgres_local" {
  for_each   = data.kubectl_file_documents.postgres_local.manifests
  yaml_body  = each.value
  depends_on = [kubectl_manifest.configmap, kubectl_manifest.secret]
}

resource "kubectl_manifest" "db_migration_sql" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "db-migration-sql"
      namespace = "autoshop"
    }
    data = {
      "000001_init_schema.up.sql"          = var.migration_sql
      "000002_add_customer_status.up.sql"  = var.migration_sql_2
    }
  })
  depends_on = [kubectl_manifest.namespace]
}

resource "kubectl_manifest" "db_migrate" {
  yaml_body = yamlencode({
    apiVersion = "batch/v1"
    kind       = "Job"
    metadata = {
      name      = "db-migrate"
      namespace = "autoshop"
    }
    spec = {
      backoffLimit = 3
      template = {
        spec = {
          restartPolicy                = "OnFailure"
          automountServiceAccountToken = false
          containers = [{
            name  = "db-migrate"
            image = "postgres:16-alpine"
            envFrom = [
              { configMapRef = { name = "autoshop-config" } },
              { secretRef = { name = "autoshop-secrets" } },
            ]
            command = ["/bin/sh", "-c"]
            args = [
              "until pg_isready -h \"$DB_HOST\" -p \"$DB_PORT\" -U \"$DB_USER\"; do sleep 2; done && for f in /migrations/*.sql; do PGPASSWORD=\"$DB_PASSWORD\" psql -h \"$DB_HOST\" -p \"$DB_PORT\" -U \"$DB_USER\" -d \"$DB_NAME\" -f \"$f\"; done"
            ]
            volumeMounts = [{
              name      = "migrations"
              mountPath = "/migrations"
            }]
          }]
          volumes = [{
            name = "migrations"
            configMap = {
              name = "db-migration-sql"
            }
          }]
        }
      }
    }
  })
  depends_on = [kubectl_manifest.db_migration_sql, kubectl_manifest.postgres_local]
}

# --- Aplicação ---
# Conteúdo vem de k8s/base/{deployment,service,hpa}.yaml do app-autoshop.
# Troca a tag padrão do manifesto (autoshop-api:latest) pela imagem recém
# publicada nesta execução do pipeline (ghcr.io/.../autoshop-api:<sha>).
resource "kubectl_manifest" "deployment" {
  yaml_body = replace(
    var.deployment_yaml,
    "image: autoshop-api:latest",
    "image: ${var.image}"
  )
  wait_for_rollout = false
  depends_on = [
    kubectl_manifest.configmap,
    kubectl_manifest.secret,
    kubectl_manifest.serviceaccount,
    kubectl_manifest.db_migrate,
  ]
}

resource "kubectl_manifest" "service" {
  yaml_body  = var.service_yaml
  depends_on = [kubectl_manifest.namespace]
}

resource "kubectl_manifest" "hpa" {
  yaml_body  = var.hpa_yaml
  depends_on = [kubectl_manifest.deployment]
}
