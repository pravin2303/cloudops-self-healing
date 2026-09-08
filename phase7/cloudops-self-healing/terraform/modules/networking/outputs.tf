output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Map of AZ -> public subnet ID."
  value       = { for az, subnet in aws_subnet.public : az => subnet.id }
}

output "private_subnet_ids" {
  description = "Map of AZ -> private subnet ID."
  value       = { for az, subnet in aws_subnet.private : az => subnet.id }
}

output "availability_zones" {
  description = "List of AZs this network spans."
  value       = keys(var.public_subnet_cidrs)
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_ids" {
  description = "Map of AZ -> NAT Gateway ID (only the AZ(s) that actually have one)."
  value       = { for az, ngw in aws_nat_gateway.this : az => ngw.id }
}
