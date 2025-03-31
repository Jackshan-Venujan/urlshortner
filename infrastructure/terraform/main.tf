# Define the required providers
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Configure the AWS provider
provider "aws" {
  region = var.aws_region
}

# Generate a random suffix to avoid naming conflicts
resource "random_id" "suffix" {
  byte_length = 4
}

# Create a VPC if create_new_vpc is true
resource "aws_vpc" "urlshortner_vpc" {
  count = var.create_new_vpc ? 1 : 0
  
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  
  tags = {
    Name = "urlshortner-vpc-${random_id.suffix.hex}"
  }
}

# Create a public subnet if create_new_vpc is true
resource "aws_subnet" "urlshortner_public_subnet" {
  count = var.create_new_vpc ? 1 : 0
  
  vpc_id     = aws_vpc.urlshortner_vpc[0].id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "${var.aws_region}a"
  
  tags = {
    Name = "urlshortner-public-subnet-${random_id.suffix.hex}"
  }
}

# Create an internet gateway if create_new_vpc is true
resource "aws_internet_gateway" "urlshortner_igw" {
  count = var.create_new_vpc ? 1 : 0
  
  vpc_id = aws_vpc.urlshortner_vpc[0].id
  
  tags = {
    Name = "urlshortner-igw-${random_id.suffix.hex}"
  }
}

# Create a route table if create_new_vpc is true
resource "aws_route_table" "urlshortner_public_rt" {
  count = var.create_new_vpc ? 1 : 0
  
  vpc_id = aws_vpc.urlshortner_vpc[0].id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.urlshortner_igw[0].id
  }
  
  tags = {
    Name = "urlshortner-public-rt"
  }
}

# Associate the route table with the subnet if create_new_vpc is true
resource "aws_route_table_association" "public_rta" {
  count = var.create_new_vpc ? 1 : 0
  
  subnet_id      = aws_subnet.urlshortner_public_subnet[0].id
  route_table_id = aws_route_table.urlshortner_public_rt[0].id
}

# Create a security group if create_new_vpc is true
resource "aws_security_group" "urlshortner_app_sg" {
  count = var.create_new_vpc ? 1 : 0
  
  name        = "urlshortner-app-sg-${random_id.suffix.hex}"
  description = "Allow traffic for URL Shortener App"
  vpc_id      = aws_vpc.urlshortner_vpc[0].id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  # Client app port
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Client App"
  }

  # Server API port
  ingress {
    from_port   = 5001
    to_port     = 5001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Server API"
  }

  # MongoDB port
  ingress {
    from_port   = 27018
    to_port     = 27018
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "MongoDB"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "urlshortner-app-sg"
  }
}

# Generate a new key pair for SSH access
resource "tls_private_key" "urlshortner_app_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key to file
resource "local_file" "private_key" {
  content         = tls_private_key.urlshortner_app_key.private_key_pem
  filename        = "${path.module}/../ansible/urlshortner_app_key.pem"
  file_permission = "0400"  # More restrictive permissions
}

# Create AWS key pair from the generated public key
resource "aws_key_pair" "urlshortner_app_keypair" {
  key_name   = "urlshortner-app-keypair-${random_id.suffix.hex}"
  public_key = tls_private_key.urlshortner_app_key.public_key_openssh
}

# Create EC2 instance
resource "aws_instance" "urlshortner_app_server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.urlshortner_app_keypair.key_name
  
  # Use appropriate subnet based on whether we're creating new infrastructure
  subnet_id     = var.create_new_vpc ? aws_subnet.urlshortner_public_subnet[0].id : var.existing_subnet_id
  
  # Ensure we're using security group IDs only (not names) when working with VPC
  vpc_security_group_ids = var.create_new_vpc ? [aws_security_group.urlshortner_app_sg[0].id] : [var.existing_security_group_id]
  
  # User data script to ensure instance is ready for SSH and container deployment
  user_data = <<-EOF
    #!/bin/bash
    # Update system packages
    yum update -y
    
    # Install Python 3.8+ for Ansible compatibility
    amazon-linux-extras enable python3.8
    yum install -y python3.8
    
    # Make Python 3.8 the default python3
    alternatives --set python3 /usr/bin/python3.8
    python3 --version
    
    # Install pip for Python 3.8
    curl -O https://bootstrap.pypa.io/get-pip.py
    python3.8 get-pip.py
    
    # Install Docker if not present
    if ! command -v docker &> /dev/null; then
      amazon-linux-extras install docker -y
      systemctl enable docker
      systemctl start docker
    fi
    
    # Ensure SSH service is running and properly configured
    # Stop and reconfigure sshd
    systemctl stop sshd
    
    # Configure sshd for better compatibility and debugging
    cat > /etc/ssh/sshd_config <<'SSHCONFIG'
    # Package generated configuration file
    # See the sshd_config(5) manpage for details

    # What ports, IPs and protocols we listen for
    Port 22
    
    # Use these privileged separation settings
    UsePrivilegeSeparation yes
    
    # Logging
    SyslogFacility AUTH
    LogLevel DEBUG
    
    # Authentication
    LoginGraceTime 120
    PermitRootLogin no
    StrictModes yes
    
    # Allow ubuntu user with SSH key
    AllowUsers ubuntu
    
    # Turn on PublicKey Authentication
    PubkeyAuthentication yes
    
    # Don't read the user's ~/.rhosts and ~/.shosts files
    IgnoreRhosts yes
    
    # Change to yes to enable challenge-response passwords (beware issues with
    # some PAM modules and threads)
    ChallengeResponseAuthentication no
    
    # Change to yes to enable tunnelled clear text passwords
    PasswordAuthentication yes
    
    X11Forwarding yes
    X11DisplayOffset 10
    PrintMotd no
    PrintLastLog yes
    TCPKeepAlive yes
    
    # Allow client to pass locale environment variables
    AcceptEnv LANG LC_*
    
    Subsystem sftp /usr/lib/openssh/sftp-server
    
    # Set this to 'yes' to enable PAM authentication, account processing,
    # and session processing. If this is enabled, PAM authentication will
    # be allowed through the ChallengeResponseAuthentication and
    # PasswordAuthentication.  Depending on your PAM configuration,
    # PAM authentication via ChallengeResponseAuthentication may bypass
    # the setting of "PermitRootLogin without-password".
    UsePAM yes
SSHCONFIG
    
    # Ensure proper permissions on .ssh directory for ubuntu user
    mkdir -p /home/ubuntu/.ssh
    chmod 700 /home/ubuntu/.ssh
    
    # Add the SSH public key directly to authorized_keys
    echo '${tls_private_key.urlshortner_app_key.public_key_openssh}' > /home/ubuntu/.ssh/authorized_keys
    
    # Set proper permissions on authorized_keys
    chmod 600 /home/ubuntu/.ssh/authorized_keys
    chown -R ubuntu:ubuntu /home/ubuntu/.ssh
    
    # Start sshd with new configuration
    systemctl start sshd
    systemctl enable sshd
    
    # Debug info
    echo "SSH server fingerprints:" > /tmp/ssh_info.txt
    ssh-keygen -lf /etc/ssh/ssh_host_rsa_key.pub >> /tmp/ssh_info.txt
    ssh-keygen -lf /etc/ssh/ssh_host_ecdsa_key.pub >> /tmp/ssh_info.txt
    ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub >> /tmp/ssh_info.txt
    
    # Save the authorized key for debugging
    echo "Authorized key:" >> /tmp/ssh_info.txt
    cat /home/ubuntu/.ssh/authorized_keys >> /tmp/ssh_info.txt
    
    # Get IP info for debugging
    echo "Network information:" >> /tmp/ssh_info.txt
    ifconfig >> /tmp/ssh_info.txt
    
    # Write a marker file to indicate user_data script completed
    echo "Initialization completed at $(date)" > /tmp/init_complete.txt
  EOF
  
  tags = {
    Name = "urlshortner-app-server-${random_id.suffix.hex}"
  }
  
  # Provisioning steps after the instance is created
  provisioner "local-exec" {
    command = <<-EOT
      # Wait for instance to be fully ready
      echo "Waiting for instance to initialize..."
      sleep 30
      
      # Output the public IP for reference
      echo "EC2 instance created with IP: ${self.public_ip}"
      
      # Create Ansible inventory file
      cat > ../ansible/inventory.ini << 'EOF'
      [urlshortner_servers]
      ${self.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=${abspath(path.module)}/../ansible/urlshortner_app_key.pem ansible_connection=ssh ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ControlMaster=auto -o ControlPersist=60s' ansible_ssh_retries=5 ansible_ssh_timeout=30

      [urlshortner_servers:vars]
      ansible_ssh_pipelining=True
      ansible_python_interpreter=/usr/bin/python3
      EOF
      
      # Make sure key has correct permissions
      chmod 400 ${abspath(path.module)}/../ansible/urlshortner_app_key.pem
      
      # Display inventory for debugging
      echo "Created Ansible inventory:"
      cat ../ansible/inventory.ini
    EOT
  }
}

# Output instance public IP
output "server_public_ip" {
  value = aws_instance.urlshortner_app_server.public_ip
}