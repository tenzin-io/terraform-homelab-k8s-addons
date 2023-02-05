variable "github_org_name" {
  type = string
}

variable "github_app_id" {
  type = string
}

variable "github_app_installation_id" {
  type = string
}

variable "github_app_private_key" {
  type      = string
  sensitive = true
}

variable "github_runners_ready" {
  type    = number
  default = 3
}

locals {
  namespace = "actions"
}

resource "kubernetes_namespace_v1" "actions" {
  metadata {
    name = local.namespace
  }
}

resource "helm_release" "actions_runner_controller" {
  depends_on = [kubernetes_namespace_v1.actions]
  name       = "actions-runner-controller"
  namespace  = local.namespace
  repository = "https://actions-runner-controller.github.io/actions-runner-controller"
  chart      = "actions-runner-controller"
  version    = "0.21.1"
  set {
    name  = "authSecret.create"
    value = true
  }

  set {
    name  = "authSecret.github_app_id"
    value = var.github_app_id
  }

  set {
    name  = "authSecret.github_app_installation_id"
    value = var.github_app_installation_id
  }

  set {
    name  = "authSecret.github_app_private_key"
    value = var.github_app_private_key
  }

  set {
    name  = "metrics.serviceMonitorLabels"
    value = "kube-prometheus"
  }

  set {
    name  = "scope.singleNamespace"
    value = true
  }

}

resource "helm_release" "actions_runner_deployment" {
  depends_on = [helm_release.actions_runner_controller]
  name       = "actions-runner-deployment"
  namespace  = local.namespace
  chart      = "${path.module}/actions-runner-deployment"
  set {
    name  = "github_org_name"
    value = var.github_org_name
  }
  set {
    name  = "github_runners_ready"
    value = var.github_runners_ready
  }
}

