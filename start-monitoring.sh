#!/bin/bash
# Monitoring Stack Quick Start

set -e

echo "=========================================="
echo "Booking Platform Monitoring Stack"
echo "=========================================="
echo ""

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl."
    exit 1
fi

# Check if cluster is running
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Kubernetes cluster not accessible."
    exit 1
fi

echo "✓ Kubernetes cluster accessible"
echo ""

# Check monitoring namespace and services
echo "=== Checking Monitoring Services ==="
kubectl get svc -n monitoring monitoring-grafana monitoring-kube-prometheus-prometheus -o wide || {
    echo "❌ Monitoring services not found"
    exit 1
}
echo ""

# Start port-forwards
echo "=== Starting Port Forwards ==="
echo "Forwarding Grafana (localhost:3000 -> monitoring-grafana:80)"
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80 >/dev/null 2>&1 &
GRAFANA_PID=$!
sleep 1

echo "Forwarding Prometheus (localhost:9090 -> prometheus:9090)"
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090 >/dev/null 2>&1 &
PROMETHEUS_PID=$!
sleep 1

echo ""
echo "=========================================="
echo "✓ Monitoring Stack Ready!"
echo "=========================================="
echo ""
echo "Access URLs:"
echo "  Grafana:       http://localhost:3000"
echo "  Prometheus:    http://localhost:9090"
echo ""
echo "Login Credentials:"
echo "  Username: admin"
echo "  Password: admin123"
echo ""
echo "Press Ctrl+C to stop port-forwards..."
echo ""

# Cleanup on exit
cleanup() {
    echo ""
    echo "Stopping port-forwards..."
    kill $GRAFANA_PID 2>/dev/null || true
    kill $PROMETHEUS_PID 2>/dev/null || true
    echo "Done!"
}

trap cleanup EXIT

# Keep running
wait
