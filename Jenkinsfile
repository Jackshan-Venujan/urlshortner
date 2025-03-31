pipeline {
    agent any

    environment {
        DOCKER_HUB_CREDENTIALS = credentials('docker-hub-credentials')
        DOCKER_IMAGE_NAME_BACKEND = 'venujan/urlshortner-server-1'
        DOCKER_IMAGE_NAME_FRONTEND = 'venujan/urlshortner-client-1'
        DOCKER_IMAGE_TAG = "${env.BUILD_NUMBER}"
        
        // AWS credentials
        AWS_CREDENTIALS = credentials('aws-credentials')
        AWS_ACCESS_KEY_ID = "${AWS_CREDENTIALS_USR}"
        AWS_SECRET_ACCESS_KEY = "${AWS_CREDENTIALS_PSW}"
        AWS_REGION = 'us-east-1'  // Replace with your preferred region
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Check') {
            parallel {
                stage('Backend Build Check') {
                    steps {
                        dir('backend') {
                            bat 'npm install'
                            bat 'npm rebuild bcrypt --update-binary'
                        }
                    }
                }
                stage('Frontend Build Check') {
                    steps {
                        dir('frontend') {
                            bat 'npm install'
                            bat 'npm run build'
                        }
                    }
                }
            }
        }

        stage('Tests') {
            parallel {
                stage('Backend Tests') {
                    steps {
                        dir('backend') {
                            echo 'Running backend tests...'
                            // Replace with actual test commands when tests are implemented
                            // bat 'npm test'
                        }
                    }
                }
                stage('Frontend Tests') {
                    steps {
                        dir('frontend') {
                            echo 'Running frontend tests...'
                            // Replace with actual test commands when tests are implemented
                            // bat 'npm test'
                        }
                    }
                }
            }
        }

        stage('Docker Login') {
            steps {
                script {
                    def loginSuccess = false
                    retry(5) {
                        try {
                            timeout(time: 2, unit: 'MINUTES') {
                                bat 'echo %DOCKER_HUB_CREDENTIALS_PSW%| docker login -u %DOCKER_HUB_CREDENTIALS_USR% --password-stdin'
                            }
                            loginSuccess = true
                        } catch (Exception e) {
                            echo "Docker login attempt failed: ${e.message}"
                            sleep(10) // Wait 10 seconds before retrying
                            error("Retrying Docker login...")
                        }
                    }
                    // If all retries fail, we'll still proceed but warn
                    if (!loginSuccess) {
                        echo "WARNING: Docker Hub login failed after multiple attempts. Will build images but skip pushing."
                    }
                }
            }
        }
        
        stage('Build Docker Images') {
            steps {
                dir('backend') {
                    bat "docker build -t ${DOCKER_IMAGE_NAME_BACKEND}:${DOCKER_IMAGE_TAG} ."
                    bat "docker tag ${DOCKER_IMAGE_NAME_BACKEND}:${DOCKER_IMAGE_TAG} ${DOCKER_IMAGE_NAME_BACKEND}:latest"
                }
                
                dir('frontend') {
                    bat "docker build -t ${DOCKER_IMAGE_NAME_FRONTEND}:${DOCKER_IMAGE_TAG} ."
                    bat "docker tag ${DOCKER_IMAGE_NAME_FRONTEND}:${DOCKER_IMAGE_TAG} ${DOCKER_IMAGE_NAME_FRONTEND}:latest"
                }
            }
        }
        
        stage('Push Docker Images') {
            steps {
                script {
                    // Only try to push if login succeeded
                    try {
                        timeout(time: 3, unit: 'MINUTES') {
                            dir('backend') {
                                bat "docker push ${DOCKER_IMAGE_NAME_BACKEND}:${DOCKER_IMAGE_TAG}"
                                bat "docker push ${DOCKER_IMAGE_NAME_BACKEND}:latest"
                            }
                        }
                    } catch (Exception e) {
                        echo "WARNING: Failed to push backend image: ${e.message}"
                        echo "Will continue with deployment using local images"
                    }
                    
                    try {
                        timeout(time: 3, unit: 'MINUTES') {
                            dir('frontend') {
                                bat "docker push ${DOCKER_IMAGE_NAME_FRONTEND}:${DOCKER_IMAGE_TAG}"
                                bat "docker push ${DOCKER_IMAGE_NAME_FRONTEND}:latest"
                            }
                        }
                    } catch (Exception e) {
                        echo "WARNING: Failed to push frontend image: ${e.message}"
                        echo "Will continue with deployment using local images"
                    }
                }
            }
        }

        stage('Deploy to Environment') {
            steps {
                echo 'Deploying to environment using Terraform and Ansible...'
                
                // For Windows, you'll need to install Terraform and Ansible
                // and make sure they're in your PATH
                script {
                    try {
                        dir('infrastructure/terraform') {
                            bat 'terraform init'
                            bat 'terraform apply -auto-approve'
                        }
                    } catch (Exception e) {
                        echo "ERROR during Terraform deployment: ${e.message}"
                        error("Terraform deployment failed. Cannot continue with deployment.")
                    }
                    
                    // Only proceed with Ansible if Terraform succeeded
                    try {
                        // Wait for EC2 instance to fully initialize
                        echo "Waiting for EC2 instance to fully initialize (180 seconds)..."
                        sleep(180)
                        
                        dir('infrastructure/ansible') {
                            // For Windows, you might need to use WSL or a different approach for Ansible
                            // This is a simplified example
                            bat 'ansible-playbook -i inventory.ini deploy.yml -e "backend_image=%DOCKER_IMAGE_NAME_BACKEND%:%DOCKER_IMAGE_TAG%" -e "frontend_image=%DOCKER_IMAGE_NAME_FRONTEND%:%DOCKER_IMAGE_TAG%"'
                        }
                    } catch (Exception e) {
                        echo "ERROR during Ansible deployment: ${e.message}"
                        error("Ansible deployment failed.")
                    }
                }
            }
        }
    }

    post {
        always {
            bat 'docker logout'
            cleanWs()
        }
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}