output "cluster_role_arn" {
  description = "EKS Cluster IAM Role ARN"

  value = aws_iam_role.eks_cluster.arn
}

output "node_role_arn" {
  description = "EKS Node IAM Role ARN"

  value = aws_iam_role.eks_node.arn
}
output "ebs_csi_irsa_role_arn" {
  value = aws_iam_role.ebs_csi_irsa.arn
}
