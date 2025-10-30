# Subnets
resource "aws_subnet" "web1_subnet" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true
  tags = { Name = "web-subnet-1" }
}

resource "aws_subnet" "web2_subnet" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.11.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true
  tags = { Name = "web-subnet-2" }
}

resource "aws_subnet" "db_subnet1" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.2.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = false
  tags = { Name = "db-subnet-1" }
}

resource "aws_subnet" "db_subnet2" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.21.0/24"
  availability_zone       = "eu-central-1c"
  map_public_ip_on_launch = false
  tags = { Name = "db-subnet-2" }
}
