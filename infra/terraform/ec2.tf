# EC2 instances: 2 app servers + 1 DB server, all Ubuntu 22.04.

# Latest official Ubuntu 22.04 (Jammy) AMI, published by Canonical.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS account

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------- App server 1 (AZ 1)
resource "aws_instance" "app_1" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.lms.key_name

  tags = {
    Name = "${var.project}-app-1"
    Role = "app"
  }
}

# ---------------------------------------------------------------- App server 2 (AZ 2)
resource "aws_instance" "app_2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[1].id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.lms.key_name

  tags = {
    Name = "${var.project}-app-2"
    Role = "app"
  }
}

# ---------------------------------------------------------------- DB server
resource "aws_instance" "db" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.db.id
  vpc_security_group_ids = [aws_security_group.db.id]
  key_name               = aws_key_pair.lms.key_name

  tags = {
    Name = "${var.project}-db"
    Role = "db"
  }
}
