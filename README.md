# EKS + Terraform + Helm(ALB Controller) + ArgoCD + NGINX (Mumbai / ap-south-1)


## Summary
This repository provisions:
- VPC (reusable module)
- EKS cluster (v1.34) with 2 node capacity (managed node group)
- IAM role for AWS Load Balancer Controller (IRSA helper)
- Helm script to install AWS Load Balancer Controller (uses role ARN)
- NGINX Deployment + Service
- ArgoCD Application YAML to sync NGINX manifests from this repo

**Terraform backend**: S3-only (no DynamoDB locking), bucket: `eks-terraform-state-mumbai` (create it as described below).

---

## Prerequisites
- AWS CLI configured with permissions to create VPC/EKS/IAM/EC2/S3
- Terraform >= 1.4.x
- kubectl
- helm
- argocd CLI (optional)

---

## 1) Create S3 bucket for Terraform backend
```bash
aws s3 mb s3://eks-terraform-state-mumbai --region ap-south-1
aws s3api put-bucket-versioning --bucket eks-terraform-state-mumbai --versioning-configuration Status=Enabled --region ap-south-1
# EKS Terraform ArgoCD NGINX - Complete CI/CD Infrastructure

A production-ready CI/CD infrastructure on AWS using Terraform, Kubernetes (EKS), ArgoCD, and Application Load Balancer with SSL/TLS termination.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Installation Guide](#installation-guide)
  - [1. AWS Configuration](#1-aws-configuration)
  - [2. Domain Setup](#2-domain-setup)
  - [3. SSL Certificate Setup](#3-ssl-certificate-setup)
  - [4. Provision EKS Cluster](#4-provision-eks-cluster)
  - [5. Install AWS Load Balancer Controller](#5-install-aws-load-balancer-controller)
  - [6. Deploy NGINX Application](#6-deploy-nginx-application)
  - [7. Setup ArgoCD](#7-setup-argocd)
  - [8. Configure Ingress](#8-configure-ingress)
- [Accessing Applications](#accessing-applications)
- [Cost Breakdown](#cost-breakdown)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## 🎯 Overview

This project demonstrates a complete GitOps workflow using:

- **Infrastructure as Code**: Terraform for AWS EKS cluster provisioning
- **Container Orchestration**: Kubernetes (EKS) for running containerized applications
- **GitOps**: ArgoCD for continuous deployment
- **Load Balancing**: AWS Application Load Balancer with SSL/TLS
- **DNS Management**: Route53 for domain management
- **Sample Application**: NGINX web server

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Route 53                             │
│                    (demoeks.click)                           │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              Application Load Balancer (ALB)                 │
│                   (SSL/TLS Termination)                      │
│          Certificate: ACM (demoeks.click)                    │
└──────────────┬──────────────────────────────────────────────┘
               │
               ├─────────────────┬─────────────────────────────┐
               │                 │                             │
               ▼                 ▼                             ▼
    ┌──────────────────┐ ┌──────────────────┐   ┌──────────────────┐
    │  NGINX Service   │ │  ArgoCD Server   │   │  Other Services  │
    │  (demoeks.click) │ │(argocd.demoeks   │   │                  │
    │                  │ │     .click)      │   │                  │
    └──────────────────┘ └──────────────────┘   └──────────────────┘
               │                 │
               ▼                 ▼
    ┌─────────────────────────────────────────────────────────┐
    │                    EKS Cluster                           │
    │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
    │  │  Node Group │  │  Node Group │  │  Node Group │    │
    │  │   (t3.med)  │  │   (t3.med)  │  │   (t3.med)  │    │
    │  └─────────────┘  └─────────────┘  └─────────────┘    │
    └─────────────────────────────────────────────────────────┘
```

## 📦 Prerequisites

Before starting, ensure you have the following installed:

- **AWS CLI** (v2.x or later)
  ```bash
  aws --version
  # aws-cli/2.x.x
  ```

- **Terraform** (v1.5.x or later)
  ```bash
  terraform version
  # Terraform v1.5.x
  ```

- **kubectl** (v1.28.x or later)
  ```bash
  kubectl version --client
  # Client Version: v1.28.x
  ```

- **Helm** (v3.12.x or later)
  ```bash
  helm version
  # version.BuildInfo{Version:"v3.12.x"}
  ```

- **AWS Account** with appropriate permissions:
  - EC2, VPC, EKS, IAM, Route53, ACM, ELB permissions

## 📁 Project Structure

```
eks-terraform-argocd-nginx/
├── terraform/
│   ├── main.tf              # Main EKS cluster configuration
│   ├── variables.tf         # Input variables
│   ├── outputs.tf           # Output values (kubeconfig, etc.)
│   ├── vpc.tf               # VPC configuration
│   └── eks.tf               # EKS node groups and IAM roles
├── manifests/
│   ├── nginx-deployment.yaml # NGINX Kubernetes deployment
│   └── nginx-service.yaml    # NGINX Kubernetes service
├── argocd/
│   ├── argocd-application.yaml    # ArgoCD application resource
│   ├── argocd-cmd-params-cm.yaml  # ArgoCD configuration
│   ├── argocd-ingress.yaml        # ArgoCD ingress resource
│   └── ingress.yaml               # NGINX ingress resource
└── README.md                # This file
```

## 🚀 Installation Guide

### 1. AWS Configuration

Configure AWS CLI with your credentials:

```bash
aws configure
```

Enter your:
- AWS Access Key ID
- AWS Secret Access Key
- Default region: `ap-south-1` (Mumbai)
- Default output format: `json`

Verify configuration:

```bash
aws sts get-caller-identity
```

### 2. Domain Setup

#### Option A: Purchase Domain via Route53

1. Navigate to Route53 Console → Registered Domains
2. Click "Register Domain"
3. Search for available domain (e.g., `demoeks.click`)
4. Complete purchase (typically $3-12/year depending on TLD)
5. Wait for registration to complete (5-10 minutes)

#### Option B: Use Existing Domain

If you already own a domain, create a hosted zone:

```bash
aws route53 create-hosted-zone \
  --name demoeks.click \
  --caller-reference $(date +%s)
```

Note the Name Servers and update them at your domain registrar.

### 3. SSL Certificate Setup

#### Request ACM Certificate

```bash
# Request certificate for your domain and wildcard subdomain
aws acm request-certificate \
  --domain-name demoeks.click \
  --subject-alternative-names "*.demoeks.click" \
  --validation-method DNS \
  --region ap-south-1
```

**Save the Certificate ARN** from the output:
```
{
    "CertificateArn": "arn:aws:acm:ap-south-1:ACCOUNT_ID:certificate/CERT_ID"
}
```

#### Get DNS Validation Records

```bash
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:ap-south-1:ACCOUNT_ID:certificate/CERT_ID \
  --region ap-south-1 \
  --query 'Certificate.DomainValidationOptions[*].[ResourceRecord.Name,ResourceRecord.Type,ResourceRecord.Value]' \
  --output table
```

#### Add CNAME Validation Record to Route53

```bash
# Get your hosted zone ID
aws route53 list-hosted-zones --query 'HostedZones[?Name==`demoeks.click.`].Id' --output text

# Create validation record
cat > acm-validation.json <<EOF
{
  "Changes": [{
    "Action": "CREATE",
    "ResourceRecordSet": {
      "Name": "_VALIDATION_NAME.demoeks.click.",
      "Type": "CNAME",
      "TTL": 300,
      "ResourceRecords": [{"Value": "_VALIDATION_VALUE.acm-validations.aws."}]
    }
  }]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id YOUR_HOSTED_ZONE_ID \
  --change-batch file://acm-validation.json
```

#### Wait for Certificate Validation

```bash
# Check certificate status (wait until it shows "ISSUED")
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:ap-south-1:ACCOUNT_ID:certificate/CERT_ID \
  --region ap-south-1 \
  --query 'Certificate.Status' \
  --output text
```

This typically takes 5-10 minutes.

### 4. Provision EKS Cluster

#### Initialize Terraform

```bash
cd terraform/

terraform init
```

#### Review and Modify Variables (if needed)

Edit `variables.tf` or create `terraform.tfvars`:

```hcl
region         = "ap-south-1"
cluster_name   = "demo-eks-cluster"
vpc_cidr       = "10.0.0.0/16"
instance_types = ["t3.medium"]
desired_size   = 2
min_size       = 1
max_size       = 3
```

#### Plan Infrastructure

```bash
terraform plan
```

Review the resources that will be created (~50-60 resources).

#### Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted. This will take approximately 15-20 minutes.

#### Configure kubectl

```bash
# Update kubeconfig to access the cluster
aws eks update-kubeconfig \
  --region ap-south-1 \
  --name demo-eks-cluster

# Verify cluster access
kubectl get nodes
```

You should see your EKS worker nodes in `Ready` state.

### 5. Install AWS Load Balancer Controller

The AWS Load Balancer Controller enables ALB ingress support in Kubernetes.

#### Create IAM Policy

```bash
# Download IAM policy
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json

# Create policy
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam-policy.json
```

#### Create IAM Service Account

```bash
# Replace ACCOUNT_ID with your AWS account ID
eksctl create iamserviceaccount \
  --cluster=demo-eks-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --region ap-south-1 \
  --approve
```

#### Install Controller via Helm

```bash
# Add EKS Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=demo-eks-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=ap-south-1 \
  --set vpcId=vpc-xxxxx  # Get this from Terraform output
```

#### Verify Installation

```bash
kubectl get deployment -n kube-system aws-load-balancer-controller

# Should show READY 2/2
```

### 6. Deploy NGINX Application

#### Apply Kubernetes Manifests

```bash
# Create namespace (optional)
kubectl create namespace default

# Apply NGINX deployment
kubectl apply -f manifests/nginx-deployment.yaml

# Apply NGINX service
kubectl apply -f manifests/nginx-service.yaml

# Verify deployment
kubectl get pods
kubectl get svc
```

#### Create Ingress for NGINX

Update `argocd/ingress.yaml` with your certificate ARN:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:ap-south-1:ACCOUNT_ID:certificate/CERT_ID
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS": 443}]'
spec:
  ingressClassName: alb
  rules:
  - host: demoeks.click
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-service
            port:
              number: 80
```

Apply the ingress:

```bash
kubectl apply -f argocd/ingress.yaml
```

#### Get ALB DNS Name

```bash
kubectl get ingress nginx-ingress
```

Wait 2-3 minutes for ALB to be provisioned.

#### Create Route53 DNS Record

```bash
# Get ALB DNS name
ALB_DNS=$(kubectl get ingress nginx-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Create A record pointing to ALB
cat > route53-nginx.json <<EOF
{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "demoeks.click",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "Z35SXDOTRQ7X7K",
        "DNSName": "$ALB_DNS",
        "EvaluateTargetHealth": true
      }
    }
  }]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id YOUR_HOSTED_ZONE_ID \
  --change-batch file://route53-nginx.json
```

**Note**: `Z35SXDOTRQ7X7K` is the canonical hosted zone ID for ALB in `ap-south-1` region.

### 7. Setup ArgoCD

#### Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=argocd -n argocd --timeout=300s
```

#### Configure ArgoCD for ALB

```bash
# Configure insecure mode (ALB handles TLS)
kubectl apply -f argocd/argocd-cmd-params-cm.yaml

# Set external URL
kubectl patch configmap argocd-cm -n argocd --type merge -p '{"data":{"url":"https://argocd.demoeks.click"}}'

# Restart ArgoCD server
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd
```

#### Create ArgoCD Ingress

Update `argocd/argocd-ingress.yaml` with your certificate ARN, then apply:

```bash
kubectl apply -f argocd/argocd-ingress.yaml
```

#### Create DNS Record for ArgoCD

```bash
# Get ALB DNS (may be same as NGINX if using path-based routing)
ALB_DNS=$(kubectl get ingress -n argocd argocd-server-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

cat > route53-argocd.json <<EOF
{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "argocd.demoeks.click",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "Z35SXDOTRQ7X7K",
        "DNSName": "$ALB_DNS",
        "EvaluateTargetHealth": true
      }
    }
  }]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id YOUR_HOSTED_ZONE_ID \
  --change-batch file://route53-argocd.json
```

#### Get ArgoCD Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
```

**Save this password!** You'll need it to login.

#### Login to ArgoCD UI

Access ArgoCD at: **https://argocd.demoeks.click**

- Username: `admin`
- Password: (from previous command)

### 8. Configure ArgoCD Application

#### Create ArgoCD Application Resource

Update `argocd/argocd-application.yaml` with your Git repository URL:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/PrasadP744/eks-terraform-argocd-nginx.git
    targetRevision: main
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

Apply the application:

```bash
kubectl apply -f argocd/argocd-application.yaml
```

#### Verify Sync

In ArgoCD UI, you should see the `nginx-app` application syncing automatically.

## 🌐 Accessing Applications

### NGINX Application

- **URL**: https://demoeks.click
- **Access Method**: Direct HTTPS access via browser
- **Verification**:
  ```bash
  curl -I https://demoeks.click
  # Should return HTTP/2 200
  ```

### ArgoCD Dashboard

- **URL**: https://argocd.demoeks.click
- **Username**: `admin`
- **Password**: Retrieved from secret (see Step 7)
- **Features**:
  - View application health and sync status
  - Manage deployments
  - View resource tree
  - Trigger manual syncs

### Port-Forward Alternative (Development)

If you prefer local access without Ingress:

```bash
# NGINX
kubectl port-forward svc/nginx-service 8080:80

# ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access at `http://localhost:8080`

## 💰 Cost Breakdown

Estimated monthly costs for running this infrastructure:

| Service | Configuration | Monthly Cost (USD) |
|---------|--------------|-------------------|
| EKS Cluster | Control Plane | $73.00 |
| EC2 Instances | 2x t3.medium nodes | ~$60.00 |
| Application Load Balancer | 2x ALBs | ~$32.00 |
| NAT Gateway | 2x AZs | ~$65.00 |
| Route53 Hosted Zone | 1 zone | $0.50 |
| Domain Registration | .click TLD | ~$0.25/month |
| Data Transfer | Minimal | ~$5.00 |
| **Total** | | **~$235/month** |

**Cost Optimization Tips**:
- Use a single ALB for multiple services (saves $16/month)
- Use t3.small instances for non-production (saves ~$30/month)
- Use NAT instances instead of NAT Gateway (saves ~$60/month)
- Stop cluster when not in use for testing

## 🔧 Troubleshooting

### Issue: Certificate Not Validating

**Solution**:
```bash
# Check certificate status
aws acm describe-certificate \
  --certificate-arn YOUR_CERT_ARN \
  --region ap-south-1

# Verify DNS validation records exist
aws route53 list-resource-record-sets \
  --hosted-zone-id YOUR_HOSTED_ZONE_ID \
  --query "ResourceRecordSets[?Type=='CNAME']"
```

### Issue: ALB Not Created

**Solution**:
```bash
# Check AWS Load Balancer Controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify controller is running
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### Issue: Ingress Shows 404

**Solution**:
```bash
# Check ingress details
kubectl describe ingress nginx-ingress

# Verify service endpoints
kubectl get endpoints nginx-service

# Check pod logs
kubectl logs deployment/nginx-deployment
```

### Issue: ArgoCD Application Not Syncing

**Solution**:
```bash
# Check application status
kubectl get application -n argocd

# View detailed status
kubectl describe application nginx-app -n argocd

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-server
```

### Issue: DNS Not Resolving

**Solution**:
```bash
# Verify DNS propagation (may take 5-10 minutes)
nslookup demoeks.click

# Check Route53 records
aws route53 list-resource-record-sets \
  --hosted-zone-id YOUR_HOSTED_ZONE_ID

# Verify ALB is healthy
aws elbv2 describe-target-health \
  --target-group-arn YOUR_TARGET_GROUP_ARN
```

### Issue: Pods Not Starting

**Solution**:
```bash
# Check pod status
kubectl get pods --all-namespaces

# Describe problematic pod
kubectl describe pod POD_NAME

# Check node resources
kubectl top nodes

# View pod logs
kubectl logs POD_NAME
```

## 🧹 Cleanup

To avoid ongoing charges, destroy all resources:

### 1. Delete Kubernetes Resources

```bash
#alternate to terraform destroy

# Delete ArgoCD applications
kubectl delete application --all -n argocd

# Delete ingress resources
kubectl delete ingress --all --all-namespaces

# Wait for ALBs to be deleted (2-3 minutes)
sleep 180

# Delete ArgoCD
kubectl delete namespace argocd

# Delete NGINX
kubectl delete -f manifests/
```

### 2. Destroy EKS Cluster

```bash
cd terraform/

terraform destroy
```

Type `yes` when prompted. This will take 10-15 minutes.

### 3. Delete Additional AWS Resources

```bash
# Delete ACM certificate
aws acm delete-certificate \
  --certificate-arn YOUR_CERT_ARN \
  --region ap-south-1

# Delete IAM policy
aws iam delete-policy \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy

# Delete Route53 hosted zone (if no longer needed)
aws route53 delete-hosted-zone \
  --id YOUR_HOSTED_ZONE_ID
```

### 4. Verify Cleanup

```bash
# Check for remaining resources
aws eks list-clusters --region ap-south-1
aws elbv2 describe-load-balancers --region ap-south-1
aws ec2 describe-vpcs --region ap-south-1
```

## 📚 Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## 📝 Notes

- All resources are deployed in `ap-south-1` (Mumbai) region
- EKS cluster uses Kubernetes v1.28 or later
- NGINX deployment uses 2 replicas for high availability
- ArgoCD is configured for automatic sync with GitOps principles
- SSL/TLS certificates are managed by AWS Certificate Manager
- Domain DNS is managed by Route53

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This project is open source and available under the MIT License.

---

**Author**: Prasad P  
**Repository**: https://github.com/PrasadP744/eks-terraform-argocd-nginx  
**Last Updated**: November 2025

