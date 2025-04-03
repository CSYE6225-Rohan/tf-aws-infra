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
    # security_groups = [ aws_security_group.load_balancer_sg.id ]
  }

  # ingress {
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  # ingress {
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    # cidr_blocks = ["0.0.0.0/0"]
    security_groups = [ aws_security_group.load_balancer_sg.id ]
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


# output "public_ip" {
#   value = aws_instance.webapp_instance.public_ip
# }

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
    security_groups = [aws_security_group.app_sg.id]  
  }

  # No outbound restrictions (RDS needs to communicate with AWS services)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    security_groups = [aws_security_group.app_sg.id]  
  }

  tags = {
    Name = "Database SG"
  }
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
# output "rds_endpoint" {
#   value = aws_db_instance.csye6225_rds.endpoint
# }

# Combined IAM Role
resource "aws_iam_role" "ec2_combined_role" {
  name = "EC2-Combined-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "EC2-Combined-Role"
  }
}

# CloudWatch Agent and S3 Full Access Policies
resource "aws_iam_policy" "combined_policy" {
  name        = "EC2-Combined-Policy"
  description = "Policy for CloudWatch Agent and S3 Full Access"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "logs:DescribeLogStreams"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = "s3:*",
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Attach Policy to IAM Role
resource "aws_iam_role_policy_attachment" "attach_combined_policy" {
  role       = aws_iam_role.ec2_combined_role.name
  policy_arn = aws_iam_policy.combined_policy.arn
}

# Instance Profile
resource "aws_iam_instance_profile" "ec2_combined_profile" {
  name = "EC2-Combined-Profile"
  role = aws_iam_role.ec2_combined_role.name
}

# Update EC2 instance to use the combined IAM role
# resource "aws_instance" "webapp_instance" {
#   ami                         = data.aws_ami.latest_ubuntu_ami.id
#   instance_type               = var.instance_type
#   vpc_security_group_ids      = [aws_security_group.app_sg.id]
#   subnet_id                   = aws_subnet.public[0].id
#   associate_public_ip_address = var.associate_public_ip_address
#   key_name                    = aws_key_pair.my_key_pair.key_name
#   iam_instance_profile        = aws_iam_instance_profile.ec2_combined_profile.name
#   root_block_device {
#     volume_size           = var.volume_size
#     volume_type           = var.volume_type
#     delete_on_termination = var.delete_on_termination
#   }


  # user_data = <<-EOF
  #             #!/bin/bash
  #             cd /opt/csye6225/webapp
  #             # Database credentials and endpoint passed to the web app
  #             sed -i "s/^username=.*/username=${aws_db_instance.csye6225_rds.username}/" .env
  #             sed -i "s/^password=.*/password=${aws_db_instance.csye6225_rds.password}/" .env
  #             sed -i "s/^hostname=.*/hostname=$(echo ${aws_db_instance.csye6225_rds.endpoint} | cut -d ':' -f 1)/" .env
  #             sed -i "s/^database=.*/database=${aws_db_instance.csye6225_rds.db_name}/" .env
  #             echo "AWS_REGION=${var.aws_region}" >> .env
              
  #             # Install CloudWatch Agent
  #             curl -O https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
  #             sudo dpkg -i -E ./amazon-cloudwatch-agent.deb

  #             # Create CloudWatch Agent config
  #             cat <<CONFIG > /opt/aws/amazon-cloudwatch-agent/bin/config.json
  #             {
  #               "agent": {
  #                 "metrics_collection_interval": 60,
  #                 "logfile": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
  #               },
  #               "metrics": {
  #                 "metrics_collected": {
  #                   "cpu": {
  #                     "measurement": ["usage_idle", "usage_user", "usage_system"],
  #                     "metrics_collection_interval": 60
  #                   },
  #                   "disk": {
  #                     "measurement": ["used_percent"],
  #                     "metrics_collection_interval": 60,
  #                     "resources": ["*"]
  #                   },
  #                   "mem": {
  #                     "measurement": ["used_percent"],
  #                     "metrics_collection_interval": 60
  #                   }
  #                 }
  #               },
  #               "logs": {
  #                 "logs_collected": {
  #                   "files": {
  #                     "collect_list": [
  #                       {
  #                         "file_path": "/var/log/syslog",
  #                         "log_group_name": "syslog-group",
  #                         "log_stream_name": "{instance_id}-syslog"
  #                       },
  #                       {
  #                         "file_path": "/var/log/app.log",
  #                         "log_group_name": "applog-group",
  #                         "log_stream_name": "{instance_id}-applog"
  #                       }
  #                     ]
  #                   }
  #                 }
  #               }
  #             }
  #             CONFIG

  #             # Start CloudWatch Agent on boot
  #             sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s
  #             sudo systemctl enable amazon-cloudwatch-agent

  #             # Install and configure StatsD
  #             sudo apt-get install -y statsd
  #             sudo tee /etc/statsd/config.js > /dev/null <<EOL
  #             {
  #               port: 8125,
  #               backends: ["./backends/console", "./backends/cloudwatch"],
  #               cloudwatch: {
  #                 region: "${var.aws_region}",
  #                 namespace: "WebAppMetrics",
  #                 dimensions: {
  #                   "Environment": "production"
  #                 }
  #               }
  #             }
  #             EOL

  #             # Start StatsD service
  #             sudo service statsd restart
              
  #             # Restart CloudWatch Agent to ensure new configuration is applied
  #             sudo systemctl restart amazon-cloudwatch-agent

  #             # Enable CloudWatch Agent on startup
  #             sudo systemctl enable amazon-cloudwatch-agent

  #             EOF

#   tags = {
#     Name = "WebApp-Instance"
#   }
# }

resource "aws_security_group" "load_balancer_sg" {
  name        = "load-balancer-sg"
  description = "Security group for Load Balancer"
  vpc_id      = aws_vpc.main.id

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch Template for EC2 Instances
resource "aws_launch_template" "webapp_template" {
  name_prefix   = "csye6225-asg"
  image_id      = data.aws_ami.latest_ubuntu_ami.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.my_key_pair.key_name
    iam_instance_profile {
    name = aws_iam_instance_profile.ec2_combined_profile.name
  }

  # security_group_names = [aws_security_group.app_sg.name]

  # Associate public IP address in the launch template
  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.app_sg.id]
  }
  user_data = base64encode(<<-EOF
              #!/bin/bash
              cd /opt/csye6225/webapp
              # Database credentials and endpoint passed to the web app
              sed -i "s/^username=.*/username=${aws_db_instance.csye6225_rds.username}/" .env
              sed -i "s/^password=.*/password=${aws_db_instance.csye6225_rds.password}/" .env
              sed -i "s/^hostname=.*/hostname=$(echo ${aws_db_instance.csye6225_rds.endpoint} | cut -d ':' -f 1)/" .env
              sed -i "s/^database=.*/database=${aws_db_instance.csye6225_rds.db_name}/" .env
              echo "AWS_REGION=${var.aws_region}" >> .env
              
              # Install CloudWatch Agent
              curl -O https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
              sudo dpkg -i -E ./amazon-cloudwatch-agent.deb

              # Create CloudWatch Agent config
              cat <<CONFIG > /opt/aws/amazon-cloudwatch-agent/bin/config.json
              {
                "agent": {
                  "metrics_collection_interval": 60,
                  "logfile": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
                },
                "metrics": {
                  "metrics_collected": {
                    "cpu": {
                      "measurement": ["usage_idle", "usage_user", "usage_system"],
                      "metrics_collection_interval": 60
                    },
                    "disk": {
                      "measurement": ["used_percent"],
                      "metrics_collection_interval": 60,
                      "resources": ["*"]
                    },
                    "mem": {
                      "measurement": ["used_percent"],
                      "metrics_collection_interval": 60
                    }
                  }
                },
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [
                        {
                          "file_path": "/var/log/syslog",
                          "log_group_name": "syslog-group",
                          "log_stream_name": "{instance_id}-syslog"
                        },
                        {
                          "file_path": "/var/log/app.log",
                          "log_group_name": "applog-group",
                          "log_stream_name": "{instance_id}-applog"
                        }
                      ]
                    }
                  }
                }
              }
              CONFIG

              # Start CloudWatch Agent on boot
              sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s
              sudo systemctl enable amazon-cloudwatch-agent

              # Install and configure StatsD
              sudo apt-get install -y statsd
              sudo tee /etc/statsd/config.js > /dev/null <<EOL
              {
                port: 8125,
                backends: ["./backends/console", "./backends/cloudwatch"],
                cloudwatch: {
                  region: "${var.aws_region}",
                  namespace: "WebAppMetrics",
                  dimensions: {
                    "Environment": "production"
                  }
                }
              }
              EOL

              # Start StatsD service
              sudo service statsd restart
              
              # Restart CloudWatch Agent to ensure new configuration is applied
              sudo systemctl restart amazon-cloudwatch-agent

              # Enable CloudWatch Agent on startup
              sudo systemctl enable amazon-cloudwatch-agent
 
              EOF
              )

  tags = {
    Name = "WebApp Launch Template"
  }
}
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up"
  autoscaling_group_name = aws_autoscaling_group.example.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = var.scale_up_adjustment
  cooldown               = var.cooldown
  policy_type            = "SimpleScaling"
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down"
  autoscaling_group_name = aws_autoscaling_group.example.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = var.scale_down_adjustment
  cooldown               = var.cooldown
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "scale_up_alarm" {
  alarm_name                = "scale-up-cpu-utilization-alarm"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = var.scale_up_period
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = var.scale_up_period  
  statistic                 = "Average"
  threshold                 = var.scale_up_threshold  
  alarm_description         = "Triggers scale-up policy when CPU utilization exceeds threshold"
  insufficient_data_actions = []
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.example.name
  }

  actions_enabled = true

  alarm_actions = [
    aws_autoscaling_policy.scale_up.arn
  ]
}

resource "aws_cloudwatch_metric_alarm" "scale_down_step_alarm" {
  alarm_name                = "scale-down-step-cpu-utilization-alarm"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = var.scale_down_evaluation_periods
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = var.scale_down_period  
  statistic                 = "Average"
  threshold                 = var.scale_down_threshold
  alarm_description         = "Triggers step scaling to decrease instances when CPU < threshold"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.example.name
  }

  actions_enabled = true

  alarm_actions = [
    aws_autoscaling_policy.scale_down.arn
  ]
}

# Application Load Balancer
resource "aws_lb" "example" {
  name               = "example-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.load_balancer_sg.id]
  subnets            = flatten([for subnet in aws_subnet.public : subnet.id])
  enable_deletion_protection = false

  enable_cross_zone_load_balancing = true
}

# ALB Listener (Port 80)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.example.arn
  }
}

# Target Group for EC2 instances (Port your app listens on, e.g., 8080)
resource "aws_lb_target_group" "example" {
  name     = "example-target-group"
  port     = var.app_port  
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    protocol = "HTTP"
    path     = "/healthz"
    matcher = "200"  
    interval = var.health_check_interval
    timeout  = var.health_check_timeout
    healthy_threshold   = var.healthy_threashold
    unhealthy_threshold = var.unhealthy_threshold
  }
} 

# Attach the target group to the Auto Scaling Group
resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.example.name
  lb_target_group_arn  = aws_lb_target_group.example.arn
}

# Auto Scaling Group (with ALB integration)
resource "aws_autoscaling_group" "example" {
  desired_capacity     = var.desired_capacity 
  min_size             = var.min_size 
  max_size             = var.max_size 
  launch_template {
    id      = aws_launch_template.webapp_template.id
    version = "$Latest"
  }
  vpc_zone_identifier  = flatten([for subnet in aws_subnet.public : subnet.id])
  health_check_type     = "ELB"
  health_check_grace_period = var.health_check_grace_period

  # Attach the ALB Target Group
  target_group_arns = [aws_lb_target_group.example.arn]

  tag {
      key                 = "Name"
      value               = "AutoScalingInstance"
      propagate_at_launch = true
    }
}

# Route 53 Hosted Zone
resource "aws_route53_record" "dev_record" {
  zone_id = var.zone_id
  name    = "${var.environment}.rohanjauhari.me"
  type    = "A"

  alias {
    name                   = aws_lb.example.dns_name
    zone_id                = aws_lb.example.zone_id
    evaluate_target_health = true
  }
}
