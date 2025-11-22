terraform {
  backend "s3" {
    bucket  = "eks-terraform-state-mumbai"
    key     = "eks-cluster/terraform.tfstate"
    region  = "ap-south-1"
    encrypt = true
  }
}
