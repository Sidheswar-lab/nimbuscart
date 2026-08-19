output "app_vpc_id" {
  value = aws_vpc.app.id
}

output "data_vpc_id" {
  value = aws_vpc.data.id
}

output "web_subnet_id" {
  value = aws_subnet.web.id
}

output "app_subnet_id" {
  value = aws_subnet.app.id
}

output "data_subnet_id" {
  value = aws_subnet.data.id
}

output "web_instance_id" {
  value = aws_instance.web.id
}

output "web_public_ip" {
  value = aws_instance.web.public_ip
}

output "app_instance_id" {
  value = aws_instance.app.id
}

output "app_private_ip" {
  value = aws_instance.app.private_ip
}

output "data_instance_id" {
  value = aws_instance.data.id
}

output "data_private_ip" {
  value = aws_instance.data.private_ip
}
