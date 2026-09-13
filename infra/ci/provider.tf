terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.5"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}

provider "kind" {}

# apply_retry_count absorve erros transitórios de rate limit do client-go
# contra a API do cluster recém-criado (comum no runner com poucos
# recursos, quando vários kubectl_manifest tentam aplicar em paralelo).
provider "kubectl" {
  config_path        = kind_cluster.ci.kubeconfig_path
  apply_retry_count  = 5
}

provider "helm" {
  kubernetes {
    config_path = kind_cluster.ci.kubeconfig_path
  }
}
