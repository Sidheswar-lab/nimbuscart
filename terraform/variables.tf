variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "nimbuscart"
}

variable "app_vpc_cidr" {
  description = "CIDR for the application VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "data_vpc_cidr" {
  description = "CIDR for the data VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "web_subnet_cidr" {
  description = "Public web subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "app_subnet_cidr" {
  description = "Private application subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "data_subnet_cidr" {
  description = "Private database subnet"
  type        = string
  default     = "10.1.1.0/24"
}
variable "key_name" {
  description = "Existing EC2 key pair name"
  type        = string
  default     = "MyKey2"
}
