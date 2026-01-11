
# AWS DevSecOps Platform

Production-ready AWS infrastructure implementing DevSecOps best practices with EKS, comprehensive security scanning, policy enforcement, and observability.

## Architecture Overview

This implementation translates the Azure DevSecOps architecture to AWS:

- **Source Control**: GitHub
- **CI/CD**: GitHub Actions
- **Container Registry**: Amazon ECR with image scanning
- **Kubernetes**: Amazon EKS with security hardening
- **Security Scanning**: Trivy + SonarCloud
- **Policy Enforcement**: Kyverno + OPA Gatekeeper
- **Monitoring**: Prometheus + Grafana (self-hosted + managed options)
- **GitOps**: Helm-based deployments

## Features

### Security
- Trivy container image scanning
- SonarCloud code quality and security analysis
- ECR image scanning enabled
- OPA Gatekeeper policy enforcement
- Kyverno policy management
- AWS Security Groups and NACLs
- IAM roles with least privilege
- Secrets management with AWS Secrets Manager
- VPC with private subnets for EKS nodes

### Cost Optimization
- Spot instances for non-production workloads
- Cluster Autoscaler for dynamic scaling
- ECR lifecycle policies for image cleanup
- Single NAT Gateway per environment
- VPC endpoints to reduce NAT traffic
- GP3 EBS volumes with optimized IOPS
- Prometheus self-hosted for dev/staging

### High Availability
- Multi-AZ EKS cluster
- Auto-scaling node groups
- Pod Disruption Budgets
- Health checks and readiness probes

## Repository Structure

```
aws-devsecops-platform/
├── .github/workflows/       # GitHub Actions CI/CD pipelines
├── terraform/
│   ├── environments/        # Environment-specific configurations
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   ├── modules/            # Reusable Terraform modules
│   │   ├── networking/     # VPC, subnets, security groups
│   │   ├── eks/           # EKS cluster and node groups
│   │   ├── ecr/           # Container registry
│   │   ├── monitoring/    # Prometheus and Grafana
│   │   ├── security/      # Security scanning and policies
│   │   └── iam/           # IAM roles and policies
│   └── shared/            # Shared resources (S3, KMS, etc.)
├── helm-charts/           # Helm charts for applications
├── policies/              # Policy-as-code definitions
│   ├── opa/              # OPA Gatekeeper policies
│   └── kyverno/          # Kyverno policies
├── scripts/              # Utility scripts
└── docs/                 # Documentation
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.6
- kubectl >= 1.28
- Helm >= 3.12
- GitHub account with Actions enabled
- SonarCloud account (optional)

## Quick Start

### 1. Configure Backend

```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://your-terraform-state-bucket --region us-east-1
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 2. Deploy Infrastructure

```bash
# Navigate to environment
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply configuration
terraform apply
```

### 3. Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig \
  --name dev-eks-cluster \
  --region us-east-1

# Verify connection
kubectl get nodes
```

### 4. Deploy Application

```bash
# Build and push image (via GitHub Actions)
# Or manually:
cd helm-charts/web-app
helm upgrade --install web-app . \
  --namespace default \
  --values values.yaml
```

## GitHub Actions Setup

### Required Secrets

Configure these secrets in your GitHub repository:

- `AWS_ACCESS_KEY_ID`: AWS access key for deployments
- `AWS_SECRET_ACCESS_KEY`: AWS secret key
- `AWS_REGION`: Target AWS region (e.g., us-east-1)
- `SONAR_TOKEN`: SonarCloud authentication token
- `SONAR_PROJECT_KEY`: SonarCloud project key

### Workflow Overview

1. **Terraform Plan/Apply**: Infrastructure changes
2. **Build, Scan, Push**: Container image pipeline
3. **Deploy to EKS**: Application deployment

## Cost Estimates

### Development Environment (Monthly)
- EKS Control Plane: $73
- EC2 Instances (3x t3.medium spot): ~$25
- NAT Gateway: $32
- EBS Storage (100GB): $10
- ECR Storage: $1-5
- **Total: ~$145/month**

### Production Environment (Monthly)
- EKS Control Plane: $73
- EC2 Instances (3x t3.large on-demand): ~$150
- NAT Gateway: $32
- EBS Storage (300GB): $30
- Managed Prometheus: ~$50
- Managed Grafana: ~$100
- ECR Storage: $5-20
- **Total: ~$440/month**

## Security Best Practices

1. **Network Isolation**: Private subnets for worker nodes
2. **Image Scanning**: Automated vulnerability scanning with Trivy
3. **Code Quality**: SonarCloud integration for SAST
4. **Policy Enforcement**: OPA and Kyverno for runtime policies
5. **Secrets Management**: AWS Secrets Manager integration
6. **Least Privilege**: IAM roles scoped to minimum requirements
7. **Audit Logging**: CloudTrail and EKS audit logs enabled

## Monitoring and Observability

- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **CloudWatch**: Log aggregation and alarms
- **Container Insights**: EKS-specific monitoring

## Policy Management

### OPA Gatekeeper
- Enforces admission control policies
- Located in `policies/opa/`
- Examples: require labels, block privileged containers

### Kyverno
- Kubernetes-native policy management
- Located in `policies/kyverno/`
- Examples: image verification, resource quotas

## Disaster Recovery

- Terraform state stored in S3 with versioning
- EKS cluster in multiple AZs
- Regular backups using Velero (optional)
- Infrastructure as Code for rapid recovery

## Contributing

1. Create a feature branch
2. Make changes
3. Run `terraform fmt` and `terraform validate`
4. Submit pull request
5. Automated CI/CD will validate changes

## Support

For issues and questions:
- Review documentation in `/docs`
- Check GitHub Issues
- Review Terraform module documentation

## License

MIT License - See LICENSE file for details
