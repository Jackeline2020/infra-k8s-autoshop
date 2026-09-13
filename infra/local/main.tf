resource "kind_cluster" "autoshop" {
  name           = var.cluster_name
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      # Expõe o NodePort 30080 direto no localhost
      extra_port_mappings {
        container_port = 30080
        host_port       = 30080
      }
    }
  }
}

# kind_cluster fica "ready" assim que o node está Ready, mas etcd/apiserver/
# coredns ainda estão subindo — essa pausa evita aplicar manifestos contra
# um control plane ainda instável.
resource "time_sleep" "wait_for_cluster" {
  create_duration = "30s"
  depends_on      = [kind_cluster.autoshop]
}

# --- Namespace ---
resource "kubectl_manifest" "namespace" {
  yaml_body  = file("${path.module}/../../k8s/base/namespace.yaml")
  depends_on = [time_sleep.wait_for_cluster]
}

# --- Config e Secret da aplicação ---
# Vem antes do banco agora porque o Deployment do Postgres lê usuário/senha
# do próprio ConfigMap/Secret (POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB).
resource "kubectl_manifest" "configmap" {
  yaml_body  = file("${path.module}/../../k8s/overlays/local/configmap.yaml")
  depends_on = [kubectl_manifest.namespace]
}

resource "kubectl_manifest" "secret" {
  yaml_body  = file("${path.module}/../../k8s/overlays/local/secret.yaml")
  depends_on = [kubectl_manifest.namespace]
}

resource "kubectl_manifest" "serviceaccount" {
  yaml_body  = file("${path.module}/../../k8s/overlays/local/serviceaccount.yaml")
  depends_on = [kubectl_manifest.namespace]
}

# --- Banco de dados ---
# Postgres roda dentro do cluster (Deployment + Service).
data "kubectl_file_documents" "postgres_local" {
  content = file("${path.module}/../../k8s/overlays/local/postgres-local.yaml")
}

resource "kubectl_manifest" "postgres_local" {
  for_each   = data.kubectl_file_documents.postgres_local.manifests
  yaml_body  = each.value
  depends_on = [kubectl_manifest.configmap, kubectl_manifest.secret]
}

# ConfigMap com o SQL da migration — mesma fonte usada em dev (docker-compose)
# e nos testes de integração, ver migrations/000001_init_schema.up.sql.
resource "kubectl_manifest" "db_migration_sql" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "db-migration-sql"
      namespace = "autoshop"
    }
    data = {
      "000001_init_schema.up.sql" = file("${path.module}/../../migrations/000001_init_schema.up.sql")
    }
  })
  depends_on = [kubectl_manifest.namespace]
}

# Job que aplica a migration contra o Postgres do cluster (equivalente ao
# serviço "migrate" do docker-compose, mas via psql — sem precisar de mais
# uma imagem/tool só pra isso dentro do k8s).
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
              "until pg_isready -h \"$DB_HOST\" -p \"$DB_PORT\" -U \"$DB_USER\"; do sleep 2; done && PGPASSWORD=\"$DB_PASSWORD\" psql -h \"$DB_HOST\" -p \"$DB_PORT\" -U \"$DB_USER\" -d \"$DB_NAME\" -f /migrations/000001_init_schema.up.sql"
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

# --- metrics-server ---
# Necessário pro HPA funcionar
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  timeout    = 600 #padrão 300s

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  depends_on = [time_sleep.wait_for_cluster]
}

# --- Aplicação ---
resource "kubectl_manifest" "deployment" {
  yaml_body = file("${path.module}/../../k8s/base/deployment.yaml")
  # O provider tem um timeout fixo de 10min pra criar o recurso, e por padrão
  # usa esse mesmo prazo pra esperar o rollout ficar 100% disponível. Se o
  # pod demorar mais que isso pra ficar pronto, o apply falha mesmo que o
  # rollout esteja progredindo normalmente. Desligamos essa espera aqui e
  # confirmamos o rollout manualmente depois (kubectl rollout status).
  wait_for_rollout = false
  depends_on = [
    kubectl_manifest.configmap,
    kubectl_manifest.secret,
    kubectl_manifest.serviceaccount,
    kubectl_manifest.db_migrate,
  ]
}

resource "kubectl_manifest" "service" {
  yaml_body  = file("${path.module}/../../k8s/base/service.yaml")
  depends_on = [kubectl_manifest.namespace]
}

resource "kubectl_manifest" "hpa" {
  yaml_body  = file("${path.module}/../../k8s/base/hpa.yaml")
  depends_on = [kubectl_manifest.deployment, helm_release.metrics_server]
}