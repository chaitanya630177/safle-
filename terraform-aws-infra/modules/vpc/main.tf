ii# modules/vpc/main.tf
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

resource "aws_eip" "nat_gateway" {
  count = length(var.public_subnets_cidr) # One EIP per public subnet for NAT Gateway
  domain = "vpc"
  tags = {
    Name = "${var.project_name}-${var.environment}-nat-eip-${count.index}"
  }
}

resource "aws_nat_gateway" "main" {
  count         = length(var.public_subnets_cidr) # One NAT Gateway per public subnet
  allocation_id = aws_eip.nat_gateway[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-gateway-${count.index}"
  }
  depends_on = [aws_internet_gateway.main]
}

resource "aws_subnet" "public" {
  count             = length(var.public_subnets_cidr)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnets_cidr[count.index]
  availability_zone = var.availability_zones[count.index]
  map_public_ip_on_launch = true # Instances in public subnets get public IPs by default

  tags = {
    Name = "${var.project_name}-${var.environment}-public-subnet-${var.availability_zones[count.index]}"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnets_cidr)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets_cidr[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-${var.environment}-private-subnet-${var.availability_zones[count.index]}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-public-rt"
  }
}

resource "aws_route_table" "private" {
  count  = length(var.private_subnets_cidr)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-private-rt-${var.availability_zones[count.index]}"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Security Group for the VPC (as a common base for other SGs)
resource "aws_security_group" "vpc_sg" {
  name_prefix = "${var.project_name}-${var.environment}-vpc-sg-"
  description = "Security Group for VPC-wide access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr_block] # Allow all traffic within the VPC
    description = "Allow all traffic within VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  tags = {
    Name = "${var.project_name}-${var.environment}-vpc-sg"
  }
}
