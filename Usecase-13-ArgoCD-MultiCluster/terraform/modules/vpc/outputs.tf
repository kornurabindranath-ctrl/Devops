output "vpc_id" {
  description = "VPC ID"

  value = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR"

  value = aws_vpc.this.cidr_block
}
output "internet_gateway_id" {
  description = "Internet Gateway ID"

  value = aws_internet_gateway.this.id
}
output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}
output "private_subnet_ids" {
  description = "Private subnet IDs"

  value = aws_subnet.private[*].id
}
output "nat_eip" {
  description = "Elastic IP for NAT Gateway"

  value = aws_eip.nat.public_ip
}
output "nat_gateway_id" {
  description = "NAT Gateway ID"

  value = aws_nat_gateway.this.id
}
output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}
