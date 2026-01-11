Bolocan Crina
Butacu Diana
Georgescu Andreea

# 1. Create cluster (make sure Docker is running)
minikube start

1.1 Create alias for commands
alias kubectl="minikube kubectl --"
echo 'alias kubectl="minikube kubectl --"' >> ~/.bashrc
source ~/.bashrc

1.2 Test cluster was created
kubectl get nodes

# 2. Enable Ingress in cluster
minikube addons enable ingress

# 3. Enter Minikube's Docker environment
eval $(minikube docker-env)

# 4. Build Auth Service Docker Image
cd auth-service
docker build -t auth-service:latest .

# 5. Build Reservation Service Docker Image
cd reservation-service
docker build -t reservation-service:latest .

# 6. Install application using Helm (first time)
cd ../proiect_cc
helm install booking ./helm/booking-platform
helm list -A

6.1 Upgrade application with Helm
helm upgrade booking ./helm/booking-platform

6.2 Uninstall application with Helm
helm uninstall booking

6.3 Check everything is up and running
kubectl get pods -A
kubectl get svc -A
kubectl get pvc -A

### 7. Access microservices:

# A. Authentication and Reservaton Service (with Ingress)
Start tunnel: minikube tunnel
Check in browser: localhost/auth/docs and localhost/reservation/docs

# B. Adminer (with NodePort)
Run: minikube service adminer
Access in browser
Authenticate with credentials:
- server: mysql
- user: root
- password:

# C. MySQL database (internally)
kubectl exec -it deployment/mysql -- mysql -u root -p



## Commands to restart deployments:
kubectl rollout restart deployment auth-service
kubectl rollout restart deployment reservation-service
