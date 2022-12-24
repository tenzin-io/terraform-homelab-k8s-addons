provider "helm" {
  kubernetes {
    config_path    = var.kubernetes.config_path
    config_context = var.kubernetes.context
  }
}

provider "kubernetes" {
  config_path    = var.kubernetes.config_path
  config_context = var.kubernetes.context
}

#
# Metal LB
#
resource "helm_release" "metallb" {
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  version          = "0.13.7"
  namespace        = "metallb-system"
  create_namespace = true
}

resource "helm_release" "metallb_config" {
  depends_on = [helm_release.metallb]
  name       = "metallb-config"
  chart      = "${path.module}/metallb-config-chart"

  set {
    name  = "metallb_ip_pool_range"
    value = var.metallb_ip_pool_range
  }

}

#
# NFS subdir provisioner
#
resource "helm_release" "nfs_subdir" {
  name             = "nfs-subdir"
  repository       = "https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner"
  chart            = "nfs-subdir-external-provisioner"
  version          = "4.0.16"
  namespace        = "storage-system"
  create_namespace = true

  set {
    name  = "nfs.server"
    value = var.nfs_subdir.server
  }

  set {
    name  = "nfs.path"
    value = var.nfs_subdir.path
  }

  set {
    name  = "nfs.mountOptions"
    value = "{nodiratime,noatime,nfsvers=3,nconnect=16,noacl,nolock}"
  }

  set {
    name  = "storageClass.defaultClass"
    value = true
  }
}

#
# Splunk
#
resource "helm_release" "splunk_operator" {
  name             = "splunk-operator"
  chart            = "splunk-operator"
  repository       = "https://splunk.github.io/splunk-operator"
  version          = "1.0.0"
  namespace        = "monitoring"
  create_namespace = true
}

resource "helm_release" "splunk_enterprise" {
  depends_on = [helm_release.splunk_operator]
  name       = "splunk-enterprise"
  chart      = "splunk-enterprise"
  repository = "https://splunk.github.io/splunk-operator"
  version    = "1.0.0"
  namespace  = "monitoring"
  skip_crds  = true

  set {
    name = "sva.s1.enabled"
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
  metadata {
    name = "splunk-stdln-standalone-secret-v1"
    namespace = "monitoring"
  }
}

#
# Fluent Bit
#
resource "helm_release" "fluent_bit" {
  depends_on = [helm_release.splunk_operator]
  name = "fluent-bit"
  chart = "fluent-bit"
  repository = "https://fluent.github.io/helm-charts"
  version = "0.21.6"
  namespace = "monitoring"
  set {
    name = "config.outputs"
    value = "${data.template_file.fluent_bit_config_outputs.rendered}"
  }
}

data "template_file" "fluent_bit_config_outputs" {
  template = file("${path.module}/fluent-bit/config.outputs.ini")
  vars = {
    splunk_hec_token = "${data.kubernetes_secret.splunk_secrets.data.hec_token}"
    splunk_host = "splunk-stdln-standalone-service"
    splunk_hec_port = "8088"
  }
}

