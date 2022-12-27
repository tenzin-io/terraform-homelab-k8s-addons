# README
This is a local Helm chart that deploys a *simple* `ClusterIssuer` custom resource.  This chart is installed after `cert-manager` Helm chart.
This deployment is specific to my use case, which is Let's Encrypt issuer with CloudFlare DNS challenge.

Helpful tutorial found here:
- <https://cert-manager.io/docs/tutorials/acme/nginx-ingress/>
