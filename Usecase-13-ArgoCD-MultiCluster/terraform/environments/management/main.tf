module "vpc" {

  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment

  vpc_cidr = var.vpc_cidr

  availability_zones = var.availability_zones

  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}
module "iam" {

  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment

  oidc_provider_arn = "arn:aws:iam::497508796460:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/04BBFEC0FAB11A298B9DF4E58E7D8057"

  oidc_issuer_url = module.eks.oidc_issuer_url
}
module "eks" {
  source = "../../modules/eks"

  project_name = var.project_name
  environment  = var.environment

  cluster_role_arn   = module.iam.cluster_role_arn
  private_subnet_ids = module.vpc.private_subnet_ids
}
module "node_group" {
  source = "../../modules/node-group"

  project_name = var.project_name
  environment  = var.environment

  cluster_name       = module.eks.cluster_name
  node_role_arn      = module.iam.node_role_arn
  private_subnet_ids = module.vpc.private_subnet_ids
}
module "addons" {

  source = "../../modules/addons"

  cluster_name = module.eks.cluster_name

  ebs_csi_irsa_role_arn = module.iam.ebs_csi_irsa_role_arn
}
