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

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = local.namespace
  create_namespace = true
  repository       = "https://kubernetes.github.io/ingress-nginx"
  version          = "4.4.0"

  # enable metrics only if monitoring is enabled
  set {
    name  = "controller.metrics.enabled"
    value = var.monitoring_enabled
  }

  # the monitoring needs to be enabled, because the prometheus operator installed there, installs the service monitor crd
  set {
    name  = "controller.metrics.serviceMonitor.enabled"
    value = var.monitoring_enabled
  }

  # the prometheus operator monitors for the release=kube-prometheus label
  set {
    name  = "controller.metrics.serviceMonitor.additionalLabels.release"
    value = "kube-prometheus"
  }

  # helm install very slow if set to true
  set {
    name  = "controller.admissionWebhooks.enabled"
    value = false
  }

  # sets the ingress-nginx as the default ingress class of the cluster
  set {
    name  = "controller.ingressClassResource.default"
    value = true
  }

}

#
# Cert-manager setup
#
resource "helm_release" "cert_manager" {
  depends_on = [helm_release.ingress_nginx]
  name       = "cert-manager"
  namespace  = local.namespace
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "1.10.1"
  wait_for_jobs = true

  set {
    name  = "installCRDs"
    value = true
  }

  set {
    name  = "prometheus.servicemonitor.enabled"
    value = var.monitoring_enabled
  }
}

variable "certificate_email" {
  type        = string
  description = "Certificate expiry contact email."
}

variable "cloudflare_token" {
  type        = string
  description = "CloudFlare API token"
  sensitive   = true
}

resource "kubernetes_secret" "cloudflare_api_secret" {
  depends_on = [helm_release.cert_manager]
  metadata {
    name      = "cloudflare-api-secret"
    namespace = local.namespace
  }

  data = {
    token = var.cloudflare_token
  }
}

resource "kubernetes_manifest" "lets_encrypt_certificate_issuer" {
  depends_on = [helm_release.cert_manager, kubernetes_secret.cloudflare_api_secret]
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind" = "ClusterIssuer"
    "metadata" = {
      "name" = "lets-encrypt"
    }
    "spec" = {
      "acme" = {
        "server" = "https://acme-v02.api.letsencrypt.org/directory"
        "privateKeySecretRef" = {
          "name" = "lets-encrypt-account-secret"
        }
        "solvers" = [{
          "dns01" = {
            "cloudflare" = {
              "apiTokenSecretRef" = {
                "key" = "token"
                "name" = "cloudflare-api-secret"
              }
              "email" = "${var.certificate_email}"
            }
          }
        }]
      }
    }
  }
}

variable "domain_name" {
  type = string
  description = "The domain name to place hosts when building Ingress manifests"
}

# Setup Kubernetes API server ingress
resource "kubernetes_ingress_v1" "kubernete_api_ingress" {
  metadata {
    name = "kubernetes-apiserver-ingress"
    namespace = "default"
     annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "cert-manager.io/cluster-issuer" = "lets-encrypt"
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
      "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "120"
      "nginx.ingress.kubernetes.io/proxy-read-timeout" = "180"
      "nginx.ingress.kubernetes.io/proxy-send-timeout" = "180"
      "nginx.ingress.kubernetes.io/proxy-body-size" = "10m"
    }
  }

  spec {
    rule {
      host = "k8s.${var.domain_name}"
      http {
        path {
          backend {
            service{
              name  = "kubernetes"
              port {
                number = 443
              }
            }
          }
          path = "/"
          path_type = "Prefix"
        }
      }
    }

    tls {
      hosts = ["k8s.${var.domain_name}"]
      secret_name = "kubernetes-apiserver-tls-secret"
    }
  }
}

