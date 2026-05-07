# =============================================================================
# OUTPUTS
# =============================================================================
# Everything a developer or pipeline needs after terraform apply is exported here.
# =============================================================================

output "instance_id" {
  description = "EC2 instance ID — used for monitoring, debugging, and AWS Console navigation"
  value       = aws_instance.api_server.id
}

output "public_ip" {
  description = "Elastic IP address — this is the endpoint you'll curl or visit in the browser"
  value       = aws_eip.api_eip.public_ip
}

output "public_dns" {
  description = "Public DNS hostname — alternative to the IP address"
  value       = aws_eip.api_eip.public_dns
}

output "vpc_id" {
  description = "VPC ID — useful for verifying network isolation in the AWS Console"
  value       = aws_vpc.main.id
}

output "security_group_id" {
  description = "Security Group ID — used to identify the firewall rules attached to the instance"
  value       = aws_security_group.ec2_sg.id
}

output "private_key_pem" {
  description = "Private SSH key — save this to a .pem file to SSH into the instance"
  value       = tls_private_key.ssh_key.private_key_pem
  sensitive   = true
}

output "health_endpoint" {
  description = "Full URL to the health check endpoint — paste this in your browser"
  value       = "http://${aws_eip.api_eip.public_ip}:${var.app_port}/health"
}
