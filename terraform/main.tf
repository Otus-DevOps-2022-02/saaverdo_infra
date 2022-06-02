provider "google" {
  project = var.project
  region  = var.region
}

resource "google_compute_instance" "app" {
  name         = "reddit-app"
  machine_type = "g1-small"
  zone         = "europe-west4-a"
  tags         = ["reddit-app"]
  # boot disk definition
  boot_disk {
    initialize_params {
      image = var.disk_image
    }
  }
  # network interface definition
  network_interface {
    # network this interface to be attached
    network = "default"
    # we'll use ephemeral IP to have access from the Internet
    access_config {}
  }
  metadata = {
    sshKeys = "appuser:${file(var.public_key_path)}"
  }
  connection {
    type  = "ssh"
    host  = google_compute_instance.app.network_interface.0.access_config.0.nat_ip
    user  = "appuser"
    agent = true
    # т.к. был создан ключ с паролем, используется опция agent, взаимоисключающая с private_key
    #private_key = "${file(var.provision_key_path)}"
  }
  provisioner "file" {
    source      = "files/puma.service"
    destination = "/tmp/puma.service"
  }
  provisioner "remote-exec" {
    script = "files/deploy.sh"
  }
}

resource "google_compute_firewall" "firewall-puma" {
  name = "allow-puma-default"
  # network where the rule applied
  network = "default"
  #
  allow {
    protocol = "tcp"
    ports    = ["9292"]
  }
  # rule SRC addresses
  source_ranges = ["0.0.0.0/0"]
  # apply the rule to instances with tags
  target_tags = ["reddit-app"]
}
