#
# Nginx Ingress
#

variable "monitoring_enabled" {
  type = bool
  description = "Is the Monitoring add-on enabled"
  default = false
}

resource "helm_release" "ingress_nginx" {
  name = "ingress-nginx"
  chart = "ingress-nginx"
  namespace = "nginx-system"
  create_namespace = true
  repository = "https://kubernetes.github.io/ingress-nginx"
  version = "4.4.0"

  set {
    name = "controller.metrics.enabled"
    value = var.monitoring_enabled
  }

  set {
    name = "controller.metrics.serviceMonitor.enabled"
    value = var.monitoring_enabled
  }

  set {
    name = "controller.metrics.serviceMonitor.additionalLabels.release"
    value = "kube-prometheus"
  }

  set {
    name = "controller.admissionWebhooks.enabled"
    value = false
  }
}
