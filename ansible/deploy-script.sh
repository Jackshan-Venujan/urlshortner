#!/bin/bash

# Set strict error handling
set -e

# Get the EC2 public IP from Terraform output
EC2_PUBLIC_IP=$(cd terraform && terraform output -raw app_public_ip)

# Ensure SSH directory exists with correct permissions
mkdir -p "${WORKSPACE}/.ssh"
chmod 700 "${WORKSPACE}/.ssh"

# Write SSH key with strict permissions
if [ -n "$SSH_KEY_CREDENTIALS" ]; then
    echo "$SSH_KEY_CREDENTIALS" > "${WORKSPACE}/.ssh/aws-key.pem"
    chmod 600 "${WORKSPACE}/.ssh/aws-key.pem"
else
    echo "Error: SSH key credentials not found"
    exit 1
fi

# Create dynamic inventory file
cat << EOF > hosts
[app_servers]
url_shortener ansible_host=${EC2_PUBLIC_IP} ansible_user=ubuntu ansible_ssh_private_key_file=${WORKSPACE}/.ssh/aws-key.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

# Copy Ansible playbooks and inventory to the target directory
cp deploy.yml inventory.yml hosts "${WORKSPACE}/.ssh/"

# Run Ansible playbook without sudo for most tasks
cd "${WORKSPACE}/.ssh"
ansible-playbook -i hosts deploy.yml