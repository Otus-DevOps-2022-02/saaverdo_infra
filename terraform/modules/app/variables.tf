variable "public_key_path" {
  description = "Path to key for ssh access"
}

variable "app_disc_image" {
  description = "Boot image for VM"
  default     = "reddit-base-otus-app"
}
