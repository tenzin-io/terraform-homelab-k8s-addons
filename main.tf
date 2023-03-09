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

variable "external_domain_name" {
  type        = string
  description = "The external domain name to place hosts when building Ingress manifests"
  default     = null
}

variable "alert_receiver_name" {
  type = string
  default = null
}
variable "alert_receiver_url" {
  type = string
  default = null
}
variable "alert_receiver_username" {
  type = string
  default = null
}
variable "alert_receiver_password" {
  type = string
  default = null
}

variable "grafana_admin_password" {
  type = string
  sensitive = true
  default = null
}

module "monitoring" {
  depends_on           = [module.nfs_subdir]
  count                = var.enable_monitoring && var.enable_nfs_subdir ? 1 : 0
  source               = "./modules/monitoring"
  external_domain_name = var.external_domain_name

  grafana_admin_password = var.grafana_admin_password

  alert_receiver_name = var.alert_receiver_name
  alert_receiver_url = var.alert_receiver_url
  alert_receiver_username= var.alert_receiver_username
  alert_receiver_password = var.alert_receiver_password
}

#
# Nginx ingress add-on
#
variable "enable_ingress_nginx" {
  type        = bool
  description = "Enable the Nginx ingress add-on"
  default     = false
}

variable "tailscale_auth_key" {
  type        = string
  description = "The Tailscale auth key to join to the tailnet."
  default     = null
}

variable "cloudflare_api_token" {
  type        = string
  description = "CloudFlare API token"
  sensitive   = true
  default     = null
}

variable "contact_email" {
  type        = string
  description = "Certificate expiry contact email."
  default     = null
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



module "ingress_nginx" {
  depends_on               = [module.monitoring]
  count                    = var.enable_ingress_nginx ? 1 : 0
  source                   = "./modules/ingress-nginx"
  monitoring_enabled       = var.enable_monitoring
  cloudflare_api_token     = var.cloudflare_api_token
  tailscale_auth_key       = var.tailscale_auth_key
  contact_email            = var.contact_email
  external_domain_name     = var.external_domain_name
  enable_external_services = var.enable_external_services
  external_services        = var.external_services
}

#
# Vault add-on
#
variable "enable_vault" {
  type        = bool
  description = "Enable the Vault add-on"
  default     = false
}

variable "vault_backup_git_url" {
  type        = string
  description = "A URL to a Git repo containing the Vault data backup."
  default     = null
}

module "vault" {
  depends_on           = [module.monitoring]
  count                = var.enable_vault ? 1 : 0
  source               = "./modules/vault"
  monitoring_enabled   = var.enable_monitoring
  vault_backup_git_url = var.vault_backup_git_url
  external_domain_name = var.external_domain_name
}

variable "enable_github_actions_runner" {
  type    = bool
  default = false
}

variable "github_org_name" {
  type    = string
  default = null
}

variable "github_app_id" {
  type    = string
  default = null
}

variable "github_app_installation_id" {
  type    = string
  default = null
}

variable "github_app_private_key" {
  type      = string
  sensitive = true
  default   = null
}

module "github_actions_runner_controller" {
  depends_on                 = [module.ingress_nginx]
  count                      = var.enable_github_actions_runner ? 1 : 0
  source                     = "./modules/actions-runner-controller"
  github_app_id              = var.github_app_id
  github_app_installation_id = var.github_app_installation_id
  github_app_private_key     = var.github_app_private_key
  github_org_name            = var.github_org_name
}
