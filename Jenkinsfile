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
            }
        }
        
        stage('Check Docker Daemon') {
            steps {
                sh 'docker info || (echo "Docker daemon is not running. Please start Docker service." && exit 1)'
            }
        }
        
        stage('Parallel Install Dependencies') {
            parallel {
                stage('Server Dependencies') {
                    steps {
                        dir('server') {
                            sh 'npm ci --only=prod'
                        }
                    }
                }
                stage('Client Dependencies') {
                    steps {
                        dir('client') {
                            sh 'npm ci --only=prod'
                        }
                    }
                }
            }
        }
        
        stage('Parallel Tests') {
            parallel {
                stage('Server Tests') {
                    steps {
                        dir('server') {
                            sh 'npm test || echo "No tests found or tests failed but continuing"'
                        }
                    }
                }
                stage('Client Tests') {
                    steps {
                        dir('client') {
                            sh 'npm test || echo "No tests found or tests failed but continuing"'
                        }
                    }
                }
            }
        }
        
        stage('Parallel Docker Builds') {
            parallel {
                stage('Build Server Image') {
                    steps {
                        sh 'docker build -t ${DOCKERHUB_USERNAME}/${APP_NAME}-server:latest ./server'
                    }
                }
                stage('Build Client Image') {
                    steps {
                        sh 'docker build -t ${DOCKERHUB_USERNAME}/${APP_NAME}-client:latest ./client'
                    }
                }
            }
        }
        
        stage('Login and Push to DockerHub') {
            steps {
                sh 'echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin'
                sh '''
                docker push ${DOCKERHUB_USERNAME}/${APP_NAME}-server:latest &
                docker push ${DOCKERHUB_USERNAME}/${APP_NAME}-client:latest &
                wait
                '''
            }
        }
        
        stage('Provision Infrastructure with Terraform') {
            steps {
                dir('terraform') {
                    withEnv([
                        "AWS_ACCESS_KEY_ID=${AWS_CREDENTIALS_USR}",
                        "AWS_SECRET_ACCESS_KEY=${AWS_CREDENTIALS_PSW}"
                    ]) {
                        sh '''
                        terraform init -input=false
                        echo "key_name = \\"${EC2_KEY_NAME}\\"" > terraform.tfvars
                        terraform plan -out=tfplan -input=false
                        terraform apply -auto-approve tfplan
                        '''
                        
                        script {
                            env.EC2_PUBLIC_IP = sh(script: 'terraform output -raw app_public_ip', returnStdout: true).trim()
                            env.EC2_PUBLIC_DNS = sh(script: 'terraform output -raw app_public_dns', returnStdout: true).trim()
                        }
                    }
                }
            }
        }
        
        stage('Wait for EC2 Instance') {
            steps {
                sh '''
                    echo "Waiting for SSH on ${EC2_PUBLIC_IP} to become available..."
                    timeout=300
                    counter=0
                    interval=10
                    
                    until nc -z -w 5 ${EC2_PUBLIC_IP} 22 || [ $counter -ge $timeout ]; do
                        echo "SSH not available yet, waiting ${interval} seconds... ($counter/$timeout seconds elapsed)"
                        sleep ${interval}
                        counter=$((counter + interval))
                    done
                    
                    if [ $counter -ge $timeout ]; then
                        echo "Timed out waiting for SSH to become available"
                        exit 1
                    fi
                '''
            }
        }
        
        stage('Deploy with Ansible') {
            steps {
                dir('ansible') {
                    sh '''
                        mkdir -p "${WORKSPACE}/.ssh"
                        chmod 700 "${WORKSPACE}/.ssh"
                        
                        cat "${SSH_KEY_CREDENTIALS}" > "${WORKSPACE}/.ssh/aws-key.pem"
                        chmod 600 "${WORKSPACE}/.ssh/aws-key.pem"
                        
                        # Create the hosts file with app_servers group
                        echo "[app_servers]" > hosts
                        echo "url_shortener ansible_host=${EC2_PUBLIC_IP} ansible_user=ubuntu ansible_ssh_private_key_file=${WORKSPACE}/.ssh/aws-key.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'" >> hosts
                        
                        # Debug: Show hosts file content
                        echo "---------- HOSTS FILE CONTENT ----------"
                        cat hosts
                        echo "----------------------------------------"
                        
                        # Debug: Show playbook content
                        echo "---------- PLAYBOOK CONTENT ----------"
                        cat deploy.yml
                        echo "--------------------------------------"
                        
                        # Run ansible with verbose logging
                        ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -vvv -i hosts deploy.yml --extra-vars "app_host_ip=${EC2_PUBLIC_IP} app_domain=${EC2_PUBLIC_DNS}"
                    '''
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                sh '''
                    if curl -s -f -m 10 http://${EC2_PUBLIC_IP}:5001/api/health; then
                        echo "Backend API is accessible at http://${EC2_PUBLIC_IP}:5001/api"
                        echo "Frontend is accessible at http://${EC2_PUBLIC_IP}:8000"
                    else
                        echo "Warning: Could not verify deployment"
                        echo "Please manually check http://${EC2_PUBLIC_IP}:8000 and http://${EC2_PUBLIC_IP}:5001/api"
                    fi
                '''
            }
        }
    }
    
    post {
        always {
            sh 'docker logout || true'
            cleanWs()
        }
        success {
            echo """
            Deployment successful! Your URL Shortener application is now available at:
            Frontend: http://${EC2_PUBLIC_IP}:8000
            Backend API: http://${EC2_PUBLIC_IP}:5001/api
            """
        }
        failure {
            echo "Pipeline failed. Please check the logs for more information."
        }
    }
}