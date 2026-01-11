#!/bin/bash

# Monitoring - Dashboard Access Guide
# Ghid rapid pentru accesare dashboard-uri

echo "=========================================="
echo "📊  - Monitoring Dashboard Access"
echo "=========================================="

echo -e "\n✅ MONITORING STACK STATUS:"
kubectl get all -n monitoring -o wide

echo -e "\n=========================================="
echo "🌐 ACCES DASHBOARDS"
echo "=========================================="

echo -e "\n📊 PROMETHEUS:"
echo "  - ClusterIP Service: prometheus:9090 (din cluster)"
echo "  - NodePort: http://localhost:30909"
echo "  - Port-Forward:"
echo "    kubectl port-forward -n monitoring svc/prometheus 9091:9090 &"
echo "    Open: http://localhost:9091"
echo ""
echo "  🔍 Targets check:"
echo "    http://localhost:9091/targets"
echo "  📈 Queries:"
echo "    http://localhost:9091/graph"

echo -e "\n📈 GRAFANA:"
echo "  - ClusterIP Service: grafana:3000 (din cluster)"
echo "  - NodePort: http://localhost:30301"
echo "  - Port-Forward:"
echo "    kubectl port-forward -n monitoring svc/grafana 3000:3000 &"
echo "    Open: http://localhost:3000"
echo ""
echo "  🔐 Credentials:"
echo "    Username: admin"
echo "    Password: admin123"
echo ""
echo "  📊 Dashboards Available:"
echo "    - Booking Platform - Advanced Metrics (main)"
echo "    - Booking Platform (basic)"

echo -e "\n=========================================="
echo "🚀 QUICK START - RECOMMENDED"
echo "=========================================="

echo -e "\n# Terminal 1: Prometheus"
echo "kubectl port-forward -n monitoring svc/prometheus 9091:9090"
echo "# Then open: http://localhost:9091"

echo -e "\n# Terminal 2: Grafana"
echo "kubectl port-forward -n monitoring svc/grafana 3000:3000"
echo "# Then open: http://localhost:3000"

echo -e "\n=========================================="
echo "📋 VERIFICARE COMPONENTE"
echo "=========================================="

# Check Metrics Server
METRICS_SERVER=$(kubectl get deployment -n kube-system metrics-server -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "$METRICS_SERVER" == "1" ]; then
  echo "✅ Metrics Server: READY"
else
  echo "❌ Metrics Server: NOT READY"
fi

# Check Prometheus
PROMETHEUS=$(kubectl get deployment -n monitoring prometheus -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "$PROMETHEUS" == "1" ]; then
  echo "✅ Prometheus: READY"
else
  echo "❌ Prometheus: NOT READY"
fi

# Check Grafana
GRAFANA=$(kubectl get deployment -n monitoring grafana -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "$GRAFANA" == "1" ]; then
  echo "✅ Grafana: READY"
else
  echo "❌ Grafana: NOT READY"
fi

echo -e "\n=========================================="
echo "💡 TIPS"
echo "=========================================="

echo -e "\n1. Check metrics availability:"
echo "   kubectl top nodes"
echo "   kubectl top pods -A"

echo -e "\n2. Prometheus scrape targets:"
echo "   curl http://localhost:9091/api/v1/targets 2>/dev/null | jq '.data.activeTargets'"

echo -e "\n3. Grafana datasources:"
echo "   kubectl exec -n monitoring deployment/grafana -- \\"
echo "     curl -s http://admin:admin123@localhost:3000/api/datasources | jq ."

echo -e "\n4. Test Prometheus query:"
echo "   curl 'http://localhost:9091/api/v1/query?query=up' 2>/dev/null | jq '.data.result'"

echo -e "\n=========================================="
echo "📚 DOCUMENTATION"
echo "=========================================="
echo "- LAB5_MONITORING.md"
echo "- MONITORING_SETUP.md"
echo "- PROMETHEUS_INTEGRATION.md"
echo "==========================================="
