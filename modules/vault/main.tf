#
# Vault add-on
#

variable "monitoring_enabled" {
  type        = bool
  default     = false
  description = "Is monitoring add-on enabled?"
}

variable "vault_backup_git_url" {
  type = string
  description = "A URL to a Git repo containing the Vault data backup."
}

variable "external_domain_name" {
  type        = string
  description = "The external domain name to place hosts when building Ingress manifests"
}

resource "helm_release" "vault" {
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  name             = "vault"
  namespace        = "vault-system"
  version          = "0.23.0"
  create_namespace = true

  values = [
    data.template_file.vault_values.rendered
    ]
}

data "template_file" "vault_values" {
  template = file("${path.module}/values.yaml")
  vars = {
    monitoring_enabled = var.monitoring_enabled
    vault_backup_git_url = var.vault_backup_git_url
    external_domain_name = var.external_domain_name
  }
}
