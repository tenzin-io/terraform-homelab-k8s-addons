#
# Nginx Ingress
#

locals {
  namespace = "nginx-system"
}

variable "monitoring_enabled" {
  type        = bool
  description = "Is the Monitoring add-on enabled"
  default     = false
}

locals {
  tailscale_auth_key_secret_name = "tailscale-auth-key-secret"
  tailscale_state_secret_name    = "tailscale-state-secret"
}

data "template_file" "ingress_nginx_values" {
  template = file("${path.module}/ingress-nginx/values.yaml")
  vars = {
    monitoring_enabled             = var.monitoring_enabled
    tailscale_auth_key_secret_name = local.tailscale_auth_key_secret_name
    tailscale_state_secret_name    = local.tailscale_state_secret_name
  }
}

variable "tailscale_auth_key" {
  type        = string
  description = "The Tailscale auth key to join to the tailnet."
}

resource "kubernetes_namespace_v1" "nginx_system" {
  metadata {
    name = local.namespace
  }
}

resource "kubernetes_secret_v1" "tailscale_auth_key_secret" {
  metadata {
    name      = local.tailscale_auth_key_secret_name
    namespace = local.namespace
  }

  data = {
    ts_auth_key = var.tailscale_auth_key
  }

  depends_on = [helm_release.ingress_nginx]
}

resource "kubernetes_role_v1" "tailscale_role" {

  metadata {
    name      = "tailscale-role"
    namespace = local.namespace
  }

  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    resource_names = [local.tailscale_auth_key_secret_name, local.tailscale_state_secret_name]
    verbs          = ["get", "update", "patch"]
  }
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["create"]
  }
  depends_on = [helm_release.ingress_nginx]
}

resource "kubernetes_role_binding_v1" "tailscale_role_binding" {
  metadata {
    name      = "tailscale-role-binding"
    namespace = local.namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "tailscale-role"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "ingress-nginx"
    namespace = local.namespace
  }
  depends_on = [helm_release.ingress_nginx]
}

resource "helm_release" "ingress_nginx" {
  depends_on = [kubernetes_namespace_v1.nginx_system]
  name       = "ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = local.namespace
  repository = "https://kubernetes.github.io/ingress-nginx"
  version    = "4.4.0"
  values     = [data.template_file.ingress_nginx_values.rendered]
}

#
# Cert-manager setup
#
resource "helm_release" "cert_manager" {
  depends_on = [kubernetes_namespace_v1.nginx_system]
  name       = "cert-manager"
  namespace  = local.namespace
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "1.10.1"

  set {
    name  = "installCRDs"
    value = true
  }

  set {
    name  = "prometheus.servicemonitor.enabled"
    value = var.monitoring_enabled
  }

  set {
    name  = "prometheus.servicemonitor.labels.release"
    value = "prometheus"
  }
}

variable "contact_email" {
  type        = string
  description = "Certificate expiry contact email."
}

variable "cloudflare_api_token" {
  type        = string
  description = "CloudFlare API token"
  sensitive   = true
}

locals {
  cloudflare_api_token_secret_name = "cloudflare-api-token-secret"
}

resource "kubernetes_secret_v1" "cloudflare_api_token_secret" {
  depends_on = [helm_release.cert_manager]
  metadata {
    name      = local.cloudflare_api_token_secret_name
    namespace = local.namespace
  }

  data = {
    token = var.cloudflare_api_token
  }
}

resource "helm_release" "cert_manager_cr" {
  depends_on = [helm_release.cert_manager]
  name       = "cert-manager-custom-resources"
  chart      = "${path.module}/cert-manager-cr-chart"
  set {
    name  = "cloudflare.apiToken.secretName"
    value = local.cloudflare_api_token_secret_name
  }
  set {
    name  = "cloudflare.contactEmail"
    value = var.contact_email
  }
}

variable "external_domain_name" {
  type        = string
  description = "The domain name to place hosts when building Ingress manifests"
}

# Setup Kubernetes API server ingress
resource "kubernetes_ingress_v1" "kubernete_api_ingress" {
  metadata {
    name      = "kubernetes-apiserver-ingress"
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class"                       = "nginx"
      "cert-manager.io/cluster-issuer"                    = "lets-encrypt"
      "nginx.ingress.kubernetes.io/backend-protocol"      = "HTTPS"
      "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "120"
      "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "180"
      "nginx.ingress.kubernetes.io/proxy-send-timeout"    = "180"
      "nginx.ingress.kubernetes.io/proxy-body-size"       = "10m"
    }
  }

  spec {
    rule {
      host = "k8s.${var.external_domain_name}"
      http {
        path {
          backend {
            service {
              name = "kubernetes"
              port {
                number = 443
              }
            }
          }
          path      = "/"
          path_type = "Prefix"
        }
      }
    }

    tls {
      hosts       = ["k8s.${var.external_domain_name}"]
      secret_name = "kubernetes-apiserver-tls-secret"
    }
  }
}

variable "enable_external_services" {
  type        = bool
  description = "Enable access to services not hosted on the Kubernetes cluster"
  default     = false
}

variable "external_services" {
  type = map(object({
    address     = string
    protocol    = string
    port        = string
    virtualHost = string
  }))
  default     = {}
  description = "A map of external services to expose from the Ingress controller"
}

resource "helm_release" "external_services" {
  depends_on = [kubernetes_namespace_v1.nginx_system]
  for_each   = var.external_services
  chart      = "${path.module}/external-services"
  name       = "${each.key}-external-service"
  namespace  = local.namespace

  set {
    name  = "clusterIssuer"
    value = "lets-encrypt"
  }

  set {
    name  = "externalServiceName"
    value = each.key
  }

  set {
    name  = "server.address"
    value = each.value.address
  }

  set {
    name  = "server.protocol"
    value = each.value.protocol
  }

  set {
    name  = "server.port"
    value = each.value.port
  }

  set {
    name  = "ingressVirtualHost"
    value = each.value.virtualHost
  }
}
