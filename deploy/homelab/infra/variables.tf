variable "pve_endpoint" {
  type    = string
  default = "https://192.168.3.64:8006/"
}
variable "pve_node" {
  type    = string
  default = "proxmox"
}
variable "vm_id" {
  type    = number
  default = 110
}
variable "vm_name" {
  type    = string
  default = "zomboid"
}
variable "cores" {
  type    = number
  default = 4
}
variable "memory_mb" {
  description = "RAM da VM. Servidor B42 com Xmx 8 GB + bot + SO."
  type        = number
  default     = 11264
}
variable "disk_gb" {
  type    = number
  default = 60
}
variable "datastore" {
  type    = string
  default = "local-lvm"
}
variable "image_datastore" {
  type    = string
  default = "local"
}
variable "bridge" {
  type    = string
  default = "vmbr0"
}
variable "ip_cidr" {
  type    = string
  default = "192.168.3.95/24"
}
variable "gateway" {
  type    = string
  default = "192.168.3.1"
}
variable "dns_servers" {
  type    = list(string)
  default = ["192.168.3.1", "1.1.1.1"]
}
variable "ssh_public_key" {
  description = "Chave publica para o usuario ubuntu da VM"
  type        = string
}
