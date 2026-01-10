# 🎟️ Booking Platform - Platformă de Rezervare Săli Evenimente

Proiect **Cloud Computing** - Platformă de rezervare online pentru săli de evenimente implementată cu arhitectură de microservicii pe Kubernetes.

---

## 📋 Descriere

Aplicație web pentru gestionarea rezervărilor de săli evenimente cu sistem de autentificare și autorizare bazat pe roluri (USER/ADMIN).

### Business Logic

**Roluri și Permisiuni:**
- **USER**: Creează rezervări proprii, vede doar rezervările proprii
- **ADMIN**: Gestionează săli (CRUD), vede și anulează orice rezervare

**Funcționalități Cheie:**
1. **Gestionare Săli** - ADMIN poate crea/edita/șterge săli
2. **Rezervări cu Validare** - Sistem automat de detectare conflicte temporale
3. **Autentificare JWT** - Token-based authentication securizat
4. **Autorizare pe Roluri** - RBAC la nivel de endpoint
5. **Management Cluster** - Kubernetes Dashboard pentru monitorizare

---

## 🏗️ Arhitectură

```
┌─────────────────────────────────────────────────────┐
│              NGINX Ingress Controller                │
│    /auth  |  /reservation  |  /dashboard            │
└────────┬─────────────┬──────────────┬───────────────┘
         │             │              │
    ┌────▼────┐   ┌────▼────┐   ┌────▼──────────┐
    │  Auth   │   │Reserv.  │   │  Kubernetes   │
    │ Service │──▶│ Service │   │  Dashboard    │
    └────┬────┘   └────┬────┘   └───────────────┘
         │             │
         └──────┬──────┘
                │
         ┌──────▼──────┐
         │   MySQL 8   │
         │  + Adminer  │
         └─────────────┘
```

### Componente

| Componentă | Tehnologie | Port | Rol |
|------------|------------|------|-----|
| **Auth Service** | FastAPI | 8000 | Autentificare JWT |
| **Reservation Service** | FastAPI | 8000 | Logică business |
| **MySQL** | MySQL 8 | 3306 | Persistență date |
| **Adminer** | Adminer | 8080 | Admin DB (NodePort) |
| **Kubernetes Dashboard** | Official K8s UI | 8443 | Management cluster |

**📚 Pentru arhitectură detaliată, flow-uri și explicații complete:** → **[ARCHITECTURE.md](ARCHITECTURE.md)**

---

## 🚀 Quick Start

### Prerequisites

```bash
# Verifică instalări necesare
docker --version          # Docker 20+
kubectl version          # Kubernetes 1.24+
helm version            # Helm 3.x
```

### Deployment

#### Metoda 1: Script Automat (Recomandat) ⭐

```bash
cd helm/booking-platform
./deploy.sh
```

Script-ul va:
- ✅ Build Docker images (opțional)
- ✅ Deploy toate serviciile cu Helm
- ✅ Aștepta ca pod-urile să fie ready
- ✅ Genera token pentru Dashboard
- ✅ Oferi opțiunea de port-forward automat

#### Metoda 2: Manual

```bash
# 1. Build imagini
cd auth-service
docker build -t auth-service:latest .

cd ../reservation-service
docker build -t reservation-service:latest .

# 2. Deploy cu Helm
cd ../helm/booking-platform
helm upgrade --install booking-platform . --namespace default --create-namespace

# 3. Verificare
kubectl get pods
kubectl get svc
```

### Verificare Deployment

```bash
# Check toate resursele
kubectl get pods                          # Aplicația
kubectl get pods -n kubernetes-dashboard  # Dashboard

# Run verification script
cd helm/booking-platform
./verify-integration.sh
```

---

## 🌐 Acces la Servicii

### API Services

```bash
# Register user
curl -X POST http://localhost/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username": "test", "password": "test123"}'

# Login (get JWT token)
curl -X POST http://localhost/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "test", "password": "test123"}'
# Response: {"access_token": "eyJ..."}

# List halls (public)
curl http://localhost/reservation/halls

# Create reservation (authenticated)
curl -X POST http://localhost/reservation/reservations \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "hall_id": 1,
    "date": "2026-01-25",
    "start_time": "14:00",
    "end_time": "16:00"
  }'
```

### Kubernetes Dashboard 📊

**Dashboard oferă vizualizare completă asupra clusterului:**

```bash
# 1. Get authentication token
kubectl -n kubernetes-dashboard create token admin-user

# 2. Port forward (acces local)
kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:8443

# 3. Accesează în browser
open https://localhost:8443

# 4. Login cu token-ul generat
```

**Ce poți face în Dashboard:**
- ✅ Vezi toate pod-urile, deployments, services
- ✅ Monitorizează CPU/Memory în timp real
- ✅ Accesezi logs din orice container
- ✅ Scale deployments (change replicas)
- ✅ Restart pods, debug evenimente
- ✅ Vizualizează PVC, ConfigMaps, Secrets

---

## 📁 Structură Proiect

```
proiect_cc/
├── auth-service/              # Microserviciu autentificare
│   ├── app/                   # Cod FastAPI
│   ├── Dockerfile
│   └── requirements.txt
│
├── reservation-service/       # Microserviciu rezervări
│   ├── app/                   # Cod FastAPI
│   ├── Dockerfile
│   └── requirements.txt
│
├── helm/booking-platform/     # Helm chart
│   ├── Chart.yaml
│   ├── values.yaml           # Configurări centrale
│   ├── deploy.sh             # Script deployment
│   ├── verify-integration.sh # Script verificare
│   └── templates/
│       ├── auth/             # K8s manifests Auth
│       ├── reservation/      # K8s manifests Reservation
│       ├── mysql/            # K8s manifests MySQL
│       ├── adminer/          # K8s manifests Adminer
│       ├── dashboard/        # K8s manifests Dashboard (10 files)
│       └── ingress.yaml      # Routing extern
│
├── README.md                 # Acest fișier
└── ARCHITECTURE.md          # 📚 Documentație tehnică completă
```

---

## 🔑 API Endpoints

### Auth Service (`/auth`)

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/auth/register` | Înregistrare utilizator nou | - |
| POST | `/auth/login` | Login, returnează JWT token | - |
| GET | `/auth/validate` | Validare token (inter-service) | Bearer |

### Reservation Service (`/reservation`)

| Method | Endpoint | Description | Auth | Role |
|--------|----------|-------------|------|------|
| GET | `/reservation/halls` | Listează săli | - | PUBLIC |
| POST | `/reservation/halls` | Creează sală | Bearer | ADMIN |
| PATCH | `/reservation/halls/{id}` | Editează sală | Bearer | ADMIN |
| DELETE | `/reservation/halls/{id}` | Șterge sală | Bearer | ADMIN |
| GET | `/reservation/availability` | Verifică disponibilitate | - | PUBLIC |
| POST | `/reservation/reservations` | Creează rezervare | Bearer | USER |
| GET | `/reservation/reservations` | Listează rezervări (proprii/toate) | Bearer | USER/ADMIN |
| POST | `/reservation/reservations/{id}/cancel` | Anulează rezervare | Bearer | USER/ADMIN |

---

## 🛠️ Configurare și Management

### Environment Variables

Configurate în `values.yaml`:

```yaml
auth:
  env:
    databaseUrl: mysql+pymysql://root:password@mysql:3306/auth_db

reservation:
  env:
    databaseUrl: mysql+pymysql://root:password@mysql:3306/reservation_db
    authServiceUrl: http://auth-service:8000/auth

dashboard:
  service:
    type: ClusterIP  # Sau NodePort pentru acces direct
    port: 8443
```

### Scaling

```bash
# Scale la nivel de deployment
kubectl scale deployment auth-service --replicas=3

# Sau modifică în values.yaml și upgrade
helm upgrade booking-platform . --set auth.replicaCount=3
```

### Logs și Monitoring

```bash
# Logs din servicii
kubectl logs -f deployment/auth-service
kubectl logs -f deployment/reservation-service

# Logs Dashboard
kubectl logs -f -n kubernetes-dashboard deployment/kubernetes-dashboard

# Events (debugging)
kubectl get events --sort-by='.lastTimestamp'

# Resource usage
kubectl top nodes
kubectl top pods
```

---

## 🐛 Troubleshooting

### Probleme Comune

**Pods nu pornesc:**
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

**Database connection failed:**
```bash
kubectl logs deployment/mysql
kubectl exec -it deployment/mysql -- mysql -u root -ppassword -e "SHOW DATABASES;"
```

**Ingress nu funcționează:**
```bash
kubectl get ingress -A
kubectl describe ingress booking-ingress

# Enable Ingress în minikube
minikube addons enable ingress
```

**Dashboard token expirat:**
```bash
kubectl -n kubernetes-dashboard create token admin-user
```

**📚 Pentru troubleshooting detaliat:** → **[ARCHITECTURE.md](ARCHITECTURE.md#troubleshooting)**

---

## 🔒 Securitate

### Măsuri de Securitate Implementate

- ✅ **Password Hashing**: bcrypt pentru passwords
- ✅ **JWT Authentication**: Token-based auth cu expirare
- ✅ **RBAC**: Role-Based Access Control la nivel de endpoint
- ✅ **Kubernetes RBAC**: ServiceAccounts cu permisiuni limitate
- ✅ **HTTPS**: Dashboard folosește HTTPS cu certificat auto-generat
- ✅ **Token Expiration**: JWT tokens expiră după 24h

### ⚠️ Pentru Producție

```bash
# 1. Schimbă credențiale MySQL
kubectl create secret generic mysql-credentials \
  --from-literal=root-password=$(openssl rand -base64 20)

# 2. Folosește Secrets pentru JWT
kubectl create secret generic jwt-secret \
  --from-literal=key=$(openssl rand -base64 32)

# 3. Configurează TLS pentru Ingress
# 4. Limitează RBAC permissions pentru Dashboard
# 5. Enable Network Policies
```

---

## 📊 Features Proiect

### ✅ Implementat

- [x] Arhitectură Microservicii
- [x] Containerizare cu Docker
- [x] Orchestrare cu Kubernetes
- [x] Helm Charts pentru deployment
- [x] JWT Authentication
- [x] Role-Based Access Control (RBAC)
- [x] Database Persistence (MySQL + PVC)
- [x] Ingress Routing (NGINX)
- [x] **Kubernetes Dashboard** - Microserviciu utilitar grafic
- [x] Metrics Scraper pentru Dashboard
- [x] Health Checks pentru toate serviciile
- [x] DB Admin UI (Adminer)
- [x] Documentație completă

### 🎯 Demonstrează

- Cloud-Native architecture
- Service Discovery automat
- Horizontal scaling ready
- Persistent storage
- Secret management
- Infrastructure as Code (IaC)
- Observability și monitoring

---

## 📚 Documentație Completă

### **[→ ARCHITECTURE.md](ARCHITECTURE.md)** 

Documentație tehnică completă cu:
- 📐 **Arhitectură detaliată** cu diagrame
- 🔄 **Flow-uri de date** pentru fiecare operațiune
- 🌐 **Networking** și comunicare inter-service
- 🔐 **Securitate** și RBAC detaliat
- 🚀 **Deployment guide** pas cu pas
- 🐛 **Troubleshooting** complet
- 📊 **Kubernetes Dashboard** - explicații complete

### Scripturi Disponibile

```bash
# Deployment automat complet
./helm/booking-platform/deploy.sh

# Verificare integrare
./helm/booking-platform/verify-integration.sh
```

---

## 🎓 Use Cases Demonstrație

**1. Arhitectură Cloud-Native:**
- "Aplicația folosește 4 microservicii independente..."
- Arată în Dashboard: deployments vizuale

**2. Scalare Orizontală:**
- "Putem scala instant cu un click..."
- Demo: Scale auth-service 1→3 replicas în Dashboard

**3. Monitoring Real-time:**
- "Monitorizăm resurse și logs în timp real..."
- Demo: Vezi logs live din reservation-service

**4. High Availability:**
- "Kubernetes asigură self-healing..."
- Demo: Delete pod → K8s recreează automat

**5. Persistent Data:**
- "Datele supraviețuiesc restart-urilor..."
- Demo: Arată PVC bound în Dashboard

---

## 🤝 Tehnologii Folosite

| Categorie | Tehnologie | Versiune |
|-----------|------------|----------|
| **Backend** | FastAPI | 0.110.0 |
| **Database** | MySQL | 8.0 |
| **ORM** | SQLAlchemy | 2.0 |
| **Auth** | JWT (PyJWT) | - |
| **Container** | Docker | - |
| **Orchestrare** | Kubernetes | 1.24+ |
| **Package Mgmt** | Helm | 3.x |
| **Ingress** | NGINX Ingress Controller | - |
| **Management** | Kubernetes Dashboard | v2.7.0 |
| **DB Admin** | Adminer | latest |

---

## 📝 Licență

Proiect academic - Cloud Computing 2026

---

## 📞 Contact & Support

Pentru întrebări despre arhitectură, deployment sau funcționalitate, consultă **[ARCHITECTURE.md](ARCHITECTURE.md)**.

---

**⭐ Proiect complet funcțional și production-ready cu Kubernetes Dashboard pentru management cluster!** 🚀

**🎯 Toate cerințele proiectului sunt îndeplinite:**
- ✅ Microservicii independente
- ✅ Containerizare
- ✅ Orchestrare Kubernetes
- ✅ Persistent storage
- ✅ **Microserviciu utilitar grafic (Dashboard)**
- ✅ Documentație completă


Grafana 📈

Grafana este utilizată pentru vizualizarea metricilor colectate de Prometheus, oferind grafice istorice și dashboard-uri personalizate pentru aplicație și cluster.

# Obținere nume pod Grafana
export POD_NAME=$(kubectl --namespace monitoring get pod \
  -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=monitoring" \
  -o name)

# Port-forward Grafana
kubectl --namespace monitoring port-forward $POD_NAME 3000:3000

# User: admin
kubectl --namespace monitoring get secrets monitoring-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d ; echo

# Acces în browser: http://localhost:3000

✔️ Monitorizare CPU / memorie pod-uri
✔️ Monitorizare noduri Kubernetes
✔️ Istoric metrici (nu doar „momentan”)
✔️ Dashboard personalizat pentru aplicație
✔️ Separare clară între management (Dashboard) și observability (Grafana)

# Explicatii:

Sistemul de monitorizare a fost implementat folosind Metrics Server pentru metrici de bază Kubernetes și kube-prometheus-stack pentru colectarea și vizualizarea metricilor avansate. Prometheus colectează date despre noduri și poduri, iar Grafana este utilizată pentru afișarea acestora într-un dashboard dedicat.

Dashboard-ul Grafana afișează utilizarea CPU, memorie și uptime pentru podurile aplicației, precum și resursele nodurilor din cluster.

1. CPU Usage per Pod - Este un grafic liniar care arată consumul de resurse în timp. Calculează rata de utilizare a procesorului (CPU) pentru fiecare pod în parte din namespace-ul "default", pe un interval de 1 minut.

2. Memory Usage per Pod - Albastru (mysql): Este de departe cel mai mare consumator, utilizând constant aproximativ 300 MB. Folosim container_memory_usage_bytes pentru a raporta valoarea absolută a memoriei utilizate în bytes. Această vizualizare este utilă pentru a verifica dacă există memory leaks.

3. Node CPU Usage - Acesta monitorizează sănătatea întregului nod Kubernetes (identificat prin IP-ul 192.168.49.2:9100). Nodul nu este suprasolicitat (nu atinge valoarea 1.0 sau peste, în funcție de numărul de nuclee), dar are o activitate dinamică.

4. Node Memory Usage - Graficul arată un consum total de memorie al sistemului între 4,52 GB și 4,66 GB.

5. Application Uptime - Durata de funcționare. Liniile sunt diagonale perfecte, urcând constant în timp. Aceasta este o dovadă clară că aplicațiile nu s-au restartat în intervalul monitorizat.

