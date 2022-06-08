variable "public_key_path" {
  description = "Path to key for ssh access"
}

variable "app_disc_image" {
  description = "Boot image for VM"
  default     = "reddit-base-otus-app"
}

variable "db_ip" {
  description = "URL of database VM"
}

variable "deploy_app" {
  description = "Enable app provisioning flag"
  type = bool
  default = false
}
