module "vpc" {
  source = "./modules/vpc"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs = [
    "ap-south-1a",
    "ap-south-1b",
    "ap-south-1c"
  ]
}

module "eks" {
  source = "./modules/eks"

  cluster_name     = var.cluster_name
  cluster_version  = var.cluster_version
  vpc_id           = module.vpc.vpc_id
  private_subnets  = module.vpc.private_subnet_ids
  public_subnets   = module.vpc.public_subnet_ids
  node_instance_type = var.node_instance_type
}
