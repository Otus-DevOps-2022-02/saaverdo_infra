resource "google_storage_bucket" "default" {
  name          = "tf-otus-state-bucket"
  force_destroy = false
  location      = "europe-west4"
  storage_class = "STANDARD"
  versioning {
    enabled = true
  }
}
