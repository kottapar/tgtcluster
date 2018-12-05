// Configure the provider
provider "google" {
  credentials = "${file("${var.credentials}")}"
  project     = "${var.project-name}"
  region      = "${var.region}"
}

// Create the VPC
resource "google_compute_network" "vpc" {
  name                    = "${var.project-name}-vpc"
  auto_create_subnetworks = "false"
}

// Create the subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.project-name}-subnet"
  ip_cidr_range = "${var.subnet-cidr}"
  network       = "${var.project-name}-vpc"
  depends_on    = ["google_compute_network.vpc"]
  region        = "${var.region}"
}

// Create the firewall config
resource "google_compute_firewall" "allow-internal" {
  name    = "${var.project-name}-firewall-int"
  network = "${google_compute_network.vpc.name}"
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = "${var.fw-int-source-range}"
}

resource "google_compute_firewall" "allow-external" {
  name    = "${var.project-name}-firewall-ext"
  network = "${google_compute_network.vpc.name}"
  allow {
    protocol = "tcp"
    ports    = ["22", "6443"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-lb-health-check" {
  name          = "${var.project-name}-firewall-lb-health-check"
  network       = "${google_compute_network.vpc.name}"
  source_ranges = "${var.lb-hchk-probe-cidr}"
  allow {
    protocol = "tcp"
  }
}

// Create a static ip to front the API servers
resource "google_compute_address" "lb-static-ip" {
  name = "lb-static-ip"
}

// Create a load balancer for the API servers
resource "google_compute_health_check" "kubernetes-health-check" {
  name         = "kubernetes-health-check"
  http_health_check {
    host         = "kubernetes.default.svc.cluster.local"
    request_path = "/healthz"
  }
}

// create a target pool for the network load balancer
resource "google_compute_target_pool" "pool" {
  name        = "api-target-pool"
  region      = "${var.region}"
  instances   = ["${google_compute_instance.master.*.self_link}"]
}


// create a forwarding rule to direct traffic to target pool
resource "google_compute_forwarding_rule" "fwd-rule" {
  name          = "api-forward-rule"
  ip_address    = "${google_compute_address.lb-static-ip.address}"
  port_range    = "${var.target-pool-ports}"
  region        = "${var.region}"
  target        = "${google_compute_target_pool.pool.self_link}"
}

// Create routes for traffic from pod cidrs to worker ip so the pods can talk to one another
resource "google_compute_route" "pod-route" {
  count       = "${var.worker-count}"
  name        = "pod-route-10-200-${count.index}"
  network     = "${google_compute_network.vpc.name}"
  dest_range  = "${google_compute_instance.worker.*.metadata.pod-cidr[count.index]}"
  next_hop_ip = "${google_compute_instance.worker.*.network_interface.0.address[count.index]}"
}

// Create the master instances
resource "google_compute_instance" "master" {
  count          = "${var.master-count}"
  name           = "master${count.index}"
  machine_type   = "${var.vm-type}"
  zone           = "${var.zone}"
  tags           = ["tgtcluster", "master"]
  can_ip_forward = "true"
  boot_disk {
    initialize_params {
      image = "${var.os}"
    }
  }

  network_interface {
    network_ip     = "10.240.0.1${count.index}"
    subnetwork     = "${google_compute_subnetwork.subnet.name}"
    access_config {
      // Leaving this blank will auto-assign external ip
    }
  }
  service_account {
    scopes = "${var.scopes}"
  }
}


// Create the worker instances
resource "google_compute_instance" "worker" {
  count        = "${var.worker-count}"
  name         = "worker${count.index}"
  machine_type = "${var.vm-type}"
  zone         = "${var.zone}"
  tags         = ["tgtcluster", "worker"]
  can_ip_forward = "true"
  boot_disk {
    initialize_params {
      image = "${var.os}"
    }
  }

  network_interface {
    network_ip = "10.240.0.2${count.index}"
    subnetwork = "${google_compute_subnetwork.subnet.name}"
    access_config {
      // Leaving this blank will auto-assign external ip
    }
  }
  service_account {
    scopes = "${var.scopes}"
  }
  metadata {
    pod-cidr = "10.200.${count.index}.0/24"
  }
}

