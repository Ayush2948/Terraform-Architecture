# Mentioning provider
provider "aws" {
  region = "ap-south-1"
}

# Custom VPC
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "Architecture_1"
  }
}

# Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpc.id  
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1a"
  tags = {
    Name = "public-subnet"
  }
}

# Private Subnet 1
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "private-subnet"
  }
}

# Private Subnet 2
resource "aws_subnet" "private_subnet1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "private-subnet1"
  }
}

# Creating Security Group for ec2 and rds
resource "aws_security_group" "sg" {
  vpc_id      = aws_vpc.vpc.id
  name        = "security-group"
  description = "Allow SSH, HTTP, HTTPS, and MySQL"
  
  # Ingress rules(inbound)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private_subnet1.cidr_block]
  }

  # Egress rules (outbound)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 1st EC2
resource "aws_instance" "nginx" {
  ami                         = "ami-0ff30663ed13c2290"
  instance_type               = "t2.micro"
  key_name                    = "key11"
  monitoring                  = true
  vpc_security_group_ids      = [aws_security_group.sg.id]
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  user_data                   = "${file("data.sh")}"
  tags = {
    Name = "first-ec2"
  }  
}

# 2nd EC2
resource "aws_instance" "web" {
  ami                         = "ami-0ff30663ed13c2290"
  instance_type               = "t2.micro"
  key_name                    = "key11"
  monitoring                  = true
  vpc_security_group_ids      = [aws_security_group.sg.id]
  subnet_id                   = aws_subnet.private_subnet.id
  tags = {
    Name = "second-ec2"
  }
}

# 3rd EC2
resource "aws_instance" "web1" {
  ami                         = "ami-0ff30663ed13c2290"
  instance_type               = "t2.micro"
  key_name                    = "key11"
  monitoring                  = true
  vpc_security_group_ids      = [aws_security_group.sg.id]
  subnet_id                   = aws_subnet.private_subnet1.id
  tags = {
    Name = "third-ec2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "Internet_Gateway"
  }
}

# Route Table for Public Subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "public_route"
  }
}

# Route for Public Subnet
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

# Associate the custom route table with the public subnet
resource "aws_route_table_association" "subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public_subnet.id
}

# Creating RDS
resource "aws_db_subnet_group" "dbsubnet" {
  name       = "main"
  subnet_ids = [aws_subnet.private_subnet.id, aws_subnet.private_subnet1.id]
}

resource "aws_db_instance" "db" {
  identifier             = "database"  # This is the instance identifier
  allocated_storage      = 20
  engine                 = "mysql" # This is the database type
  instance_class         = "db.t2.micro"
  username               = "arch"
  password               = "1starchpass"
  engine_version         = "8.0.33" # This is the version of MySQL
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.dbsubnet.name
  vpc_security_group_ids = [aws_security_group.sg.id] # This is the security group
}

# Creating Elastic IP (EIP)
resource "aws_eip" "eip" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.gw]
}

