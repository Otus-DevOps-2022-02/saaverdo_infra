variable "project" {
  description = "project ID"
}

variable "region" {
  description = "Region"
  default     = "europe-west4-a"
}

variable "public_key_path" {
  description = "Path to key for ssh access"
}

variable "disk_image" {
  description = "Disk image name"
}

variable "provision_key_path" {
  description = "Path to key for provisioners access"
}
