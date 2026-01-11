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

### 8. Monitoring Stack (Grafana + Prometheus)

# 8.1 Start Monitoring (Quick Start)
./start-monitoring.sh
# This will port-forward both Grafana and Prometheus

# 8.2 Access Grafana
URL: http://localhost:3000
Username: admin
Password: admin123

# 8.3 Access Prometheus
URL: http://localhost:9090

# 8.4 Manually start port-forwards (if not using start-monitoring.sh)
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:3000
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090

# 8.5 Check monitoring pods
kubectl get pods -n monitoring

# 8.6 Create Grafana Dashboard with Prometheus queries
See PROMETHEUS_QUERIES.md for sample queries
Use queries like:
- Pod count: count(kube_pod_info)
- CPU usage: sum(rate(container_cpu_usage_seconds_total[5m]))
- Memory usage: sum(container_memory_usage_bytes) / 1024 / 1024 / 1024



## Commands to restart deployments:
kubectl rollout restart deployment auth-service
kubectl rollout restart deployment reservation-service
kubectl rollout restart deployment monitoring-grafana -n monitoring
kubectl rollout restart deployment monitoring-kube-prometheus-operator -n monitoring
