#!/bin/bash

# Script pentru deployment complet al aplicației Booking Platform cu Kubernetes Dashboard

set -e

echo "🚀 Deploying Booking Platform cu Kubernetes Dashboard..."

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Verifică dacă Helm este instalat
echo -e "${BLUE}📦 Verificare Helm...${NC}"
if ! command -v helm &> /dev/null; then
    echo -e "${YELLOW}❌ Helm nu este instalat. Instalează Helm mai întâi.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Helm găsit${NC}"

# Step 2: Build Docker images (dacă este necesar)
echo -e "${BLUE}🐳 Build Docker images...${NC}"
read -p "Dorești să rebuild imaginile Docker? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    CURRENT_DIR=$(pwd)
    
    cd ../../auth-service
    docker build -t auth-service:latest .
    
    cd ../reservation-service
    docker build -t reservation-service:latest .
    
    cd "$CURRENT_DIR"
    echo -e "${GREEN}✅ Docker images built${NC}"
else
    echo -e "${YELLOW}⏭️  Skipping Docker build${NC}"
fi

# Step 3: Deploy cu Helm
echo -e "${BLUE}☸️  Deploying cu Helm...${NC}"
helm upgrade --install booking-platform . \
    --namespace default \
    --create-namespace \
    --wait \
    --timeout 5m

echo -e "${GREEN}✅ Helm deployment complet${NC}"

# Step 4: Verificare resurse
echo -e "${BLUE}🔍 Verificare resurse...${NC}"
sleep 5

echo -e "\n${BLUE}📊 Pods în namespace default:${NC}"
kubectl get pods -n default

echo -e "\n${BLUE}📊 Pods în namespace kubernetes-dashboard:${NC}"
kubectl get pods -n kubernetes-dashboard

echo -e "\n${BLUE}📊 Services:${NC}"
kubectl get svc -n default
kubectl get svc -n kubernetes-dashboard

echo -e "\n${BLUE}📊 Ingress:${NC}"
kubectl get ingress

# Step 5: Așteaptă ca toate pod-urile să fie ready
echo -e "\n${BLUE}⏳ Așteptare pod-uri ready...${NC}"
kubectl wait --for=condition=ready pod --all -n default --timeout=300s
kubectl wait --for=condition=ready pod --all -n kubernetes-dashboard --timeout=300s

echo -e "\n${GREEN}✅ Toate pod-urile sunt ready!${NC}"

# Step 6: Obține Dashboard Token
echo -e "\n${BLUE}🔐 Generare token pentru Kubernetes Dashboard...${NC}"
sleep 2

DASHBOARD_TOKEN=$(kubectl -n kubernetes-dashboard create token admin-user 2>/dev/null || echo "")

if [ -z "$DASHBOARD_TOKEN" ]; then
    echo -e "${YELLOW}⚠️  Nu s-a putut genera token automat${NC}"
    echo -e "${YELLOW}Rulează manual: kubectl -n kubernetes-dashboard create token admin-user${NC}"
else
    echo -e "${GREEN}✅ Dashboard Token:${NC}"
    echo -e "${YELLOW}${DASHBOARD_TOKEN}${NC}"
    echo ""
    echo -e "${BLUE}💾 Token salvat în dashboard-token.txt${NC}"
    echo "$DASHBOARD_TOKEN" > dashboard-token.txt
fi

# Step 7: Instrucțiuni de acces
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 DEPLOYMENT COMPLET!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${BLUE}📋 Servicii disponibile:${NC}"
echo -e "  • Auth Service: /auth"
echo -e "  • Reservation Service: /reservation"
echo -e "  • Kubernetes Dashboard: /dashboard"
echo -e "  • Adminer (DB Admin): NodePort"

echo -e "\n${BLUE}🌐 Acces la Kubernetes Dashboard:${NC}"
echo -e "  1. Port-forward:"
echo -e "     ${YELLOW}kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:8443${NC}"
echo -e "     Apoi accesează: ${YELLOW}https://localhost:8443${NC}"
echo -e ""
echo -e "  2. Prin Ingress (dacă este configurat):"
echo -e "     ${YELLOW}https://<your-domain>/dashboard${NC}"

echo -e "\n${BLUE}🔑 Autentificare Dashboard:${NC}"
echo -e "  • Selectează 'Token' ca metodă de autentificare"
echo -e "  • Folosește token-ul de mai sus (sau din dashboard-token.txt)"

echo -e "\n${BLUE}📚 Pentru mai multe detalii:${NC}"
echo -e "  • Citește: ${YELLOW}KUBERNETES_DASHBOARD.md${NC}"

echo -e "\n${BLUE}🛠️  Comenzi utile:${NC}"
echo -e "  • Logs: ${YELLOW}kubectl logs -f <pod-name>${NC}"
echo -e "  • Shell în pod: ${YELLOW}kubectl exec -it <pod-name> -- /bin/bash${NC}"
echo -e "  • Restart deployment: ${YELLOW}kubectl rollout restart deployment/<name>${NC}"

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Step 8: Întreabă dacă vrea să pornească port-forward
read -p "Dorești să pornești port-forward pentru Dashboard acum? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}🚀 Starting port-forward...${NC}"
    echo -e "${YELLOW}Dashboard va fi disponibil la: https://localhost:8443${NC}"
    echo -e "${YELLOW}Pentru a opri, apasă Ctrl+C${NC}\n"
    kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:8443
fi

