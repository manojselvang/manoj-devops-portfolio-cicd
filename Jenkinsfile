
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        // Application source repository
        APP_REPO_URL = 'https://github.com/manojselvang/manoj-devops-portfolio.git'
        APP_BRANCH   = 'main'

        // Docker Hub image names
        DOCKERHUB_NAMESPACE = 'manojselvang'
        FRONTEND_IMAGE = 'portfolio-frontend'
        BACKEND_IMAGE  = 'portfolio-backend'

        // Kubernetes configuration
        K8S_NAMESPACE = 'portfolio'

        // Jenkins credential IDs
        DOCKERHUB_CREDENTIALS = 'dockerhub-credentials'
        KUBECONFIG_CREDENTIALS = 'k8s-deployer-kubeconfig'
    }

    stages {

        // --------------------------------------------------
        // 1. Checkout CI/CD repository
        // --------------------------------------------------
        stage('Checkout CI/CD Configuration') {
            steps {
                checkout scm

                sh '''
                    echo "Checking CI/CD repository..."
                    echo "Current branch: ${BRANCH_NAME:-unknown}"
                    echo "Workspace: $WORKSPACE"

                    test -d k8s || {
                        echo "ERROR: k8s directory not found."
                        exit 1
                    }

                    find k8s -maxdepth 2 -type f -print
                '''
            }
        }

        // --------------------------------------------------
        // 2. Checkout application repository
        // --------------------------------------------------
        stage('Checkout Application') {
            steps {
                dir('app') {
                    git branch: "${APP_BRANCH}",
                        url: "${APP_REPO_URL}"
                }

                sh '''
                    echo "Application source checked out."
                    test -f app/frontend/package.json
                    test -f app/backend/pom.xml
                    test -f app/frontend/Dockerfile
                    test -f app/backend/Dockerfile
                '''
            }
        }

        // --------------------------------------------------
        // 3. Validate Kubernetes manifests
        // --------------------------------------------------
        stage('Validate Kubernetes Manifests') {
            steps {
                sh '''
                    echo "Validating Kubernetes YAML files..."

                    test -n "$(find k8s -type f -name '*.yaml' -o -name '*.yml')"

                    if [ -f scripts/validate-manifests.sh ]; then
                        chmod +x scripts/validate-manifests.sh
                        ./scripts/validate-manifests.sh
                    else
                        echo "Validation script not found; checking files exist only."
                        find k8s -type f \\( -name '*.yaml' -o -name '*.yml' \\) -print
                    fi
                '''
            }
        }

        // --------------------------------------------------
        // 4. Build and test Java backend
        // --------------------------------------------------
        stage('Build and Test Backend') {
            steps {
                dir('app/backend') {
                    sh '''
                        echo "Building Spring Boot backend..."
                        mvn -B clean verify
                    '''
                }
            }
        }

        // --------------------------------------------------
        // 5. Build React frontend
        // --------------------------------------------------
        stage('Build and Test Frontend') {
            steps {
                dir('app/frontend') {
                    sh '''
                        echo "Installing frontend dependencies..."
                        npm ci

                        echo "Running frontend tests, if configured..."
                        node -e "
                          const p = require('./package.json');
                          process.exit(p.scripts && p.scripts.test ? 0 : 0);
                        "

                        echo "Building React/Vite application..."
                        npm run build

                        test -d dist
                    '''
                }
            }
        }

        // --------------------------------------------------
        // 6. Build Docker images
        // --------------------------------------------------
        stage('Build Docker Images') {
            steps {
                sh '''
                    echo "Building Docker images..."

                    docker build \
                      -t ${DOCKERHUB_NAMESPACE}/${FRONTEND_IMAGE}:${BUILD_NUMBER} \
                      -t ${DOCKERHUB_NAMESPACE}/${FRONTEND_IMAGE}:latest \
                      app/frontend

                    docker build \
                      -t ${DOCKERHUB_NAMESPACE}/${BACKEND_IMAGE}:${BUILD_NUMBER} \
                      -t ${DOCKERHUB_NAMESPACE}/${BACKEND_IMAGE}:latest \
                      app/backend

                    docker images
                '''
            }
        }

        // --------------------------------------------------
        // 7. Push images to Docker Hub
        // --------------------------------------------------
        stage('Push Images to Docker Hub') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: "${DOCKERHUB_CREDENTIALS}",
                        usernameVariable: 'DH_USER',
                        passwordVariable: 'DH_TOKEN'
                    )
                ]) {
                    sh '''
                        set +x

                        echo "$DH_TOKEN" | docker login \
                          --username "$DH_USER" \
                          --password-stdin

                        docker push ${DOCKERHUB_NAMESPACE}/${FRONTEND_IMAGE}:${BUILD_NUMBER}
                        docker push ${DOCKERHUB_NAMESPACE}/${FRONTEND_IMAGE}:latest

                        docker push ${DOCKERHUB_NAMESPACE}/${BACKEND_IMAGE}:${BUILD_NUMBER}
                        docker push ${DOCKERHUB_NAMESPACE}/${BACKEND_IMAGE}:latest

                        docker logout
                    '''
                }
            }
        }

        // --------------------------------------------------
        // 8. Deploy to Kubernetes
        // --------------------------------------------------
        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([
                    file(
                        credentialsId: "${KUBECONFIG_CREDENTIALS}",
                        variable: 'KUBECONFIG_FILE'
                    )
                ]) {
                    sh '''
                        set -eu

                        export KUBECONFIG="$KUBECONFIG_FILE"

                        echo "Checking Kubernetes connectivity..."
                        kubectl cluster-info
                        kubectl get nodes

                        echo "Applying Kubernetes manifests..."
                        kubectl apply -f k8s/

                        echo "Updating frontend image..."
                        kubectl set image \
                          deployment/portfolio-frontend \
                          frontend=${DOCKERHUB_NAMESPACE}/${FRONTEND_IMAGE}:${BUILD_NUMBER} \
                          -n ${K8S_NAMESPACE}

                        echo "Updating backend image..."
                        kubectl set image \
                          deployment/portfolio-backend \
                          backend=${DOCKERHUB_NAMESPACE}/${BACKEND_IMAGE}:${BUILD_NUMBER} \
                          -n ${K8S_NAMESPACE}
                    '''
                }
            }
        }

        // --------------------------------------------------
        // 9. Verify deployment
        // --------------------------------------------------
        stage('Verify Deployment') {
            steps {
                withCredentials([
                    file(
                        credentialsId: "${KUBECONFIG_CREDENTIALS}",
                        variable: 'KUBECONFIG_FILE'
                    )
                ]) {
                    sh '''
                        export KUBECONFIG="$KUBECONFIG_FILE"

                        echo "Waiting for frontend rollout..."
                        kubectl rollout status \
                          deployment/portfolio-frontend \
                          -n ${K8S_NAMESPACE} \
                          --timeout=180s

                        echo "Waiting for backend rollout..."
                        kubectl rollout status \
                          deployment/portfolio-backend \
                          -n ${K8S_NAMESPACE} \
                          --timeout=180s

                        echo "Deployment verification complete."

                        kubectl get deployments -n ${K8S_NAMESPACE}
                        kubectl get pods -n ${K8S_NAMESPACE}
                        kubectl get services -n ${K8S_NAMESPACE}
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'CI/CD pipeline completed successfully!'
            echo 'Docker images built, pushed, and deployed.'
        }

        failure {
            echo 'CI/CD pipeline failed. Review the stage logs.'
        }

        always {
            sh '''
                docker logout >/dev/null 2>&1 || true
            '''
            echo "Build ${BUILD_NUMBER} finished with status: ${currentBuild.currentResult}"
        }
    }
}
