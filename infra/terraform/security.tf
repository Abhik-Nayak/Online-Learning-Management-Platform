# Key pair and security groups.

# ---------------------------------------------------------------- Key pair
# Uploads the Management Server's public key (~/.ssh/lms_key.pub) to AWS.
# Every instance gets it, so Ansible can SSH in with ~/.ssh/lms_key (no password).
resource "aws_key_pair" "lms" {
  key_name   = "${var.project}-key"
  public_key = file(pathexpand(var.public_key_path))

  tags = {
    Name = "${var.project}-key"
  }
}

# ---------------------------------------------------------------- app-sg
# App servers: SSH from the Management Server, HTTP from anywhere.
resource "aws_security_group" "app" {
  name        = "${var.project}-app-sg"
  description = "LMS app servers: SSH from mgmt, HTTP from anywhere"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from Management Server"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.mgmt_cidr]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-app-sg"
  }
}

# ---------------------------------------------------------------- db-sg
# DB server: PostgreSQL ONLY from app servers, SSH from the Management Server.
resource "aws_security_group" "db" {
  name        = "${var.project}-db-sg"
  description = "LMS DB: 5432 from app-sg only, SSH from mgmt"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from app servers only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id] # source = app-sg, not an IP range
  }

  ingress {
    description = "SSH from Management Server"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.mgmt_cidr]
  }

  egress {
    description = "All outbound traffic (needed for apt install)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-db-sg"
  }
}
