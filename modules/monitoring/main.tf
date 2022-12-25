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
}

resource "helm_release" "splunk_enterprise" {
  depends_on = [helm_release.splunk_operator]
  name       = "splunk-enterprise"
  chart      = "splunk-enterprise"
  repository = "https://splunk.github.io/splunk-operator"
  version    = "1.0.0"
  namespace  = local.namespace
  skip_crds  = true

  set {
    name  = "sva.s1.enabled"
    value = true
  }
  set {
    name  = "splunk-operator.enabled"
    value = false
  }

  set {
    name  = "clusterMaster.enabled"
    value = true
  }

  set {
    name  = "indexerCluster.enabled"
    value = true
  }

  set {
    name  = "searchHeadCluster.enabled"
    value = true
  }

}

data "kubernetes_secret" "splunk_secrets" {
  depends_on = [helm_release.splunk_enterprise]
  metadata {
    name      = "splunk-stdln-standalone-secret-v1"
    namespace = local.namespace
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
    file("${path.module}/kube-prometheus-stack/values.yaml")
  ]
}
