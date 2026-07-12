############################################
# EKS Managed Node Group
############################################

resource "aws_eks_node_group" "this" {

  cluster_name = var.cluster_name

  node_group_name = "${var.project_name}-${var.environment}-nodes"

  node_role_arn = var.node_role_arn

  subnet_ids = var.private_subnet_ids

  ami_type = "AL2023_x86_64_STANDARD"

  capacity_type = "ON_DEMAND"

  instance_types = [
    "t3.medium"
  ]

  scaling_config {

    desired_size = 2

    min_size = 2

    max_size = 3
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-node-group"
    }
  )
}
