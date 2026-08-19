# ============================================================
# VPC - APP
# ============================================================

resource "aws_vpc" "app" {
  cidr_block           = var.app_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-app-vpc"
  }
}

# ============================================================
# VPC - DATA
# ============================================================

resource "aws_vpc" "data" {
  cidr_block           = var.data_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-data-vpc"
  }
}

# ============================================================
# SUBNETS
# ============================================================

resource "aws_subnet" "web" {
  vpc_id                  = aws_vpc.app.id
  cidr_block              = var.web_subnet_cidr
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-web-subnet"
  }
}

resource "aws_subnet" "app" {
  vpc_id                  = aws_vpc.app.id
  cidr_block              = var.app_subnet_cidr
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-app-subnet"
  }
}

resource "aws_subnet" "data" {
  vpc_id                  = aws_vpc.data.id
  cidr_block              = var.data_subnet_cidr
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-data-subnet"
  }
}

# ============================================================
# INTERNET GATEWAY - APP VPC ONLY
# ============================================================

resource "aws_internet_gateway" "app" {
  vpc_id = aws_vpc.app.id

  tags = {
    Name = "${var.project_name}-app-igw"
  }
}

# ============================================================
# NAT GATEWAY - APP VPC ONLY
# ============================================================

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "app" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.web.id

  depends_on = [
    aws_internet_gateway.app
  ]

  tags = {
    Name = "${var.project_name}-app-nat-gateway"
  }
}

# ============================================================
# VPC PEERING
# ============================================================

resource "aws_vpc_peering_connection" "app_data" {
  vpc_id      = aws_vpc.app.id
  peer_vpc_id = aws_vpc.data.id
  auto_accept = true

  tags = {
    Name = "${var.project_name}-app-data-peering"
  }
}

# ============================================================
# WEB ROUTE TABLE
# ============================================================

resource "aws_route_table" "web" {
  vpc_id = aws_vpc.app.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app.id
  }

  tags = {
    Name = "${var.project_name}-web-route-table"
  }
}

resource "aws_route_table_association" "web" {
  subnet_id      = aws_subnet.web.id
  route_table_id = aws_route_table.web.id
}

# ============================================================
# APP ROUTE TABLE
# ============================================================

resource "aws_route_table" "app" {
  vpc_id = aws_vpc.app.id

  # App subnet -> Internet through NAT Gateway
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.app.id
  }

  # App subnet -> Data VPC through VPC Peering
  route {
    cidr_block                = var.data_vpc_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.app_data.id
  }

  tags = {
    Name = "${var.project_name}-app-route-table"
  }
}

resource "aws_route_table_association" "app" {
  subnet_id      = aws_subnet.app.id
  route_table_id = aws_route_table.app.id
}

# ============================================================
# DATA ROUTE TABLE
# ============================================================

resource "aws_route_table" "data" {
  vpc_id = aws_vpc.data.id

  # Data subnet -> App VPC through VPC Peering
  route {
    cidr_block                = var.app_vpc_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.app_data.id
  }

  # IMPORTANT:
  # No 0.0.0.0/0 route.
  # No NAT Gateway.
  # No Internet Gateway.
  #
  # The database remains private and can communicate
  # with the App VPC through VPC peering.

  tags = {
    Name = "${var.project_name}-data-route-table"
  }
}

resource "aws_route_table_association" "data" {
  subnet_id      = aws_subnet.data.id
  route_table_id = aws_route_table.data.id
}

# ============================================================
# SECURITY GROUP - WEB
# ============================================================

resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Security group for the web tier"
  vpc_id      = aws_vpc.app.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}

# ============================================================
# SECURITY GROUP - APP
# ============================================================

resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Security group for the application tier"
  vpc_id      = aws_vpc.app.id

  ingress {
    description = "API from Web subnet"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.web_subnet_cidr]
  }

  ingress {
    description = "SSH for administration"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-app-sg"
  }
}

# ============================================================
# SECURITY GROUP - DATA
# ============================================================

resource "aws_security_group" "data" {
  name        = "${var.project_name}-data-sg"
  description = "Security group for the database tier"
  vpc_id      = aws_vpc.data.id

  # Only the App subnet can access MySQL
  ingress {
    description = "MySQL from App subnet"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.app_subnet_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-data-sg"
  }
}

# ============================================================
# SECURITY GROUP - SSM ENDPOINTS
# ============================================================

resource "aws_security_group" "ssm_endpoint" {
  name        = "${var.project_name}-ssm-endpoint-sg"
  description = "Security group for SSM VPC endpoints"
  vpc_id      = aws_vpc.data.id

  ingress {
    description = "HTTPS from Data subnet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.data_subnet_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ssm-endpoint-sg"
  }
}

# ============================================================
# SSM ENDPOINT
# ============================================================

resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = aws_vpc.data.id
  service_name      = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.data.id
  ]

  security_group_ids = [
    aws_security_group.ssm_endpoint.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-ssm-endpoint"
  }
}

# ============================================================
# SSM MESSAGES ENDPOINT
# ============================================================

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id            = aws_vpc.data.id
  service_name      = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.data.id
  ]

  security_group_ids = [
    aws_security_group.ssm_endpoint.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-ssmmessages-endpoint"
  }
}

# ============================================================
# EC2 MESSAGES ENDPOINT
# ============================================================

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id            = aws_vpc.data.id
  service_name      = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.data.id
  ]

  security_group_ids = [
    aws_security_group.ssm_endpoint.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-ec2messages-endpoint"
  }
}

# ============================================================
# UBUNTU AMI
# ============================================================

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name = "name"

    values = [
      "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
    ]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ============================================================
# IAM ROLE - APP EC2
# ============================================================

resource "aws_iam_role" "app_ec2" {
  name = "${var.project_name}-app-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-app-ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "app_ecr" {
  role       = aws_iam_role.app_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "app_ssm" {
  role       = aws_iam_role.app_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app_ec2" {
  name = "${var.project_name}-app-ec2-profile"
  role = aws_iam_role.app_ec2.name
}

# ============================================================
# IAM ROLE - DATA EC2
# ============================================================

resource "aws_iam_role" "data_ec2" {
  name = "${var.project_name}-data-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-data-ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "data_ssm" {
  role       = aws_iam_role.data_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "data_ec2" {
  name = "${var.project_name}-data-ec2-profile"
  role = aws_iam_role.data_ec2.name
}

# ============================================================
# WEB EC2
# ============================================================

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.web.id

  key_name = var.key_name

  vpc_security_group_ids = [
    aws_security_group.web.id
  ]

  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash

    apt-get update -y
    apt-get install -y nginx

    systemctl enable nginx
    systemctl start nginx
  EOF

  tags = {
    Name = "${var.project_name}-web-server"
  }
}

# ============================================================
# APP EC2
# ============================================================

resource "aws_instance" "app" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.app.id

  key_name = var.key_name

  vpc_security_group_ids = [
    aws_security_group.app.id
  ]

  associate_public_ip_address = false

  iam_instance_profile = aws_iam_instance_profile.app_ec2.name

  user_data = <<-EOF
    #!/bin/bash

    apt-get update -y

    apt-get install -y \
      ca-certificates \
      curl \
      gnupg

    install -m 0755 -d /etc/apt/keyrings

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      -o /etc/apt/keyrings/docker.asc

    chmod a+r /etc/apt/keyrings/docker.asc

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list

    apt-get update -y

    apt-get install -y \
      docker-ce \
      docker-ce-cli \
      containerd.io \
      docker-buildx-plugin \
      docker-compose-plugin

    systemctl enable docker
    systemctl start docker

    usermod -aG docker ubuntu
  EOF

  tags = {
    Name = "${var.project_name}-app-server"
  }
}

# ============================================================
# DATA EC2
# ============================================================

resource "aws_instance" "data" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.data.id

  key_name = var.key_name

  vpc_security_group_ids = [
    aws_security_group.data.id
  ]

  associate_public_ip_address = false

  iam_instance_profile = aws_iam_instance_profile.data_ec2.name

  # Do not install MySQL here using apt.
  #
  # The Data subnet intentionally has no internet/NAT.
  # MySQL installation will be handled separately.

  tags = {
    Name = "${var.project_name}-data-server"
  }
}
