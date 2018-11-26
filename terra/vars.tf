variable "region" {}
variable "zone" {}
variable "instance-name" {
  type = "list"
}
variable "project-name" {}
variable "network" {}
variable "vm-type" {}
variable "os" {}
variable "credentials" {}
variable "fw-int-source-range" {
  type = "list"
}
variable "subnet-cidr" {}
variable "master-count" {}
variable "worker-count" {}
variable "scopes" {
  type = "list"
}
