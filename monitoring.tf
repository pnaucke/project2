resource "aws_instance" "grafana" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.grafana_subnet.id
  private_ip             = "172.31.4.10"
  vpc_security_group_ids = [aws_security_group.grafana_sg.id]
  key_name               = "Project1"
  tags = { Name = "grafana" }

  user_data = <<-EOT
    #!/bin/bash
    yum update -y
    yum install -y wget tar
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
    systemctl enable grafana-server
    systemctl start grafana-server
  EOT
}

resource "grafana_dashboard" "web_monitoring" {
  config_json = file("${path.module}/grafana_dashboard/web_monitoring.json")
}
