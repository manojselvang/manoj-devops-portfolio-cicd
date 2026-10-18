
pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/manojselvang/manoj-devops-portfolio.git'
            }
        }

        stage('Build Backend') {
            steps {
                dir('backend') {
                    sh 'mvn -B clean package'
                }
            }
        }

        stage('Build Backend Image') {
            steps {
                sh '''
                    docker build \
                        -t manojselvang/portfolio-backend:latest \
                        -f backend/Dockerfile backend
                '''
            }
        }

        stage('Build Frontend Image') {
            steps {
                sh '''
                    docker build \
                        -t manojselvang/portfolio-frontend:latest \
                        -f frontend/Dockerfile frontend
                '''
            }
        }

        stage('Push Images to Docker Hub') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKERHUB_USERNAME',
                        passwordVariable: 'DOCKERHUB_TOKEN'
                    )
                ]) {
                    sh '''
                        set +x
                        echo "$DOCKERHUB_TOKEN" | docker login \
                            --username "$DOCKERHUB_USERNAME" \
                            --password-stdin

                        docker push manojselvang/portfolio-backend:latest
                        docker push manojselvang/portfolio-frontend:latest

                        docker logout
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'Build successful. Both images were pushed to Docker Hub.'
        }
        failure {
            echo 'Pipeline failed. Check Console Output for the failing stage.'
        }
    }
}
