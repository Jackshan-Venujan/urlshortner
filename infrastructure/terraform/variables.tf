variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"  # Changed to ap-southeast-1 (Singapore)
}

variable "ami_id" {
  description = "Amazon Machine Image ID"
  type        = string
  default     = "ami-078c1149d8ad719a7"  # Ubuntu 22.04 LTS AMI for ap-southeast-1 (Singapore)
}

variable "instance_type" {
  description = "Instance type for EC2"
  default     = "t2.micro"
}

variable "key_name" {
  description = "SSH key name"
  default     = ""  # Set to empty so we can provide it during terraform apply
}

variable "create_new_vpc" {
  description = "Whether to create a new VPC or use an existing one"
  type        = bool
  default     = false
}

variable "existing_vpc_id" {
  description = "ID of an existing VPC to use if create_new_vpc is false"
  type        = string
  default     = ""
}

variable "existing_subnet_id" {
  description = "ID of an existing subnet to use if create_new_vpc is false"
  type        = string
  default     = ""
}

variable "existing_security_group_id" {
  description = "ID of an existing security group to use if create_new_vpc is false"
  type        = string
  default     = ""
}