resource "google_compute_instance" "app" {
  name         = "reddit-app"
  machine_type = "g1-small"
  zone         = "europe-west4-a"
  tags         = ["reddit-app"]
  # boot disk definition
  boot_disk {
    initialize_params {
      image = var.app_disc_image
    }
  }
  # network interface definition
  network_interface {
    # network this interface to be attached
    network = "default"
    # we'll use ephemeral IP to have access from the Internet
    access_config {
      nat_ip = google_compute_address.app_ip.address
    }
  }
  metadata = {
    sshKeys = "appuser:${file(var.public_key_path)}"
  }
  depends_on = [local_file.gen_service_file]
}

resource "null_resource" "provisioner" {
  count = var.deploy_app ? 1 : 0
  connection {
    type  = "ssh"
    host  = google_compute_instance.app.network_interface.0.access_config.0.nat_ip
    user  = "appuser"
    agent = true
    # т.к. был создан ключ с паролем, используется опция agent, взаимоисключающая с private_key
    #private_key = "${file(var.provision_key_path)}"
  }
  provisioner "file" {
    source      = "../modules/app/files/puma.service"
    destination = "/tmp/puma.service"
  }
  provisioner "remote-exec" {
    script = "../modules/app/files/deploy.sh"
  }
  depends_on = [local_file.gen_service_file]
}

resource "local_file" "gen_service_file" {
    content = templatefile("../modules/app/files/puma.service.tpl", {
      db_url = var.db_ip
    })
    filename = "./files/puma.service"
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

resource "google_compute_firewall" "firewall-web" {
  name = "allow-web-default"
  # network where the rule applied
  network = "default"
  #
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  # rule SRC addresses
  source_ranges = ["0.0.0.0/0"]
  # apply the rule to instances with tags
  target_tags = ["reddit-app"]
}

resource "google_compute_address" "app_ip" {
  name   = "reddit-app-ip"
  region = "europe-west4"
}
