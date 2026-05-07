# Automated API Infrastructure with Terraform & AWS

**Portfolio project — Junior DevOps**

Infrastructure-as-Code project that provisions a complete AWS environment
for a containerized Flask API. One command creates everything,
one command destroys it cleanly.

## Problem

Manual server configuration is slow, error-prone, and not reproducible
across environments.

## Solution

Full infrastructure defined as code with Terraform, enabling consistent
and repeatable deployments.

## Architecture

```
┌─────────────────────────────────────────────┐
│                  AWS Cloud (us-east-1)        │
│                                               │
│  ┌──────────────────────────────────────┐     │
│  │                VPC                    │     │
│  │  ┌──────────┐    ┌──────────┐        │     │
│  │  │  Public   │    │  Private  │        │     │
│  │  │  Subnet   │    │  Subnet   │        │     │
│  │  └─────┬─────┘    └──────────┘        │     │
│  │        │                                │     │
│  │  ┌─────┴─────────────────────┐         │     │
│  │  │    EC2 t2.micro            │         │     │
│  │  │    Docker + Flask +        │         │     │
│  │  │    Gunicorn                │         │     │
│  │  └───────────────────────────┘         │     │
│  └──────────────────────────────────────┘     │
│                                               │
│  ┌──────────┐    ┌──────────────────┐        │
│  │    S3     │    │   IAM Roles       │         │
│  │  (State)  │    │                   │         │
│  └──────────┘    └──────────────────┘        │
└─────────────────────────────────────────────┘
```

## Tech Stack

| Layer          | Technology              |
|----------------|-------------------------|
| IaC            | Terraform               |
| Cloud          | AWS (Free Tier)         |
| Compute        | EC2 t2.micro            |
| Networking     | VPC, Subnets, SG        |
| Storage        | S3 (remote state)       |
| App Backend    | Python Flask            |
| Container      | Docker (multi-stage)    |
| WSGI Server    | Gunicorn                |
| CI/CD          | GitHub Actions          |

## Project Structure

```
devops-terraform-project/
├── terraform/          # Terraform configuration files
├── app/                # Flask application + Dockerfile
├── .github/workflows/  # CI/CD pipelines
├── docs/               # Evidence screenshots
└── README.md
```

## Getting Started

### Prerequisites

- Terraform >= 1.5
- AWS CLI configured
- Docker Desktop
- Git

### Quick Start

```bash
# Clone the repository
git clone https://github.com/<your-username>/devops-terraform-project.git
cd devops-terraform-project

# Initialize Terraform
cd terraform
terraform init

# Deploy infrastructure
terraform apply

# Destroy everything when done
terraform destroy
```

## Evidence

Screenshots documenting each phase are in the `docs/` folder.

---

> Built as a portfolio project to demonstrate DevOps skills.
> No infrastructure remains running — only the code and this README.
