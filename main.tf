# --- 1. VARIÁVEIS E PROVEDORES ---
variable "aws_region" { default = "us-east-1" }
variable "suffix" { default = "demo-01" }
variable "gcp_project_id" { type = string }
variable "gcp_region" { 
  type        = string
  default     = "us-central1"
}

terraform {
  required_version = ">= 0.14.9"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 3.27" }
    google = { source = "hashicorp/google", version = "4.51.0" }
  }
}

# --- Provedores ---
provider "aws" {
  region  = "us-east-1"
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# --- 2. INFRAESTRUTURA AWS (Lado Destino) ---

resource "aws_vpc" "aws_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "aws_sub" {
  vpc_id     = aws_vpc.aws_vpc.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_s3_bucket" "private_bucket" {
  bucket = "tfc-private-demo-${var.suffix}"
}

# Interface Endpoint (PrivateLink) - Essencial para acesso via VPN
resource "aws_vpc_endpoint" "s3_interface" {
  vpc_id            = aws_vpc.aws_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.aws_sub.id]
  security_group_ids = [aws_security_group.allow_gcp_traffic.id]
}

resource "aws_security_group" "allow_gcp_traffic" {
  name   = "allow_gcp_via_vpn"
  vpc_id = aws_vpc.aws_vpc.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["192.168.1.0/24"] # IP da Subnet do GCP
  }
}

# --- 3. INFRAESTRUTURA GCP (Lado Origem) ---

resource "google_compute_network" "gcp_vpc" {
  name = "gcp-vpc-multicloud"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "gcp_sub" {
  name          = "gcp-sub-latam"
  ip_cidr_range = "192.168.1.0/24"
  network       = google_compute_network.gcp_vpc.id
}

# DNS PRIVADO: O "Pulo do Gato" para a VM achar o S3 via IP Privado
resource "google_dns_managed_zone" "s3_private_zone" {
  name        = "s3-aws-zone"
  dns_name    = "amazonaws.com."
  visibility  = "private"
  private_visibility_config {
    networks { network_url = google_compute_network.gcp_vpc.id }
  }
}

resource "google_dns_record_set" "s3_endpoint_record" {
  name         = "s3.${var.aws_region}.amazonaws.com."
  managed_zone = google_dns_managed_zone.s3_private_zone.name
  type         = "A"
  ttl          = 300
  rrdatas      = [aws_vpc_endpoint.s3_interface.dns_entry[0].ip_address]
}

# VM COM STARTUP SCRIPT PARA TESTE AUTOMATIZADO
resource "google_compute_instance" "vm_client" {
  name         = "gcp-vm-analyst"
  machine_type = "e2-micro"
  zone         = "${var.gcp_region}-a"

  boot_disk {
    initialize_params { image = "debian-cloud/debian-11" }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.gcp_sub.id
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y awscli dnsutils
    
    # Registra o log do teste
    echo "Iniciando teste de conectividade Multicloud..." > /var/log/multicloud_test.log
    
    # 1. Teste de DNS
    nslookup s3.${var.aws_region}.amazonaws.com >> /var/log/multicloud_test.log
    
    # 2. Teste de Rota (Simulação de comando AWS)
    # Nota: Em aula, você deve configurar as chaves AWS para este comando funcionar
    echo "Para testar o bucket use: aws s3 ls s3://${aws_s3_bucket.private_bucket.id} --region ${var.aws_region}" >> /var/log/multicloud_test.log
  EOT
}
