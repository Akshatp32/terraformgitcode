terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.12.0"
    }
  }
}
provider "aws" {
  region     = var.region_Name
  access_key = var.access_key
  secret_key = var.secret_key
}

# genrate key using tls module 
resource "tls_private_key" "ins_key" {
  algorithm = "RSA"
}

# genrate key pair on aws 
resource "aws_key_pair" "mykey" {
  key_name   = "ins_test_key"
  public_key = tls_private_key.ins_key.public_key_openssh
}

# crate a custom vpc 
resource "aws_vpc" "myvpc" {
  cidr_block       = var.vpc_cidrblock
  instance_tenancy = "default"

  tags = {
    Name = var.vpc_name
  }
}

# create subnet1 as public 
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.subnet1_cidrblock
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Subnet1_Public_Myvpc"
  }
}
# create subnet2 as public 
resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.subnet2_cidrblock
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "Subnet2_Public_Myvpc"
  }
}
# create subnet3 as public 
resource "aws_subnet" "subnet3" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.subnet3_cidrblock
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "Subnet3_Public_Myvpc"
  }
}

# create security group for instance 
resource "aws_security_group" "public_grp" {
  name        = "Allow ALL RULE"
  description = "Allow  inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description      = "ALLOW Http"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
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
    Name = "Public-grp"
  }
}
# create security group for instance 
resource "aws_security_group" "private_grp" {
  name        = "Allow database access"
  description = "Allow  inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description      = "ALLOW in Database "
    from_port        = 3306
    to_port          = 3306
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
    Name = "Private-Secgrp"
  }
}

# crate a internetgateway for vpc
resource "aws_internet_gateway" "myvpcigw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "MyVpc_igw"
  }
}

# create a route table for Public Sudbnet 
resource "aws_route_table" "Publicrt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myvpcigw.id
  }

  tags = {
    "Name" = "PublicRT_MyVpc"
  }
}

# Associate subnet1 with publicRT 
resource "aws_route_table_association" "publicsubnet1assosiate" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.Publicrt.id
}

resource "aws_db_subnet_group" "my_dbsubnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.subnet2.id, aws_subnet.subnet3.id]
}

resource "aws_db_instance" "my_db_instance" {
  identifier           = "my-db-instance"
  engine               = "mysql"
  engine_version       = "8.0.28"
  instance_class       = var.db_instance
  db_name              = var.database_name
  allocated_storage    = 20
  username             = var.username
  password             = var.password
  db_subnet_group_name = aws_db_subnet_group.my_dbsubnet_group.name
  vpc_security_group_ids = [
    aws_security_group.private_grp.id
  ]
  multi_az                  = false
  skip_final_snapshot       = true
  publicly_accessible       = false
  final_snapshot_identifier = "my-final-snapshot"
}

# create Public instance 
resource "aws_instance" "instance1" {
  ami                    = var.instance_ami
  instance_type          = var.server_instance
  subnet_id              = aws_subnet.subnet1.id
  vpc_security_group_ids = [aws_security_group.public_grp.id]
  key_name               = aws_key_pair.mykey.key_name
  tags = {
    "Name" = "Ins1"
  }
}

# output of database endpoint link and port
output "db_endpoint" {
  value = aws_db_instance.my_db_instance.endpoint
}
output "rds_port" {
  value = aws_db_instance.my_db_instance.port
}

# download key pair file in local system 
resource "local_file" "private_key" {
  content  = tls_private_key.ins_key.private_key_pem
  filename = "Host.pem"
}

# output of public ip
output "outputip_Public_Instance1" {
  value = aws_instance.instance1.public_ip
}

# output of key pair file 
output "ins_key" {
  value     = tls_private_key.ins_key.private_key_pem
  sensitive = true
}