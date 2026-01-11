#!/bin/bash

# Add Prometheus annotations to existing services
# Acest script adaugă annotații Prometheus la deployments existente

echo "Configurare servicii existente pentru monitorizare Prometheus..."

# 1. Auth Service
kubectl patch deployment auth-service -p '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/port":"8000","prometheus.io/path":"/metrics"}}}}}'

# 2. Reservation Service  
kubectl patch deployment reservation-service -p '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/port":"8000","prometheus.io/path":"/metrics"}}}}}'

# 3. MySQL Service
kubectl patch deployment mysql -p '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/port":"3306"}}}}}'

echo "✓ Servicii configurate pentru Prometheus scraping"
echo ""
echo "Nota: Pentru a monitoriza metricile aplicației, trebuie să exponezi /metrics endpoint"
echo "      sau să adaugi un sidecar exporter (ex: statsd_exporter, prometheus_client)"
