variable "metallb_ip_pool_range" {
  type = string
  description = "IP address pool range for Load balancer's external IPs"
}

variable "nfs_subdir" {
  type = object({
    server = string
    path = string
  })
  description = "NFS subdir parameters"
}
