
resource "google_compute_instance_template" "default" {
  name         = "default"
  machine_type = "f1-micro"
  region = var.gcp_region

  metadata_startup_script = file("./gceme.sh.tpl")

  tags = [ "allow-ssh","allow-service" ]
  labels = {
    "key" = "value"
  }

  disk {
    source_image = "debian-cloud/debian-11"
  }

  network_interface {
    network = "default"
  }
}

resource "google_compute_router" "default" {
  name = "default"
  region = var.gcp_region
  network = "default"
}

resource "google_compute_router_nat" "default" {
  name = "default"
  router = google_compute_router.default.name
  region = google_compute_router.default.region
  # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat#source_subnetwork_ip_ran› ›ges_to_nat
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES" 
  # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat#nat_ip_allocate_option
  nat_ip_allocate_option = "AUTO_ONLY"
}

resource "google_compute_region_instance_group_manager" "default" {
  name   = "default"
  region = var.gcp_region
  version {
    instance_template = google_compute_instance_template.default.self_link
  }

  base_instance_name = "mig"
  target_size        = null

  auto_healing_policies {
    health_check      = google_compute_health_check.default.self_link
    initial_delay_sec = 30
  }
  timeouts {
    create = "15m"
  }
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

resource "google_compute_backend_service" "backend1" {
  name          = "default"
  backend {
    group = google_compute_region_instance_group_manager.default.instance_group
  }
  health_checks = [google_compute_health_check.mig_helth_check.self_link]

  protocol      = "HTTP"
  timeout_sec   = 10
  port_name     = "http"
}

resource "google_compute_url_map" "default" {
  name            = "default"
  default_service = google_compute_backend_service.backend1.self_link
}

resource "google_compute_target_http_proxy" "default" {
  name        = "default"
  url_map     = google_compute_url_map.default.self_link
  ssl_certificates = [google_compute_managed_ssl_certificate.example.self_link]
}

resource "google_compute_ssl_certificate" "example" {
  name        = "example"
  private_key = tls_private_key.example.private_key_pem
  certificate = tls_self_signed_cert.example.cert_pem
}

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 2048
}