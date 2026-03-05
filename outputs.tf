output "instance_id" {
  value = aws_spot_instance_request.windows_instance.id
}

output "instance_ip" {
  value = aws_eip.windows_instance.public_ip
}

output "instance_password" {
  value = random_password.password.result
  sensitive = true
}