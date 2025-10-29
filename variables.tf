variable "region" {
  description = "AWS regio"
  type        = string
  default     = "eu-central-1"
}

variable "key_pair_name" {
  description = "Naam van het AWS Key Pair voor EC2"
  type        = string
}

variable "db_password" {
  description = "Database wachtwoord"
  type        = string
  sensitive   = true
}

variable "allowed_admin_ips" {
  description = "Lijst van IP-adressen met SSH-toegang"
  type        = list(string)
  default     = ["82.170.150.87/32", "145.93.76.108/32"]
}