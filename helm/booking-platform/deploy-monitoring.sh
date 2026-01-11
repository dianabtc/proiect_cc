#!/bin/bash

# Monitoring Stack Deployment Script
# Deploy complet de Metrics Server, Prometheus și Grafana

set -e

NAMESPACE_MONITORING="monitoring"
NAMESPACE_KUBE_SYSTEM="kube-system"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

echo "=========================================="
echo "Booking Platform - Monitoring Stack Setup"
echo "=========================================="

# Step 1: Create namespace
echo -e "\n[1/5] Crearea namespace monitoring..."
kubectl create namespace $NAMESPACE_MONITORING --dry-run=client -o yaml | kubectl apply -f -
echo "✓ Namespace monitoring creat"

# Step 2: Deploy Metrics Server
echo -e "\n[2/5] Instalare Metrics Server..."
kubectl apply -f "$TEMPLATES_DIR/metrics-server/"
echo "✓ Metrics Server instalat"
echo "  - Așteptă pod să fie Ready..."
kubectl rollout status deployment/metrics-server -n $NAMESPACE_KUBE_SYSTEM --timeout=2m

# Step 3: Deploy Prometheus
echo -e "\n[3/5] Instalare Prometheus..."
kubectl apply -f "$TEMPLATES_DIR/prometheus/"
echo "✓ Prometheus instalat"
echo "  - Așteptă pod să fie Ready..."
kubectl rollout status deployment/prometheus -n $NAMESPACE_MONITORING --timeout=2m

# Step 4: Deploy Grafana
echo -e "\n[4/5] Instalare Grafana..."
kubectl apply -f "$TEMPLATES_DIR/grafana/"
echo "✓ Grafana instalat"
echo "  - Așteptă pod să fie Ready..."
kubectl rollout status deployment/grafana -n $NAMESPACE_MONITORING --timeout=2m

# Step 5: Deploy Ingress
echo -e "\n[5/5] Actualizare Ingress..."
kubectl apply -f "$TEMPLATES_DIR/ingress.yaml"
echo "✓ Ingress actualizat"

# Final status
echo -e "\n=========================================="
echo "Monitoring Stack Status"
echo "=========================================="

echo -e "\n📊 Metrics Server (kube-system):"
kubectl get deployment -n $NAMESPACE_KUBE_SYSTEM metrics-server

echo -e "\n📈 Prometheus (monitoring):"
kubectl get deployment,svc -n $NAMESPACE_MONITORING -l app=prometheus

echo -e "\n📉 Grafana (monitoring):"
kubectl get deployment,svc -n $NAMESPACE_MONITORING -l app=grafana

echo -e "\n💾 Storage (PVCs):"
kubectl get pvc -n $NAMESPACE_MONITORING

echo -e "\n🌐 Services & NodePorts:"
kubectl get svc -n $NAMESPACE_MONITORING

echo -e "\n=========================================="
echo "Acces Servicii"
echo "=========================================="

PROMETHEUS_NODEPORT=$(kubectl get svc -n $NAMESPACE_MONITORING prometheus -o jsonpath='{.spec.ports[0].port}')
GRAFANA_NODEPORT=$(kubectl get svc -n $NAMESPACE_MONITORING grafana -o jsonpath='{.spec.ports[0].nodePort}')

echo -e "\n✅ Servicii pornite cu succes!\n"
echo "Acces local (port-forward):"
echo "  Prometheus: kubectl port-forward -n $NAMESPACE_MONITORING svc/prometheus 9090:9090"
echo "  Grafana:    kubectl port-forward -n $NAMESPACE_MONITORING svc/grafana 3000:3000"
echo ""
echo "Acces via NodePort:"
echo "  Prometheus: http://localhost:30909"
echo "  Grafana:    http://localhost:$GRAFANA_NODEPORT"
echo "  (Schimbă localhost cu IP-ul nodului dacă accesezi din alt calculator)"
echo ""
echo "Credențiale Grafana:"
echo "  Username: admin"
echo "  Password: admin123"
echo ""
echo "Documentație: MONITORING_SETUP.md"
echo "=========================================="
