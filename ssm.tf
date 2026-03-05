resource  "random_integer" "az_id" {
  min = 0
  max = length(var.allowed_availability_zone_identifier) - 1
}

resource "random_password" "password" {
  length = 32
  special = true
}

resource "aws_ssm_parameter" "password" {
  name = "cloud-gaming-administrator-password"
  type = "SecureString"
  value = random_password.password.result

  tags = {
    App = var.rs_app
  }
}