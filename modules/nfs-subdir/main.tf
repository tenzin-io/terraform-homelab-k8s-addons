#
# NFS subdir provisioner
#

variable "server" {
  type        = string
  description = "The NFS server"
}

variable "mountOptions" {
  type        = string
  default     = "noatime,nodiratime,nfsvers=3,nconnect=16,noacl,nolock"
  description = "The NFS share mount options"
}

variable "path" {
  type        = string
  description = "The NFS share path"
}

variable "defaultStorageClass" {
  type        = bool
  description = "Configure this volume provisioner to be the default storage class"
  default     = true
}

locals {
  namespace = "storage"
}


resource "kubernetes_namespace_v1" "storage" {
  metadata {
    name = local.namespace
  }
}

resource "helm_release" "nfs_subdir" {
  depends_on = [kubernetes_namespace_v1.storage]
  name       = "nfs-subdir"
  repository = "https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner"
  chart      = "nfs-subdir-external-provisioner"
  version    = "4.0.16"
  namespace  = local.namespace

  set {
    name  = "nfs.server"
    value = var.server
  }

  set {
    name  = "nfs.path"
    value = var.path
  }

  set {
    name  = "nfs.mountOptions"
    value = "{${var.mountOptions}}"
  }

  set {
    name  = "storageClass.defaultClass"
    value = var.defaultStorageClass
  }
}

