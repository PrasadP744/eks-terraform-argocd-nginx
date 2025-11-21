module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                   = var.vpc_id
  subnet_ids               = var.private_subnets
  control_plane_subnet_ids = var.private_subnets

  enable_irsa = true

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  eks_managed_node_groups = {
    default = {
      min_size     = 3
      desired_size = 3
      max_size     = 3

      instance_types = [var.node_instance_type]
      capacity_type  = "ON_DEMAND"
    }
  }

  cluster_addons = {
    vpc-cni = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
  }
}
