# =============================================================================
# VARIABLES
# =============================================================================
# Every configurable value is declared here with a description so recruiters
# can understand what each parameter controls without reading the resource code.
# =============================================================================

variable "project_name" {
  description = "Name used for resource naming and tagging across all AWS resources"
  type        = string
  default     = "devops-terraform-api"
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod) — tagged on all resources"
  type        = string
  default     = "portfolio"
}

variable "region" {
  description = "AWS region where all resources will be provisioned"
  type        = string
  default     = "us-east-1"
}

# --- VPC & Networking ---

variable "vpc_cidr" {
  description = "CIDR block for the VPC — defines the private IP range for all subnets"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet — resources here can reach the internet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet — no direct internet access (Free Tier: no NAT)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "az_a" {
  description = "Primary availability zone"
  type        = string
  default     = "us-east-1a"
}

variable "az_b" {
  description = "Secondary availability zone for private subnet"
  type        = string
  default     = "us-east-1b"
}

# --- EC2 ---

variable "instance_type" {
  description = "EC2 instance type — t3.micro is Free Tier eligible"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of the SSH key pair to create for EC2 access"
  type        = string
  default     = "devops-terraform-key"
}

variable "app_port" {
  description = "TCP port where the Flask API will listen"
  type        = number
  default     = 5000
}

# --- Security ---

variable "allowed_ssh_cidr" {
  description = "Your public IP in CIDR notation (e.g., 203.0.113.5/32) — restricts SSH to you only"
  type        = string
  # No default: must be explicitly set in terraform.tfvars
  # Leaving SSH open to 0.0.0.0/0 is a security risk even in a portfolio project
}

# --- S3 Backend ---

variable "state_bucket_name" {
  description = "S3 bucket name for Terraform remote state (must be globally unique)"
  type        = string
  default     = "devops-terraform-state-183088117731"
}
