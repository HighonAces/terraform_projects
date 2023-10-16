resource "aws_vpc" "EKSVPC" {
    cidr_block = "192.168.0.0/16"
    tags = {
      "Name" = var.VPC_name
      "terraform" = "true"
    }
}

resource "aws_subnet" "PublicSubnet1" {
  vpc_id = aws_vpc.EKSVPC.id
  cidr_block = "192.168.0.0/18"
  availability_zone = "us-east-2a"
  tags = {
    "Name" = format("%s-%s", var.subnet_name, "public1")
    "terraform" = "true"
  }
}

resource "aws_subnet" "PublicSubnet2" {
  vpc_id = aws_vpc.EKSVPC.id
  cidr_block = "192.168.64.0/18"
  availability_zone = "us-east-2b"
  tags = {
    "Name" = format("%s-%s", var.subnet_name, "public1")
    "terraform" = "true"
  }
}

resource "aws_subnet" "PrivateSubnet1" {
  vpc_id = aws_vpc.EKSVPC.id
  cidr_block = "192.168.128.0/18"
  availability_zone = "us-east-2a"
  tags = {
    "Name" = format("%s-%s", var.subnet_name, "private1")
    "terraform" = "true"
  }
}

resource "aws_subnet" "PrivateSubnet2" {
  vpc_id = aws_vpc.EKSVPC.id
  cidr_block = "192.168.192.0/18"
  availability_zone = "us-east-2b"
  tags = {
    "Name" = format("%s-%s", var.subnet_name, "private2")
    "terraform" = "true"
  }
}

resource "aws_internet_gateway" "igw4eks" {
  vpc_id = aws_vpc.EKSVPC.id

  tags = {
    "Name" = "IGW_for_EKS"
  }
}

resource "aws_eip" "IPforNAT" {
  domain = "vpc"

  tags = {
    "Name" = "EIP_for_EKS"
    "terraform" = "true"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.IPforNAT.id
  subnet_id = aws_subnet.PublicSubnet1.id

  tags = {
    "Name" = "NAT"
    "terraform" = "true"
  }

  depends_on = [ aws_internet_gateway.igw4eks ]
}

resource "aws_route_table" "privateTable" {
  vpc_id = aws_vpc.EKSVPC.id

  route {
      cidr_block                 = "0.0.0.0/0"
      nat_gateway_id             = aws_nat_gateway.nat.id
    }

   tags = {
     "Name" = "PrivateTable"
     "terraform" = "True"
   }
}

resource "aws_route_table" "publicTable" {
  vpc_id = aws_vpc.EKSVPC.id
  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.igw4eks.id
    }

  tags = {
    "Name" = "PublicTable"
    "terrafrom" = "true"
  }
}

resource "aws_route_table_association" "private-us-east-2a" {
  subnet_id = aws_subnet.PrivateSubnet1.id
  route_table_id = aws_route_table.privateTable.id
}

resource "aws_route_table_association" "private-us-east-2b" {
  subnet_id = aws_subnet.PrivateSubnet2.id
  route_table_id = aws_route_table.privateTable.id
}

resource "aws_route_table_association" "public-us-east-2a" {
  subnet_id = aws_subnet.PublicSubnet1.id
  route_table_id = aws_route_table.publicTable.id
}

resource "aws_route_table_association" "public-us-east-2b" {
  subnet_id = aws_subnet.PublicSubnet2.id
  route_table_id = aws_route_table.publicTable.id
}