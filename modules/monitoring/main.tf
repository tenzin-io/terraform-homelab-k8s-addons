#
# Splunk
#
locals {
  namespace = "monitoring"
}

resource "helm_release" "splunk_operator" {
  name             = "splunk-operator"
  chart            = "splunk-operator"
  repository       = "https://splunk.github.io/splunk-operator"
  version          = "1.0.0"
  namespace        = local.namespace
  create_namespace = true
  wait_for_jobs    = true
}

resource "helm_release" "splunk_enterprise" {
  depends_on = [helm_release.splunk_operator]
  name       = "splunk-enterprise"
  chart      = "splunk-enterprise"
  repository = "https://splunk.github.io/splunk-operator"
  version    = "1.0.0"
  namespace  = local.namespace
  skip_crds  = true
  values = [
    file("${path.module}/splunk-enterprise/values.yaml")
  ]
}

# Wait 10 seconds after Helm installation of Splunk Enterprise chart.
# Terraform tries to read the splunk_secrets immediately and Splunk has yet to create them, which results in an error.
resource "time_sleep" "wait_10_seconds" {
  depends_on      = [helm_release.splunk_enterprise]
  create_duration = "10s"
}

data "kubernetes_secret" "splunk_secrets" {
  depends_on = [time_sleep.wait_10_seconds]
  metadata {
    name      = "splunk-stdln-standalone-secret-v1"
    namespace = local.namespace
  }
}

variable "domain_name" {
  type        = string
  description = "The domain name to place hosts when building Ingress manifests"
}

# Setup Splunk Ingress
resource "kubernetes_ingress_v1" "splunk_ingress" {
  depends_on = [helm_release.splunk_enterprise]
  metadata {
    name      = "splunk-ingress"
    namespace = local.namespace
    annotations = {
      "kubernetes.io/ingress.class"    = "nginx"
      "cert-manager.io/cluster-issuer" = "lets-encrypt"
    }
  }

  spec {
    rule {
      host = "splunk.${var.domain_name}"
      http {
        path {
          backend {
            service {
              name = "splunk-stdln-standalone-service"
              port {
                name = "http-splunkweb"
              }
            }
          }
          path      = "/"
          path_type = "Prefix"
        }
      }
    }

    tls {
      hosts       = ["splunk.${var.domain_name}"]
      secret_name = "splunk-tls-secret"
    }
  }
}

#
# Fluent Bit
#
resource "helm_release" "fluent_bit" {
  depends_on = [helm_release.splunk_operator]
  name       = "fluent-bit"
  chart      = "fluent-bit"
  repository = "https://fluent.github.io/helm-charts"
  version    = "0.21.6"
  namespace  = local.namespace
  set {
    name  = "config.outputs"
    value = data.template_file.fluent_bit_config_outputs.rendered
  }
}

data "template_file" "fluent_bit_config_outputs" {
  template = file("${path.module}/fluent-bit/config.outputs.ini")
  vars = {
    splunk_hec_token = "${data.kubernetes_secret.splunk_secrets.data.hec_token}"
    splunk_host      = "splunk-stdln-standalone-service"
    splunk_hec_port  = "8088"
  }
}

#
# Prometheus operator
#
resource "helm_release" "prometheus" {
  depends_on = [helm_release.splunk_operator]
  name       = "prometheus"
  chart      = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  version    = "43.1.4"
  namespace  = local.namespace
  values = [
    data.template_file.prometheus_values.rendered
  ]
}

data "template_file" "prometheus_values" {
  template = file("${path.module}/kube-prometheus-stack/values.yaml")
  vars = {
    grafana_admin_password = "${data.kubernetes_secret.splunk_secrets.data.password}"
  }
}

# Setup Grafana Ingress
resource "kubernetes_ingress_v1" "grafana_ingress" {
  depends_on = [helm_release.prometheus]
  metadata {
    name      = "grafana-ingress"
    namespace = local.namespace
    annotations = {
      "kubernetes.io/ingress.class"    = "nginx"
      "cert-manager.io/cluster-issuer" = "lets-encrypt"
    }
  }

  spec {
    rule {
      host = "grafana.${var.domain_name}"
      http {
        path {
          backend {
            service {
              name = "prometheus-grafana"
              port {
                name = "http-web"
              }
            }
          }
          path      = "/"
          path_type = "Prefix"
        }
      }
    }

    tls {
      hosts       = ["grafana.${var.domain_name}"]
      secret_name = "grafana-tls-secret"
    }
  }
}


#
# Metrics server
#

resource "helm_release" "metrics_server" {
  depends_on = [helm_release.prometheus]
  name       = "metrics-server"
  chart      = "metrics-server"
  version    = "3.8.3"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  namespace  = local.namespace

  set {
    name  = "metrics.enabled"
    value = true
  }
  set {
    name = "args"
    value = "{--kubelet-insecure-tls}"
  }

  set {
    name  = "serviceMonitor.enabled"
    value = true
  }

}
