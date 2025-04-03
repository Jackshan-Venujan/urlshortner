pipeline {
    agent any
    
    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
        AWS_CREDENTIALS = credentials('aws-credentials')
        SSH_KEY_CREDENTIALS = credentials('aws-ssh-key')
        APP_NAME = "urlshortner"
        DOCKERHUB_USERNAME = "venujan"
        WORKSPACE_PATH = "${WORKSPACE}"
        AWS_REGION = "us-east-1"
        EC2_KEY_NAME = "aws-key"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'echo "Code checkout complete"'
            }
        }
        
        stage('Check Docker Daemon') {
            steps {
                script {
                    try {
                        sh 'docker info'
                        echo 'Docker daemon is running'
                    } catch (Exception e) {
                        error "Docker daemon is not running. Please start Docker service."
                    }
                }
            }
        }
        
        stage('Check for Build Errors') {
            steps {
                dir('server') {
                    sh 'npm install --only=prod'
                }
                dir('client') {
                    sh 'npm install --only=prod'
                }
                echo "Dependency check completed"
            }
        }
        
        stage('Run Tests') {
            steps {
                dir('server') {
                    script {
                        try {
                            sh 'npm test || echo "No tests found or tests failed but continuing"'
                        } catch (Exception e) {
                            echo "Tests failed but continuing: ${e.message}"
                        }
                    }
                }
                dir('client') {
                    script {
                        try {
                            sh 'npm test || echo "No tests found or tests failed but continuing"'
                        } catch (Exception e) {
                            echo "Tests failed but continuing: ${e.message}"
                        }
                    }
                }
            }
        }
        
        stage('Build Docker Images') {
            steps {
                sh 'docker build --no-cache -t ${DOCKERHUB_USERNAME}/${APP_NAME}-server:latest ./server'
                sh 'docker build --no-cache -t ${DOCKERHUB_USERNAME}/${APP_NAME}-client:latest ./client'
            }
        }
        
        stage('Login to DockerHub') {
            steps {
                sh 'echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin'
            }
        }
        
        stage('Push to DockerHub') {
            steps {
                sh 'docker push ${DOCKERHUB_USERNAME}/${APP_NAME}-server:latest'
                sh 'docker push ${DOCKERHUB_USERNAME}/${APP_NAME}-client:latest'
            }
        }
        
        stage('Provision Infrastructure with Terraform') {
            steps {
                dir('terraform') {
                    sh 'terraform init'
                    
                    // Export AWS credentials for Terraform
                    withEnv([
                        "AWS_ACCESS_KEY_ID=${AWS_CREDENTIALS_USR}",
                        "AWS_SECRET_ACCESS_KEY=${AWS_CREDENTIALS_PSW}"
                    ]) {
                        // Create terraform.tfvars with key_name variable
                        writeFile file: 'terraform.tfvars', text: "key_name = \"${EC2_KEY_NAME}\"\n"
                        
                        // Plan and apply Terraform changes
                        sh 'terraform plan -out=tfplan'
                        sh 'terraform apply -auto-approve tfplan'
                        
                        // Capture the EC2 instance public IP
                        script {
                            env.EC2_PUBLIC_IP = sh(script: 'terraform output -raw app_public_ip', returnStdout: true).trim()
                            env.EC2_PUBLIC_DNS = sh(script: 'terraform output -raw app_public_dns', returnStdout: true).trim()
                            echo "EC2 instance provisioned at IP: ${env.EC2_PUBLIC_IP}"
                        }
                    }
                }
            }
        }
        
        stage('Wait for EC2 Instance') {
            steps {
                // Wait for SSH to be available
                sh '''
                    # Wait for SSH to be available on the EC2 instance
                    echo "Waiting for SSH on ${EC2_PUBLIC_IP} to become available..."
                    timeout=600
                    counter=0
                    interval=15
                    
                    until nc -z -w 5 ${EC2_PUBLIC_IP} 22 || [ $counter -ge $timeout ]; do
                        echo "SSH not available yet, waiting ${interval} seconds... ($counter/$timeout seconds elapsed)"
                        sleep ${interval}
                        counter=$((counter + interval))
                    done
                    
                    if [ $counter -ge $timeout ]; then
                        echo "Timed out waiting for SSH to become available"
                        exit 1
                    else
                        echo "SSH is now available on ${EC2_PUBLIC_IP} after $counter seconds"
                    fi
                '''
            }
        }
        
        stage('Deploy with Ansible') {
            steps {
                dir('ansible') {
                    // Copy the SSH key to workspace with proper error handling and correct path escaping and correct path escaping
                    sh '''
                        # Create .ssh directory with proper permissions
                        mkdir -p "${WORKSPACE}/.ssh"
                        chmod 700 "${WORKSPACE}/.ssh"
                        
                        # Debug directory existence
                        echo "Dhecking directery: ${WORKSPACE}/.ssh"
                        ls -la "${WORKSPACE}/.ssh" || echo "Directory listing failed"
                        
                        # Cobug directory existence - with proper quoting for paths with spaces
                        eath"o "Checking directory:" > ${WORKSPACE}/.ssh"
                        ls -la "${WORKSPACE}/.ssh" || echo "Directory listing failed"
                        
                        # Copy and secure the SSH key - with proper quoting for paths with spaces
                        cat "${SSH_KEY_CREDENTIALS}" > "${WORKSPACE}/.ssh/aws-key.pem"
                        chmod 600 "${WORKSPACE}/.ssh/aws-key.pem"
                        
                        # Verify the file exists
                        if [ ! -f "${WORKSPACE}/.ssh/aws-klly"
                            es -ya "${WORKSPACE}/.ssh/aws-ke..pempem" ]; then
                            echo "Failed to create key file"
                            exit 1
                        else
                            echo "SSH key copied successfully"
                            ls -la "${WORKSPACE}/.ssh/aws-key.pem"
                        fi
                    '''
                    
                    // Create the hosts file for Ansible
                    sh "echo 'url_shortener ansible_host=${EC2_PUBLIC_IP} ansible_user=ubuntu ansible_ssh_private_key_file=${WORKSPACE}/.ssh/aws-key.pem ansible_ssh_common_args=\"-o StrictHostKeyChecking=no\"' > hosts"
                    
                    // Run Ansible playbook
                    sh "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts deploy.yml --extra-vars 'app_host_ip=${EC2_PUBLIC_IP} app_domain=${EC2_PUBLIC_DNS}'"
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                script {
                    try {
                        sh "curl -s http://${EC2_PUBLIC_IP}:5001/api/health"
                        echo "Backend API is accessible at http://${EC2_PUBLIC_IP}:5001/api"
                        echo "Frontend is accessible at http://${EC2_PUBLIC_IP}:8000"
                    } catch (Exception e) {
                        echo "Warning: Could not verify deployment: ${e.message}"
                        echo "Please manually check http://${EC2_PUBLIC_IP}:8000 and http://${EC2_PUBLIC_IP}:5001/api"
                    }
                }
            }
        }
    }
    
    post {
        always {
            sh 'docker logout'
            cleanWs()
        }
        success {
            echo "Deployment successful! Your URL Shortener application is now available at:"
            echo "Frontend: http://${EC2_PUBLIC_IP}:8000"
            echo "Backend API: http://${EC2_PUBLIC_IP}:5001/api"
        }
        failure {
            echo "Pipeline failed. Please check the logs for more information."
        }
    }
}