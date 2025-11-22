module "vpc" {
  source = "./modules/vpc"
  
  vpc_name             = "${var.cluster_name}-vpc"
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  environment          = var.environment
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  # Tags required for EKS
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
  
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

module "eks" {
  source = "./modules/eks"
  
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  
  vpc_id                   = module.vpc.vpc_id
  private_subnet_ids       = module.vpc.private_subnet_ids
  control_plane_subnet_ids = module.vpc.private_subnet_ids
  
  # Enable IRSA (IAM Roles for Service Accounts)
  enable_irsa = true
  
  # Cluster endpoint access
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  
  # REMOVE THIS BLOCK - Encryption is already handled inside the module
  # cluster_encryption_config = {
  #   resources        = ["secrets"]
  #   provider_key_arn = null
  # }
  
  # Enable control plane logging
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]
  
  # Node group configuration
  node_groups = {
    main = {
      name           = "${var.cluster_name}-node-group"
      desired_size   = var.node_group_desired_size
      min_size       = var.node_group_min_size
      max_size       = var.node_group_max_size
      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"
      disk_size      = 50
      
      # Use AL2023 for EKS 1.33
      ami_type = "AL2023_x86_64_STANDARD"
      
      labels = {
        Environment = var.environment
        NodeGroup   = "main"
      }
      
      tags = {
        Name = "${var.cluster_name}-node"
      }
    }
  }
  
  environment = var.environment
}
