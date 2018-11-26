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

// Create a static ip to front the API servers

resource "google_compute_address" "lb-static-ip" {
  name = "lb-static-ip"
}

// Create the master instances

resource "google_compute_instance" "master" {
  count        = "${var.master-count}"
  name         = "master${count.index}"
  machine_type = "${var.vm-type}"
  zone         = "${var.zone}"
  tags         = ["tgtcluster", "master"]

  boot_disk {
    initialize_params {
      image = "${var.os}"
    }
  }

  network_interface {
    network_ip = "10.240.0.1${count.index}"
    subnetwork = "${google_compute_subnetwork.subnet.name}"
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

  boot_disk {
    initialize_params {
      image = "${var.os}"
    }
  }

  network_interface {
    network_ip = "10.240.0.2${count.index}"
    subnetwork = "${google_compute_subnetwork.subnet.name}"
  }
  service_account {
    scopes = "${var.scopes}"
  }
  metadata {
    pod-cidr = "10.200.${count.index}.0/24"
  }
}





