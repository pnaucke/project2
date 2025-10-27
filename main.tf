terraform {
  backend "s3" {
    bucket         = "innovatech-terraform-state"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }

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
# Subnets
# ----------------------
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

resource "aws_subnet" "soar_subnet" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.3.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = false
  tags = { Name = "soar-subnet" }
}

resource "aws_subnet" "grafana_subnet" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.4.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true
  tags = { Name = "grafana-subnet" }
}

# ----------------------
# AMI and random suffix
# ----------------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "random_id" "suffix" {
  byte_length = 2
}

# ----------------------
# Security Groups
# ----------------------
resource "aws_security_group" "web_sg" {
  name   = "web-sg-${random_id.suffix.hex}"
  vpc_id = data.aws_vpc.default.id

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

# Security group rule for Prometheus scraping
resource "aws_security_group_rule" "web_from_grafana" {
  type                     = "ingress"
  from_port                = 9100
  to_port                  = 9100
  protocol                 = "tcp"
  security_group_id        = aws_security_group.web_sg.id
  source_security_group_id = aws_security_group.grafana_sg.id
}

# ----------------------
# User Data voor Webservers (Node Exporter automatisch)
# ----------------------
locals {
  web_user_data = <<-EOT
    #!/bin/bash
    set -e

    yum update -y
    amazon-linux-extras enable nginx1 -y
    yum install -y nginx wget tar

    systemctl start nginx
    systemctl enable nginx

    # Node Exporter
    useradd --no-create-home --shell /bin/false node_exporter

    cd /tmp
    wget https://github.com/prometheus/node_exporter/releases/download/v1.8.0/node_exporter-1.8.0.linux-amd64.tar.gz
    tar xvf node_exporter-1.8.0.linux-amd64.tar.gz
    cp node_exporter-1.8.0.linux-amd64/node_exporter /usr/local/bin/
    chown node_exporter:node_exporter /usr/local/bin/node_exporter
    chmod +x /usr/local/bin/node_exporter

    # Systemd service
    cat <<EOF >/etc/systemd/system/node_exporter.service
    [Unit]
    Description=Node Exporter
    After=network.target

    [Service]
    User=node_exporter
    ExecStart=/usr/local/bin/node_exporter

    [Install]
    WantedBy=multi-user.target
    EOF

    systemctl daemon-reload
    systemctl enable --now node_exporter

    # Wait until Node Exporter is serving metrics
    until curl -s http://127.0.0.1:9100/metrics; do
        echo "Waiting for Node Exporter..."
        sleep 5
    done
  EOT
}

# ----------------------
# Webservers
# ----------------------
resource "aws_instance" "web1" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.web1_subnet.id
  private_ip             = "172.31.1.10"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = "Project1"
  user_data              = local.web_user_data
  tags = { Name = "web1" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "web2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.web2_subnet.id
  private_ip             = "172.31.11.10"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = "Project1"
  user_data              = local.web_user_data
  tags = { Name = "web2" }

  lifecycle {
    create_before_destroy = true
  }
}

# ----------------------
# Grafana instance
# ----------------------
locals {
  grafana_user_data = <<-EOT
    #!/bin/bash
    yum update -y
    yum install -y wget tar

    # Install Grafana
    cat <<EOF > /etc/yum.repos.d/grafana.repo
    [grafana]
    name=grafana
    baseurl=https://packages.grafana.com/oss/rpm
    repo_gpgcheck=1
    enabled=1
    gpgcheck=1
    gpgkey=https://packages.grafana.com/gpg.key
    EOF

    yum install -y grafana
    systemctl enable --now grafana-server

    # Install Prometheus
    cd /tmp
    wget https://github.com/prometheus/prometheus/releases/download/v2.47.0/prometheus-2.47.0.linux-amd64.tar.gz
    tar xvf prometheus-2.47.0.linux-amd64.tar.gz
    cd prometheus-2.47.0.linux-amd64

    mkdir -p /etc/prometheus
    cat <<EOF >/etc/prometheus/prometheus.yml
    global:
      scrape_interval: 15s

    scrape_configs:
      - job_name: 'node_exporter'
        static_configs:
          - targets: ['${aws_instance.web1.private_ip}:9100','${aws_instance.web2.private_ip}:9100']
    EOF

    cp prometheus /usr/local/bin/
    cp promtool /usr/local/bin/

    cat <<EOF >/etc/systemd/system/prometheus.service
    [Unit]
    Description=Prometheus
    Wants=network-online.target
    After=network-online.target

    [Service]
    ExecStart=/usr/local/bin/prometheus \\
      --config.file=/etc/prometheus/prometheus.yml \\
      --storage.tsdb.path=/var/lib/prometheus/ \\
      --web.listen-address=:9090 \\
      --web.enable-lifecycle
    Restart=always

    [Install]
    WantedBy=multi-user.target
    EOF

    mkdir -p /var/lib/prometheus
    systemctl daemon-reload
    systemctl enable --now prometheus
  EOT
}

resource "aws_instance" "grafana" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.grafana_subnet.id
  private_ip             = "172.31.4.10"
  vpc_security_group_ids = [aws_security_group.grafana_sg.id]
  key_name               = "Project1"
  user_data              = local.grafana_user_data
  tags = { Name = "grafana" }
}

# ----------------------
# Load Balancer
# ----------------------
resource "aws_lb" "web_lb" {
  name               = "web-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.web1_subnet.id, aws_subnet.web2_subnet.id]
  security_groups    = [aws_security_group.lb_sg.id]
}

resource "aws_lb_target_group" "web_tg" {
  name        = "web-tg-${random_id.suffix.hex}"
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
# Outputs
# ----------------------
output "load_balancer_dns" {
  value = aws_lb.web_lb.dns_name
}

output "grafana_private_ip" {
  value = aws_instance.grafana.private_ip
}