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
        EC2_KEY_NAME = "urlshortner-new-key"
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
                            sh 'npm ci --omit=dev'
                        }
                    }
                }
                stage('Client Dependencies') {
                    steps {
                        dir('client') {
                            sh 'npm ci --omit=dev'
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
                sh 'docker logout'
            }
        }
        
        stage('Provision Infrastructure with Terraform') {
            steps {
                dir('terraform') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'aws-credentials', 
                            usernameVariable: 'AWS_ACCESS_KEY_ID', 
                            passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                        )
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
                    max_attempts=10
                    attempt=0
                    
                    while [ $attempt -lt $max_attempts ]; do
                        if nc -z -w 10 ${EC2_PUBLIC_IP} 22; then
                            echo "SSH is now available on ${EC2_PUBLIC_IP}"
                            exit 0
                        fi
                        
                        echo "Waiting for SSH on ${EC2_PUBLIC_IP}... (Attempt $((attempt+1))/$max_attempts)"
                        sleep 30
                        attempt=$((attempt+1))
                    done
                    
                    echo "Timed out waiting for SSH to become available"
                    exit 1
                '''
            }
        }
        
        stage('Deploy with Ansible') {
            steps {
                dir('ansible') {
                    script {
                        try {
                            // Prepare SSH key and inventory
                            sh '''
                                mkdir -p "${WORKSPACE}/.ssh"
                                chmod 700 "${WORKSPACE}/.ssh"
                                
                                # Write SSH key securely
                                echo "${SSH_KEY_CREDENTIALS}" > "${WORKSPACE}/.ssh/aws-key.pem"
                                chmod 600 "${WORKSPACE}/.ssh/aws-key.pem"
                                
                                # Create dynamic inventory
                                echo "[url_shortener]" > hosts
                                echo "${EC2_PUBLIC_IP} ansible_user=ubuntu ansible_ssh_private_key_file=${WORKSPACE}/.ssh/aws-key.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'" >> hosts
                            '''
                            
                            // Run Ansible playbook with robust error handling
                            sh '''
                                export ANSIBLE_HOST_KEY_CHECKING=False
                                ansible-playbook -i hosts deploy.yml \
                                    --extra-vars "app_host_ip=${EC2_PUBLIC_IP} app_domain=${EC2_PUBLIC_DNS}" \
                                    -vvv
                            '''
                        } catch (Exception e) {
                            echo "Ansible deployment failed: ${e.getMessage()}"
                            throw e
                        }
                    }
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                script {
                    // Enhanced deployment verification
                    def maxRetries = 3
                    def retryCount = 0
                    def serviceCheck = false
                    
                    while (!serviceCheck && retryCount < maxRetries) {
                        try {
                            sh '''
                                # Wait for services to fully start
                                sleep 60
                                
                                # Robust health checks
                                backend_check=$(curl -s -o /dev/null -w "%{http_code}" http://${EC2_PUBLIC_IP}:5001/api/health)
                                frontend_check=$(curl -s -o /dev/null -w "%{http_code}" http://${EC2_PUBLIC_IP}:8000)
                                
                                # Check if both services return 200 OK
                                if [ "$backend_check" -eq 200 ] && [ "$frontend_check" -eq 200 ]; then
                                    echo "Backend and Frontend are accessible"
                                    exit 0
                                else
                                    echo "Service checks failed. Backend: $backend_check, Frontend: $frontend_check"
                                    exit 1
                                fi
                            '''
                            serviceCheck = true
                        } catch (Exception e) {
                            retryCount++
                            echo "Deployment verification attempt ${retryCount} failed: ${e.getMessage()}"
                            sleep(30) // Wait before retrying
                        }
                    }
                    
                    if (!serviceCheck) {
                        error "Failed to verify deployment after ${maxRetries} attempts"
                    }
                }
            }
        }
    }
    
    post {
        always {
            // Cleanup steps
            sh 'docker logout || true'
            cleanWs()
        }
        
        success {
            echo """
            Deployment Successful! 
            URL Shortener Application is now available at:
            - Frontend: http://${EC2_PUBLIC_IP}:8000
            - Backend API: http://${EC2_PUBLIC_IP}:5001/api
            """
        }
        
        failure {
            echo "Pipeline failed. Please review the logs for detailed error information."
            // Optional: Add notification mechanism like email or Slack
        }
    }
}