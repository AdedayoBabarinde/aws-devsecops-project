# Quick Start Guide

This guide will get your AWS DevSecOps Platform up and running in approximately 30 minutes.

## Prerequisites Checklist

- [ ] AWS Account with appropriate permissions
- [ ] AWS CLI installed and configured (`aws configure`)
- [ ] Terraform >= 1.6 installed
- [ ] kubectl >= 1.28 installed  
- [ ] Helm >= 3.12 installed
- [ ] GitHub repository created
- [ ] SonarCloud account (optional, for code scanning)

## Step-by-Step Setup

### 1. Initialize Terraform State Backend (5 minutes)

```bash
# Set your unique bucket name
export TF_STATE_BUCKET="your-company-terraform-state-$(date +%s)"

# Create S3 bucket for Terraform state
aws s3 mb s3://${TF_STATE_BUCKET} --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket ${TF_STATE_BUCKET} \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket ${TF_STATE_BUCKET} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

echo "Terraform backend created: ${TF_STATE_BUCKET}"
```

### 2. Configure Terraform Backend (2 minutes)

Update `terraform/environments/dev/main.tf`:

```hcl
backend "s3" {
  bucket         = "your-company-terraform-state-TIMESTAMP"  # Use your bucket name
  key            = "dev/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-state-lock"
}
```

### 3. Deploy Development Infrastructure (10-15 minutes)

```bash
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply configuration
terraform apply -auto-approve

# Save outputs
terraform output -json > outputs.json
```

**Expected resources created:**
- VPC with public/private subnets across 3 AZs
- EKS cluster (takes ~10 minutes)
- ECR repository
- IAM roles and policies
- Security groups
- NAT gateway and VPC endpoints

### 4. Configure kubectl (1 minute)

```bash
# Get cluster name from outputs
CLUSTER_NAME=$(terraform output -raw cluster_name)

# Update kubeconfig
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region us-east-1

# Verify connectivity
kubectl get nodes
kubectl get pods --all-namespaces
```

You should see:
- 2-3 worker nodes in Ready state
- System pods running (coredns, aws-node, kube-proxy, etc.)

### 5. Verify Add-ons Installation (2 minutes)

```bash
# Check installed Helm releases
helm list --all-namespaces

# Verify Cluster Autoscaler
kubectl get deployment cluster-autoscaler -n kube-system

# Verify AWS Load Balancer Controller
kubectl get deployment aws-load-balancer-controller -n kube-system

# Verify Prometheus stack
kubectl get pods -n monitoring

# Verify policy engines
kubectl get pods -n kyverno
kubectl get pods -n gatekeeper-system
```

### 6. Apply Security Policies (2 minutes)

```bash
cd ../../../  # Return to repo root

# Apply Kyverno policies
kubectl apply -f policies/kyverno/

# Verify policies
kubectl get clusterpolicy

# View policy reports
kubectl get policyreport -A
```

### 7. Configure GitHub Actions (5 minutes)

Add these secrets to your GitHub repository:

Settings → Secrets and variables → Actions → New repository secret

```
AWS_ACCESS_KEY_ID: <your-aws-access-key>
AWS_SECRET_ACCESS_KEY: <your-aws-secret-key>
AWS_REGION: us-east-1
SONAR_TOKEN: <your-sonarcloud-token> (optional)
SONAR_PROJECT_KEY: <your-project-key> (optional)
SONAR_ORGANIZATION: <your-org> (optional)
```

### 8. Deploy Sample Application (3 minutes)

```bash
# Get ECR repository URL
ECR_REPO=$(terraform output -json | jq -r '.ecr_repository_url.value')

# Build and push a sample image (or use GitHub Actions)
cd helm-charts/web-app

# Update values.yaml with your ECR repository URL
sed -i "s|123456789012.dkr.ecr.us-east-1.amazonaws.com/web-app|${ECR_REPO}|g" values.yaml

# Deploy using Helm
helm upgrade --install web-app . \
  --namespace default \
  --set image.tag=latest \
  --wait

# Check deployment
kubectl get pods -n default
kubectl get ingress -n default
```

### 9. Access Monitoring (2 minutes)

```bash
# Port-forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &

# Open browser to http://localhost:3000
# Default login: admin / prom-operator
```

### 10. Verify Everything (2 minutes)

Run this comprehensive check:

```bash
echo "=== Cluster Status ==="
kubectl cluster-info

echo "=== Nodes ==="
kubectl get nodes

echo "=== System Pods ==="
kubectl get pods --all-namespaces | grep -E "(kube-system|monitoring|kyverno|gatekeeper)"

echo "=== Application ==="
kubectl get deployments,pods,services,ingress -n default

echo "=== Policies ==="
kubectl get clusterpolicy

echo "=== Cost Estimate ==="
echo "Monthly cost for dev environment: ~$145"
```

## Common Issues & Solutions

### Issue: EKS cluster creation timeout
**Solution**: EKS takes 10-15 minutes. Wait patiently or check CloudFormation events in AWS Console.

### Issue: Nodes not joining cluster
**Solution**: 
```bash
kubectl get nodes
# If empty, check node group:
aws eks describe-nodegroup --cluster-name <cluster-name> --nodegroup-name <nodegroup-name>
```

### Issue: Pods pending with "Insufficient memory/CPU"
**Solution**: Scale up node group or adjust resource requests in values.yaml

### Issue: Ingress not getting external IP
**Solution**: AWS Load Balancer Controller needs time to provision ALB (2-5 minutes)
```bash
kubectl describe ingress -n default
```

### Issue: Policy violations blocking deployments
**Solution**: Start with policies in audit mode, then switch to enforce:
```bash
kubectl edit clusterpolicy <policy-name>
# Change validationFailureAction: audit
```

## Next Steps

1. **Configure DNS**: Point your domain to the ALB hostname
2. **Enable HTTPS**: Configure ACM certificate in ingress annotations
3. **Set up monitoring alerts**: Configure Alertmanager rules
4. **Production deployment**: Repeat steps for staging/prod environments
5. **CI/CD**: Push code to trigger GitHub Actions workflows

## Getting Help

- Review documentation in `/docs` directory
- Check GitHub Actions workflow runs for errors
- Review CloudWatch logs:
  ```bash
  aws logs tail /aws/eks/dev-eks-cluster/cluster --follow
  ```
- Kubernetes events:
  ```bash
  kubectl get events --all-namespaces --sort-by='.lastTimestamp'
  ```

## Cleanup (if testing)

To avoid ongoing charges:

```bash
cd terraform/environments/dev

# Destroy all resources
terraform destroy -auto-approve

# Delete S3 bucket (must be empty)
aws s3 rb s3://${TF_STATE_BUCKET} --force

# Delete DynamoDB table
aws dynamodb delete-table --table-name terraform-state-lock
```

**Estimated Total Setup Time: 30-40 minutes**

## Success Indicators

✅ EKS cluster accessible via kubectl  
✅ Nodes in Ready state  
✅ System pods running  
✅ Policies installed and reporting  
✅ Application deployed successfully  
✅ Monitoring dashboards accessible  
✅ GitHub Actions configured  

Congratulations! Your AWS DevSecOps Platform is ready! 🎉
