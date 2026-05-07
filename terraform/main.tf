# =============================================================================
# MAIN RESOURCES
# =============================================================================
# Every resource below has a comment explaining:
#   1. WHAT it does
#   2. WHY we need it
#   3. WHAT would break without it
# =============================================================================

# =========================================================================== #
# DATA SOURCE — Latest Amazon Linux 2023 AMI
# =========================================================================== #
# Without this: we'd hardcode an AMI ID that becomes stale. Using a data
# source ensures we always launch the latest patched image.
# =========================================================================== #
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# =========================================================================== #
# VPC — Virtual Private Cloud
# =========================================================================== #
# Without a VPC: EC2 would launch in the default VPC which has no custom
# subnets, no isolation, and poor security posture.
# =========================================================================== #
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # Required so instances can resolve DNS names
  enable_dns_hostnames = true # Required so instances get public DNS hostnames

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# =========================================================================== #
# PUBLIC SUBNET
# =========================================================================== #
# Houses the EC2 instance. Without this: the instance would have no network
# segment to live in and couldn't receive traffic.
# =========================================================================== #
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.az_a
  map_public_ip_on_launch = true # Instances get a public IP automatically

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

# =========================================================================== #
# PRIVATE SUBNET
# =========================================================================== #
# Reserved for future internal services (database, cache). Without this:
# we'd have no secure subnet for resources that should not face the internet.
# NOTE: No NAT Gateway — that costs ~$32/month. In production you'd add one.
# =========================================================================== #
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.az_b

  tags = {
    Name = "${var.project_name}-private-subnet"
  }
}

# =========================================================================== #
# INTERNET GATEWAY
# =========================================================================== #
# Connects the VPC to the internet. Without this: the public subnet would
# have no route to the internet — the EC2 would be unreachable.
# =========================================================================== #
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# =========================================================================== #
# PUBLIC ROUTE TABLE
# =========================================================================== #
# Routes internet-bound traffic (0.0.0.0/0) to the Internet Gateway.
# Without this: even with an IGW attached, the subnet wouldn't know how
# to send packets out to the internet.
# =========================================================================== #
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Link the public route table to the public subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# =========================================================================== #
# PRIVATE ROUTE TABLE
# =========================================================================== #
# Routes only local VPC traffic. No route to the internet by design.
# =========================================================================== #
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# =========================================================================== #
# SECURITY GROUP
# =========================================================================== #
# Acts as a stateful firewall around the EC2 instance. Without this:
# all ports would be open to the world, which is a massive security risk.
#
# Rules:
#   - SSH (22)     → ONLY from your IP (defined in terraform.tfvars)
#   - HTTP (80)    → Public (for future SSL redirect)
#   - HTTPS (443)  → Public (for future SSL)
#   - App (5000)   → Public (the Flask API)
#   - Egress        → All outbound traffic allowed
# =========================================================================== #
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-sg"
  description = "Security group for the Flask API EC2 instance"
  vpc_id      = aws_vpc.main.id

  # --- INGRESS RULES ---

  ingress {
    description = "SSH restricted to my IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "HTTP public access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS public access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Flask API public access"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # --- EGRESS RULES ---

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# =========================================================================== #
# IAM ROLE FOR EC2
# =========================================================================== #
# Allows the EC2 instance to call AWS APIs without storing credentials
# on the machine. Without this: we'd have to hardcode access keys on the
# instance, which is a security anti-pattern.
# =========================================================================== #
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  # Trust policy: who can assume this role? → Only the EC2 service
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ec2-role"
  }
}

# =========================================================================== #
# IAM POLICY — Minimal S3 access for application logs
# =========================================================================== #
# Follows the principle of least privilege: only grants what the app needs.
# Without this: the app couldn't write logs to S3, but also wouldn't have
# any more permissions than necessary.
# =========================================================================== #
resource "aws_iam_policy" "s3_logs_policy" {
  name        = "${var.project_name}-s3-logs-policy"
  description = "Minimal policy allowing the app to write logs to a specific S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-logs-*",
          "arn:aws:s3:::${var.project_name}-logs-*/*"
        ]
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "s3_logs_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_logs_policy.arn
}

# =========================================================================== #
# IAM INSTANCE PROFILE
# =========================================================================== #
# The "container" that links the IAM role to the EC2 instance. Without this:
# you can't attach an IAM role to an EC2 instance — AWS requires an instance
# profile as an intermediary.
# =========================================================================== #
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# =========================================================================== #
# SSH KEY PAIR
# =========================================================================== #
# Creates an AWS key pair from a local public key. Terraform generates the
# private key locally and uploads only the public part to AWS.
# Without this: you cannot SSH into the instance at all.
# =========================================================================== #
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2_key" {
  key_name   = var.key_name
  public_key = tls_private_key.ssh_key.public_key_openssh

  tags = {
    Name = var.key_name
  }
}

# =========================================================================== #
# EC2 INSTANCE
# =========================================================================== #
# The compute layer running our Flask API inside Docker.
# Without this: there's no server to host the application.
#
# Key decisions explained:
#   - t3.micro: Free Tier eligible (750 hrs/month)
#   - Amazon Linux 2023: AWS's recommended distro, well-integrated
#   - User data: bootstraps Docker so the instance is ready for app deployment
#   - IAM profile attached: allows instance to write logs to S3 securely
# =========================================================================== #
resource "aws_instance" "api_server" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = aws_key_pair.ec2_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # Root volume — 8 GB is Free Tier eligible
  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true

    tags = {
      Name = "${var.project_name}-root-volume"
    }
  }

  # ==========================================================================
  # Boot script — runs once on first launch.
  # Installs Docker, installs Git, clones the public GitHub repo, builds
  # the multi-stage Docker image, and runs the Flask API container on port 5000.
  # The entire application stack is self-bootstrapping — no manual SSH needed.
  # ==========================================================================
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

    echo "[user-data] ========================================"
    echo "[user-data] Phase 2 — Flask API auto-deploy"
    echo "[user-data] ========================================"

    # --- System packages ---
    dnf update -y

    echo "[user-data] Installing Docker..."
    dnf install -y docker git
    systemctl enable docker
    systemctl start docker
    usermod -a -G docker ec2-user

    # --- Clone the repository ---
    REPO_URL="https://github.com/AruHonshou/devops-terraform-project.git"
    APP_DIR="/home/ec2-user/app"

    if [ -d "$APP_DIR/.git" ]; then
      echo "[user-data] Repo exists — pulling latest..."
      cd "$APP_DIR" && git pull origin main
    else
      echo "[user-data] Cloning repository..."
      git clone "$REPO_URL" "$APP_DIR"
    fi

    # --- Build multi-stage Docker image ---
    echo "[user-data] Building Docker image..."
    cd "$APP_DIR/app"
    docker build -t devops-terraform-api:latest .

    # --- Run the container ---
    # Stop and remove any old container running on the same port
    docker stop flask-api 2>/dev/null || true
    docker rm flask-api 2>/dev/null || true

    echo "[user-data] Starting container..."
    docker run -d \
      --name flask-api \
      --restart always \
      -p ${var.app_port}:${var.app_port} \
      devops-terraform-api:latest

    echo "[user-data] ========================================"
    echo "[user-data] Flask API deployed on port ${var.app_port}"
    echo "[user-data] ========================================"
  EOF
  )

  tags = {
    Name = "${var.project_name}-api-server"
  }

  # Ensures Terraform waits for user data to complete before marking
  # the resource as created (best effort)
  lifecycle {
    create_before_destroy = true
  }
}

# =========================================================================== #
# ELASTIC IP
# =========================================================================== #
# A static public IP that survives instance reboots and stop/start cycles.
# Without this: every time the instance restarts, it gets a new random
# public IP, breaking any DNS records or hardcoded URLs.
# =========================================================================== #
resource "aws_eip" "api_eip" {
  instance = aws_instance.api_server.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }
}

