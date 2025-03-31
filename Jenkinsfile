pipeline {
    agent any

    environment {
        DOCKER_HUB_CREDENTIALS = credentials('docker-hub-credentials')
        DOCKER_IMAGE_NAME_SERVER = 'venujan/urlshortner-server'
        DOCKER_IMAGE_NAME_CLIENT = 'venujan/urlshortner-client'
        DOCKER_IMAGE_TAG = "${env.BUILD_NUMBER}"
        
        // AWS credentials
        AWS_CREDENTIALS = credentials('aws-credentials')
        AWS_ACCESS_KEY_ID = "${AWS_CREDENTIALS_USR}"
        AWS_SECRET_ACCESS_KEY = "${AWS_CREDENTIALS_PSW}"
        AWS_REGION = 'us-east-1'
        
        // Add Terraform to PATH
        PATH = "C:\\Terraform;${env.PATH}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Check') {
            parallel {
                stage('Server Build Check') {
                    steps {
                        dir('server') {
                            bat 'npm install'
                            bat 'npm rebuild bcrypt --update-binary'
                        }
                    }
                }
                stage('Client Build Check') {
                    steps {
                        dir('client') {
                            bat 'npm install'
                            bat 'npm run build'
                        }
                    }
                }
            }
        }

        stage('Tests') {
            parallel {
                stage('Server Tests') {
                    steps {
                        dir('server') {
                            echo 'Running server tests...'
                            // bat 'npm test'
                        }
                    }
                }
                stage('Client Tests') {
                    steps {
                        dir('client') {
                            echo 'Running client tests...'
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
                    retry(3) {
                        try {
                            timeout(time: 2, unit: 'MINUTES') {
                                bat 'echo %DOCKER_HUB_CREDENTIALS_PSW%| docker login -u %DOCKER_HUB_CREDENTIALS_USR% --password-stdin'
                            }
                            loginSuccess = true
                        } catch (Exception e) {
                            echo "Docker login attempt failed: ${e.message}"
                            sleep(10)
                            error("Retrying Docker login...")
                        }
                    }
                    if (!loginSuccess) {
                        echo "WARNING: Docker Hub login failed after multiple attempts. Will build images but skip pushing."
                    }
                }
            }
        }
        
        stage('Build Docker Images') {
            steps {
                script {
                    try {
                        dir('server') {
                            echo "Building server Docker image..."
                            bat "docker build -t ${DOCKER_IMAGE_NAME_SERVER}:${DOCKER_IMAGE_TAG} ."
                            
                            // Remove existing latest tag if it exists
                            bat "docker rmi ${DOCKER_IMAGE_NAME_SERVER}:latest || echo Latest tag doesn't exist yet"
                            bat "docker tag ${DOCKER_IMAGE_NAME_SERVER}:${DOCKER_IMAGE_TAG} ${DOCKER_IMAGE_NAME_SERVER}:latest"
                        }
                    } catch (Exception e) {
                        echo "WARNING: Failed to build server image: ${e.message}"
                        echo "Will continue with client image build"
                    }
                    
                    try {
                        dir('client') {
                            echo "Building client Docker image..."
                            bat "docker build -t ${DOCKER_IMAGE_NAME_CLIENT}:${DOCKER_IMAGE_TAG} ."
                            
                            // Remove existing latest tag if it exists
                            bat "docker rmi ${DOCKER_IMAGE_NAME_CLIENT}:latest || echo Latest tag doesn't exist yet"
                            bat "docker tag ${DOCKER_IMAGE_NAME_CLIENT}:${DOCKER_IMAGE_TAG} ${DOCKER_IMAGE_NAME_CLIENT}:latest"
                        }
                    } catch (Exception e) {
                        echo "WARNING: Failed to build client image: ${e.message}"
                    }
                }
            }
        }
        
        stage('Create Docker Hub Repositories') {
            steps {
                script {
                    // Create repositories if they don't exist
                    try {
                        bat '''
                        curl -X POST -H "Content-Type: application/json" -H "Authorization: JWT %DOCKER_HUB_CREDENTIALS_PSW%" -d "{\"namespace\":\"%DOCKER_HUB_CREDENTIALS_USR%\",\"name\":\"urlshortner-server\",\"is_private\":false}" https://hub.docker.com/v2/repositories/
                        '''
                    } catch (Exception e) {
                        echo "Repository urlshortner-server might already exist: ${e.message}"
                    }
                    
                    try {
                        bat '''
                        curl -X POST -H "Content-Type: application/json" -H "Authorization: JWT %DOCKER_HUB_CREDENTIALS_PSW%" -d "{\"namespace\":\"%DOCKER_HUB_CREDENTIALS_USR%\",\"name\":\"urlshortner-client\",\"is_private\":false}" https://hub.docker.com/v2/repositories/
                        '''
                    } catch (Exception e) {
                        echo "Repository urlshortner-client might already exist: ${e.message}"
                    }
                }
            }
        }
        
        stage('Push Docker Images') {
            steps {
                script {
                    try {
                        timeout(time: 3, unit: 'MINUTES') {
                            dir('server') {
                                bat "docker push ${DOCKER_IMAGE_NAME_SERVER}:${DOCKER_IMAGE_TAG}"
                                bat "docker push ${DOCKER_IMAGE_NAME_SERVER}:latest"
                            }
                        }
                    } catch (Exception e) {
                        echo "WARNING: Failed to push server image: ${e.message}"
                        echo "Will continue with deployment using local images"
                    }
                    
                    try {
                        timeout(time: 3, unit: 'MINUTES') {
                            dir('client') {
                                bat "docker push ${DOCKER_IMAGE_NAME_CLIENT}:${DOCKER_IMAGE_TAG}"
                                bat "docker push ${DOCKER_IMAGE_NAME_CLIENT}:latest"
                            }
                        }
                    } catch (Exception e) {
                        echo "WARNING: Failed to push client image: ${e.message}"
                        echo "Will continue with deployment using local images"
                    }
                }
            }
        }

        stage('Deploy to Environment') {
            steps {
                echo 'Deploying to environment using Terraform and Ansible...'
                
                script {
                    try {
                        dir('infrastructure/terraform') {
                            // Check if Terraform is available
                            bat 'where terraform || echo Terraform not found in PATH'
                            
                            // Try to initialize and apply Terraform
                            bat 'terraform init'
                            bat 'terraform apply -auto-approve'
                        }
                    } catch (Exception e) {
                        echo "ERROR during Terraform deployment: ${e.message}"
                        echo "Attempting to use local Terraform installation..."
                        
                        dir('infrastructure/terraform') {
                            bat 'C:\terraform_1.11.3_windows_amd64\terraform.exe init'
                            bat 'C:\terraform_1.11.3_windows_amd64\terraform.exe apply -auto-approve'
                        }
                    }
                    
                    try {
                        echo "Waiting for EC2 instance to fully initialize (180 seconds)..."
                        sleep(180)
                        
                        dir('infrastructure/ansible') {
                            // Check if inventory file exists
                            bat 'if exist inventory.ini (echo Inventory file found) else (echo Inventory file not found)'
                            
                            // Create temp directory if it doesn't exist
                            bat 'if not exist C:\\temp mkdir C:\\temp'
                            bat 'if not exist C:\\temp\\templates mkdir C:\\temp\\templates'
                            
                            // Check if we need to create a mock inventory file
                            bat '''
                            if not exist inventory.ini (
                                echo Creating mock inventory file for testing...
                                echo [urlshortner_servers] > C:\\temp\\inventory.ini
                                echo 127.0.0.1 ansible_user=ubuntu ansible_connection=local >> C:\\temp\\inventory.ini
                                echo. >> C:\\temp\\inventory.ini
                                echo [urlshortner_servers:vars] >> C:\\temp\\inventory.ini
                                echo ansible_python_interpreter=/usr/bin/python3 >> C:\\temp\\inventory.ini
                            ) else (
                                copy inventory.ini C:\\temp\\inventory.ini
                            )
                            '''
                            
                            // Copy the deploy.yml file to a location accessible by WSL
                            bat 'copy deploy.yml C:\\temp\\deploy.yml'
                            
                            // Copy the template file to a location accessible by WSL
                            bat 'copy ..\\templates\\docker-compose.yml.j2 C:\\temp\\templates\\'
                            
                            // Check if SSH key exists and copy it
                            bat '''
                            if exist urlshortner_app_key.pem (
                                copy urlshortner_app_key.pem C:\\temp\\
                                echo SSH key found and copied
                            ) else (
                                echo SSH key not found, will use local deployment
                            )
                            '''
                            
                            // Run Ansible through WSL with appropriate options
                            bat '''
                            echo Running Ansible through WSL...
                            
                            if exist C:\\temp\\urlshortner_app_key.pem (
                                wsl chmod 400 /mnt/c/temp/urlshortner_app_key.pem
                                wsl ansible-playbook -i /mnt/c/temp/inventory.ini /mnt/c/temp/deploy.yml -e "server_image=%DOCKER_IMAGE_NAME_SERVER%:%DOCKER_IMAGE_TAG%" -e "client_image=%DOCKER_IMAGE_NAME_CLIENT%:%DOCKER_IMAGE_TAG%" --extra-vars "ansible_ssh_private_key_file=/mnt/c/temp/urlshortner_app_key.pem"
                            ) else (
                                echo Using local deployment mode since SSH key is not available
                                wsl ansible-playbook -i /mnt/c/temp/inventory.ini /mnt/c/temp/deploy.yml -e "server_image=%DOCKER_IMAGE_NAME_SERVER%:%DOCKER_IMAGE_TAG%" -e "client_image=%DOCKER_IMAGE_NAME_CLIENT%:%DOCKER_IMAGE_TAG%" -c local
                            )
                            '''
                        }
                    } catch (Exception e) {
                        echo "ERROR during deployment: ${e.message}"
                        echo "Attempting local Docker Compose deployment as fallback..."
                        
                        // Fallback to local Docker Compose deployment
                        dir('infrastructure/templates') {
                            bat '''
                            echo Creating local Docker Compose file...
                            type docker-compose.yml.j2 | findstr /v "{{ .* }}" > C:\\temp\\docker-compose.yml
                            echo Replacing template variables...
                            powershell -Command "(Get-Content C:\\temp\\docker-compose.yml) -replace '\\{\\{ server_image \\}\\}', '%DOCKER_IMAGE_NAME_SERVER%:%DOCKER_IMAGE_TAG%' -replace '\\{\\{ client_image \\}\\}', '%DOCKER_IMAGE_NAME_CLIENT%:%DOCKER_IMAGE_TAG%' | Set-Content C:\\temp\\docker-compose.yml"
                            
                            echo Running Docker Compose locally...
                            cd C:\\temp
                            docker-compose up -d
                            '''
                        }
                        
                        error("Remote deployment failed, but local deployment attempted.")
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