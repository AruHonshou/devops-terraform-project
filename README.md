# Automated API Infrastructure with Terraform & AWS

[![App CI/CD](https://github.com/AruHonshou/devops-terraform-project/actions/workflows/app-pipeline.yml/badge.svg)](https://github.com/AruHonshou/devops-terraform-project/actions/workflows/app-pipeline.yml)
[![Terraform CI/CD](https://github.com/AruHonshou/devops-terraform-project/actions/workflows/terraform-pipeline.yml/badge.svg)](https://github.com/AruHonshou/devops-terraform-project/actions/workflows/terraform-pipeline.yml)

**Junior DevOps Portfolio Project**

Full-stack DevOps project: infrastructure as code with Terraform, containerized Flask API on AWS, and automated CI/CD with GitHub Actions. One command builds everything; one command destroys it cleanly.

---

## The Problem

Provisioning servers manually through the AWS Console is slow, error-prone, and impossible to reproduce across environments. Teams waste hours clicking through the same setup for dev, staging, and production — and when something breaks, there's no single source of truth for what was configured.

## The Solution

Define every piece of infrastructure as code with Terraform. A developer clones this repo, sets three secrets, and runs `terraform apply`. Five minutes later, a Flask API is serving traffic on a fully configured EC2 instance inside a custom VPC. When the demo is over, `terraform destroy` removes everything — zero lingering costs, zero orphaned resources.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      AWS Cloud (us-east-1)                    │
│                                                               │
│  ┌───────────────────────────────────────────────────────┐   │
│  │                         VPC                            │   │
│  │                   10.0.0.0/16                           │   │
│  │                                                        │   │
│  │  ┌───────────────────┐    ┌──────────────────────┐     │   │
│  │  │  Public Subnet     │    │  Private Subnet       │     │   │
│  │  │  10.0.1.0/24      │    │  10.0.2.0/24          │     │   │
│  │  │  us-east-1a       │    │  us-east-1b           │     │   │
│  │  │                    │    │                        │     │   │
│  │  │  ┌──────────────┐ │    │  (reserved for future  │     │   │
│  │  │  │  EC2 t3.micro │ │    │   databases, cache)   │     │   │
│  │  │  │              │ │    │                        │     │   │
│  │  │  │  Docker       │ │    └──────────────────────┘     │   │
│  │  │  │  ┌─────────┐ │ │                                   │   │
│  │  │  │  │ Gunicorn │ │ │     ┌─────────────────────┐     │   │
│  │  │  │  │ Flask    │ │ │     │  Security Group     │     │   │
│  │  │  │  │ API      │ │ │     │  SSH: my IP only    │     │   │
│  │  │  │  └─────────┘ │ │     │  80,443,5000: open  │     │   │
│  │  │  └──────┬───────┘ │     └─────────────────────┘     │   │
│  │  │         │          │                                   │   │
│  │  │    Elastic IP      │     ┌─────────────────────┐     │   │
│  │  │    (static)        │     │  Route Table        │     │   │
│  │  └───────────────────┘     │  0.0.0.0/0 → IGW    │     │   │
│  │            │               └──────────┬──────────┘     │   │
│  │            │                          │                 │   │
│  │  ┌─────────┴──────────────────────────┴────────────┐   │   │
│  │  │               Internet Gateway                   │   │   │
│  │  └─────────────────────────────────────────────────┘   │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌─────────────────┐   ┌────────────────────────────┐        │
│  │  S3 (state)      │   │  IAM Role + Instance       │        │
│  │  encrypted       │   │  Profile (least privilege) │        │
│  └─────────────────┘   └────────────────────────────┘        │
└──────────────────────────────────────────────────────────────┘
```

---

## Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| **IaC** | Terraform 1.5+ | Industry standard, declarative, state management |
| **Cloud** | AWS (Free Tier) | Most widely used cloud provider |
| **Compute** | EC2 `t3.micro` | Free Tier eligible (750 hrs/month) |
| **OS** | Amazon Linux 2023 | AWS-optimized, lightweight, well-integrated |
| **Networking** | VPC, Subnets, SG, IGW | Isolated network with public/private segmentation |
| **State** | S3 (remote backend) | Prevents state loss if laptop fails |
| **App Backend** | Python 3.12 + Flask 3 | Simple, well-documented web framework |
| **Container** | Docker (multi-stage) | Consistent runtime, smaller images |
| **WSGI** | Gunicorn | Production-grade Python WSGI server |
| **CI/CD** | GitHub Actions | Free, integrated, 2 automated pipelines |

---

## Project Structure

```
devops-terraform-project/
├── .github/workflows/
│   ├── app-pipeline.yml         # App CI/CD: test → build → push → deploy
│   └── terraform-pipeline.yml   # Terraform CI/CD: fmt → plan → apply
├── app/
│   ├── app.py                   # Flask API (3 endpoints)
│   ├── requirements.txt         # Python dependencies
│   ├── Dockerfile               # Multi-stage (builder + production)
│   ├── .dockerignore            # Exclude tests and dev files
│   └── tests/
│       └── test_app.py          # 9 unit tests (pytest)
├── terraform/
│   ├── backend.tf               # Provider + S3 backend config
│   ├── main.tf                  # VPC, EC2, SG, IAM, EIP, user_data
│   ├── variables.tf             # All configurable parameters
│   ├── outputs.tf               # Public IP, instance ID, health URL
│   └── terraform.tfvars.example # Template (real values are gitignored)
├── docs/                        # 21 evidence screenshots
├── .gitignore
└── README.md
```

---

## How It Works

### Full Flow

```
  git push (main)
       │
       ├─── app/** changed? ───────► App CI/CD Pipeline
       │         │                        │
       │         ├─ 1. Checkout           ├─ 5. Docker login
       │         ├─ 2. Python 3.12        ├─ 6. Build & push
       │         ├─ 3. pip install        │      → Docker Hub
       │         └─ 4. pytest (9 tests)   └─ 7. SSH to EC2
       │              │                        ├─ docker pull
       │              │ FAIL? → ❌ STOP        ├─ docker restart
       │              │                        └─ curl /health
       │              ▼
       │           All pass? → continue
       │
       ├─── terraform/** changed? ───► Terraform CI/CD Pipeline
       │         │                        │
       │         ├─ 1. Checkout           ├─ 5. terraform init
       │         ├─ 2. Terraform 1.5      ├─ 6. terraform validate
       │         ├─ 3. AWS credentials    └─ 7. terraform plan
       │         └─ 4. terraform fmt           │
       │                                   PR? → comment with plan
       │                                   main push? → apply
       │
       └─── Both pass ✅ ──► Infrastructure updated, app deployed
```

---

## Infrastructure Resources (17 Terraform-managed resources)

| Resource | Type | Purpose |
|----------|------|---------|
| `aws_vpc.main` | VPC | Isolated network (10.0.0.0/16) |
| `aws_subnet.public` | Subnet | EC2 hosting (10.0.1.0/24, us-east-1a) |
| `aws_subnet.private` | Subnet | Reserved for future DB/cache (10.0.2.0/24) |
| `aws_internet_gateway.igw` | IGW | Internet access for VPC |
| `aws_route_table.public` | Route Table | Routes 0.0.0.0/0 → IGW |
| `aws_route_table.private` | Route Table | Local VPC routes only |
| `aws_security_group.ec2_sg` | Security Group | Ingress: 22 (my IP), 80, 443, 5000 |
| `aws_instance.api_server` | EC2 | t3.micro, Amazon Linux 2023, Docker auto-install |
| `aws_eip.api_eip` | Elastic IP | Static public IP (survives reboots) |
| `aws_key_pair.ec2_key` | Key Pair | RSA 4096, generated by Terraform |
| `aws_iam_role.ec2_role` | IAM Role | EC2 assume role |
| `aws_iam_policy.s3_logs_policy` | IAM Policy | Minimal S3 access (PutObject, GetObject) |
| `aws_iam_instance_profile` | Instance Profile | Links role to EC2 |
| Data `aws_ami` | AMI Source | Latest Amazon Linux 2023 (auto-resolved) |

---

## Quick Start

### Prerequisites

- Terraform >= 1.5
- AWS CLI configured (`aws configure`)
- Docker Desktop
- Git
- GitHub account

### 5 Steps to Reproduce

```bash
# 1. Clone
git clone https://github.com/AruHonshou/devops-terraform-project.git
cd devops-terraform-project

# 2. Configure variables
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars: set allowed_ssh_cidr to your IP (curl ifconfig.me)

# 3. Create S3 backend bucket (one-time)
aws s3api create-bucket --bucket devops-terraform-state-YOUR_ACCOUNT_ID --region us-east-1

# 4. Deploy
cd terraform
terraform init
terraform apply

# 5. Test
curl http://$(terraform output -raw public_ip):5000/health

# Clean up
terraform destroy
aws s3 rb s3://devops-terraform-state-YOUR_ACCOUNT_ID --force
```

### Configure GitHub Secrets for CI/CD

| Secret | How to get it |
|--------|---------------|
| `DOCKERHUB_USERNAME` | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub → Settings → Security → Access Token |
| `AWS_ACCESS_KEY_ID` | IAM → Users → terraform-deployer → Security credentials |
| `AWS_SECRET_ACCESS_KEY` | IAM → Users → terraform-deployer → Security credentials |
| `EC2_HOST` | Output of `terraform output public_ip` |
| `EC2_SSH_PRIVATE_KEY` | Contents of `terraform output -raw private_key_pem` |
| `SSH_ALLOWED_CIDR` | Your IP in CIDR notation (e.g. `203.0.113.5/32`) |
| `APP_PORT` | `5000` |

---

## CI/CD Pipelines

### Pipeline 1 — App CI/CD (`app-pipeline.yml`)

Triggers on changes to `app/**`. Runs on every push and Pull Request.

| Step | What | Blocks on failure? |
|------|------|--------------------|
| Checkout | Pulls latest code | No |
| Python 3.12 | Sets up Python | No |
| pip install | Installs Flask, Gunicorn, pytest | No |
| **pytest** | 9 unit tests across 3 endpoints | **YES** — pipeline stops |
| Docker login | Authenticates to Docker Hub (main only) | No |
| Build & push | Multi-stage build → Docker Hub (main only) | No |
| Deploy to EC2 | SSH → pull image → restart container (main only) | No |

### Pipeline 2 — Terraform CI/CD (`terraform-pipeline.yml`)

Triggers on changes to `terraform/**`. Runs on every push and Pull Request.

| Step | What | Runs on |
|------|------|---------|
| terraform fmt | Style check | Always |
| terraform init | Downloads providers + S3 backend | Always |
| terraform validate | Syntax check | Always |
| terraform plan | Shows what will change | Always |
| Post plan to PR | Comment with full plan output | PR only |
| terraform apply | Applies changes to AWS | Push to main only |

---

## Evidence

All screenshots documenting the project lifecycle are in `docs/`.

| Phase | Screenshots |
|-------|-------------|
| **Phase 0** — Setup | `01`–`04`: Terraform version, AWS identity, project structure, IAM policies |
| **Phase 1** — Infrastructure | `05`–`09`: `terraform plan`, `terraform apply`, health endpoint, EC2 console, VPC console |
| **Phase 2** — App & Docker | `10`–`14`: `curl` all endpoints, `docker ps` via SSH, browser screenshots |
| **Phase 3** — CI/CD | `15`–`18`: GitHub Actions green pipelines, Docker Hub image, CI/CD field in API |
| **Phase 4** — Destroy | `19`–`21`: `terraform destroy` output, empty AWS console, final README |

---

## Key Learnings

1. **Infrastructure as Code eliminates drift.** Every resource is declared once, and `terraform plan` shows exactly what will change before applying. No more "who changed the security group at 3 AM?"

2. **Remote state is non-negotiable.** Storing `terraform.tfstate` in S3 (instead of local disk) means the team always works from the same truth. If a laptop dies, the state survives.

3. **CI/CD catches mistakes before production.** The App pipeline runs `pytest` BEFORE building the Docker image — if a test fails, nothing gets pushed. The Terraform pipeline runs `fmt` + `validate` before `plan` before `apply`.

4. **Secrets never touch source code.** AWS keys, Docker tokens, SSH keys — everything is in GitHub Secrets, injected only at runtime via environment variables. `terraform.tfvars` is gitignored.

5. **Multi-stage Docker builds matter.** The production image is 140 MB (Python slim + only app files), while a naive build would be 400+ MB. Smaller images = faster pulls = faster deploys.

6. **Destroy is a feature, not a bug.** `terraform destroy` proves the infrastructure is fully reproducible. Any reviewer can clone this repo and recreate the exact same environment in their own AWS account.

---

## Author

**AruHonshou** — Junior DevOps Candidate

- GitHub: [github.com/AruHonshou](https://github.com/AruHonshou)
- Docker Hub: [hub.docker.com/r/aruhonshou/devops-terraform-api](https://hub.docker.com/r/aruhonshou/devops-terraform-api)
- Project: [github.com/AruHonshou/devops-terraform-project](https://github.com/AruHonshou/devops-terraform-project)

---

> "The infrastructure is gone. The code and the knowledge remain."
> — Built as a portfolio project. No AWS resources are left running.
