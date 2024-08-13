output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.demo_server.public_ip
}

output "ip" {
  description = "Public IP address of the GCE instance"
  value       = google_compute_instance.vm_instance.network_interface.0.network_ip
}
