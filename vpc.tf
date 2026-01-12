# ============================================================
# VPC-A: On-Premise 환경 시뮬레이션
# ============================================================

# Availability Zones 데이터 소스
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC 생성 (On-Premise 시뮬레이션)
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-onpremise-vpc"
      Type = var.enable_tgw_architecture ? "OnPremiseSimulation-TGW" : "OnPremiseSimulation-IGW"
    }
  )
}

# ============================================================
# Internet Gateway (TGW 아키텍처 미사용 시에만 생성)
# ============================================================

resource "aws_internet_gateway" "main" {
  count = var.enable_tgw_architecture ? 0 : 1

  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-igw"
    }
  )
}

# ============================================================
# Public Subnet (TGW 아키텍처 미사용 시에만 생성)
# ============================================================

resource "aws_subnet" "public" {
  count = var.enable_tgw_architecture ? 0 : 1

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-public-subnet"
      Type = "Public"
    }
  )
}

# Route Table for Public Subnet
resource "aws_route_table" "public" {
  count = var.enable_tgw_architecture ? 0 : 1

  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-public-rt"
    }
  )
}

# Route Table Association for Public Subnet
resource "aws_route_table_association" "public" {
  count = var.enable_tgw_architecture ? 0 : 1

  subnet_id      = aws_subnet.public[0].id
  route_table_id = aws_route_table.public[0].id
}

# ============================================================
# Private Subnet (TGW 아키텍처 사용 시에만 생성)
# ============================================================

resource "aws_subnet" "private" {
  count = var.enable_tgw_architecture ? 1 : 0

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-private-subnet"
      Type = "Private"
    }
  )
}

