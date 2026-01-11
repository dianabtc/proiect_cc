#!/bin/bash

# Verification script for monitoring stack deployment

set -e

NAMESPACE_MONITORING="monitoring"
NAMESPACE_KUBE_SYSTEM="kube-system"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================================"
echo "   Monitoring Stack Verification"
echo "================================================"

# Function to check resource
check_resource() {
    local resource=$1
    local namespace=$2
    local name=$3
    
    if kubectl get $resource $name -n $namespace &> /dev/null; then
        echo -e "${GREEN}✓${NC} $resource/$name"
        return 0
    else
        echo -e "${RED}✗${NC} $resource/$name"
        return 1
    fi
}

# Function to check pod status
check_pod_ready() {
    local name=$1
    local namespace=$2
    
    READY=$(kubectl get deployment $name -n $namespace -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    DESIRED=$(kubectl get deployment $name -n $namespace -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    
    if [ "$READY" == "$DESIRED" ] && [ "$DESIRED" != "0" ]; then
        echo -e "${GREEN}✓${NC} $name ($READY/$DESIRED ready)"
        return 0
    else
        echo -e "${YELLOW}⏳${NC} $name ($READY/$DESIRED ready)"
        return 1
    fi
}

# Check Metrics Server
echo -e "\n${YELLOW}[Metrics Server - kube-system]${NC}"
check_pod_ready "metrics-server" "$NAMESPACE_KUBE_SYSTEM"

# Check Prometheus
echo -e "\n${YELLOW}[Prometheus - monitoring]${NC}"
check_resource "namespace" $NAMESPACE_MONITORING "monitoring" || true
check_pod_ready "prometheus" "$NAMESPACE_MONITORING"

# Check Grafana
echo -e "\n${YELLOW}[Grafana - monitoring]${NC}"
check_pod_ready "grafana" "$NAMESPACE_MONITORING"

# Check Services
echo -e "\n${YELLOW}[Services]${NC}"
kubectl get svc -n $NAMESPACE_MONITORING 2>/dev/null | tail -n +2 | while read line; do
    SERVICE=$(echo $line | awk '{print $1}')
    echo -e "${GREEN}✓${NC} Service: $SERVICE"
done

# Check PVCs
echo -e "\n${YELLOW}[Storage (PVCs)]${NC}"
kubectl get pvc -n $NAMESPACE_MONITORING 2>/dev/null | tail -n +2 | while read line; do
    PVC=$(echo $line | awk '{print $1}')
    STATUS=$(echo $line | awk '{print $2}')
    if [ "$STATUS" == "Bound" ]; then
        echo -e "${GREEN}✓${NC} PVC: $PVC ($STATUS)"
    else
        echo -e "${YELLOW}⏳${NC} PVC: $PVC ($STATUS)"
    fi
done

# Check Node Resources
echo -e "\n${YELLOW}[Node Resources Available]${NC}"
if kubectl top nodes &> /dev/null; then
    kubectl top nodes
else
    echo -e "${YELLOW}⏳${NC} Metrics Server nu a colectat date încă (așteptare 1-2 min)"
fi

# Endpoints check
echo -e "\n${YELLOW}[Prometheus Targets]${NC}"
PROMETHEUS_POD=$(kubectl get pod -n $NAMESPACE_MONITORING -l app=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ ! -z "$PROMETHEUS_POD" ]; then
    TARGETS=$(kubectl exec -n $NAMESPACE_MONITORING $PROMETHEUS_POD -- \
        curl -s http://localhost:9090/api/v1/targets 2>/dev/null | grep -o '"labels"' | wc -l)
    if [ $TARGETS -gt 0 ]; then
        echo -e "${GREEN}✓${NC} Prometheus vizualizează $TARGETS targets"
    else
        echo -e "${YELLOW}⏳${NC} Prometheus încă colectează targets"
    fi
else
    echo -e "${RED}✗${NC} Prometheus pod nu găsit"
fi

# Connectivity check
echo -e "\n${YELLOW}[Connectivity Test]${NC}"
PROMETHEUS_POD=$(kubectl get pod -n $NAMESPACE_MONITORING -l app=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ ! -z "$PROMETHEUS_POD" ]; then
    if kubectl exec -n $NAMESPACE_MONITORING $PROMETHEUS_POD -- \
        curl -s http://prometheus:9090/-/healthy &> /dev/null; then
        echo -e "${GREEN}✓${NC} Prometheus health check: OK"
    else
        echo -e "${RED}✗${NC} Prometheus health check: FAILED"
    fi
fi

# Grafana connectivity
GRAFANA_POD=$(kubectl get pod -n $NAMESPACE_MONITORING -l app=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ ! -z "$GRAFANA_POD" ]; then
    if kubectl exec -n $NAMESPACE_MONITORING $GRAFANA_POD -- \
        curl -s http://localhost:3000/api/health &> /dev/null; then
        echo -e "${GREEN}✓${NC} Grafana health check: OK"
    else
        echo -e "${RED}✗${NC} Grafana health check: FAILED"
    fi
fi

# Final summary
echo -e "\n================================================"
echo "              Verification Summary"
echo "================================================"

METRICS_READY=$(kubectl get deployment metrics-server -n $NAMESPACE_KUBE_SYSTEM -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
PROMETHEUS_READY=$(kubectl get deployment prometheus -n $NAMESPACE_MONITORING -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
GRAFANA_READY=$(kubectl get deployment grafana -n $NAMESPACE_MONITORING -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

if [ "$METRICS_READY" == "1" ] && [ "$PROMETHEUS_READY" == "1" ] && [ "$GRAFANA_READY" == "1" ]; then
    echo -e "${GREEN}✓ Monitoring stack fully operational!${NC}"
    echo ""
    echo "Acces:"
    echo "  Prometheus: kubectl port-forward -n $NAMESPACE_MONITORING svc/prometheus 9090:9090"
    echo "  Grafana:    kubectl port-forward -n $NAMESPACE_MONITORING svc/grafana 3000:3000"
    echo ""
    echo "Apoi vizitează:"
    echo "  Prometheus: http://localhost:9090"
    echo "  Grafana:    http://localhost:3000 (admin / admin123)"
else
    echo -e "${YELLOW}⏳ Monitoring stack starting...${NC}"
    echo "Metrics Server: $METRICS_READY/1"
    echo "Prometheus:     $PROMETHEUS_READY/1"
    echo "Grafana:        $GRAFANA_READY/1"
    echo ""
    echo "Așteptă 1-2 minute și relanseaza verificarea"
fi

echo "================================================"
