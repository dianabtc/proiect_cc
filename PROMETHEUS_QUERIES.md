# Prometheus Queries for Grafana Dashboards

## Quick Start - Copy & Paste Queries

### 1. POD METRICS

#### Pod Count (Total)
```promql
count(kube_pod_info)
```

### 2. CPU METRICS

#### CPU Usage (Total Cluster)
```promql
sum(rate(container_cpu_usage_seconds_total[5m]))
```

#### CPU Usage per Pod
```promql
sum(rate(container_cpu_usage_seconds_total[5m])) by (pod)
```

#### CPU Usage by Namespace
```promql
sum(rate(container_cpu_usage_seconds_total[5m])) by (namespace)
```

### 3. MEMORY METRICS

#### Memory Usage (Total)
```promql
sum(container_memory_usage_bytes) / 1024 / 1024 / 1024
```
*Result in GB*

#### Memory Usage per Pod (MB)
```promql
sum(container_memory_usage_bytes) by (pod) / 1024 / 1024
```

### 4. DISK METRICS

#### Disk Usage Percentage per Node
```promql
(1 - (node_filesystem_avail_bytes{device!~'by-uuid'} / node_filesystem_size_bytes)) * 100
```


### 5. UPTIME & AVAILABILITY

#### Pod Uptime (Hours)
```promql
(time() - kube_pod_created) / 3600
```


#### Node Uptime (Days)
```promql
(time() - node_boot_time_seconds) / 86400
```
