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
  namespace = "actions-runner-system"
}


resource "helm_release" "actions_runner_controller" {
  name             = "actions-runner-controller"
  namespace        = local.namespace
  create_namespace = true
  repository       = "https://actions-runner-controller.github.io/actions-runner-controller"
  chart            = "actions-runner-controller"
  version          = "0.21.1"
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

resource "kubernetes_manifest" "actions_runner_deployment" {
  depends_on = [helm_release.actions_runner_controller]
  manifest = {
    apiVersion = "actions.summerwind.dev/v1alpha1"
    kind       = "RunnerDeployment"
    metadata = {
      name      = "${var.github_org_name}-actions-runner"
      namespace = local.namespace
    }

    spec = {
      replicas = var.github_runners_ready
      template = {
        spec = {
          organization : var.github_org_name
        }
      }
    }
  }
}

