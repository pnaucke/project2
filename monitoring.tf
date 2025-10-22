# AWS Managed Grafana workspace
resource "aws_grafana_workspace" "grafana" {
  name          = "${var.project_name}-grafana"
  account_access_type = "SERVICE_MANAGED"
  authentication_providers = ["AWS_SSO"]
  permission_type = "SERVICE_MANAGED"
  region = var.aws_region
}

# Optioneel: CloudWatch dashboard kan hier later toegevoegd worden
# Grafana kan CloudWatch metrics automatisch lezen
