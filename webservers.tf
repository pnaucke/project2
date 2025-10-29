# ----------------------
# User Data voor Webservers
# ----------------------
locals {
  user_data = <<-EOT
    #!/bin/bash
    yum update -y
    amazon-linux-extras enable nginx1
    yum install -y nginx mysql wget tar
    ...
    systemctl enable --now node_exporter
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
  user_data              = local.user_data
  tags = { Name = "web1" }
}

resource "aws_instance" "web2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.web2_subnet.id
  private_ip             = "172.31.11.10"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = "Project1"
  user_data              = local.user_data
  tags = { Name = "web2" }
}
