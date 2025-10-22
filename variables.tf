variable "aws_region" {
  description = "AWS regio waar de infrastructuur wordt gedeployed"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project naam voor tagging en resource namen"
  type        = string
  default     = "project2"
}

variable "allowed_ssh_ips" {
  description = "IP-adressen die SSH toegang hebben"
  type        = list(string)
  default     = ["82.170.150.87/32", "SCHOOL_IP/32"]
}

variable "db_password" {
  description = "Database password"
  type        = string
  default     = "SuperSecret123!"
}
