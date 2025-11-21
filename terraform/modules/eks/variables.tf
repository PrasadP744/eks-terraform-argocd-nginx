variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "cluster_version" {
  type        = string
  description = "EKS Kubernetes version"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for the cluster"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnets for nodes and control plane"
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnets (usually for load balancers)"
}

variable "node_instance_type" {
  type        = string
  description = "Instance type for worker nodes"
  default     = "t3.medium"
}
