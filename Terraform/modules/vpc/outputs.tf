output "vpc_id" {
  value = aws_vpc.wl6vpc.id
}

output "public_subnet_id_1" {
  value = aws_subnet.public_subnet_1.id
}

output "private_subnet_id_1" {
  value = aws_subnet.private_subnet_1.id
}

output "public_subnet_id_2" {
  value = aws_subnet.public_subnet_2.id
}

output "private_subnet_id_2" {
  value = aws_subnet.private_subnet_2.id
}

output "app_security_group_id" {
  value = aws_security_group.app_security_group.id
}