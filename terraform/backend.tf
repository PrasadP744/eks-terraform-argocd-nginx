terraform {
  backend "s3" {
    bucket = "eks-terraform-state-mumbai"
    key    = "eks-argocd-demo/terraform.tfstate"
    region = "ap-south-1"
  }
}
