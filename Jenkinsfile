pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        //         stage('Build Frontend') {
        //     steps {
        //         script {
        //             dir('frontend/todo-app') {
        //                 bat 'docker build -t todo-frontend .'
        //             }
        //         }
        //     }
        // }

        // stage('Build Backend') {
        //     steps {
        //         script {
        //             dir('backend/TodoApi') {
        //                 bat 'docker build -t todo-backend .'
        //             }
        //         }
        //     }
        // }

        stage('Deploy') {
            steps {
                script {
                   
                    bat 'docker-compose up --build -d'
                }
            }
        }
    }

    post {

        success {
            echo 'Build and deployment successful!'
        }
        failure {
            echo 'Build or deployment failed!'
        }
    }
}