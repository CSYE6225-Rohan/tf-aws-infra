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

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
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

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs"
  type        = list(string)
}

variable "custom_ami" {
  description = "Custom AMI ID"
  type        = string
}

variable "app_port" {
  description = "Port on which the application runs"
  type        = number
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}