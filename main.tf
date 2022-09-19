
resource "google_compute_instance_template" "default" {
  name         = "default"
  machine_type = "f1-micro"

  disk {
    source_image = "debian-cloud/debian-11"
  }

  network_interface {
    network = "default"
  }
}

resource "google_compute_region_instance_group_manager" "default" {
  name   = "default"
  region = "asia-northeast1"
  version {
    instance_template = google_compute_instance_template.default.self_link
  }

  base_instance_name = "mig"
  target_size        = 6
}

resource "google_compute_region_autoscaler" "default" {
  name = "default"

  target = google_compute_region_instance_group_manager.default.self_link
  autoscaling_policy {
    max_replicas = 10
    min_replicas = 6
  }
}

resource "google_compute_health_check" "default" {
  name               = "default"
  http_health_check {
    port = 80
  }
}

resource "google_compute_firewall" "default" {
  name    = "health-check"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags = [ "allow-service" ]
}

resource "google_compute_firewall" "default_ssh" {
  name = "defdault-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [ "0.0.0.0/0" ]
  target_tags = [ "allow-ssh" ]
}
