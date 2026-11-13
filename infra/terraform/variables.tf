# Input variables. Override them in terraform.tfvars
# (copy terraform.tfvars.example -> terraform.tfvars).

variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Project name, used as a prefix for Name tags"
  type        = string
  default     = "lms"
}

variable "instance_type" {
  description = "EC2 instance type for app and DB servers"
  type        = string
  default     = "t2.micro"
}

variable "mgmt_cidr" {
  description = "CIDR allowed to SSH (port 22) into the servers. Use the Management Server's public IP, e.g. 13.201.69.23/32"
  type        = string
  # No default on purpose: you must set it, so SSH is never left open to the world by accident.
}

variable "public_key_path" {
  description = "Path to the SSH public key uploaded as the EC2 key pair (Ansible uses the matching private key)"
  type        = string
  default     = "~/.ssh/lms_key.pub"
}

# Network ranges (defaults match the assessment spec).
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the two public (app) subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "db_subnet_cidr" {
  description = "CIDR block for the DB subnet"
  type        = string
  default     = "10.0.3.0/24"
}
