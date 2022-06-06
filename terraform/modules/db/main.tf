resource "google_compute_instance" "db" {
  name         = "reddit-db"
  machine_type = "g1-small"
  zone         = "europe-west4-a"
  tags         = ["reddit-db"]
  # boot disk definition
  boot_disk {
    initialize_params {
      image = var.db_disc_image
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
  #connection {
  #  type  = "ssh"
  #  host  = google_compute_instance.app.network_interface.0.access_config.0.nat_ip
  #  user  = "appuser"
  #  agent = true
  #  # т.к. был создан ключ с паролем, используется опция agent, взаимоисключающая с private_key
  #  #private_key = "${file(var.provision_key_path)}"
  #}
  #provisioner "file" {
  #  source      = "files/puma.service"
  #  destination = "/tmp/puma.service"
  #}
  #provisioner "remote-exec" {
  #  script = "files/deploy.sh"
  #}
}

resource "google_compute_firewall" "firewall-mongo" {
  name = "allow-mongo-default"
  # network where the rule applied
  network = "default"
  #
  allow {
    protocol = "tcp"
    ports    = ["27017"]
  }
  # rule SRC tagss
  source_tags = ["reddit-app"]
  # rule target tags
  target_tags = ["reddit-db"]
}
