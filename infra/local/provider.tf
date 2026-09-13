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

# Aponta pro kubeconfig que o próprio kind_cluster gera — permite ao
# Terraform aplicar manifestos Kubernetes como resources reais (kubectl_manifest),
# em vez de um script chamando "kubectl apply" por fora.
provider "kubectl" {
  config_path        = kind_cluster.autoshop.kubeconfig_path
  apply_retry_count  = 5
}

provider "helm" {
  kubernetes {
    config_path = kind_cluster.autoshop.kubeconfig_path
  }
}
