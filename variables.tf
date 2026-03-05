variable "rs_app" {
  description = "Resource app value"
  type = string
}

variable "rs_name" {
  description = "Resource name value"
  type = string
}

variable "aws_region" {
  description = "aws regions value"
  type = string
}

variable "public_subnet_1" {
  description = "public subnet availability zone"
  type = string
}

variable "vpc_cidr" {
  description = "vpc cidr value"
  type = string
}

variable "subnet_cidr_1" {
  description = "public subnet 1 cidr value"
  type = string
}

variable "my_public_ip" {
  description = "Your public IP address for RDP/VNC access. Set in terraform.tfvars."
  type = string
}

variable "instance_type" {
  description = "Type of ec2 instance size"
  type = string
}

locals {
  availability_zone = "${var.aws_region}${element(var.allowed_availability_zone_identifier, random_integer.az_id.result)}"
}

variable "allowed_availability_zone_identifier" {
  description = "The allowed availability zone identify (the letter suffixing the region). Choose ones that allows you to request the desired instance as spot instance in your region. An availability zone will be selected at random and the instance will be booted in it."
  type = list(string)
  default = ["a", "b"]
}

variable "root_block_device_size_gb" {
  description = "The size of the root block device (C:\\ drive) attached to the instance"
  type = number
  default = 120
}

variable "custom_ami" {
  description = "Use the specified AMI instead of the most recent windows AMI in available in the region"
  type = string
  default = ""
}

variable "install_parsec" {
  description = "Download and run Parsec-Cloud-Preparation-Tool on first login"
  type = bool
  default = true
}

variable "install_auto_login" {
  description = "Configure auto-login on first boot"
  type = bool
  default = true
}

variable "install_graphic_card_driver" {
  description = "Download and install the Nvidia driver on first boot"
  type = bool
  default = true
}

variable "install_steam" {
  description = "Download and install Valve Steam on first boot"
  type = bool
  default = true
}

variable "install_epic_games_launcher" {
  description = "Download and install EPIC Games Launcher on first boot"
  type = bool
  default = false
}