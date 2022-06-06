variable "public_key_path" {
  description = "Path to key for ssh access"
}

variable "db_disc_image" {
  description = "Boot image for VM"
  default     = "reddit-base-otus-db"
}
