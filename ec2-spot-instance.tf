data "aws_ami" "windows_ami" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }
}

resource "aws_spot_instance_request" "windows_instance" {
  instance_type = var.instance_type
  ami = (length(var.custom_ami) > 0) ? var.custom_ami : data.aws_ami.windows_ami.image_id
  subnet_id              = aws_subnet.public1.id
  vpc_security_group_ids = [aws_security_group.default.id]
  user_data = templatefile("${path.module}/templates/user_data.tpl", {
    password_ssm_parameter=aws_ssm_parameter.password.name,
    var={
      instance_type=var.instance_type,
      install_parsec=var.install_parsec,
      install_auto_login=var.install_auto_login,
      install_graphic_card_driver=var.install_graphic_card_driver,
      install_steam=var.install_steam,
      install_epic_games_launcher=var.install_epic_games_launcher,
    }
    })
  iam_instance_profile = aws_iam_instance_profile.windows_instance_profile.id

  # Spot configuration
  spot_type = "one-time"
  wait_for_fulfillment = true

  # EBS configuration
  ebs_optimized = true
  root_block_device {
    volume_size = var.root_block_device_size_gb
  }

  tags = {
    Name = var.rs_name
    App = var.rs_app
  }
}

resource "aws_eip" "windows_instance" {
  domain = "vpc"

  tags = {
    Name = var.rs_name
    App  = var.rs_app
  }
}

resource "aws_eip_association" "windows_instance" {
  instance_id   = aws_spot_instance_request.windows_instance.spot_instance_id
  allocation_id = aws_eip.windows_instance.id
}