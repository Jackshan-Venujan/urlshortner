# Use this file to provide your existing infrastructure details
# Leave create_new_vpc as true to create new resources
# Or set to false if you want to use existing infrastructure

# To get VPC details, run: aws ec2 describe-vpcs
# To get subnet details, run: aws ec2 describe-subnets
# To get security group details, run: aws ec2 describe-security-groups

# IMPORTANT NOTE: You must set create_new_vpc=true if you're starting fresh
# Or provide ACTUAL EXISTING VALUES for the resource IDs below

create_new_vpc = true  # Setting to true to create all new resources

# Only needed if create_new_vpc = false
# Replace these with your actual AWS resource IDs when using existing infrastructure
existing_vpc_id = "vpc-YOUR_VPC_ID"
existing_subnet_id = "subnet-YOUR_SUBNET_ID"
existing_security_group_id = "sg-YOUR_SECURITY_GROUP_ID"

# AWS region to deploy to
aws_region = "us-east-1"

# EC2 instance type
instance_type = "t2.micro"

# Latest Ubuntu 20.04 LTS AMI for us-east-1
ami_id = "ami-0c55b159cbfafe1f0"