#
# Metal LB
#

variable "ip_pool_range" {
  type        = string
  description = "The IP address pool range to manage for LoadBalancer's external IPs"
}

locals {
  namespace = "metallb"
}

resource "kubernetes_namespace_v1" "metallb" {
  metadata {
    name = local.namespace
  }
}

resource "helm_release" "metallb" {
  depends_on = [kubernetes_namespace_v1.metallb]
  name       = "metallb"
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"
  version    = "0.13.7"
  namespace  = local.namespace
}

resource "helm_release" "metallb_config" {
  depends_on = [helm_release.metallb]
  name       = "metallb-config"
  chart      = "${path.module}/config-chart"
  namespace  = local.namespace

  set {
    name  = "ip_pool_range"
    value = var.ip_pool_range
  }

}
