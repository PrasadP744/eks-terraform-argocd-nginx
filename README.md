# EKS + Terraform + Helm(ALB Controller) + ArgoCD + NGINX (Mumbai / ap-south-1)

Assignment reference: `/mnt/data/DevOps  Assignment for Experienced.pdf` :contentReference[oaicite:1]{index=1}

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
- jq (useful)

---

## 1) Create S3 bucket for Terraform backend
```bash
aws s3 mb s3://eks-terraform-state-mumbai --region ap-south-1
aws s3api put-bucket-versioning --bucket eks-terraform-state-mumbai --versioning-configuration Status=Enabled --region ap-south-1
