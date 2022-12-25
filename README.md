# README
A Terraform module repository to manage my Kubernetes cluster add-ons.

| feature flag | description |
| - | - |
| `enable_metallb` | Turns on the MetalLB loadbalancer in the cluster. |
| `enable_nfs_subdir` | Turns on the NFS subdir provisioner as the defaultStorageClass. |
| `enable_monitoring` | Turns on Splunk with Fluent-bit for logging and Prometheus with Grafana for metrics |
| `enable_ingress_nginx` | Turns on the Nginx ingress controller |

## TODOs:
- Add Grafana support
