locals {
  soar_user_data = <<-EOT
#!/bin/bash
yum update -y
yum install -y wget tar

# SOAR installatie (voorbeeld)
cd /tmp
wget https://example.com/soar-latest.tar.gz
tar xvf soar-latest.tar.gz
cd soar
./install.sh

systemctl enable soar
systemctl start soar
EOT
}

resource "aws_instance" "soar" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.soar_subnet.id
  private_ip             = "172.31.3.10"
  vpc_security_group_ids = [aws_security_group.soar_sg.id]
  key_name               = "Project1"
  user_data              = local.soar_user_data
  tags = { Name = "soar" }
}