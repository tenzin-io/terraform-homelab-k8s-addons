#
# Splunk
#
locals {
  namespace = "monitoring"
}

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = local.namespace
  }
}

resource "helm_release" "splunk_enterprise" {
  depends_on    = [kubernetes_namespace_v1.monitoring]
  name          = "splunk-enterprise"
  chart         = "splunk-enterprise"
  repository    = "https://splunk.github.io/splunk-operator"
  version       = "2.2.0"
  namespace     = local.namespace
  wait_for_jobs = true
  set {
    name  = "sva.s1.enabled"
    value = true
  }

  set {
    name  = "splunk-operator.enabled"
    value = true
  }

  set {
    name  = "clusterMaster.enabled"
    value = true
  }

  set {
    name  = "searchHeadCluster.enabled"
    value = true
  }
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

variable "external_domain_name" {
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
      host = "splunk.${var.external_domain_name}"
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
      hosts       = ["splunk.${var.external_domain_name}"]
      secret_name = "splunk-tls-secret"
    }
  }
}

#
# Fluent Bit
#
resource "helm_release" "fluent_bit" {
  depends_on = [helm_release.splunk_enterprise]
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
  depends_on = [helm_release.splunk_enterprise]
  template = file("${path.module}/templates/fluent-bit/config.outputs.ini")
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
  depends_on = [kubernetes_namespace_v1.monitoring]
  name       = "prometheus"
  chart      = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  version    = "45.7.1"
  namespace  = local.namespace
  values = [
    data.template_file.prometheus_values.rendered
  ]
}

data "template_file" "prometheus_values" {
  template = file("${path.module}/templates/kube-prometheus-stack/values.yaml")
  vars = {
    grafana_admin_password = var.grafana_admin_password
    external_domain_name   = var.external_domain_name
    alert_receiver_name = var.alert_receiver_name
    alert_receiver_url = var.alert_receiver_url
    alert_receiver_username = var.alert_receiver_username
    alert_receiver_password = var.alert_receiver_password
  }
}

variable "grafana_admin_password" {
  type = string
  description = "Grafana admin user password"
  sensitive = true
}

variable "alert_receiver_name" {
  type = string
  description = "Name of the AlertManager receiver"
}

variable "alert_receiver_url" {
  type = string
  description = "API URL to send webhook Alert requests"
}

variable "alert_receiver_username" {
  type = string
  description = "Username to use the API"
}

variable "alert_receiver_password" {
  type = string
  sensitive = true
  description = "Password to use the API"
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
    name  = "args"
    value = "{--kubelet-insecure-tls}"
  }

  set {
    name  = "serviceMonitor.enabled"
    value = true
  }

  set {
    name  = "serviceMonitor.interval"
    value = "15s"
  }

  set {
    name  = "serviceMonitor.additionalLabels.release"
    value = "prometheus"
  }

}
