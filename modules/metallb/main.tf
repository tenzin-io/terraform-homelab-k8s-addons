#
# Metal LB
#

variable "ip_pool_range" {
  type        = string
  description = "The IP address pool range to manage for LoadBalancer's external IPs"
}

locals {
  namespace = "metallb-system"
}

resource "helm_release" "metallb" {
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  version          = "0.13.7"
  namespace        = local.namespace
  create_namespace = true
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
