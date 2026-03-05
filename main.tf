resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"

    tags = {
        App = "cloud-gaming"
    }
}

resource "aws_subnet" "public1" {
    vpc_id = aws_vpc.main.id
    cidr_block = var.subnet_cidr_1
    availability_zone = var.public_subnet_1
    map_public_ip_on_launch = true

    tags = {
        App = var.rs_app
    }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    App = var.rs_app
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    App = var.rs_app
  }
}

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "default" {
  name   = "cloud-gaming-sg"
  vpc_id = aws_vpc.main.id

  tags = {
    App = var.rs_app
  }
}

# Allow rdp connections from the local ip
resource "aws_security_group_rule" "rdp_ingress" {
  type = "ingress"
  description = "Allow rdp connections (port 3389)"
  from_port = 3389
  to_port = 3389
  protocol = "tcp"
  cidr_blocks = ["${var.my_public_ip}/32"]
  security_group_id = aws_security_group.default.id
}

# Allow vnc connections from the local ip
resource "aws_security_group_rule" "vnc_ingress" {
  type = "ingress"
  description = "Allow vnc connections (port 5900)"
  from_port = 5900
  to_port = 5900
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"] #change this to the below to allow only your IP to access 
  #cidr_blocks = ["${var.my_public_ip}/32"] 
  security_group_id = aws_security_group.default.id
}


# Allow outbound connection to everywhere
resource "aws_security_group_rule" "default" {
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.default.id
}