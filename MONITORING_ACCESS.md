# Monitoring Stack Access Guide

## Architecture
The monitoring stack uses the existing **kube-prometheus-stack** Helm chart with:
- **Grafana** (v12.3.1): Dashboards & visualization
- **Prometheus** (v0.87.1): Metrics collection & storage  
- **Metrics Server** (v0.6.3): Kubernetes resource metrics
- **Node Exporter**: Hardware-level metrics
- **kube-state-metrics**: Kubernetes object metrics

## Service Configuration

### Services Created
```
monitoring-grafana              NodePort 80:30301/TCP       ✓ External Access
monitoring-kube-prometheus-prometheus  NodePort 9090:30909/TCP     ✓ External Access
```

### Grafana Admin Credentials
- **Username:** admin
- **Password:** admin123

## Access Methods

### Option 1: Port-Forward (Recommended for Development)
```bash
# Start port-forwards
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80 &
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090 &

# Access:
# Grafana:     http://localhost:3000
# Prometheus:  http://localhost:9090
```

### Option 2: Minikube Service Tunnel
```bash
# Start minikube tunnel (requires separate terminal)
minikube tunnel

# Then access via NodePort:
# Grafana:     http://192.168.49.2:30301
# Prometheus:  http://192.168.49.2:30909
```

### Option 3: kubectl proxy
```bash
# Start proxy
kubectl proxy --port=8888 &

# Grafana:
curl http://localhost:8888/api/v1/namespaces/monitoring/services/monitoring-grafana:80/proxy/

# Prometheus:
curl http://localhost:8888/api/v1/namespaces/monitoring/services/monitoring-kube-prometheus-prometheus:9090/proxy/-/healthy
```

### Option 4: Ingress (If Configured)
```
http://booking-platform.local/grafana
http://booking-platform.local/prometheus
```

## Monitoring Targets

Prometheus scrapes metrics from:
1. **Kubernetes API Server** - api server metrics
2. **Kubernetes Nodes** - node CPU, memory, disk
3. **Kubernetes Pods** - pod resource usage
4. **Services** - service metrics
5. **Metrics Server** - kubelet collected metrics
6. **cAdvisor** - container metrics

## Grafana Dashboards

### Available Dashboards
- **Kubernetes Cluster** - Overall cluster health
- **Kubernetes Pods** - Pod resource usage
- **Prometheus Server** - Prometheus internals
- **Node Exporter** - Node-level metrics

### Default Prometheus Datasource
- **Name:** Prometheus
- **URL:** http://monitoring-kube-prometheus-prometheus:9090
- **Type:** Prometheus
- **Status:** ✓ Connected

## Useful Prometheus Queries

### CPU Usage
```promql
# CPU usage per pod
sum(rate(container_cpu_usage_seconds_total{container!="POD",container!=""}[5m])) by (pod)

# CPU by node
sum(rate(node_cpu_seconds_total[5m])) by (node)
```

### Memory Usage
```promql
# Memory per pod
sum(container_memory_usage_bytes{container!="POD",container!=""}) by (pod)

# Memory by node
node_memory_MemAvailable_bytes
```

### Pod Count
```promql
count(kube_pod_info)
```

### Uptime
```promql
# Pod uptime in hours
(time() - kube_pod_created{pod=~".*"}) / 3600
```

## Verification Checklist

✓ Port-forwards established
✓ Services configured as NodePort
✓ Grafana admin login functional
✓ Prometheus scrape targets active
✓ Metrics Server operational
✓ Storage PVCs bound
✓ RBAC ClusterRoles configured

## Troubleshooting

### Services not accessible
```bash
# Check services
kubectl get svc -n monitoring

# Check pod status
kubectl get pods -n monitoring

# Check logs
kubectl logs -n monitoring deployment/monitoring-grafana
kubectl logs -n monitoring prometheus-monitoring-kube-prometheus-prometheus-0
```

### Metrics not appearing
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
# Visit http://localhost:9090/targets

# Check metrics availability
kubectl exec -n monitoring deployment/monitoring-kube-state-metrics -- curl -s http://localhost:8080/metrics | head -20
```

### Grafana not loading dashboards
```bash
# Check datasource connectivity
kubectl exec -n monitoring deployment/monitoring-grafana -- \
  curl -s http://monitoring-kube-prometheus-prometheus:9090/-/healthy

# Restart Grafana if needed
kubectl rollout restart deployment/monitoring-grafana -n monitoring
```

## Storage

### PersistentVolumes
- **Grafana Storage:** 5Gi (configuration & dashboards)
- **Prometheus Storage:** 10Gi (metrics data, 30-day retention)
- **StorageClass:** default

### Verify Storage
```bash
kubectl get pvc -n monitoring
kubectl get pv -n monitoring
```

## Metrics Retention

- **Prometheus:** 30 days
- **Scrape Interval:** 30 seconds
- **Evaluation Interval:** 30 seconds

## Next Steps

1. Access Grafana via port-forward
2. Login with admin/admin123
3. Verify Prometheus datasource connection
4. Browse pre-configured dashboards
5. Create custom dashboards as needed

---
**Last Updated:** 2024
**Helm Chart:** kube-prometheus-stack v80.13.3
