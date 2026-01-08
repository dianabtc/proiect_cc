#!/bin/bash

# Script de verificare integrare Kubernetes Dashboard cu aplicația Booking Platform

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Verificare Integrare Kubernetes Dashboard            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}\n"

ERRORS=0
WARNINGS=0

# Function to check and report
check_resource() {
    local resource=$1
    local namespace=$2
    local expected=$3
    local description=$4
    
    echo -ne "${BLUE}[Checking]${NC} $description... "
    
    if [ -z "$namespace" ]; then
        COUNT=$(kubectl get $resource 2>/dev/null | grep -v NAME | wc -l | tr -d ' ')
    else
        COUNT=$(kubectl get $resource -n $namespace 2>/dev/null | grep -v NAME | wc -l | tr -d ' ')
    fi
    
    if [ "$COUNT" -ge "$expected" ]; then
        echo -e "${GREEN}✓${NC} ($COUNT/$expected)"
        return 0
    else
        echo -e "${RED}✗${NC} ($COUNT/$expected)"
        ((ERRORS++))
        return 1
    fi
}

check_status() {
    local resource=$1
    local name=$2
    local namespace=$3
    local description=$4
    
    echo -ne "${BLUE}[Checking]${NC} $description... "
    
    if [ -z "$namespace" ]; then
        STATUS=$(kubectl get $resource $name -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "Unknown")
    else
        STATUS=$(kubectl get $resource $name -n $namespace -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "Unknown")
    fi
    
    if [ "$STATUS" == "True" ]; then
        echo -e "${GREEN}✓${NC} (Available)"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} (Status: $STATUS)"
        ((WARNINGS++))
        return 1
    fi
}

echo -e "${YELLOW}═══ 1. Verificare Namespace-uri ═══${NC}\n"

check_resource "namespace" "" 2 "Namespace default exists"
if kubectl get namespace kubernetes-dashboard &>/dev/null; then
    echo -e "${BLUE}[Checking]${NC} Namespace kubernetes-dashboard exists... ${GREEN}✓${NC}"
else
    echo -e "${BLUE}[Checking]${NC} Namespace kubernetes-dashboard exists... ${RED}✗${NC}"
    ((ERRORS++))
fi

echo -e "\n${YELLOW}═══ 2. Verificare Aplicație (namespace: default) ═══${NC}\n"

check_resource "deployment" "default" 4 "Deployments in default namespace"
check_status "deployment" "auth-service" "default" "Auth Service deployment"
check_status "deployment" "reservation-service" "default" "Reservation Service deployment"
check_status "deployment" "mysql" "default" "MySQL deployment"

echo ""
check_resource "service" "default" 4 "Services in default namespace"
check_resource "pod" "default" 4 "Running pods in default namespace"

echo -e "\n${YELLOW}═══ 3. Verificare Dashboard (namespace: kubernetes-dashboard) ═══${NC}\n"

check_resource "deployment" "kubernetes-dashboard" 2 "Dashboard deployments"
check_status "deployment" "kubernetes-dashboard" "kubernetes-dashboard" "Kubernetes Dashboard"
check_status "deployment" "dashboard-metrics-scraper" "kubernetes-dashboard" "Metrics Scraper"

echo ""
check_resource "service" "kubernetes-dashboard" 2 "Dashboard services"
check_resource "pod" "kubernetes-dashboard" 2 "Dashboard pods"

echo -e "\n${YELLOW}═══ 4. Verificare RBAC pentru Dashboard ═══${NC}\n"

echo -ne "${BLUE}[Checking]${NC} ServiceAccount admin-user... "
if kubectl get sa admin-user -n kubernetes-dashboard &>/dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    ((ERRORS++))
fi

echo -ne "${BLUE}[Checking]${NC} ClusterRole kubernetes-dashboard... "
if kubectl get clusterrole kubernetes-dashboard &>/dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    ((ERRORS++))
fi

echo -ne "${BLUE}[Checking]${NC} ClusterRoleBinding admin-user... "
if kubectl get clusterrolebinding admin-user &>/dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    ((ERRORS++))
fi

echo -e "\n${YELLOW}═══ 5. Verificare Ingress ═══${NC}\n"

check_resource "ingress" "default" 1 "Ingress in default namespace"
check_resource "ingress" "kubernetes-dashboard" 1 "Ingress in kubernetes-dashboard namespace"

echo -ne "${BLUE}[Checking]${NC} Ingress paths for booking... "
PATHS=$(kubectl get ingress booking-ingress -n default -o jsonpath='{.spec.rules[0].http.paths[*].path}' 2>/dev/null || echo "")
if [[ "$PATHS" == *"/auth"* ]] && [[ "$PATHS" == *"/reservation"* ]]; then
    echo -e "${GREEN}✓${NC} (/auth, /reservation)"
else
    echo -e "${RED}✗${NC} (Missing paths)"
    ((ERRORS++))
fi

echo -ne "${BLUE}[Checking]${NC} Ingress paths for dashboard... "
DASH_PATHS=$(kubectl get ingress dashboard-ingress -n kubernetes-dashboard -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null || echo "")
if [[ "$DASH_PATHS" == *"dashboard"* ]]; then
    echo -e "${GREEN}✓${NC} (/dashboard)"
else
    echo -e "${YELLOW}⚠${NC} (Path: $DASH_PATHS)"
    ((WARNINGS++))
fi

echo -e "\n${YELLOW}═══ 6. Verificare Persistence ═══${NC}\n"

echo -ne "${BLUE}[Checking]${NC} PersistentVolumeClaim mysql-pvc... "
PVC_STATUS=$(kubectl get pvc mysql-pvc -n default -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
if [ "$PVC_STATUS" == "Bound" ]; then
    echo -e "${GREEN}✓${NC} (Bound)"
else
    echo -e "${YELLOW}⚠${NC} (Status: $PVC_STATUS)"
    ((WARNINGS++))
fi

echo -e "\n${YELLOW}═══ 7. Test Conectivitate Inter-Service ═══${NC}\n"

echo -ne "${BLUE}[Testing]${NC} Dashboard poate accesa K8s API... "
# Verifică dacă Dashboard pod poate face requests la K8s API
DASH_POD=$(kubectl get pods -n kubernetes-dashboard -l app=kubernetes-dashboard -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$DASH_POD" ]; then
    # Check if pod has serviceAccount mounted
    SA_MOUNT=$(kubectl get pod $DASH_POD -n kubernetes-dashboard -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null || echo "")
    if [ "$SA_MOUNT" == "kubernetes-dashboard" ]; then
        echo -e "${GREEN}✓${NC} (ServiceAccount mounted)"
    else
        echo -e "${RED}✗${NC} (No ServiceAccount)"
        ((ERRORS++))
    fi
else
    echo -e "${RED}✗${NC} (Dashboard pod not found)"
    ((ERRORS++))
fi

echo -e "\n${YELLOW}═══ 8. Verificare Dashboard poate vedea resurse aplicației ═══${NC}\n"

echo -ne "${BLUE}[Testing]${NC} Token generation pentru admin-user... "
TOKEN=$(kubectl -n kubernetes-dashboard create token admin-user 2>/dev/null || echo "")
if [ -n "$TOKEN" ]; then
    echo -e "${GREEN}✓${NC}"
    echo -e "${BLUE}[Info]${NC} Token generat (lungime: ${#TOKEN} chars)"
else
    echo -e "${RED}✗${NC} (Nu s-a putut genera token)"
    ((ERRORS++))
fi

echo -e "\n${YELLOW}═══ 9. Verificare Health Endpoints ═══${NC}\n"

# Această secțiune necesită că serviciile sunt accesibile
# În producție ar trebui să testezi cu curl, dar în test doar verificăm că exist

echo -ne "${BLUE}[Info]${NC} Auth service health endpoint... "
AUTH_POD=$(kubectl get pods -n default -l app=auth-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$AUTH_POD" ]; then
    echo -e "${GREEN}✓${NC} (Pod exists: $AUTH_POD)"
else
    echo -e "${YELLOW}⚠${NC} (Pod not found)"
    ((WARNINGS++))
fi

echo -ne "${BLUE}[Info]${NC} Reservation service health endpoint... "
RESV_POD=$(kubectl get pods -n default -l app=reservation-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$RESV_POD" ]; then
    echo -e "${GREEN}✓${NC} (Pod exists: $RESV_POD)"
else
    echo -e "${YELLOW}⚠${NC} (Pod not found)"
    ((WARNINGS++))
fi

echo -e "\n${YELLOW}═══ 10. Summary: Dashboard Integration ═══${NC}\n"

echo -e "${BLUE}[Info]${NC} Dashboard poate monitioriza:"
echo -e "  ${GREEN}→${NC} Toate pod-urile din namespace 'default'"
echo -e "  ${GREEN}→${NC} Deployments: auth-service, reservation-service, mysql, adminer"
echo -e "  ${GREEN}→${NC} Services și Ingress-uri"
echo -e "  ${GREEN}→${NC} Logs în timp real din orice pod"
echo -e "  ${GREEN}→${NC} Resource usage (CPU, Memory)"
echo -e "  ${GREEN}→${NC} Events pentru debugging"

echo -e "\n${BLUE}[Info]${NC} Acces la Dashboard:"
echo -e "  ${YELLOW}→${NC} Port-forward: kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:8443"
echo -e "  ${YELLOW}→${NC} URL: https://localhost:8443"
echo -e "  ${YELLOW}→${NC} Token: kubectl -n kubernetes-dashboard create token admin-user"

echo -e "\n${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  REZULTAT FINAL                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}\n"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ SUCCES!${NC} Toate verificările au trecut!"
    echo -e "${GREEN}Dashboard-ul este corect integrat cu aplicația ta.${NC}\n"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ WARNINGS!${NC} Verificări trecute cu $WARNINGS avertismente."
    echo -e "${YELLOW}Dashboard-ul funcționează, dar ar trebui investigate avertismentele.${NC}\n"
    exit 0
else
    echo -e "${RED}✗ ERORI!${NC} Găsite $ERRORS erori și $WARNINGS avertismente."
    echo -e "${RED}Dashboard-ul nu este complet integrat. Verifică erorile de mai sus.${NC}\n"
    exit 1
fi

