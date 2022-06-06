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
  default     = "reddit-base-otus-w-hw5"
}

variable "provision_key_path" {
  description = "Path to key for provisioners access"
}

variable "app_disc_image" {
  description = "Boot image for VM"
  default     = "reddit-base-otus-app"
}

variable "db_disc_image" {
  description = "Boot image for VM"
  default     = "reddit-base-otus-db"
}
