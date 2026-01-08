# 🏗️ Arhitectură Booking Platform - Documentație Tehnică Completă

## 📋 Cuprins

1. [Prezentare Generală](#prezentare-generală)
2. [Arhitectura Aplicației](#arhitectura-aplicației)
3. [Componente Detaliate](#componente-detaliate)
4. [Kubernetes Dashboard](#kubernetes-dashboard---microserviciu-utilitar-grafic)
5. [Flow-uri de Date](#flow-uri-de-date)
6. [Networking și Comunicare](#networking-și-comunicare)
7. [Deployment și Orchestrare](#deployment-și-orchestrare)
8. [Securitate și RBAC](#securitate-și-rbac)
9. [Deployment Guide](#deployment-guide)
10. [Troubleshooting](#troubleshooting)

---

## Prezentare Generală

**Booking Platform** este o aplicație de rezervare săli evenimente implementată cu arhitectură de **microservicii** pe **Kubernetes**. Aplicația demonstrează concepte cloud-native: containerizare, orchestrare, service discovery, persistent storage și monitoring.

### 🎯 Scopul Aplicației

- **Utilizatori** pot rezerva săli pentru evenimente
- **Administratori** gestionează sălile și toate rezervările
- **Validare automată** a conflictelor de rezervări
- **Autentificare JWT** cu roluri (USER/ADMIN)
- **Management cluster** prin Kubernetes Dashboard

### 🛠️ Stack Tehnologic

| Componentă | Tehnologie | Versiune |
|------------|------------|----------|
| Backend Framework | FastAPI | 0.110.0 |
| Database | MySQL | 8.0 |
| ORM | SQLAlchemy | 2.0 |
| Autentificare | JWT (PyJWT) | - |
| Container Runtime | Docker | - |
| Orchestrare | Kubernetes | 1.24+ |
| Package Manager | Helm | 3.x |
| Ingress Controller | NGINX | - |
| Management UI | Kubernetes Dashboard | v2.7.0 |
| DB Admin UI | Adminer | latest |

---

## Arhitectura Aplicației

### 🎨 Diagrama Arhitecturii Generale

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Internet / User                              │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                    ┌────────────▼─────────────┐
                    │  NGINX Ingress Controller │
                    │   (Kubernetes Ingress)    │
                    └────────────┬─────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
   ─────▼─────             ─────▼─────            ──────▼──────
   │  /auth  │             │ /reserv.│            │ /dashboard│
   └────┬────┘             └────┬────┘            └─────┬─────┘
        │                       │                        │
        │                       │                        │
┌───────▼────────┐     ┌────────▼─────────┐    ┌────────▼──────────┐
│  Auth Service  │────▶│ Reservation Svc  │    │   Kubernetes      │
│   (FastAPI)    │     │    (FastAPI)     │    │   Dashboard       │
│                │     │                  │    │   (WebUI)         │
│ Port: 8000     │     │ Port: 8000       │    │ Port: 8443        │
│ NS: default    │     │ NS: default      │    │ NS: k8s-dashboard │
└───────┬────────┘     └────────┬─────────┘    └───────────────────┘
        │                       │                         │
        │                       │                         │
        └───────┬───────────────┘                         │
                │                                         │
        ┌───────▼──────────┐                              │
        │     MySQL 8      │                              │
        │                  │                              │
        │  - auth_db       │                    ┌─────────▼─────────┐
        │  - reservation_db│◀───────────────────│  Kubernetes API   │
        │                  │   Monitorizare     │  Server           │
        │ Port: 3306       │   Resurse          └───────────────────┘
        │ NS: default      │
        └───────┬──────────┘
                │
        ┌───────▼──────────┐
        │ PersistentVolume │
        │   (mysql-pvc)    │
        │     1Gi          │
        └──────────────────┘

┌──────────────────────────────────────────────────────────────┐
│  Componente Auxiliare                                        │
│                                                              │
│  ┌──────────────┐                                           │
│  │   Adminer    │  (DB Management UI)                       │
│  │ NodePort     │  Accesibil extern pentru admin DB        │
│  └──────────────┘                                           │
└──────────────────────────────────────────────────────────────┘
```

### 📦 Componente Principale

| Componentă | Namespace | Replicas | Resurse | Rol |
|------------|-----------|----------|---------|-----|
| auth-service | default | 1 | CPU/Mem: default | Autentificare utilizatori |
| reservation-service | default | 1 | CPU/Mem: default | Logică business rezervări |
| mysql | default | 1 | CPU/Mem: default | Persistență date |
| adminer | default | 1 | CPU/Mem: default | Admin interfață DB |
| kubernetes-dashboard | kubernetes-dashboard | 1 | CPU/Mem: default | Management cluster |
| dashboard-metrics-scraper | kubernetes-dashboard | 1 | CPU/Mem: default | Colectare metrici |

---

## Componente Detaliate

### 1. Auth Service 🔐

**Responsabilități:**
- Înregistrare utilizatori noi
- Autentificare cu username/password
- Generare JWT tokens
- Validare tokens pentru alte servicii

**API Endpoints:**

```python
POST /auth/register
{
  "username": "john_doe",
  "password": "secure_pass"
}
Response: {"message": "User registered successfully"}

POST /auth/login
{
  "username": "john_doe",
  "password": "secure_pass"
}
Response: {"access_token": "eyJhbGc..."}

GET /auth/validate
Headers: Authorization: Bearer <token>
Response: {"valid": true, "payload": {"sub": "john_doe", "role": "USER"}}
```

**Model Date:**
```python
class User:
    id: int (PK)
    username: str (unique)
    password: str (hashed with bcrypt)
    role: str (default="USER", options: USER|ADMIN)
```

**Baza de Date:** `auth_db` în MySQL

**Environment Variables:**
```yaml
DATABASE_URL: mysql+pymysql://root:password@mysql:3306/auth_db
JWT_SECRET_KEY: your-secret-key
JWT_ALGORITHM: HS256
JWT_EXPIRATION_HOURS: 24
```

**Securitate:**
- Passwords sunt hash-uite cu **bcrypt**
- JWT tokens conțin: `sub` (username), `role`, `exp` (expiration)
- Tokens expiră după 24h

---

### 2. Reservation Service 🎟️

**Responsabilități:**
- CRUD pentru săli evenimente (Event Halls) - doar ADMIN
- Creare rezervări - USER
- Verificare disponibilitate - PUBLIC
- Anulare rezervări - USER (proprii) / ADMIN (toate)
- Validare conflicte temporale

**API Endpoints:**

**Halls Management (ADMIN only):**
```python
POST /reservation/halls
Headers: Authorization: Bearer <admin-token>
{
  "name": "Conference Hall A",
  "location": "Building 1, Floor 2",
  "capacity": 50
}

GET /reservation/halls  # PUBLIC
Response: [{"id": 1, "name": "...", "location": "...", "capacity": 50}]

PATCH /reservation/halls/{id}  # ADMIN only
DELETE /reservation/halls/{id}  # ADMIN only
```

**Reservations:**
```python
GET /reservation/availability?hall_id=1&date=2026-01-20&start_time=10:00&end_time=12:00
Response: {"available": true}

POST /reservation/reservations
Headers: Authorization: Bearer <token>
{
  "hall_id": 1,
  "date": "2026-01-20",
  "start_time": "10:00",
  "end_time": "12:00"
}

GET /reservation/reservations
# USER: vede doar ale lui
# ADMIN: vede toate

POST /reservation/reservations/{id}/cancel
# USER: doar ale lui
# ADMIN: orice rezervare
```

**Modele Date:**
```python
class EventHall:
    id: int (PK)
    name: str (unique)
    location: str
    capacity: int

class Reservation:
    id: int (PK)
    user_sub: str (username din JWT)
    hall_id: int (FK → EventHall)
    date: Date
    start_time: Time
    end_time: Time
    status: Enum(ACTIVE, CANCELLED)
```

**Logică Business - Validare Conflicte:**

O rezervare este validă DOAR dacă **nu există altă rezervare ACTIVĂ** care se suprapune:

```python
def has_conflict(hall_id, date, start_time, end_time):
    """
    Conflict există dacă:
    - Aceeași sală (hall_id)
    - Aceeași dată (date)
    - Status = ACTIVE
    - Overlap temporal: existing.start < new.end AND new.start < existing.end
    """
    return db.query(Reservation).filter(
        Reservation.hall_id == hall_id,
        Reservation.date == date,
        Reservation.status == "ACTIVE",
        Reservation.start_time < end_time,
        start_time < Reservation.end_time
    ).first() is not None
```

**Autorizare:**
- Folosește **Auth Service** pentru validare token
- Extrage `role` și `sub` din JWT payload
- Enforcement la nivel de endpoint cu decorators

**Baza de Date:** `reservation_db` în MySQL

---

### 3. MySQL Database 🗄️

**Configurare:**
```yaml
Image: mysql:8
Port: 3306
Root Password: password (⚠️ schimbă în producție!)
Databases:
  - auth_db        # Pentru Auth Service
  - reservation_db # Pentru Reservation Service
```

**Persistență:**
- **PersistentVolumeClaim (PVC)**: `mysql-pvc`
- **Size**: 1Gi
- **StorageClass**: default (depinde de cluster)
- **AccessMode**: ReadWriteOnce

**Init Database:**
- Tabelele sunt create automat de SQLAlchemy prin `Base.metadata.create_all()`
- La primul start, MySQL creează bazele de date
- Schema este gestionată de ORM (models.py)

**Backup Strategy (pentru producție):**
```bash
# Backup
kubectl exec deployment/mysql -- mysqldump -u root -ppassword auth_db > backup.sql

# Restore
kubectl exec -i deployment/mysql -- mysql -u root -ppassword auth_db < backup.sql
```

---

### 4. Adminer - DB Management UI 💻

**Configurare:**
```yaml
Image: adminer
Port: 8080
Service Type: NodePort
```

**Acces:**
```bash
kubectl get svc adminer  # vezi NodePort
# Accesează: http://<node-ip>:<nodeport>
```

**Credențiale:**
- Server: `mysql`
- Username: `root`
- Password: `password`
- Database: `auth_db` sau `reservation_db`

**Use Cases:**
- Inspecție manuală baze de date
- Debug schema issues
- Query manual pentru testing
- Vizualizare relații între tabele

---

## Kubernetes Dashboard - Microserviciu Utilitar Grafic

### 🎯 Scop și Funcționalitate

**Kubernetes Dashboard** este instrumentul oficial de management vizual pentru clustere Kubernetes. În acest proiect, Dashboard-ul servește ca **microserviciu utilitar grafic** care oferă:

✅ **Vizualizare în timp real** a tuturor resurselor din cluster
✅ **Monitorizare** CPU, memorie, status pod-uri
✅ **Acces la logs** din orice container
✅ **Management** deployments, scaling, restart
✅ **Debugging** prin events și resource inspection

### 📦 Arhitectura Dashboard-ului

```
┌──────────────────────────────────────────────────────────────┐
│            Namespace: kubernetes-dashboard                    │
│                                                              │
│  ┌────────────────────────┐    ┌─────────────────────────┐ │
│  │ kubernetes-dashboard   │    │ metrics-scraper         │ │
│  │ Pod                    │───▶│ Pod                     │ │
│  │                        │    │                         │ │
│  │ - Interfață WebUI      │    │ - Colectare metrici    │ │
│  │ - HTTPS (8443)         │    │ - CPU/Memory graphs    │ │
│  │ - Token auth           │    │ - HTTP (8000)          │ │
│  └────────┬───────────────┘    └─────────────────────────┘ │
│           │                                                  │
│           │ ServiceAccount: kubernetes-dashboard            │
│           │ ClusterRoleBinding → ClusterRole                │
│           │                                                  │
└───────────┼──────────────────────────────────────────────────┘
            │
            ▼
    ┌───────────────────┐
    │ Kubernetes API    │  ← Dashboard citește TOATE resursele
    │ Server            │    din cluster prin API
    └───────────────────┘
            │
            ├─► Namespace: default (aplicația ta)
            │   ├─ auth-service pods, logs, metrics
            │   ├─ reservation-service pods, logs, metrics
            │   ├─ mysql pods, PVC, logs
            │   ├─ Services, Ingress, ConfigMaps
            │   └─ Events pentru debugging
            │
            └─► Namespace: kubernetes-dashboard (el însuși)
                └─ Propriile resurse
```

### 🔐 RBAC și Securitate

**Dashboard-ul folosește 3 nivele de permisiuni:**

1. **ServiceAccount: kubernetes-dashboard**
   - Acces la propriile resurse (secrets, configmaps)
   - Proxy către metrics scraper

2. **ClusterRole: kubernetes-dashboard-readonly**
   ```yaml
   # Permissions read-only pentru:
   - pods, services, nodes, namespaces
   - deployments, replicasets, statefulsets
   - ingresses, configmaps, secrets (metadata only)
   - persistentvolumes, persistentvolumeclaims
   - events
   ```

3. **ServiceAccount: admin-user** (pentru autentificare)
   - ClusterRoleBinding către **cluster-admin**
   - Acces complet la toate resursele
   - Folosit pentru generare token JWT

**Flow Autentificare:**
```
1. User generează token:
   $ kubectl -n kubernetes-dashboard create token admin-user
   
2. Token este JWT cu:
   - Subject: admin-user
   - Permissions: cluster-admin (toate)
   - Expiration: 1h (default)

3. Dashboard verifică token prin Kubernetes API
   - Token valid → acces la toate resursele
   - Token invalid/expirat → error 401
```

### 🌐 Networking și Acces

**Service Configuration:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  type: ClusterIP
  ports:
    - port: 8443
      targetPort: 8443
      protocol: TCP
  selector:
    app: kubernetes-dashboard
```

**Ingress Configuration:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dashboard-ingress
  namespace: kubernetes-dashboard
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /dashboard(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: kubernetes-dashboard
                port:
                  number: 8443
```

**Metode de Acces:**

| Metodă | Comandă | URL | Use Case |
|--------|---------|-----|----------|
| Port Forward | `kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8443:8443` | https://localhost:8443 | Development local |
| NodePort | Modifică service type în values.yaml | https://\<node-ip\>:30443 | Testing, lab environment |
| Ingress | Deploy cu Ingress configurat | https://\<domain\>/dashboard | Production |

### 📊 Ce Poate Monitoriza Dashboard-ul?

**În namespace `default` (aplicația ta):**

| Resurse | Ce Vezi | Acțiuni Posibile |
|---------|---------|------------------|
| **Deployments** | auth-service, reservation-service, mysql, adminer | Scale replicas, restart, edit |
| **Pods** | Status (Running/Error), restart count, age | View logs, exec shell, delete |
| **Services** | ClusterIP, ports, endpoints | Edit, view endpoints |
| **Ingress** | Paths (/auth, /reservation), backends | View config, rules |
| **PVC** | mysql-pvc status, size, binding | View details, check storage |
| **ConfigMaps** | Configuration data | Edit values |
| **Secrets** | Există, dar values sunt hidden | View metadata |
| **Events** | Deployment events, warnings, errors | Filter, sort, debug |

**Metrics Disponibile:**
- CPU usage per pod (grafic în timp)
- Memory usage per pod (grafic în timp)
- Network I/O (dacă metrics-server instalat)
- Disk usage pentru volumes

**Real-time Logs:**
```
Dashboard → Pods → click pe pod → Logs icon
- Follow logs în timp real
- Download logs
- Filter by timestamp
- Previous container logs (dacă a crashuit)
```

### 🔍 Integration cu Aplicația

**Dashboard-ul NU modifică aplicația, ci doar o OBSERVĂ:**

❌ **Dashboard NU:**
- Nu interceptează request-uri HTTP
- Nu modifică codul aplicației
- Nu accesează direct MySQL
- Nu afectează performance-ul

✅ **Dashboard POATE:**
- Vedea toate pod-urile și status-ul lor
- Accesa logs pentru debugging
- Monitoriza resource usage
- Scale deployments (change replicas)
- Restart pods (delete → K8s recreează)
- Vizualiza networking (services, ingress)
- Debug prin events

**Exemplu Flow Debugging:**
```
Scenario: Auth Service nu răspunde

1. Dashboard → Switch la namespace "default"
2. Workloads → Pods → auth-service-xxx
3. Status: CrashLoopBackOff (RED)
4. Click pe pod → Logs
5. Vezi error: "Cannot connect to MySQL at mysql:3306"
6. Navigate to Services → mysql
7. Status: Running, Endpoints: OK
8. Navigate to Events
9. Vezi: "Warning BackOff pod/auth-service-xxx"
10. Fix: Verifici DATABASE_URL în ConfigMap
11. După fix, Dashboard arată pod revine la Running (GREEN)
```

### 🚀 Deployment și Configurare

**1. Helm Values (`values.yaml`):**
```yaml
dashboard:
  replicaCount: 1
  image:
    repository: kubernetesui/dashboard
    tag: v2.7.0
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP      # Sau NodePort pentru acces extern direct
    port: 8443
    nodePort: 30443      # Doar dacă type: NodePort
```

**2. Deploy cu Helm:**
```bash
helm upgrade --install booking-platform . --namespace default
```

Helm va crea automat:
- Namespace `kubernetes-dashboard`
- Toate resursele Dashboard-ului
- RBAC (ServiceAccounts, ClusterRoles, Bindings)
- Ingress pentru acces

**3. Verificare Deployment:**
```bash
# Check pods
kubectl get pods -n kubernetes-dashboard

# Ar trebui să vezi:
# kubernetes-dashboard-xxx          1/1   Running
# dashboard-metrics-scraper-xxx     1/1   Running

# Check RBAC
kubectl get sa,clusterrole,clusterrolebinding | grep dashboard
```

**4. Acces și Autentificare:**
```bash
# Generează token
TOKEN=$(kubectl -n kubernetes-dashboard create token admin-user)
echo $TOKEN

# Port forward
kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8443:8443

# Deschide browser
open https://localhost:8443

# Login:
# 1. Selectează "Token"
# 2. Paste $TOKEN
# 3. Click "Sign In"
```

### 📈 Use Cases pentru Proiectul Tău

**1. Demonstrație Arhitectură Microservicii:**
```
"Aplicația noastră are 4 microservicii independente..."
→ Arată în Dashboard: Workloads → Deployments
→ Vizualizare clară: auth, reservation, mysql, adminer
```

**2. Health Monitoring:**
```
"Toate serviciile sunt healthy și running..."
→ Dashboard: Pods → Verde checks pentru toate
→ CPU/Memory în limite normale
```

**3. Scaling Demonstration:**
```
"Putem scala orizontal foarte ușor..."
→ Dashboard: Deployments → auth-service → Edit
→ Change replicas: 1 → 3
→ Vezi instant 3 pods auth-service
```

**4. Debugging Real-time:**
```
"Dacă avem o problemă, o putem debug instant..."
→ Dashboard: Pods → reservation-service → Logs
→ Follow logs, vezi requests incoming
```

**5. Persistent Storage:**
```
"Datele sunt persistente prin PersistentVolumeClaim..."
→ Dashboard: Config and Storage → PVCs
→ mysql-pvc: Bound, 1Gi
```

**6. Resource Management:**
```
"Monitorizăm continuu utilizarea resurselor..."
→ Dashboard: Grafice CPU/Memory per pod
→ MySQL consumă cel mai mult (evident)
```

---

## Flow-uri de Date

### 🔄 Flow 1: Înregistrare Utilizator

```
┌─────────┐
│ Client  │
└────┬────┘
     │ POST /auth/register
     │ {"username": "john", "password": "pass123"}
     ▼
┌──────────────────┐
│  Ingress NGINX   │
│  /auth → auth:   │
│         8000     │
└────┬─────────────┘
     │
     ▼
┌──────────────────┐
│  Auth Service    │
│  1. Verify user  │──────────┐
│     not exists   │          │
│  2. Hash password│          │ Query: SELECT * FROM users
│     (bcrypt)     │          │        WHERE username='john'
│  3. Save to DB   │          │
└────┬─────────────┘          │
     │                        ▼
     │ INSERT INTO users   ┌─────────────┐
     │ (username, pass,    │   MySQL     │
     │  role='USER')       │   auth_db   │
     └────────────────────▶│   Table:    │
                           │   - users   │
     ┌─────────────────────└─────────────┘
     │ Response:
     ▼ {"message": "User registered"}
┌─────────┐
│ Client  │
└─────────┘
```

### 🔄 Flow 2: Login și Obținere Token JWT

```
┌─────────┐
│ Client  │
└────┬────┘
     │ POST /auth/login
     │ {"username": "john", "password": "pass123"}
     ▼
┌──────────────────┐
│  Auth Service    │
│  1. Get user     │──────────┐
│     from DB      │          │ Query: SELECT * FROM users
│  2. Verify       │          │        WHERE username='john'
│     password     │          │
│     (bcrypt)     │          ▼
│  3. Generate JWT │      ┌─────────────┐
│                  │◀─────│   MySQL     │
└────┬─────────────┘      │   auth_db   │
     │                    └─────────────┘
     │ JWT Payload:
     │ {
     │   "sub": "john",
     │   "role": "USER",
     │   "exp": timestamp + 24h
     │ }
     │ Signed with: JWT_SECRET_KEY
     │
     │ Response:
     │ {"access_token": "eyJhbGciOiJIUzI1NiIs..."}
     ▼
┌─────────┐
│ Client  │ Saves token for future requests
└─────────┘
```

### 🔄 Flow 3: Creare Rezervare (cu Autentificare și Validare)

```
┌─────────┐
│ Client  │
└────┬────┘
     │ POST /reservation/reservations
     │ Headers: Authorization: Bearer <JWT_TOKEN>
     │ Body: {"hall_id": 1, "date": "2026-01-20",
     │        "start_time": "10:00", "end_time": "12:00"}
     ▼
┌──────────────────────┐
│  Ingress NGINX       │
│  /reservation →      │
│  reservation:8000    │
└────┬─────────────────┘
     │
     ▼
┌──────────────────────┐
│ Reservation Service  │
│ 1. Extract JWT token │
└────┬─────────────────┘
     │
     │ GET /auth/validate
     │ Headers: Bearer <token>
     ▼
┌──────────────────────┐
│  Auth Service        │
│  1. Decode JWT       │───┐
│  2. Verify signature │   │ JWT validation:
│  3. Check expiration │   │ - Signature valid?
│  4. Return payload   │◀──┘ - Not expired?
└────┬─────────────────┘
     │
     │ Response:
     │ {"valid": true,
     │  "payload": {"sub": "john", "role": "USER"}}
     ▼
┌──────────────────────┐
│ Reservation Service  │
│ 2. Validate time     │
│    interval          │
│ 3. Check hall exists │──────┐
│ 4. Check conflicts   │      │
└────┬─────────────────┘      │
     │                        │ Queries:
     │                        │ 1. SELECT * FROM event_halls
     │                        │    WHERE id=1
     │                        │
     │                        │ 2. SELECT * FROM reservations
     │                        │    WHERE hall_id=1
     │                        │      AND date='2026-01-20'
     │                        │      AND status='ACTIVE'
     │                        │      AND start_time < '12:00'
     │                        │      AND '10:00' < end_time
     │                        ▼
     │                    ┌─────────────────┐
     │                    │    MySQL        │
     │                    │ reservation_db  │
     │◀───────────────────│ Tables:         │
     │  No conflicts      │ - event_halls   │
     │                    │ - reservations  │
     │                    └─────────────────┘
     │
     │ 5. Create reservation
     │    INSERT INTO reservations
     │    (user_sub='john', hall_id=1,
     │     date, start_time, end_time,
     │     status='ACTIVE')
     │
     │ Response:
     │ {"id": 42, "user_sub": "john",
     │  "hall_id": 1, "date": "2026-01-20",
     │  "start_time": "10:00", "end_time": "12:00",
     │  "status": "ACTIVE"}
     ▼
┌─────────┐
│ Client  │
└─────────┘
```

### 🔄 Flow 4: Listare Rezervări (cu Autorizare pe Rol)

```
┌─────────┐
│ Client  │
└────┬────┘
     │ GET /reservation/reservations
     │ Headers: Authorization: Bearer <JWT_TOKEN>
     ▼
┌──────────────────────┐
│ Reservation Service  │
│ 1. Validate token    │──▶ Auth Service (validate)
│ 2. Get payload       │◀── {"sub": "john", "role": "USER"}
└────┬─────────────────┘
     │
     │ role == "USER"?
     │   YES → Query: WHERE user_sub='john'
     │   NO (ADMIN) → Query: (toate)
     │
     │ Query:
     │ SELECT * FROM reservations
     │ WHERE user_sub='john'  -- doar dacă USER
     │ ORDER BY id DESC
     ▼
┌─────────────────┐
│    MySQL        │
│ reservation_db  │
└────┬────────────┘
     │ Result:
     │ [
     │   {id: 42, user_sub: "john", hall_id: 1, ...},
     │   {id: 38, user_sub: "john", hall_id: 2, ...}
     │ ]
     ▼
┌──────────────────────┐
│ Reservation Service  │
│ Return filtered list │
└────┬─────────────────┘
     │
     ▼
┌─────────┐
│ Client  │
└─────────┘
```

### 🔄 Flow 5: Dashboard Monitorizare

```
┌──────────────────┐
│  User Browser    │
└────┬─────────────┘
     │ 1. Accesează: https://localhost:8443
     │
     ▼
┌──────────────────────────┐
│  Kubernetes Dashboard    │
│  Pod (kubernetes-        │
│       dashboard ns)      │
│  1. Cere autentificare   │
└────┬─────────────────────┘
     │
     │ 2. User introduce Token:
     │    kubectl -n kubernetes-dashboard create token admin-user
     │    → "eyJhbGciOiJSUzI1NiIs..."
     │
     ▼
┌──────────────────────────┐
│  Dashboard verifică      │
│  token prin K8s API      │
└────┬─────────────────────┘
     │
     ▼
┌──────────────────────────┐
│  Kubernetes API Server   │
│  1. Validate token       │
│  2. Check permissions:   │
│     - admin-user has     │
│       cluster-admin      │
│  3. Allow access         │
└────┬─────────────────────┘
     │
     │ Token valid + cluster-admin permissions
     │
     ▼
┌──────────────────────────┐
│  Dashboard UI loaded     │
│  User selectează         │
│  namespace: "default"    │
└────┬─────────────────────┘
     │
     │ 3. Dashboard face API calls pentru resurse:
     │
     ├──▶ GET /api/v1/namespaces/default/pods
     │    Response: [auth-service-xxx, reservation-service-xxx, ...]
     │
     ├──▶ GET /apis/apps/v1/namespaces/default/deployments
     │    Response: [auth-service, reservation-service, mysql, adminer]
     │
     ├──▶ GET /api/v1/namespaces/default/services
     │    Response: [auth-service:8000, reservation-service:8000, ...]
     │
     └──▶ GET /api/v1/namespaces/default/persistentvolumeclaims
          Response: [mysql-pvc: Bound, 1Gi]
     │
     ▼
┌──────────────────────────┐
│  Dashboard afișează:     │
│  ✓ 4 Deployments         │
│  ✓ 4 Pods (Running)      │
│  ✓ 4 Services            │
│  ✓ 1 PVC (Bound)         │
│  ✓ CPU/Memory graphs     │
└──────────────────────────┘

User click pe pod "auth-service-xxx"
     │
     ▼
┌──────────────────────────┐
│  Dashboard face:         │
│  GET /api/v1/namespaces/ │
│      default/pods/       │
│      auth-service-xxx/   │
│      log?follow=true     │
└────┬─────────────────────┘
     │
     ▼ Real-time logs stream
┌──────────────────────────┐
│ INFO:     Started server │
│ INFO:     Waiting for... │
│ INFO:     POST /auth/... │
│ ...                      │
└──────────────────────────┘
```

---

## Networking și Comunicare

### 🌐 Kubernetes Services

**Service Discovery:**
- Toate serviciile folosesc **ClusterIP** (internal)
- Kubernetes DNS rezolvă automat: `service-name.namespace.svc.cluster.local`
- Simplified: `service-name` (în același namespace)

**Service Map:**

```yaml
# Auth Service
auth-service.default.svc.cluster.local:8000
  → Selector: app=auth-service
  → Target: auth-service pods

# Reservation Service  
reservation-service.default.svc.cluster.local:8000
  → Selector: app=reservation-service
  → Target: reservation-service pods

# MySQL
mysql.default.svc.cluster.local:3306
  → Selector: app=mysql
  → Target: mysql pod

# Dashboard
kubernetes-dashboard.kubernetes-dashboard.svc.cluster.local:8443
  → Selector: app=kubernetes-dashboard
  → Target: dashboard pod
```

### 🚪 Ingress Routing

**NGINX Ingress Controller** gestionează external access:

```
External Request: http://your-domain.com/auth/login
  │
  ▼
┌─────────────────────────────────────┐
│  NGINX Ingress Controller           │
│                                     │
│  Rules:                             │
│  - host: * (all)                    │
│    paths:                           │
│      /auth → auth-service:8000      │
│      /reservation → reservation:    │
│                     8000            │
└─────────────────────────────────────┘
  │                    │
  ▼                    ▼
auth-service      reservation-service
(ClusterIP)       (ClusterIP)

---

┌─────────────────────────────────────┐
│  Dashboard Ingress                  │
│  (namespace: kubernetes-dashboard)  │
│                                     │
│  Rules:                             │
│  - path: /dashboard                 │
│    backend: kubernetes-dashboard:   │
│             8443                    │
│  - annotations:                     │
│      backend-protocol: HTTPS        │
│      rewrite-target: /$2            │
└─────────────────────────────────────┘
           │
           ▼
    kubernetes-dashboard
    (ClusterIP, HTTPS)
```

**Path Rewriting Example:**
```
Request: http://your-domain.com/dashboard/
  │
  ▼ Ingress rewrite-target: /$2
  │
  ▼
https://kubernetes-dashboard:8443/
```

### 🔗 Inter-Service Communication

**Reservation Service → Auth Service:**

```python
# reservation-service/app/auth_client.py

AUTH_SERVICE_URL = os.getenv("AUTH_SERVICE_URL", "http://auth-service:8000/auth")

def validate_token(token: str):
    response = requests.get(
        f"{AUTH_SERVICE_URL}/validate",
        headers={"Authorization": f"Bearer {token}"}
    )
    return response.json()
```

**Service-to-Service Flow:**
```
reservation-service pod
  │
  │ HTTP GET http://auth-service:8000/auth/validate
  │
  ▼
Kubernetes DNS
  │ Resolves: auth-service → ClusterIP (e.g., 10.96.45.123)
  │
  ▼
auth-service ClusterIP
  │ Load balances to one of auth-service pods
  │
  ▼
auth-service pod
  │ Processes request
  │ Returns: {"valid": true, "payload": {...}}
  │
  ▼
reservation-service pod
  │ Receives response
  │ Continues processing
```

### 📡 Network Policies (Optional - Production)

Pentru producție, poți restricționa trafic:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: reservation-service-netpol
spec:
  podSelector:
    matchLabels:
      app: reservation-service
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: ingress-nginx  # Doar de la Ingress
      ports:
        - protocol: TCP
          port: 8000
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: auth-service  # Poate comunica cu Auth
        - podSelector:
            matchLabels:
              app: mysql  # Poate comunica cu MySQL
      ports:
        - protocol: TCP
          port: 8000  # auth-service
        - protocol: TCP
          port: 3306  # mysql
```

---

## Deployment și Orchestrare

### 📦 Helm Chart Structure

```
helm/booking-platform/
├── Chart.yaml              # Metadata chart
├── values.yaml            # Configurări centrale
├── deploy.sh              # Script automat deployment
├── verify-integration.sh  # Script verificare
└── templates/
    ├── auth/
    │   ├── deployment.yaml
    │   └── service.yaml
    ├── reservation/
    │   ├── deployment.yaml
    │   └── service.yaml
    ├── mysql/
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   └── pvc.yaml
    ├── adminer/
    │   ├── deployment.yaml
    │   └── service.yaml
    ├── dashboard/
    │   ├── namespace.yaml
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   ├── serviceaccount.yaml
    │   ├── secret.yaml
    │   ├── clusterrole.yaml
    │   ├── clusterrolebinding.yaml
    │   ├── admin-user.yaml
    │   ├── metrics-scraper-deployment.yaml
    │   └── metrics-scraper-service.yaml
    └── ingress.yaml        # 2 Ingress resources
```

### 🚀 Deployment Process

**Metoda 1: Script Automat (Recomandat)**

```bash
cd helm/booking-platform
./deploy.sh
```

Script-ul execută:
1. ✅ Verifică Helm instalat
2. ✅ Oferă rebuild Docker images (opțional)
3. ✅ `helm upgrade --install booking-platform .`
4. ✅ Așteaptă pods ready (timeout 5min)
5. ✅ Generează Dashboard token
6. ✅ Salvează token în `dashboard-token.txt`
7. ✅ Afișează instrucțiuni acces
8. ✅ Oferă start port-forward automat

**Metoda 2: Manual cu Helm**

```bash
# 1. Build Docker images
cd auth-service
docker build -t auth-service:latest .

cd ../reservation-service
docker build -t reservation-service:latest .

# 2. Deploy
cd ../helm/booking-platform
helm upgrade --install booking-platform . \
  --namespace default \
  --create-namespace \
  --wait \
  --timeout 5m

# 3. Verificare
kubectl get pods
kubectl get svc
kubectl get ingress -A

# 4. Dashboard token
kubectl -n kubernetes-dashboard create token admin-user
```

### 🔄 Update și Rollback

**Update configurație:**

```bash
# Modifică values.yaml (ex: scale replicas)
vim values.yaml

# Apply changes
helm upgrade booking-platform .

# Sau override values din CLI
helm upgrade booking-platform . --set auth.replicaCount=3
```

**Rollback la versiune anterioară:**

```bash
# Vezi history
helm history booking-platform

# Rollback
helm rollback booking-platform 1  # rollback la revision 1
```

### 🧹 Cleanup

```bash
# Uninstall aplicație
helm uninstall booking-platform

# Șterge namespace Dashboard
kubectl delete namespace kubernetes-dashboard

# Șterge PVC (dacă vrei să ștergi și datele)
kubectl delete pvc mysql-pvc -n default
```

---

## Securitate și RBAC

### 🔐 Securitate la Nivel de Aplicație

**1. Auth Service:**
- Passwords hash-uite cu **bcrypt** (cost factor: 12)
- JWT tokens signed cu **HS256** (HMAC-SHA256)
- Secret key stocat în environment variable
- Tokens expiră după 24h

**2. Reservation Service:**
- Toate endpoint-urile protejate necesită JWT valid
- Authorization checks bazate pe `role` din JWT
- USER poate vedea doar rezervările proprii
- ADMIN are acces la toate

**3. MySQL:**
- ⚠️ **Pentru producție**: schimbă `root` password
- Creează utilizatori separați pentru fiecare service
- Grant only needed permissions

### 🛡️ RBAC pentru Dashboard

**ServiceAccounts:**

```yaml
# 1. kubernetes-dashboard (pentru Dashboard însuși)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard

# 2. admin-user (pentru autentificare users)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
```

**ClusterRoles:**

```yaml
# 1. kubernetes-dashboard - basic permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kubernetes-dashboard
rules:
  - apiGroups: [""]
    resources: ["secrets", "configmaps"]
    verbs: ["get", "update", "delete"]

# 2. kubernetes-dashboard-readonly - view all resources
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kubernetes-dashboard-readonly
rules:
  - apiGroups: ["", "apps", "batch", "networking.k8s.io"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]
```

**ClusterRoleBindings:**

```yaml
# admin-user → cluster-admin (full access)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin  # Built-in role: god mode
subjects:
  - kind: ServiceAccount
    name: admin-user
    namespace: kubernetes-dashboard
```

### 🔒 Best Practices Production

1. **Secrets Management:**
   ```bash
   # Nu hardcoda secrets în values.yaml
   # Folosește Kubernetes Secrets
   kubectl create secret generic jwt-secret \
     --from-literal=key=$(openssl rand -base64 32)
   
   kubectl create secret generic mysql-credentials \
     --from-literal=root-password=$(openssl rand -base64 20)
   ```

2. **TLS pentru Ingress:**
   ```yaml
   spec:
     tls:
       - hosts:
           - your-domain.com
         secretName: tls-secret
   ```

3. **Network Policies:**
   - Restricționează inter-pod communication
   - Allow only necessary traffic

4. **Pod Security:**
   ```yaml
   securityContext:
     runAsNonRoot: true
     runAsUser: 1000
     fsGroup: 2000
     capabilities:
       drop:
         - ALL
   ```

5. **Resource Limits:**
   ```yaml
   resources:
     requests:
       memory: "256Mi"
       cpu: "250m"
     limits:
       memory: "512Mi"
       cpu: "500m"
   ```

---

## Deployment Guide

### 📋 Prerequisites

```bash
# Verifică instalări
docker --version          # Docker 20+
kubectl version --client  # Kubernetes 1.24+
helm version             # Helm 3.x
minikube version         # Sau alt cluster (kind, k3s, cloud)

# Start cluster local (dacă folosești minikube)
minikube start --memory=4096 --cpus=2

# Enable Ingress addon
minikube addons enable ingress
```

### 🚀 Deployment Steps

**Pas 1: Clonează/Navighează la Proiect**

```bash
cd /path/to/proiect_cc
```

**Pas 2: Build Docker Images**

```bash
# Auth Service
cd auth-service
docker build -t auth-service:latest .

# Reservation Service
cd ../reservation-service
docker build -t reservation-service:latest .

# Dacă folosești minikube, load images în cluster
eval $(minikube docker-env)
# Re-run build commands
```

**Pas 3: Deploy cu Helm**

```bash
cd ../helm/booking-platform

# Quick deploy cu script
./deploy.sh

# SAU manual
helm upgrade --install booking-platform . \
  --namespace default \
  --create-namespace \
  --wait
```

**Pas 4: Verificare**

```bash
# Check pods
kubectl get pods
kubectl get pods -n kubernetes-dashboard

# Check services
kubectl get svc
kubectl get svc -n kubernetes-dashboard

# Check ingress
kubectl get ingress -A

# Run verification script
./verify-integration.sh
```

**Pas 5: Acces Dashboard**

```bash
# Get token
kubectl -n kubernetes-dashboard create token admin-user

# Port forward
kubectl port-forward -n kubernetes-dashboard \
  service/kubernetes-dashboard 8443:8443

# Browser: https://localhost:8443
# Login cu token
```

**Pas 6: Test API**

```bash
# Register user
curl -X POST http://localhost/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username": "testuser", "password": "test123"}'

# Login
TOKEN=$(curl -s -X POST http://localhost/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "testuser", "password": "test123"}' \
  | jq -r '.access_token')

echo "Token: $TOKEN"

# List halls
curl http://localhost/reservation/halls

# Create reservation
curl -X POST http://localhost/reservation/reservations \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "hall_id": 1,
    "date": "2026-01-25",
    "start_time": "14:00",
    "end_time": "16:00"
  }'
```

### 🔍 Monitoring în Dashboard

După deployment:

1. **Login în Dashboard** (https://localhost:8443)
2. **Switch la namespace "default"**
3. **Navigate:**
   - Workloads → Deployments (vezi cele 4)
   - Workloads → Pods (status Running)
   - Services → Services (vezi ports)
   - Config → PersistentVolumeClaims (mysql-pvc)
4. **Test logs real-time:**
   - Click pe auth-service pod
   - Click "Logs" icon
   - Vezi FastAPI logs
5. **Test scaling:**
   - Deployments → auth-service → Edit
   - Change replicas: 1 → 3
   - Vezi 3 pods apar instant

---

## Troubleshooting

### 🐛 Probleme Comune

#### 1. Pod în status ImagePullBackOff

**Cauză:** Docker image nu există sau nu e accesibil

**Soluție:**
```bash
# Verifică image-ul
kubectl describe pod <pod-name>

# Dacă folosești minikube, load images
eval $(minikube docker-env)
docker build -t auth-service:latest auth-service/
docker build -t reservation-service:latest reservation-service/

# Sau schimbă imagePullPolicy
# În values.yaml: pullPolicy: Never (pentru local)
```

#### 2. Pod în status CrashLoopBackOff

**Cauză:** Container crashuiește la start

**Soluție:**
```bash
# Vezi logs
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # logs din crashul anterior

# Common causes:
# - Database connection failed
# - Missing environment variables
# - Port already in use

# Check environment
kubectl exec -it <pod-name> -- env | grep DATABASE
```

#### 3. Service nu răspunde

**Cauză:** Service nu găsește pods sau pods nu sunt ready

**Soluție:**
```bash
# Check endpoints
kubectl get endpoints <service-name>
# Dacă nu sunt endpoints → selector greșit

# Verifică selector vs labels
kubectl describe svc <service-name>
kubectl get pods --show-labels

# Test direct în pod
kubectl run test-pod --rm -i --tty --image=curlimages/curl -- sh
curl http://auth-service:8000/health
```

#### 4. MySQL Connection Failed

**Cauză:** MySQL nu e ready sau credentials greșite

**Soluție:**
```bash
# Check MySQL pod
kubectl logs deployment/mysql

# Test connection
kubectl exec -it deployment/mysql -- mysql -u root -ppassword -e "SHOW DATABASES;"

# Verifică environment în service pods
kubectl exec -it deployment/auth-service -- env | grep DATABASE_URL

# Should be: mysql+pymysql://root:password@mysql:3306/auth_db
```

#### 5. Ingress nu funcționează

**Cauză:** Ingress Controller nu e instalat

**Soluție:**
```bash
# Check Ingress Controller
kubectl get pods -n ingress-nginx

# Dacă lipsește, instalează:
# Minikube:
minikube addons enable ingress

# Kind:
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Verifică Ingress
kubectl describe ingress booking-ingress
kubectl describe ingress dashboard-ingress -n kubernetes-dashboard
```

#### 6. Dashboard Token expirat

**Cauză:** Tokens JWT expiră după 1h (default)

**Soluție:**
```bash
# Generează nou token
kubectl -n kubernetes-dashboard create token admin-user

# Pentru token cu expirare mai lungă
kubectl -n kubernetes-dashboard create token admin-user --duration=24h
```

#### 7. PVC nu se bind-uie

**Cauză:** StorageClass lipsește sau PV nu există

**Soluție:**
```bash
# Check PVC status
kubectl get pvc mysql-pvc
kubectl describe pvc mysql-pvc

# Check StorageClass
kubectl get storageclass

# Dacă lipsește, instalează:
# Minikube: automat există
# Kind: needs local-path-provisioner
```

### 📊 Debugging Commands

```bash
# Pod debugging
kubectl get pods -A                          # Toate pods
kubectl describe pod <pod-name>              # Detalii pod
kubectl logs <pod-name> -f                   # Follow logs
kubectl exec -it <pod-name> -- /bin/bash     # Shell în pod

# Service debugging
kubectl get svc -A                           # Toate services
kubectl get endpoints <service-name>         # Service endpoints
kubectl port-forward svc/<service> 8080:8000 # Test direct

# Ingress debugging
kubectl get ingress -A
kubectl describe ingress <ingress-name>

# Events (FOARTE UTIL!)
kubectl get events --sort-by='.lastTimestamp'
kubectl get events -n kubernetes-dashboard --sort-by='.lastTimestamp'

# Resource usage
kubectl top nodes
kubectl top pods

# Full cluster status
kubectl get all -A
```

### 🔍 Dashboard-Specific Issues

**Dashboard nu se încarcă:**
```bash
# Check pod status
kubectl get pods -n kubernetes-dashboard

# Check logs
kubectl logs -n kubernetes-dashboard deployment/kubernetes-dashboard

# Restart deployment
kubectl rollout restart deployment/kubernetes-dashboard -n kubernetes-dashboard

# Verify RBAC
kubectl get sa,clusterrole,clusterrolebinding | grep dashboard
```

**Token nu funcționează:**
```bash
# Verifică admin-user există
kubectl get sa admin-user -n kubernetes-dashboard

# Recreează dacă lipsește
kubectl apply -f templates/dashboard/admin-user.yaml

# Generează token nou
kubectl -n kubernetes-dashboard create token admin-user
```

---

## 🎉 Concluzie

Această arhitectură demonstrează:

✅ **Microservicii** independente, scalabile
✅ **Containerizare** cu Docker
✅ **Orchestrare** cu Kubernetes
✅ **Service Discovery** automat
✅ **Persistent Storage** pentru date
✅ **JWT Authentication** securizat
✅ **Role-Based Access Control** (RBAC)
✅ **Ingress Routing** pentru external access
✅ **Management UI** prin Kubernetes Dashboard
✅ **Infrastructure as Code** cu Helm
✅ **Cloud-Native** best practices

Aplicația este **production-ready** cu câteva îmbunătățiri:
- Secrets management cu Vault/Sealed Secrets
- TLS certificates cu cert-manager
- Monitoring cu Prometheus + Grafana
- Centralized logging cu ELK/Loki
- CI/CD pipeline cu GitLab/ArgoCD
- Horizontal Pod Autoscaling
- Resource quotas și limits

**Proiectul este complet funcțional și gata de demonstrație!** 🚀

---

**Documentat cu ❤️ pentru proiectul Cloud Computing 2026**

