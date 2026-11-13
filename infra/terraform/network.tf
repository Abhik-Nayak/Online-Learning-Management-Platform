# Network: VPC, 2 public subnets, 1 DB subnet, Internet Gateway, route tables.

# Pick the first two Availability Zones in the region (e.g. ap-south-1a and 1b).
data "aws_availability_zones" "available" {
  state = "available"
}

# ---------------------------------------------------------------- VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project}-vpc"
  }
}

# ---------------------------------------------------------------- Subnets
# Public subnets for the two app servers, one per AZ.
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-public-${count.index + 1}"
  }
}

# DB subnet.
# map_public_ip_on_launch = true: see the "DB internet access" note below for why.
resource "aws_subnet" "db" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.db_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-db-subnet"
  }
}

# ---------------------------------------------------------------- Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-igw"
  }
}

# ---------------------------------------------------------------- Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------- DB route table
# DB internet access: we chose the cheapest simple option.
#
# The DB needs the internet (once) to `apt install postgresql`. Two choices:
#
#   1. NAT Gateway in a public subnet, DB route 0.0.0.0/0 -> NAT.
#      + DB has no public IP at all (truly private).
#      - About $0.056/hour + data charges in ap-south-1 (~$40/month),
#        even when idle, and an Elastic IP. Not free-tier.
#      - The Management Server lives in a DIFFERENT VPC (the default VPC),
#        so it could not SSH to a private-only DB without a bastion or
#        VPC peering, which makes Ansible harder.
#
#   2. (CHOSEN) Route 0.0.0.0/0 -> Internet Gateway and give the DB a public IP,
#      but lock it down with db-sg:
#        - 5432 ONLY from app-sg (the app servers)
#        - 22 ONLY from mgmt_cidr (the Management Server)
#        - nothing else can reach it.
#      + Free, simple, and Ansible can SSH to it directly from the Management Server.
#      - The DB has a public IP, so security relies on the security group.
#
# The DB still gets its OWN route table, so switching to option 1 later is
# a one-line change: replace gateway_id below with nat_gateway_id = aws_nat_gateway.<name>.id
# (and set map_public_ip_on_launch = false on the DB subnet).
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project}-db-rt"
  }
}

resource "aws_route_table_association" "db" {
  subnet_id      = aws_subnet.db.id
  route_table_id = aws_route_table.db.id
}
