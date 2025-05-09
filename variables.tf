variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
}
variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "aws_profile" {
  description = "AWS profile"
  type        = string
}

variable "db_password" {
  description = "MYSQL password"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs"
  type        = list(string)
}

variable "associate_public_ip_address" {
  description = "associate_public_ip_address"
  type        = bool
}



variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs"
  type        = list(string)
}

variable "app_port" {
  description = "Port on which the application runs"
  type        = number
}

variable "volume_size" {
  type    = number
  default = 25
}

variable "volume_type" {
  type    = string
  default = "gp2"
}

variable "delete_on_termination" {
  type    = bool
  default = true
}
variable "db_instance_identifier" {
  type    = string
  default = "csye6225"
}

variable "db_engine" {
  type    = string
  default = "mysql"
}

variable "db_engine_version" {
  type    = string
  default = "8.0.35"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_username" {
  type    = string
  default = "csye6225"
}

variable "db_name" {
  type    = string
  default = "csye6225"
}


variable "db_publicly_accessible" {
  type    = bool
  default = false
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "db_skip_final_snapshot" {
  type    = bool
  default = true
}

variable "db_instance_tag" {
  type    = string
  default = "CSYE6225 RDS Instance"
}

variable "public_key" {
  type    = string
  default = "public key"
}

variable "ami_owners" {
  type    = list(string)
  default = ["266735815279"]
}

variable "zone_id" {
  type    = string
  default = "Z0895763G312FT8J372X"
}

variable "desired_capacity" {
  description = "Desired number of EC2 instances"
  type        = number
}

variable "min_size" {
  description = "minimum number of EC2 instances"
  type        = number
}

variable "max_size" {
  description = "Maximum number of EC2 instances"
  type        = number
}

variable "scale_down_evaluation_periods" {
  description = "Times"
  type        = number
}

variable "scale_down_period" {
  type    = number
}

variable "scale_down_threshold" {
  type    = number
}

variable "scale_up_evaluation_periods" {
  description = "Times"
  type        = number
}

variable "scale_up_period" {
  type    = number
}

variable "scale_up_threshold" {
  type    = number
}

variable "cooldown" {
  type    = number
}
variable "scale_down_adjustment" {
  type    = number
}
variable "scale_up_adjustment" {
  type    = number
}
variable "health_check_grace_period" {
  type    = number
}
variable "health_check_interval" {
  type    = number
}
variable "health_check_timeout" {
  type    = number
}
variable "healthy_threashold" {
  type    = number
}
variable "unhealthy_threshold" {
  type    = number
}