terraform {

  required_version = ">= 0.14.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }

    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
  }

}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

provider "google" {
  project = "solid-solstice-312901"
}

# AWS Resource #
resource "aws_instance" "demo_server" {
  ami           = "ami-02e136e904f3da870"
  instance_type = "t2.medium"
  tags = {
    Name = "Demo-TFC3"
  }
}

# GCP Resource #
resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
}

resource "google_compute_instance" "vm_instance" {
  name         = "terraform-instance2"
  machine_type = "f1-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
    }
  }
}
