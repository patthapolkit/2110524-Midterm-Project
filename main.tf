terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.region
}

# VPC
resource "aws_vpc" "wordpress_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "WordPress-VPC"
  }
}

# Subnets
resource "aws_subnet" "app_inet_subnet" {
  vpc_id                  = aws_vpc.wordpress_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zone

  tags = {
    Name = "App-Inet"
  }
}

resource "aws_subnet" "app_db_subnet" {
  vpc_id            = aws_vpc.wordpress_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.availability_zone

  tags = {
    Name = "App-DB"
  }
}

resource "aws_subnet" "db_inet_subnet" {
  vpc_id            = aws_vpc.wordpress_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = var.availability_zone

  tags = {
    Name = "DB-Inet"
  }
}

resource "aws_subnet" "nat_gw_subnet" {
  vpc_id            = aws_vpc.wordpress_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = var.availability_zone

  tags = {
    Name = "NAT-GW"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.wordpress_vpc.id

  tags = {
    Name = "WordPress-IGW"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "NAT-Gateway-EIP"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.nat_gw_subnet.id

  tags = {
    Name = "WordPress-NAT-GW"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Route Tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.wordpress_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "WordPress-Public-RT"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.wordpress_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "WordPress-Private-RT"
  }
}

# Route Table Associations
resource "aws_route_table_association" "app_inet_rta" {
  subnet_id      = aws_subnet.app_inet_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "nat_gw_rta" {
  subnet_id      = aws_subnet.nat_gw_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "db_inet_rta" {
  subnet_id      = aws_subnet.db_inet_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# Security Groups
resource "aws_security_group" "app_sg" {
  name        = "wordpress_app_sg"
  description = "Security group for WordPress application instance"
  vpc_id      = aws_vpc.wordpress_vpc.id

  # Allow HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP"
  }

  # Allow HTTPS from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS"
  }

  # Allow SSH from anywhere (for administration)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "WordPress-App-SG"
  }
}

resource "aws_security_group" "db_sg" {
  name        = "wordpress_db_sg"
  description = "Security group for MariaDB instance"
  vpc_id      = aws_vpc.wordpress_vpc.id

  # Allow MySQL/MariaDB access only from the application instance's private subnet
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.app_db_subnet.cidr_block]
    description = "Allow MariaDB from App-DB subnet"
  }

  # Allow SSH from the App-DB subnet
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.app_db_subnet.cidr_block]
    description = "Allow SSH from App-DB subnet"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "WordPress-DB-SG"
  }
}

# Network Interfaces
resource "aws_network_interface" "app_inet_eni" {
  subnet_id       = aws_subnet.app_inet_subnet.id
  security_groups = [aws_security_group.app_sg.id]

  tags = {
    Name = "WordPress-App-Public-ENI"
  }
}

resource "aws_network_interface" "app_db_eni" {
  subnet_id       = aws_subnet.app_db_subnet.id
  security_groups = [aws_security_group.app_sg.id]

  tags = {
    Name = "WordPress-App-Private-ENI"
  }
}

resource "aws_network_interface" "db_inet_eni" {
  subnet_id       = aws_subnet.db_inet_subnet.id
  security_groups = [aws_security_group.db_sg.id]

  tags = {
    Name = "WordPress-DB-Internet-ENI"
  }
}

resource "aws_network_interface" "db_app_eni" {
  subnet_id       = aws_subnet.app_db_subnet.id
  security_groups = [aws_security_group.db_sg.id]

  tags = {
    Name = "WordPress-DB-App-ENI"
  }
}

# Elastic IP for WordPress
resource "aws_eip" "wordpress_ip" {
  domain = "vpc"

  tags = {
    Name = "WordPress-Public-IP"
  }
}

# Elastic IP Association
resource "aws_eip_association" "wordpress_eip_assoc" {
  allocation_id        = aws_eip.wordpress_ip.id
  network_interface_id = aws_network_interface.app_inet_eni.id
}

# S3 Bucket for Media Storage
resource "aws_s3_bucket" "wordpress_media" {
  bucket = var.bucket_name

  tags = {
    Name = "WordPress-Media-Storage"
  }
}

resource "aws_s3_bucket_ownership_controls" "wordpress_media_ownership" {
  bucket = aws_s3_bucket.wordpress_media.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "wordpress_media_public_access" {
  bucket                  = aws_s3_bucket.wordpress_media.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "wordpress_media_policy" {
  bucket = aws_s3_bucket.wordpress_media.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.wordpress_media.arn}/*"
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.wordpress_media_public_access]
}

# IAM User for S3 Access
resource "aws_iam_user" "wordpress_s3_user" {
  name = "wordpress-s3-user"

  tags = {
    Name = "WordPress-S3-User"
  }
}

resource "aws_iam_access_key" "wordpress_s3_key" {
  user = aws_iam_user.wordpress_s3_user.name
}

resource "aws_iam_user_policy" "wordpress_s3_policy" {
  name = "wordpress-s3-policy"
  user = aws_iam_user.wordpress_s3_user.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "s3:*",
        Effect = "Allow",
        Resource = [
          "${aws_s3_bucket.wordpress_media.arn}",
          "${aws_s3_bucket.wordpress_media.arn}/*"
        ]
      }
    ]
  })
}

# EC2 Instances
resource "aws_instance" "wordpress_app" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = aws_key_pair.cloud_wordpress_key.key_name

  network_interface {
    network_interface_id = aws_network_interface.app_inet_eni.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.app_db_eni.id
    device_index         = 1
  }

  user_data = templatefile("${path.module}/wordpress_setup.sh", {
    db_host       = aws_network_interface.db_app_eni.private_ip
    db_name       = var.database_name
    db_user       = var.database_user
    db_pass       = var.database_pass
    admin_user    = var.admin_user
    admin_pass    = var.admin_pass
    s3_access_key = aws_iam_access_key.wordpress_s3_key.id
    s3_secret_key = aws_iam_access_key.wordpress_s3_key.secret
    s3_bucket     = aws_s3_bucket.wordpress_media.bucket
    s3_region     = var.region
    public_ip     = aws_eip.wordpress_ip.public_ip
  })

  tags = {
    Name = "WordPress-App-Instance"
  }

  depends_on = [aws_instance.mariadb]
}

resource "aws_instance" "mariadb" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = aws_key_pair.cloud_wordpress_key.key_name

  network_interface {
    network_interface_id = aws_network_interface.db_inet_eni.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.db_app_eni.id
    device_index         = 1
  }

  user_data = templatefile("${path.module}/mariadb_setup.sh", {
    db_name = var.database_name
    db_user = var.database_user
    db_pass = var.database_pass
  })

  tags = {
    Name = "WordPress-DB-Instance"
  }
}

# SSH Key Pair
resource "aws_key_pair" "cloud_wordpress_key" {
  key_name   = "cloud-wordpress-key"
  public_key = var.ssh_public_key
}
