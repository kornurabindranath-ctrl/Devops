output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr" {
  value = module.vpc.vpc_cidr
}
output "internet_gateway_id" {
  value = module.vpc.internet_gateway_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}
output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}
output "nat_eip" {
  value = module.vpc.nat_eip
}
output "nat_gateway_id" {
  value = module.vpc.nat_gateway_id
}
output "public_route_table_id" {
  value = module.vpc.public_route_table_id
}

output "private_route_table_id" {
  value = module.vpc.private_route_table_id
}
output "cluster_role_arn" {
  value = module.iam.cluster_role_arn

}

output "node_role_arn" {
  value = module.iam.node_role_arn

}
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
output "node_group_name" {
  value = module.node_group.node_group_name
}
output "ebs_csi_irsa_role_arn" {
  value = module.iam.ebs_csi_irsa_role_arn
}
