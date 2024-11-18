#Create VPC 
resource "aws_vpc" "wl6vpc" {
  cidr_block = "10.0.0.0/16"
}

# Reference the default vpc
data "aws_vpc" "default_vpc" {
  id = var.default_vpc_id
}

# Create an Internet Gateway for the VPC
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.wl6vpc.id

  tags = {
    Name = "my-igw"
  }
}

# Create public subnet 
resource "aws_subnet" "public_subnet_1" {
  vpc_id     = aws_vpc.wl6vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public_subnet_1"
  }
}

# Create public subnet two 
resource "aws_subnet" "public_subnet_2" {
  vpc_id     = aws_vpc.wl6vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public_subnet_2"
  }
}

# Create two private subnets
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.wl6vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private_subnet_1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.wl6vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private_subnet_2"
  }
}

# Create a route table for the public subnets
resource "aws_route_table" "my_public_route_table" {
  vpc_id = aws_vpc.wl6vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "my-public-route-table"
  }
}

# Associate the route table with the public subnets
resource "aws_route_table_association" "public_route_table_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.my_public_route_table.id
}

resource "aws_route_table_association" "public_route_table_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.my_public_route_table.id
}

# Create Elastic IPs for NAT Gateway
resource "aws_eip" "nat_eip_1" {
  domain = "vpc"
}

# Create NAT Gateway
resource "aws_nat_gateway" "nat_gateway_1" {
  allocation_id = aws_eip.nat_eip_1.id
  subnet_id     = aws_subnet.public_subnet_1.id
  
  tags = {
    Name = "nat-gateway_1"
  }

  depends_on = [aws_internet_gateway.my_igw]
}

# Create a route table for the private subnets
resource "aws_route_table" "private_route_table_1" {
  vpc_id = aws_vpc.wl6vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    gateway_id     = aws_nat_gateway.nat_gateway_1.id
  }

  tags = {
    Name = "private-route-table_1"
  }
}

resource "aws_route_table_association" "private_rt_assoc_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table_1.id
}

resource "aws_route_table_association" "private_rt_assoc_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table_1.id
}

# Create a VPC Peering Connection between the default VPC and the Terraform-created VPC
resource "aws_vpc_peering_connection" "vpc_peering" {
  vpc_id        = data.aws_vpc.default_vpc.id  # default VPC ID
  peer_vpc_id   = aws_vpc.wl6vpc.id             # Accepter VPC ID
  auto_accept   = true  # Automatically accept the peering connection
}

# Add a route to the default VPC's route table 
resource "aws_route" "default_vpc_to_vpc" {
  route_table_id         = var.default_route_table_id  # Route Table ID of the manual VPC
  destination_cidr_block = aws_vpc.wl6vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}

# Define the routes for the public route table
resource "aws_route" "public_to_default" {
  route_table_id         = aws_route_table.my_public_route_table.id  
  destination_cidr_block = data.aws_vpc.default_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}

# Define the routes for the first private route table
resource "aws_route" "private_1_to_default" {
  route_table_id         = aws_route_table.private_route_table_1.id 
  destination_cidr_block = data.aws_vpc.default_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}

#Creating this here so that its available for the RDS
resource "aws_security_group" "app_security_group" {
  name        = "app_sg"
  description = "Security group for our app"
  vpc_id = aws_vpc.wl6vpc.id

  # Ingress (inbound) rules
  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH from any IP
  }

  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP from any IP
  }

  ingress {
    description = "Node runs on port 3000"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  ingress {
    description = "Allow inbound traffic on Node Exporters default port 9100"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  # Egress (outbound) rule to allow all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }

  tags = {
    Name : "app_sg"
    Terraform : "true"
  }
}