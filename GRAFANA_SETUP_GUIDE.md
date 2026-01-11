# Grafana Setup & Access Guide

## Pentru Dezvoltator Local

### Pasul 1: Porniți Monitoring Stack
```bash
cd /mnt/d/proiect_cc_new
./start-monitoring.sh
```

**Rezultat:** Port-forward-urile se deschid
```
Port-forwards started in background
Forwarding Grafana (localhost:3000 -> monitoring-grafana:80)
Forwarding Prometheus (localhost:9090 -> prometheus:9090)
```

### Pasul 2: Accesați Grafana Local
```
URL: http://localhost:3000
Username: admin
Password: admin123
```

### Pasul 3: Să Opriți Port-forward-urile
```bash
```

---

## Pentru Alt Dezvoltator

### Prerequisite
- Git
- Docker Desktop sau Minikube instalat
- kubectl instalat

### Pasul 1: Clone Repository
```bash
git clone <repo-url>
cd proiect_cc_new
```

### Pasul 2: Verificați Kubernetes Cluster
```bash
kubectl cluster-info
```

Dacă nu e pornit:
```bash
# Dacă aveți Docker Desktop:
# Activați Kubernetes din Docker Desktop Settings

# Dacă aveți Minikube:
minikube start
```

### Pasul 3: Verificați Namespace-ul Monitoring
```bash
kubectl get ns monitoring
```

Dacă nu există:
```bash
kubectl create namespace monitoring
```

### Pasul 4: Porniți Port-Forward Manual
```bash
# Terminal 1 - Grafana
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:3000

# Terminal 2 - Prometheus (opțional)
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
```

### Pasul 5: Accesați Grafana
```
URL: http://localhost:3000
Username: admin
Password: admin123
```

### Pasul 6: Configurați Prometheus Datasource (dacă nu e deja)

1. **Mergeți la:** Configuration → Data Sources
2. **Click pe:** Prometheus
3. **URL:** `http://localhost:9090`
4. **Click:** Save & Test
5. **Result:** ✓ "Data source is working"

---

## Dacă Port-forward Doesn't Work

### Verificați Status Cluster
```bash
# Check if monitoring namespace exists
kubectl get namespace monitoring

# Check if Grafana pod is running
kubectl get pods -n monitoring

# Check services
kubectl get svc -n monitoring

# Check for errors
kubectl describe pod -n monitoring -l app=monitoring-grafana
```

### Reinstall Monitoring Stack
```bash
# If needed, reinstall everything
kubectl delete namespace monitoring
kubectl create namespace monitoring

# Then run setup script if available
# Or follow manual deployment steps
```

---

## Opțional: Setup Acces Extern (Pentru Producție)

### Metoda 1: Folosiți Ingress

```bash
# 1. Verificați dacă Ingress Controller e activ
kubectl get ingress -A

# 2. Aplicați Ingress config
kubectl apply -f helm/booking-platform/templates/ingress.yaml

# 3. Adăugați în /etc/hosts (Linux/Mac) sau C:\Windows\System32\drivers\etc\hosts (Windows)
127.0.0.1 booking-platform.local

# 4. Accesați via
http://booking-platform.local/grafana
```

### Metoda 2: Expuneți ca LoadBalancer

```bash
# 1. Schimbați service type
kubectl patch svc monitoring-grafana -n monitoring -p '{"spec":{"type":"LoadBalancer"}}'

# 2. Obțineți External IP
kubectl get svc monitoring-grafana -n monitoring

# 3. Accesați via
http://<EXTERNAL-IP>:3000
```

### Metoda 3: Port-Forward Persistent (SSH Tunnel)

**Din server:**
```bash
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:3000 --address=0.0.0.0
```

**Din client (altă mașină):**
```bash
# Visit în browser:
http://server-ip:3000
```

---

## Troubleshooting

### "Connection refused"
```bash
# Verificați dacă port-forward e activ
ps aux | grep "port-forward"

# Restart port-forward
pkill -f "port-forward"
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:3000
```

### "Pod not found"
```bash
# Verificați namespace
kubectl get pods -n monitoring

# Dacă nu există pods, instalați monitoring stack
# Contactați DevOps/Admin pentru deploy
```

### "Can't login"
Credențialele sunt:
- **Username:** admin
- **Password:** admin123

Dacă nu funcționează, resetați:
```bash
kubectl exec -n monitoring deployment/monitoring-grafana -- \
  grafana-cli admin reset-admin-password admin123
```

### "Prometheus datasource not connected"
```bash
# Verificați dacă Prometheus service rulează
kubectl get svc -n monitoring | grep prometheus

# Restart Prometheus
kubectl rollout restart deployment -n monitoring -l app.kubernetes.io/name=prometheus
```

---

## File Structure pentru Reference

```
proiect_cc_new/
├── helm/
│   └── booking-platform/
│       ├── values.yaml          # Configurație Helm
│       ├── templates/
│       │   ├── grafana/         # Grafana manifests
│       │   ├── prometheus/      # Prometheus manifests
│       │   └── metrics-server/  # Metrics Server manifests
│       └── deploy.sh            # Deploy script
├── start-monitoring.sh          # Quick start script
├── GRAFANA_SETUP_GUIDE.md       # This file
└── MONITORING_ACCESS.md         # Detailed access info
```

---

## Commands Summary

| Task | Command |
|------|---------|
| Start monitoring locally | `./start-monitoring.sh` |
| Port-forward Grafana | `kubectl port-forward -n monitoring svc/monitoring-grafana 3000:3000` |
| Port-forward Prometheus | `kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090` |
| Check pods | `kubectl get pods -n monitoring` |
| Check services | `kubectl get svc -n monitoring` |
| View Grafana logs | `kubectl logs -n monitoring -l app=monitoring-grafana` |
| Reset admin password | `kubectl exec -n monitoring deployment/monitoring-grafana -- grafana-cli admin reset-admin-password admin123` |
| Access Grafana API | `curl -u admin:admin123 http://localhost:3000/api/user` |

---

## Support

Dacă aveți probleme:

1. Verificați Kubernetes cluster status
2. Verificați pod-urile din namespace monitoring
3. Revizuiți log-urile pod-urilor
4. Contactați DevOps team

---

**Last Updated:** January 2026
**Grafana Version:** Latest
**Admin User:** admin
**Admin Password:** admin123
