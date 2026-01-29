# -----------------------------------------------------------------------------
# VPC Module
# Creates a standard VPC with public, private, and database subnets
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.number_of_azs)

  # Calculate subnet CIDRs
  # VPC CIDR: 10.X.0.0/16
  # Each AZ gets a /20 block (4096 IPs per AZ)
  # Within each AZ: public /24, private /22, database /24, reserved /24
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-vpc"
    Environment = var.environment
  })
}

# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "main" {
  count = var.create_igw ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-igw"
    Environment = var.environment
  })
}

# -----------------------------------------------------------------------------
# Subnets
# -----------------------------------------------------------------------------

# Public Subnets
resource "aws_subnet" "public" {
  count = var.create_public_subnets ? var.number_of_azs : 0

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index * 10)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-public-${local.azs[count.index]}"
    Environment = var.environment
    Tier        = "public"
    "kubernetes.io/role/elb" = var.enable_eks_tags ? "1" : null
  })
}

# Private Subnets (for applications, EKS nodes)
resource "aws_subnet" "private" {
  count = var.number_of_azs

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 6, count.index * 4 + 1)
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-private-${local.azs[count.index]}"
    Environment = var.environment
    Tier        = "private"
    "kubernetes.io/role/internal-elb" = var.enable_eks_tags ? "1" : null
  })
}

# Database Subnets
resource "aws_subnet" "database" {
  count = var.create_database_subnets ? var.number_of_azs : 0

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index * 10 + 2)
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-database-${local.azs[count.index]}"
    Environment = var.environment
    Tier        = "database"
  })
}

# Database Subnet Group
resource "aws_db_subnet_group" "database" {
  count = var.create_database_subnets ? 1 : 0

  name        = "${var.name_prefix}-db-subnet-group"
  description = "Database subnet group for ${var.name_prefix}"
  subnet_ids  = aws_subnet.database[*].id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-db-subnet-group"
    Environment = var.environment
  })
}

# -----------------------------------------------------------------------------
# NAT Gateway (Optional - costs money!)
# -----------------------------------------------------------------------------

resource "aws_eip" "nat" {
  count = var.create_nat_gateway ? var.single_nat_gateway ? 1 : var.number_of_azs : 0

  domain = "vpc"

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-nat-eip-${count.index + 1}"
    Environment = var.environment
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count = var.create_nat_gateway ? var.single_nat_gateway ? 1 : var.number_of_azs : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-nat-${count.index + 1}"
    Environment = var.environment
  })

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# Route Tables
# -----------------------------------------------------------------------------

# Public Route Table
resource "aws_route_table" "public" {
  count = var.create_public_subnets ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-public-rt"
    Environment = var.environment
  })
}

resource "aws_route" "public_internet" {
  count = var.create_public_subnets && var.create_igw ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main[0].id
}

resource "aws_route_table_association" "public" {
  count = var.create_public_subnets ? var.number_of_azs : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# Private Route Tables
resource "aws_route_table" "private" {
  count = var.number_of_azs

  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-private-rt-${local.azs[count.index]}"
    Environment = var.environment
  })
}

resource "aws_route" "private_nat" {
  count = var.create_nat_gateway ? var.number_of_azs : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
}

resource "aws_route_table_association" "private" {
  count = var.number_of_azs

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Database Route Table (uses private route table associations)
resource "aws_route_table_association" "database" {
  count = var.create_database_subnets ? var.number_of_azs : 0

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# -----------------------------------------------------------------------------
# VPC Flow Logs
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/${var.name_prefix}/flow-logs"
  retention_in_days = var.flow_logs_retention_days

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-flow-logs"
    Environment = var.environment
  })
}

resource "aws_iam_role" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name_prefix}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-vpc-flow-logs-role"
    Environment = var.environment
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name_prefix}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_flow_log" "main" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id                   = aws_vpc.main.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  iam_role_arn             = aws_iam_role.vpc_flow_logs[0].arn
  max_aggregation_interval = 60

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-flow-log"
    Environment = var.environment
  })
}

# -----------------------------------------------------------------------------
# Default Security Group (locked down)
# -----------------------------------------------------------------------------

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # No inbound or outbound rules - effectively denies all traffic
  # This ensures resources must explicitly define their security groups

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-default-sg-restricted"
    Environment = var.environment
    Purpose     = "Default SG - No traffic allowed"
  })
}
