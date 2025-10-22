resource "aws_subnet" "public_1" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.0.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-public-1" }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.10.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-public-2" }
}

resource "aws_subnet" "web_1" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.1.0/24"
  availability_zone = "eu-central-1a"
  tags = { Name = "${var.project_name}-web-1" }
}

resource "aws_subnet" "web_2" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.11.0/24"
  availability_zone = "eu-central-1b"
  tags = { Name = "${var.project_name}-web-2" }
}

resource "aws_subnet" "db_1" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.2.0/24"
  availability_zone = "eu-central-1a"
  tags = { Name = "${var.project_name}-db-1" }
}

resource "aws_subnet" "db_2" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.12.0/24"
  availability_zone = "eu-central-1b"
  tags = { Name = "${var.project_name}-db-2" }
}

resource "aws_subnet" "soar" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.20.0/24"
  availability_zone = "eu-central-1a"
  tags = { Name = "${var.project_name}-soar" }
}
