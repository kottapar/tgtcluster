region              = "us-west1"
zone                = "us-west1-c"
credentials         = "../creds/terra-admin.json"
instance-name       = ["master", "worker"]
project-name        = "tgtcluster"
network             = "tgtcluster-network"
vm-type             = "n1-standard-1"
os                  = "ubuntu-1804-bionic-v20181120"
subnet-cidr         = "10.240.0.0/24"
fw-int-proto        = ["icmp", "tcp", "udp"]
fw-int-source-range = ["10.240.0.0/24", "10.200.0.0/16"]
// list of cidr range to be allowed via fw rule for the http health check
lb-hchk-probe-cidr  = ["209.85.152.0/22", "209.85.204.0/22", "35.191.0.0/16"]
target-pool-ports   = "6443"
master-count        = "3"
worker-count        = "3"
scopes              = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
