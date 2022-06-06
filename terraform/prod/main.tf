provider "google" {
  project = var.project
  region  = var.region
}

module "app" {
  source          = "../modules/app"
  public_key_path = var.public_key_path
  app_disc_image  = var.app_disc_image
}

module "db" {
  source          = "../modules/db"
  public_key_path = var.public_key_path
  db_disc_image   = var.db_disc_image
}

module "vpc" {
  source        = "../modules/vpc"
  source_ranges = ["0.0.0.0/0"]
}
