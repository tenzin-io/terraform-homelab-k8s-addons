terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

#
# MetalLB add-on
#
variable "enable_metallb" {
  type        = bool
  description = "Enable MetalLB add-on"
  default     = false
}

variable "metallb_params" {
  type = object({
    ip_pool_range = string
  })

  default = {
    ip_pool_range = "10.0.0.1-10.0.0.10"
  }
}

module "metallb" {
  count         = var.enable_metallb ? 1 : 0
  source        = "./modules/metallb"
  ip_pool_range = var.metallb_params.ip_pool_range
}

#
# NFS subdir provisioner add-on
#
variable "enable_nfs_subdir" {
  type        = bool
  description = "Enable the NFS subdir provisioner add-on"
  default     = false
}

variable "nfs_subdir_params" {
  type = object({
    server              = string
    path                = string
    mountOptions        = string
    defaultStorageClass = bool
  })
  default = {
    server              = "nfsserver-1"
    path                = "/vmgr"
    mountOptions        = "nfsvers=3"
    defaultStorageClass = true
  }
}

module "nfs_subdir" {
  count               = var.enable_nfs_subdir ? 1 : 0
  source              = "./modules/nfs-subdir"
  server              = var.nfs_subdir_params.server
  path                = var.nfs_subdir_params.path
  mountOptions        = var.nfs_subdir_params.mountOptions
  defaultStorageClass = var.nfs_subdir_params.defaultStorageClass
}

#
# Monitoring add-on
# Adds Splunk, Fluent Bit, Prometheus, Grafana
#
variable "enable_monitoring" {
  type        = bool
  description = "Enable the Monitoring add-on"
  default     = false
}

module "monitoring" {
  depends_on = [ module.nfs_subdir ]
  count  = var.enable_monitoring ? 1 : 0
  source = "./modules/monitoring"
}

#
# Nginx ingress add-on
#
variable "enable_ingress_nginx" {
  type = bool
  description = "Enable the Nginx ingress add-on"
  default = false
}

module "ingress_nginx" {
  depends_on = [module.monitoring]
  count = var.enable_ingress_nginx ? 1 : 0
  source = "./modules/ingress-nginx"
  monitoring_enabled = var.enable_monitoring
}
