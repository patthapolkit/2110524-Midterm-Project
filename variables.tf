variable "region" {
  description = "AWS region"
  type        = string
}

variable "availability_zone" {
  description = "AWS availability zone"
  type        = string
}

variable "ami" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket name for media storage"
  type        = string
}

variable "database_name" {
  description = "WordPress database name"
  type        = string
}

variable "database_user" {
  description = "WordPress database user"
  type        = string
}

variable "database_pass" {
  description = "WordPress database password"
  type        = string
}

variable "admin_user" {
  description = "WordPress admin username"
  type        = string
}

variable "admin_pass" {
  description = "WordPress admin password"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}
