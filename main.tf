terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}
# Provider, it configures the specified provider here aws

provider "aws" {
    region = "us-east-1" # region where your server will be located 
    access_key = "AKIA6NSOKW7EEZ2PPPAI" # access key, this comes from AWS account 
    secret_key = "9e82yR5VcKo4JqRJG+43QycsTk7bTjTuHO+q7xna" # secret key comes from AWS Account
}
# Create a VPC 

resource "aws_vpc" "prod-vpc" {
    cidr_block = "10.0.0.0/16" # IP address range 

    tags = { # This specifies the name to be displayed on aws console 
      "Name" = "Prod-VPC"
    }
  
}

# Create an internet gateway

resource "aws_internet_gateway" "prod-gateway" {
    vpc_id = aws_vpc.prod-vpc.id #comes from the resource "aws_vpc" "prod-vpc"

    tags = {
      "Name" = "Prod_Gateway"
    }
  
}

# Create a route table

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod-gateway.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.prod-gateway.id
  }

  tags = {
    "Name" = "Prod-Route"
  }
  
}

# Create a subnet 

resource "aws_subnet" "prod-subnet0" {
  vpc_id = aws_vpc.prod-vpc.id
  availability_zone = "us-east-1c"
  cidr_block = "10.0.1.0/24"

  tags = {
    "Name" = "Prod-Subnet"
  }
  
}

# Associate subnet with a route table

resource "aws_route_table_association" "Prod-associate" {
  subnet_id      = aws_subnet.prod-subnet0.id
  route_table_id = aws_route_table.prod-route-table.id
}

# Create a security Group to allow traffc on port 22, 80, 443


resource "aws_security_group" "prod-allow_tls" {
  name        = "prod-allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

   ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

   ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Prod-Allow_tls"
  }
}

# Create a network interface with an IP in the subnet

resource "aws_network_interface" "prod-nic" {
  subnet_id       = aws_subnet.prod-subnet0.id
  private_ips     = ["10.0.1.20"]
  security_groups = [aws_security_group.prod-allow_tls.id]
}

# Assign an elastic IP address to the network interface
resource "aws_eip" "prod-eip" {
  vpc                       = true
  network_interface         = aws_network_interface.prod-nic.id
  associate_with_private_ip = "10.0.1.20"
  depends_on = [aws_internet_gateway.prod-gateway]
}

# Create an Ubuntu server and install Nginx 

resource "aws_instance" "web-server-instance" {
    ami = "ami-052efd3df9dad4825"
    instance_type = "t2.micro"
    availability_zone = "us-east-1c"
    key_name = "prod-key"

    network_interface {
        device_index = 0
        network_interface_id = aws_network_interface.prod-nic.id
      
    }

    user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install nginx -y
                sudo systemctl start nginx
                sudo bash -c 'echo his is my first Nginx server > /var/www/html/index.html'
                EOF

    tags = {
      "Name" = "Web-Server"
    }

  
}

