variable "vpc_cidr" {
  default = "10.0.0.0/16"
}


resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "aurora-vpc"
  }
}

resource "aws_subnet" "isolated" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "isolated-subnet-${count.index + 1}"
  }
}

resource "aws_route_table" "isolated" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "isolated-route-table"
  }
}

resource "aws_route_table_association" "isolated" {
  count          = 2
  subnet_id      = aws_subnet.isolated[count.index].id
  route_table_id = aws_route_table.isolated.id
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "aurora-subnet-group"
  subnet_ids = aws_subnet.isolated[*].id

  tags = {
    Name = "Aurora DB Subnet Group"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}
