provider "helm" {
  kubernetes {
    config_path = var.kubernetes.config_path
    config_context = var.kubernetes.context
  }
}

provider "kubernetes" {
    config_path = var.kubernetes.config_path
    config_context = var.kubernetes.context
}

#
# Metal LB
#
resource "helm_release" "metallb" {
  name       = "metallb"
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"
  version    = "0.13.7"
  namespace  = "metallb-system"
  create_namespace = true
}

resource "helm_release" "metallb_config" {
  depends_on = [ helm_release.metallb ]
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
  name = "nfs-subdir"
  repository = "https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner"
  chart = "nfs-subdir-external-provisioner"
  version = "4.0.16"
  namespace = "storage-system"
  create_namespace = true

  set {
    name  = "nfs.server"
    value = var.nfs_subdir.server
  }

  set {
    name = "nfs.path"
    value = var.nfs_subdir.path
  }

  set {
    name = "nfs.mountOptions"
    value = "{nodiratime,noatime,nfsvers=3,nconnect=16,noacl,nolock}"
  }

  set {
    name = "storageClass.defaultClass"
    value = true
  }
}
