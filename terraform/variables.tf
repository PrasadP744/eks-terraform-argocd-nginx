variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_name" {
  description = "Name for the VPC"
  type        = string
  default     = "eks-demo-vpc"
}

variable "vpc_cidr" {
  description = "CIDR for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_name" {
  description = "EKS Cluster name"
  type        = string
  default     = "eks-argocd-demo"
}

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "node_instance_type" {
  description = "Instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}
