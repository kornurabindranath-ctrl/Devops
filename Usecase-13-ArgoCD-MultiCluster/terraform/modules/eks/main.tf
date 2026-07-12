############################################
# EKS Cluster
############################################

resource "aws_eks_cluster" "this" {

  name = "${var.project_name}-${var.environment}"

  role_arn = var.cluster_role_arn

  version = "1.33"

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {

    subnet_ids = var.private_subnet_ids

    endpoint_private_access = true

    endpoint_public_access = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}"
    }
  )
}
