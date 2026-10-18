# Architecture --- DevOps Portfolio CI/CD Platform

## 1. Overview

This project demonstrates an end-to-end CI/CD workflow for a
containerized portfolio application. The application source code is
maintained separately from the CI/CD configuration. Jenkins builds the
application images, publishes them to Docker Hub, and deploys them to a
Kubernetes cluster running on AWS EC2.

The platform is designed as a practical learning and portfolio project.
It uses a self-managed Kubernetes cluster created with `kubeadm`, with
Calico providing pod networking.

## 2. High-level architecture

![High-level architecture diagram](architecture-diagram.png)

> The diagram shows the intended delivery flow. Actual public
> reachability depends on the EC2 security-group rules and the node
> address used by the browser. The Kubernetes API should be reached
> privately from Jenkins over the VPC.

## 3. AWS infrastructure

The lab uses three EC2 instances in the AWS Mumbai region
(`ap-south-1`).

  ------------------------------------------------------------------------------
  Instance               Role                        Private IP Responsibility
  ---------------------- ---------------- --------------------- ----------------
  `devops-jenkins`       CI/CD server              `10.0.0.152` Runs Jenkins,
                                                                builds container
                                                                images, pushes
                                                                to Docker Hub,
                                                                and invokes
                                                                Kubernetes
                                                                deployments.

  `devops-k8s-control`   Kubernetes                 `10.0.0.14` Hosts the
                         control plane                          Kubernetes API
                                                                server and
                                                                cluster
                                                                control-plane
                                                                components.

  `devops-k8s-worker`    Kubernetes                `10.0.0.188` Runs the
                         worker                                 application
                                                                workloads
                                                                scheduled by
                                                                Kubernetes.
  ------------------------------------------------------------------------------

All three instances are in the same VPC and security group, as
configured for this lab. Security-group rules should follow least
privilege: SSH should be limited to the administrator's trusted source
IP, and Kubernetes control-plane traffic should not be exposed to the
public internet. Jenkins should access the Kubernetes API through the
control plane's private address.

## 4. Application components

### Frontend

-   Built with React and Vite.
-   The frontend Docker image uses a Node.js build stage and an Nginx
    runtime stage.
-   Nginx serves the static frontend files.
-   Nginx routes requests under `/api/` to `http://backend:8080/api/`,
    where `backend` is the Kubernetes Service DNS name.
-   The frontend is exposed through a Kubernetes NodePort Service on
    port `30080` in the current lab configuration.

### Backend

-   Built with Java and Spring Boot using Maven.
-   Packaged as `portfolio-api.jar`.
-   Runs in a container based on a Java 17 runtime image.
-   Exposes application port `8080`.
-   Has a health endpoint at `/api/health`.
-   The backend is exposed internally through a Kubernetes `ClusterIP`
    Service named `backend` on port `8080`.

### Container registry

Docker Hub stores the versioned application images:

-   `manojselvang/portfolio-frontend`
-   `manojselvang/portfolio-backend`

The `latest` tag may be used for convenience during development. CI/CD
deployments should preferably use an immutable tag, such as the Jenkins
build number or a Git commit SHA, so that a deployment can be traced to
a specific build.

## 5. CI/CD workflow

The intended pipeline workflow is:

1.  A developer pushes changes to the application repository or updates
    the CI/CD repository.
2.  Jenkins checks out the CI/CD configuration and application source.
3.  Jenkins builds and tests the Spring Boot backend with Maven.
4.  Jenkins builds the backend and frontend Docker images.
5.  Jenkins authenticates to Docker Hub using a Jenkins-managed
    credential and pushes the images.
6.  Jenkins uses a dedicated Kubernetes ServiceAccount identity to
    update the Kubernetes Deployments.
7.  Kubernetes schedules the workloads and pulls the referenced images
    from Docker Hub.
8.  Jenkins waits for the backend and frontend rollouts to complete.
9.  The pipeline reports success only after the configured verification
    steps pass.

The exact trigger policy (for example, manual build, webhook, or
polling) should be documented when it is configured in Jenkins.

## 6. Kubernetes architecture

The cluster is bootstrapped with `kubeadm` and uses containerd as its
container runtime. Calico provides pod networking.

The cluster includes:

-   **Control plane:** Kubernetes API server, scheduler, controller
    manager, and etcd.
-   **Worker node:** Runs the frontend and backend application Pods.
-   **Deployments:** Manage the desired replica count and rolling
    updates for the application.
-   **Services:** Provide stable network endpoints for the frontend and
    backend.
-   **Calico:** Provides pod networking between cluster workloads.

Current observed application layout:

  -----------------------------------------------------------------------
  Resource                Type                    Purpose
  ----------------------- ----------------------- -----------------------
  `backend`               Deployment              Runs the Spring Boot
                                                  API container.

  `backend`               ClusterIP Service       Makes the API reachable
                                                  inside the cluster on
                                                  port `8080`.

  `frontend`              Deployment              Runs the Nginx-served
                                                  React application.

  `frontend`              NodePort Service        Exposes the frontend on
                                                  node port `30080`.
  -----------------------------------------------------------------------

## 7. Deployment identity and secrets

Jenkins uses a dedicated Kubernetes ServiceAccount named
`portfolio-deployer` and role-based access control (RBAC) rather than
the cluster administrator's kubeconfig.

Sensitive values must not be stored in GitHub. In particular, do not
commit:

-   `jenkins.kubeconfig` or any other kubeconfig containing credentials
-   `/etc/kubernetes/admin.conf`
-   Kubernetes bearer tokens or token Secret data
-   Docker Hub access tokens
-   SSH private keys
-   Jenkins secret files or environment files containing credentials

Store Docker Hub credentials in Jenkins Credentials. Store the
Kubernetes kubeconfig as a Jenkins **Secret file** credential and bind
it only for the pipeline steps that need it. Restrict the ServiceAccount
permissions to the Kubernetes resources and namespaces required for
deployment.

The kubeconfig currently created for the lab points to the control
plane's private API endpoint, `https://10.0.0.14:6443`. Keep this
endpoint private and ensure the Jenkins instance can reach it over the
VPC.

## 8. Network flow

-   **Developer to GitHub:** HTTPS.
-   **Jenkins to GitHub:** HTTPS for repository checkout.
-   **Jenkins to Docker Hub:** HTTPS for registry authentication and
    image push.
-   **Kubernetes nodes to Docker Hub:** HTTPS for image pulls.
-   **Jenkins to Kubernetes API:** HTTPS to the control plane's private
    address on TCP `6443`.
-   **Browser to frontend:** HTTP to a reachable Kubernetes node address
    on NodePort `30080`, if the corresponding security-group rule
    permits it.
-   **Frontend to backend:** Nginx proxy to the `backend` Kubernetes
    Service on TCP `8080`, within the cluster network.

Avoid exposing the Kubernetes API, kubelet port, or broad internal
cluster traffic to the public internet. Open only the required ports
between trusted sources.

## 9. Repository responsibilities

### Application repository --- `manoj-devops-portfolio`

Contains the application code and build configuration, including:

-   React/Vite frontend
-   Spring Boot backend
-   Maven `pom.xml`
-   Frontend and backend Dockerfiles
-   Nginx configuration

### CI/CD repository --- `manoj-devops-portfolio-cicd`

Contains the deployment automation and operational documentation,
including:

-   `Jenkinsfile`
-   `k8s/backend.yaml`
-   `k8s/frontend.yaml`
-   `scripts/validate-manifests.sh`
-   `scripts/verify-deployment.sh`
-   `docs/architecture.md`
-   Jenkins and Kubernetes setup guides

This separation keeps application development independent from the
deployment implementation.

## 10. Operational checks

Useful checks from the control-plane node include:

``` bash
kubectl get nodes -o wide
kubectl get deployments
kubectl get pods -o wide
kubectl get services
kubectl get pods -n kube-system
```

Check rollout status with:

``` bash
kubectl rollout status deployment/backend
kubectl rollout status deployment/frontend
```

Check the backend health endpoint from within the frontend Pod:

``` bash
kubectl exec deployment/frontend -- \
  wget -q -O - http://backend:8080/api/health
```

The health endpoint should return a successful response when the backend
is healthy.

## 11. Current scope

Current project scope:

-   GitHub-based source control
-   Jenkins CI pipeline
-   Maven backend build
-   Docker image builds and Docker Hub publishing
-   `kubeadm` Kubernetes cluster on EC2
-   Calico networking
-   Kubernetes Deployments and Services
-   Jenkins-to-Kubernetes authentication using a restricted identity

Manoj Selvan G
Aspiring DevOps and Cloud Engineer
linkedin/in/manojselvang
manojselvang@gmail.com