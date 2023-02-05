#
# Vault add-on
#

variable "monitoring_enabled" {
  type        = bool
  default     = false
  description = "Is monitoring add-on enabled?"
}

variable "vault_backup_git_url" {
  type        = string
  description = "A URL to a Git repo containing the Vault data backup."
}

variable "external_domain_name" {
  type        = string
  description = "The external domain name to place hosts when building Ingress manifests"
}

resource "helm_release" "vault" {
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  name             = "vault"
  namespace        = "vault-system"
  version          = "0.23.0"
  create_namespace = true

  values = [
    data.template_file.vault_values.rendered
  ]
}

data "template_file" "vault_values" {
  template = file("${path.module}/values.yaml")
  vars = {
    monitoring_enabled   = var.monitoring_enabled
    vault_backup_git_url = var.vault_backup_git_url
    external_domain_name = var.external_domain_name
  }
}

resource "kubernetes_service_account_v1" "vault_trust" {
  metadata {
    name      = "vault-trust"
    namespace = "kube-system"
  }
}

resource "kubernetes_secret_v1" "vault_trust" {
  metadata {
    name      = "vault-trust"
    namespace = "kube-system"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.vault_trust.metadata.0.name
    }
  }
  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_cluster_role_v1" "vault_trust" {
  metadata {
    name = "vault-trust"
  }
  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["get"]
  }

  rule {
    api_groups = [""]
    resources  = ["serviceaccounts", "serviceaccounts/token"]
    verbs      = ["create", "update", "delete"]
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["rolebindings", "clusterrolebindings"]
    verbs      = ["create", "update", "delete"]
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["roles", "clusterroles"]
    verbs      = ["bind", "escalate", "create", "update", "delete"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "vault_trust" {
  metadata {
    name = "vault-trust"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "vault-trust"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "vault-trust"
    namespace = "kube-system"
  }
}
