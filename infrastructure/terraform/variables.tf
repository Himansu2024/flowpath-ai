# infrastructure/terraform/variables.tf
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Deployment environment (production | staging)"
  type        = string
  default     = "production"
  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "environment must be production, staging, or development."
  }
}

variable "ubuntu_ami" {
  description = "Ubuntu 22.04 LTS AMI ID for ap-south-1"
  type        = string
  default     = "ami-0f5ee92e2d63afc18"  # Ubuntu 22.04 ap-south-1 (2024)
}

variable "key_pair_name" {
  description = "Name for the EC2 SSH key pair"
  type        = string
}

variable "public_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/flowpath.pub"
}

variable "admin_ip" {
  description = "Admin IP for SSH access (CIDR notation, e.g. 1.2.3.4/32)"
  type        = string
}

variable "db_username" {
  description = "RDS PostgreSQL master username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "RDS PostgreSQL master password (min 16 characters)"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.db_password) >= 16
    error_message = "Database password must be at least 16 characters."
  }
}

variable "github_org" {
  description = "GitHub organisation or username (used in EC2 user_data)"
  type        = string
}
