#VPC
resource "aws_vpc" "prod_vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${var.name}-vpc"
  }
}

#Subnets
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = var.public_a_cidr
  availability_zone = var.az_a

  tags = {
    Name = "${var.name}-public-a"
  }
}
resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = var.public_b_cidr
  availability_zone = var.az_b

  tags = {
    Name = "${var.name}-public-b"
  }
}
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = var.private_a_cidr
  availability_zone = var.az_a

  tags = {
    Name = "${var.name}-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = var.private_b_cidr
  availability_zone = var.az_b

  tags = {
    Name = "${var.name}-private-b"
  }
}

#Internet Access
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.prod_vpc.id

  tags = {
    Name = "${var.name}-igw"
  }
}
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.name}-public-rt"
  }
}
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "public_assoc_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}

# NAT Gateway (for private subnet outbound internet access)

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "${var.name}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "${var.name}-nat-a"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }

  tags = {
    Name = "${var.name}-private-rt"
  }
}

resource "aws_route_table_association" "private_assoc_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_rt.id
}