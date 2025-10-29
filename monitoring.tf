# ----------------------
# Grafana instance
# ----------------------
locals {
  grafana_user_data = <<-EOT
    #!/bin/bash
    yum update -y
    yum install -y wget tar
    ...
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
