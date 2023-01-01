
resource helm_release "artifactory" {
  repository = "https://charts.jfrog.io"
  name = "artifactory"
  chart = "artifactory-jcr"
  version = "107.49.3"
  namespace = "jfrog-system"
  create_namespace = true

  values = [ data.template_file.artifactory_values.rendered ]
}

variable "external_domain_name" {
  type = string
  description = "The external domain name to append to hostnames"
}

data "template_file" "artifactory_values" {
  template = file("${path.module}/values.yaml")
  vars = {
    external_domain_name = var.external_domain_name
  }
}
