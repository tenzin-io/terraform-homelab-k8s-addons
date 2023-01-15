# README
A Terraform module repository to manage my Kubernetes cluster add-ons.

| feature flag | description |
| - | - |
| `enable_metallb` | Turns ON the MetalLB loadbalancer in the cluster. |
| `enable_nfs_subdir` | Turns on the NFS subdir provisioner as the default storage class. |
| `enable_monitoring` | Turns ON Splunk with Fluent-bit for logging and Prometheus with Grafana for metrics. The `enable_nfs_subdir` must be set to `true`, because this feature needs to create persistent volumes. |
| `enable_ingress_nginx` | Turns ON the Nginx ingress controller. Integrated with cert-manager, using Lets Encrypt + CloudFlare as the solver method. |
| `enable_vault` | Turns ON the Vault add-on. |
| `enable_github_actions_runner` | Turns ON the GitHub Actions Runner add-on. |
