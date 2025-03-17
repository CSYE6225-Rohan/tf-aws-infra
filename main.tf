provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${var.vpc_name}"
  }
}

resource "aws_subnet" "public" {
  count = length(var.azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.vpc_name}-public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count = length(var.azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.vpc_name}-private-subnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vpc_name}-public-rt"
  }
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "public" {
  count = length(var.azs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vpc_name}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count = length(var.azs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "app_sg" {
  name        = "application-security-group"
  description = "Security group for EC2 hosting web applications"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "latest_ubuntu_ami" {
  most_recent = true
  owners      = var.ami_owners

  filter {
    name   = "name"
    values = ["custom-ubuntu-24.04-ami*"]

  }
}

resource "random_id" "key_id" {
  byte_length = 4
}

resource "aws_key_pair" "my_key_pair" {
  key_name   = "ec2_key-${random_id.key_id.hex}" # Unique key name with random suffix
  public_key = var.public_key
}


output "public_ip" {
  value = aws_instance.webapp_instance.public_ip
}

resource "random_uuid" "bucket_uuid" {}

resource "aws_s3_bucket" "private_bucket" {
  bucket = random_uuid.bucket_uuid.result

  force_destroy = true 

  tags = {
    Name = "Private S3 Bucket"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.private_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.private_bucket.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

output "bucket_name" {
  value = aws_s3_bucket.private_bucket.id
}

# Create the database security group (for RDS)
resource "aws_security_group" "db_sg" {
  name        = "database-sg"
  description = "Security group for RDS instances"
  vpc_id      = aws_vpc.main.id

  # Allow inbound MySQL traffic from the application security group
  ingress {
    from_port       = 3306  
    to_port         = 3306  
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]  # Only allow traffic from app_sg
  }

  # No outbound restrictions (RDS needs to communicate with AWS services)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Database SG"
  }
}

# Output Security Group IDs
output "app_sg_id" {
  value = aws_security_group.app_sg.id
}

output "db_sg_id" {
  value = aws_security_group.db_sg.id
}

# Create a DB Parameter Group for MySQL 8.0
resource "aws_db_parameter_group" "custom_pg" {
  name        = "custom-mysql-parameter-group"
  family      = "mysql8.0"
  description = "Custom parameter group for MySQL 8.0"

  parameter {
    name  = "max_connections"
    value = "200"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  tags = {
    Name = "Custom MySQL Parameter Group"
  }
}

resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.private[0].id, aws_subnet.private[1].id, aws_subnet.private[2].id]  

  tags = {
    Name = "RDS Subnet Group"
  }
}

# Create an RDS Instance
resource "aws_db_instance" "csye6225_rds" {
  identifier             = var.db_instance_identifier
  engine                 = var.db_engine
  engine_version         = var.db_engine_version  
  instance_class         = var.db_instance_class  
  allocated_storage      = var.db_allocated_storage
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.my_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]  
  publicly_accessible    = var.db_publicly_accessible  
  multi_az               = var.db_multi_az  
  parameter_group_name   = aws_db_parameter_group.custom_pg.name  
  skip_final_snapshot    = var.db_skip_final_snapshot
  db_name                = var.db_name

  tags = {
    Name = var.db_publicly_accessible
  }
}

# Output the RDS Endpoint and Parameter Group Name
output "rds_endpoint" {
  value = aws_db_instance.csye6225_rds.endpoint
}

output "db_parameter_group_name" {
  value = aws_db_parameter_group.custom_pg.name
}

resource "aws_instance" "webapp_instance" {
  ami                         = data.aws_ami.latest_ubuntu_ami.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  subnet_id                   = aws_subnet.public[0].id
  associate_public_ip_address = var.associate_public_ip_address
  key_name                    = aws_key_pair.my_key_pair.key_name
  root_block_device {
    volume_size           = var.volume_size
    volume_type           = var.volume_type
    delete_on_termination = var.delete_on_termination
  }

  disable_api_termination = false


  user_data = <<-EOF
              #!/bin/bash
              cd /opt/csye6225/webapp
              # Database credentials and endpoint passed to the web app
              sed -i "s/^username=.*/username=${aws_db_instance.csye6225_rds.username}/" .env
              sed -i "s/^password=.*/password=${aws_db_instance.csye6225_rds.password}/" .env
              sed -i "s/^hostname=.*/hostname=$(echo ${aws_db_instance.csye6225_rds.endpoint} | cut -d ':' -f 1)/" .env
              sed -i "s/^database=.*/database=${aws_db_instance.csye6225_rds.db_name}/" .env
              echo "AWS_ACCESS_KEY_ID=${var.aws_access}" >> .env
              echo "AWS_SECRET_ACCESS_KEY=${var.aws_secret_access}" >> .env
              echo "AWS_REGION=${var.aws_region}" >> .env
              EOF
  tags = {
    Name = "WebApp-Instance"
  }

}