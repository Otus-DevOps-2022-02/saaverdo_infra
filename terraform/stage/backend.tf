terraform {
  backend "gcs" {
    bucket = "tf-otus-state-bucket"
    prefix = "stage"
  }
}
