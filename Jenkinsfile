pipeline {
    agent any
    
    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
        APP_NAME = "urlshortner"
        DOCKERHUB_USERNAME = "venujan"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build Docker Images') {
            steps {
                sh 'docker build --no-cache -t ${DOCKERHUB_USERNAME}/${APP_NAME}-server:latest ./server'
                sh 'docker build --no-cache -t ${DOCKERHUB_USERNAME}/${APP_NAME}-client:latest ./client'
                // If you have a separate MongoDB image to build:
                // sh 'docker build -t ${DOCKERHUB_USERNAME}/${APP_NAME}-mongodb:latest ./mongodb'
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
                // If you have a MongoDB image to push:
                // sh 'docker push ${DOCKERHUB_USERNAME}/${APP_NAME}-mongodb:latest'
            }
        }
    }
    
    post {
        always {
            sh 'docker logout'
        }
    }
}