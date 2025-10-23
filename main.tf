terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = "eu-central-1"
}

# ----------------------
# Default VPC
# ----------------------
data "aws_vpc" "default" {
  default = true
}

# ----------------------
# Random suffix voor unieke namen
# ----------------------
resource "random_id" "suffix" {
  byte_length = 2
}

# ----------------------
# Subnets
# ----------------------
resource "aws_subnet" "public1" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.0.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-1" }
}

resource "aws_subnet" "public2" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.10.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-2" }
}

resource "aws_subnet" "web1" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = false
  tags = { Name = "web-subnet-1" }
}

resource "aws_subnet" "web2" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.11.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = false
  tags = { Name = "web-subnet-2" }
}

resource "aws_subnet" "db1" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.2.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = false
  tags = { Name = "db-subnet-1" }
}

resource "aws_subnet" "db2" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.12.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = false
  tags = { Name = "db-subnet-2" }
}

resource "aws_subnet" "soar" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.20.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = false
  tags = { Name = "soar-subnet" }
}

resource "aws_subnet" "grafana" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.21.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = false
  tags = { Name = "grafana-subnet" }
}

# ----------------------
# Security Groups
# ----------------------
resource "aws_security_group" "web_sg" {
  name   = "web-sg-${random_id.suffix.hex}"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  ingress {
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.grafana_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["82.170.150.87/32", "145.93.76.108/32", "SCHOOL_IP/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  name   = "db-sg-${random_id.suffix.hex}"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  ingress {
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.grafana_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "soar_sg" {
  name   = "soar-sg-${random_id.suffix.hex}"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.db_sg.id]
  }

  ingress {
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [aws_security_group.grafana_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "grafana_sg" {
  name   = "grafana-sg-${random_id.suffix.hex}"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  ingress {
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [aws_security_group.soar_sg.id]
  }

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.db_sg.id]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["82.170.150.87/32","145.93.76.108/32","SCHOOL_IP/32"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["82.170.150.87/32","145.93.76.108/32","SCHOOL_IP/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "lb_sg" {
  name   = "lb-sg-${random_id.suffix.hex}"
  vpc_id = data.aws_vpc.default.id

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ----------------------
# Database
# ----------------------
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db-subnet-group"
  subnet_ids = [aws_subnet.db1.id, aws_subnet.db2.id]
}

resource "aws_db_instance" "db" {
  identifier              = "mydb-${random_id.suffix.hex}"
  allocated_storage       = 20
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  db_name                 = "myappdb"
  username                = "admin"
  password                = "SuperSecret123!"
  parameter_group_name    = "default.mysql8.0"
  skip_final_snapshot     = true
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.name
  publicly_accessible     = false
}

# ----------------------
# Webservers user data
# ----------------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

locals {
  user_data = <<-EOT
    #!/bin/bash
    yum update -y
    amazon-linux-extras enable nginx1
    yum install -y nginx mysql wget tar

    systemctl start nginx
    systemctl enable nginx

    MY_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

    DB_TEST="OK"
    mysql -h ${aws_db_instance.db.address} -uadmin -pSuperSecret123! -e "SELECT 1;" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      DB_TEST="FAILED"
    fi

    echo "<h1>Welkom bij mijn website!</h1>" > /usr/share/nginx/html/index.html
    echo "<p>Deze webserver IP: $MY_IP</p>" >> /usr/share/nginx/html/index.html
    echo "<p>Database verbindingstest: $DB_TEST</p>" >> /usr/share/nginx/html/index.html
  EOT
}

# ----------------------
# Webservers
# ----------------------
resource "aws_instance" "web1" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.web1.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = "Project1"
  user_data              = local.user_data
  tags = { Name = "web1" }
}

resource "aws_instance" "web2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.web2.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = "Project1"
  user_data              = local.user_data
  tags = { Name = "web2" }
}

# ----------------------
# Grafana instance
# ----------------------
resource "aws_instance" "grafana" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.grafana.id
  vpc_security_group_ids = [aws_security_group.grafana_sg.id]
  key_name               = "Project1"
  tags = { Name = "grafana" }
}

# ----------------------
# Load Balancer
# ----------------------
resource "aws_lb" "web_lb" {
  name               = "web-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public1.id, aws_subnet.public2.id]
  security_groups    = [aws_security_group.lb_sg.id]
}

resource "aws_lb_target_group" "web_tg" {
  name        = "web-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "web1_attach" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web2_attach" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web2.id
  port             = 80
}

# ----------------------
# SOAR Components
# ----------------------
# DynamoDB Table
resource "aws_dynamodb_table" "soar_logs" {
  name         = "soar-logs-${random_id.suffix.hex}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "Event"

  attribute {
    name = "Event"
    type = "S"
  }
}

# IAM Role
resource "aws_iam_role" "lambda_role" {
  name = "soar-lambda-role-${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_ec2_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_sns_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

# Lambda
resource "aws_lambda_function" "soar_lambda" {
  function_name = "soar-lambda-${random_id.suffix.hex}"
  handler       = "lambda_function.handler"
  runtime       = "python3.10"
  role          = aws_iam_role.lambda_role.arn
  filename      = "lambda_function_payload.zip"

  vpc_config {
    subnet_ids         = [aws_subnet.soar.id]
    security_group_ids = [aws_security_group.soar_sg.id]
  }

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.soar_logs.name
      PROJECT_NAME   = "project"
    }
  }
}

# ----------------------
# Outputs
# ----------------------
output "load_balancer_dns" {
  value = aws_lb.web_lb.dns_name
}

output "db_endpoint" {
  value = aws_db_instance.db.address
}

output "grafana_public_ip" {
  value = aws_instance.grafana.public_ip
}