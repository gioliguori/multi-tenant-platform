#!/bin/bash
# 🚀 MULTI-TENANT KUBERNETES PLATFORM - FINAL SETUP WITH POSTGRESQL METRICS
# Updated for PostgreSQL exporter sidecar and complete monitoring

echo "🚀 Starting Multi-Tenant Kubernetes Platform with PostgreSQL Metrics..."

# =============================================================================
# PART 1: KIND CLUSTER SETUP
# =============================================================================

echo "📡 PART 1: Kubernetes Cluster Setup"

# 1. CREATE KIND CLUSTER
echo "Creating Kind cluster..."
kind create cluster --name multi-tenant --config kind-config.yaml

# 2. VERIFY KIND NODES
echo "Verifying Kind cluster..."
kubectl get nodes
# Expected: 3 nodes (NotReady - missing CNI)

# 3. INSTALL CALICO CNI
echo "Installing Calico CNI..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/calico.yaml

# 4. WAIT FOR CALICO
echo "🔍 Waiting for Calico installation..."
echo "This may take 2-3 minutes..."
kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=300s
kubectl wait --for=condition=ready pod -l k8s-app=calico-kube-controllers -n kube-system --timeout=300s

# 5. VERIFY NODES READY
echo "Verifying nodes are Ready..."
kubectl wait --for=condition=ready node --all --timeout=300s
kubectl get nodes

# =============================================================================
# PART 2: MULTI-TENANT FOUNDATION
# =============================================================================

echo "🏢 PART 2: Multi-Tenant Foundation"

# 6. DEPLOY NAMESPACES & IDENTITIES
echo "Deploying namespaces and service accounts..."
kubectl apply -f kubernetes/01-namespaces/

# 7. DEPLOY SECURITY POLICIES
echo "Deploying security policies..."
kubectl apply -f kubernetes/02-security/

# 8. VERIFY FOUNDATION
echo "Verifying foundation..."
kubectl get namespaces | grep team-
kubectl get serviceaccounts -A | grep team-
kubectl get resourcequota -A
kubectl get networkpolicy -A

# =============================================================================
# PART 3: POSTGRESQL DATABASE WITH METRICS
# =============================================================================

echo "🗄️ PART 3: PostgreSQL Database with Metrics Sidecar"

# 9. DEPLOY POSTGRESQL WITH POSTGRES_EXPORTER SIDECAR
echo "Deploying PostgreSQL with postgres_exporter sidecar..."
kubectl apply -f kubernetes/03-workloads/backend/postgres-deployment.yaml

# 10. WAIT FOR POSTGRESQL
echo "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgresql -n team-backend --timeout=180s

# 11. VERIFY POSTGRESQL 
echo "Verifying PostgreSQL with metrics sidecar..."
kubectl get pods -n team-backend -l app=postgresql

# =============================================================================
# PART 4: APPLICATION DEPLOYMENT
# =============================================================================

echo "📦 PART 4: Application Deployment"

# 12. BUILD APPLICATIONS
echo "Building applications..."
echo "Building frontend..."
cd applications/frontend/react-store-demo && docker build -t react-store:latest . && cd ../../..

echo "Building backend..."
cd applications/backend/users-api && docker build -t users-api:latest . && cd ../../..

# 13. LOAD IMAGES IN KIND
echo "Loading images in Kind..."
kind load docker-image react-store:latest --name multi-tenant
kind load docker-image users-api:latest --name multi-tenant

# 14. DEPLOY APPLICATIONS
echo "Deploying applications..."
kubectl apply -f kubernetes/03-workloads/frontend/
kubectl apply -f kubernetes/03-workloads/backend/users-api-deployment.yaml
kubectl apply -f kubernetes/03-workloads/backend/users-api-service.yaml

# 15. DEPLOY SCALING FEATURES
echo "Deploying auto-scaling and high availability..."
kubectl apply -f kubernetes/04-scaling/

# 16. WAIT FOR APPLICATION PODS
echo "🔍 Waiting for application pods..."
kubectl wait --for=condition=ready pod -l app=react-store -n team-frontend --timeout=300s
kubectl wait --for=condition=ready pod -l app=users-api -n team-backend --timeout=300s

# 17. VERIFY DEPLOYMENTS
echo "Verifying deployments..."
kubectl get pods -n team-frontend
kubectl get pods -n team-backend
kubectl get hpa -A
kubectl get pdb -A

# =============================================================================
# PART 5: MONITORING SETUP WITH POSTGRESQL METRICS
# =============================================================================

echo "📊 PART 5: Complete Monitoring Setup"

# 18. SETUP GRAFANA DASHBOARDS
echo "Creating Grafana dashboards ConfigMap..."
kubectl create configmap grafana-platform-dashboards \
    --from-file=kubernetes/05-monitoring/grafana/dashboards/ \
    -n team-platform \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl label configmap grafana-platform-dashboards \
    grafana_dashboard=1 -n team-platform --overwrite

# 19. INSTALL PROMETHEUS STACK
echo "Installing Prometheus Stack via Helm..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1

helm install prometheus prometheus-community/kube-prometheus-stack \
    --namespace team-platform \
    --values kubernetes/05-monitoring/prometheus/prometheus-stack-values.yaml \
    --wait --timeout 10m

# 20. DEPLOY SERVICEMONITORS FOR BOTH APP AND DB
echo "Deploying ServiceMonitors for application and database metrics..."
kubectl apply -f kubernetes/05-monitoring/prometheus/backend-servicemonitor.yaml

# 21. WAIT FOR PROMETHEUS STACK
echo "Waiting for Prometheus Stack to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n team-platform --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n team-platform --timeout=300s

echo "✅ Complete monitoring stack deployed"

# =============================================================================
# PART 6: ACCESS SETUP & TESTING
# =============================================================================

echo "🌐 PART 6: Access Setup & Testing"

# 22. SETUP PORT-FORWARDS (including monitoring)
echo "Setting up port-forwards..."
pkill -f "port-forward" 2>/dev/null || true
sleep 2

kubectl port-forward -n team-backend svc/users-api 3001:3000 &
kubectl port-forward -n team-frontend svc/react-store 3000:3000 &
kubectl port-forward svc/prometheus-grafana 3002:80 -n team-platform &
kubectl port-forward svc/prometheus-prometheus 9090:9090 -n team-platform &

# 23. WAIT FOR PORT-FORWARDS
echo "Waiting for port-forwards to establish..."
sleep 10

# 24. TEST BACKEND
echo "Testing backend..."
echo "📋 Health check:"
curl -s http://localhost:3001/api/health | jq '.' || curl -s http://localhost:3001/api/health

echo "📋 Database test:"
curl -s http://localhost:3001/api/db-test | jq '.' || curl -s http://localhost:3001/api/db-test

echo "📋 Products API:"
curl -s http://localhost:3001/api/products | jq '.metadata' || curl -s http://localhost:3001/api/products

echo "📋 Categories API:"
curl -s http://localhost:3001/api/categories | jq '.' || curl -s http://localhost:3001/api/categories

# 25. TEST FRONTEND
echo "📋 Testing frontend..."
curl -s http://localhost:3000 >/dev/null && echo "✅ Frontend accessible" || echo "❌ Frontend not accessible"

# 26. TEST MONITORING STACK
echo "📋 Testing monitoring stack..."
curl -s http://localhost:9090/-/healthy >/dev/null && echo "✅ Prometheus accessible" || echo "❌ Prometheus not accessible"
curl -s -u admin:admin123 http://localhost:3002/api/health >/dev/null && echo "✅ Grafana accessible" || echo "❌ Grafana not accessible"

# 27. TEST METRICS ENDPOINTS
echo "📋 Testing metrics endpoints..."
curl -s http://localhost:3001/metrics >/dev/null && echo "✅ Backend app metrics OK" || echo "❌ Backend app metrics KO"

# Test PostgreSQL metrics directly
PG_POD=$(kubectl get pods -n team-backend -l app=postgresql -o jsonpath='{.items[0].metadata.name}')
if [ ! -z "$PG_POD" ]; then
    echo "📋 Testing PostgreSQL metrics..."
    kubectl port-forward -n team-backend pod/$PG_POD 9187:9187 >/dev/null 2>&1 &
    PF_PID=$!
    sleep 3
    curl -s http://localhost:9187/metrics >/dev/null && echo "✅ PostgreSQL exporter metrics OK" || echo "❌ PostgreSQL exporter metrics KO"
    kill $PF_PID 2>/dev/null || true
fi

# 28. CHECK PROMETHEUS TARGETS
echo "📋 Checking Prometheus targets..."
sleep 5
BACKEND_TARGETS=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null | grep -c "users-api" || echo "0")
DB_TARGETS=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null | grep -c "postgresql" || echo "0")

if [ "$BACKEND_TARGETS" -gt 0 ]; then
    echo "✅ Backend ServiceMonitor discovered ($BACKEND_TARGETS targets)"
else
    echo "❌ Backend ServiceMonitor not found"
fi

if [ "$DB_TARGETS" -gt 0 ]; then
    echo "✅ PostgreSQL ServiceMonitor discovered ($DB_TARGETS targets)"
else
    echo "❌ PostgreSQL ServiceMonitor not found"
fi

# 29. GENERATE INITIAL TRAFFIC FOR METRICS
echo "🚀 Generating initial traffic for metrics population..."
for i in {1..30}; do
    curl -s http://localhost:3001/api/products >/dev/null || true
    curl -s http://localhost:3001/api/categories >/dev/null || true
    curl -s http://localhost:3001/api/db-test >/dev/null || true
    curl -s http://localhost:3001/api/server-info >/dev/null || true
    sleep 0.5
done

echo "✅ Initial traffic generated for dashboard population"

# =============================================================================
# PART 7: DEMO SCENARIOS
# =============================================================================

echo "🎬 PART 7: Demo Scenarios"

# 30. DEMO LOAD BALANCING
echo "🎯 LOAD BALANCING DEMO"
echo "Scaling backend to 3 replicas for better demo..."
kubectl scale deployment users-api --replicas=3 -n team-backend
kubectl wait --for=condition=ready pod -l app=users-api -n team-backend --timeout=120s

echo "Testing load balancing across backend pods..."
for i in {1..5}; do
    echo -n "Request $i: "
    curl -s http://localhost:3001/api/server-info | jq -r '.hostname' 2>/dev/null || echo "failed"
    sleep 1
done

# 31. DEMO NETWORK ISOLATION
echo "🛡️ NETWORK ISOLATION DEMO"
echo "Testing network isolation (should timeout)..."
timeout 10 kubectl run curl-test --image=curlimages/curl -n team-frontend --rm -it --restart=Never -- \
    curl --max-time 5 http://users-api.team-backend.svc.cluster.local:3000/api/health 2>/dev/null && \
    echo "❌ Network policy not working" || echo "✅ Network isolation working correctly"

# 32. DEMO RESOURCE QUOTAS
echo "💰 RESOURCE QUOTAS DEMO"
echo "Current resource usage:"
kubectl describe resourcequota -n team-frontend | grep -A 10 "Resource.*Used.*Hard"
kubectl describe resourcequota -n team-backend | grep -A 10 "Resource.*Used.*Hard"

# 33. DEMO AUTOSCALING
echo "📈 AUTOSCALING DEMO"
echo "Current HPA status:"
kubectl get hpa -A

# 34. DEMO METRICS SEPARATION
echo "📊 METRICS SEPARATION DEMO"
echo "🔹 Application metrics from Node.js API:"
curl -s http://localhost:3001/metrics | grep -E "(http_requests_total|api_errors_total)" | head -3

echo ""
echo "🔹 Database metrics from PostgreSQL exporter:"
if [ ! -z "$PG_POD" ]; then
    kubectl port-forward -n team-backend pod/$PG_POD 9187:9187 >/dev/null 2>&1 &
    PF_PID=$!
    sleep 3
    echo "Sample PostgreSQL metrics:"
    curl -s http://localhost:9187/metrics | grep -E "(pg_up|pg_stat_database_numbackends|pg_stat_database_size)" | head -3 2>/dev/null || echo "DB metrics not ready yet"
    kill $PF_PID 2>/dev/null || true
fi

echo ""
echo "🎉 SETUP COMPLETE!"
echo ""
echo "🌐 Access URLs:"
echo "  Frontend:       http://localhost:3000"
echo "  Backend API:    http://localhost:3001"
echo "  Grafana:        http://localhost:3002     (admin / admin123)"
echo "  Prometheus:     http://localhost:9090"
echo ""
echo "📊 Metrics Endpoints:"
echo "  Backend App Metrics:     http://localhost:3001/metrics"
echo "  PostgreSQL DB Metrics:   kubectl port-forward pod/postgresql-xxx 9187:9187"
echo "  Prometheus Targets:      http://localhost:9090/targets"
echo "  Grafana Dashboards:      http://localhost:3002/dashboards"
echo ""
echo "🎯 Available Demo Endpoints:"
echo "  GET /api/products - All products from PostgreSQL"
echo "  GET /api/categories - Product categories with counts"
echo "  GET /api/products/category/:category - Products by category"
echo "  GET /api/server-info - Load balancing demo"
echo "  GET /api/db-test - Database connection test"
echo "  GET /api/health - Health check"
echo "  GET /metrics - Application metrics (Node.js)"
echo ""
echo "📈 Available Grafana Dashboards:"
echo "  - Platform Overview (all teams & infrastructure)"
echo "  - Frontend Team Dashboard (React app metrics)"
echo "  - Backend Team Dashboard (API + Database metrics)"
echo ""
echo "🔍 Key Demo Features:"
echo "  ✅ Multi-tenant isolation (RBAC + Network Policies + Quotas)"
echo "  ✅ Load balancing across multiple backend pods"
echo "  ✅ Auto-scaling (HPA) and High Availability (PDB)"
echo "  ✅ Separated metrics: Application (Node.js) + Database (PostgreSQL)"
echo "  ✅ Real-time monitoring with Prometheus + Grafana"
echo "  ✅ Enterprise-grade security and resource governance"
echo ""
echo "🔍 VERIFICATION COMMANDS:"
echo "  kubectl get pods -A                          # All pods status"
echo "  kubectl get nodes                            # Nodes status"
echo "  kubectl get servicemonitor -A                # Prometheus ServiceMonitors"
echo "  kubectl get networkpolicy -A                 # Network policies"
echo "  kubectl get resourcequota -A                 # Resource quotas"
echo "  kubectl get hpa -A                           # Horizontal Pod Autoscalers"
echo "  kubectl get pdb -A                           # Pod Disruption Budgets"
echo ""
echo "🧹 CLEANUP COMMANDS:"
echo "  pkill -f 'port-forward'                      # Stop port-forwards"
echo "  helm uninstall prometheus -n team-platform   # Remove monitoring"
echo "  kind delete cluster --name multi-tenant     # Delete cluster"
echo "  docker rmi react-store:latest users-api:latest # Clean images"
echo ""
echo "🏗️ Architecture: Multi-Tenant Kubernetes Platform"
echo "🔒 Security: RBAC + Network Policies + Resource Quotas + Pod Security"
echo "📈 Enterprise Features: Auto-scaling + High Availability + Load Balancing"
echo "📊 Advanced Monitoring: Prometheus + Grafana + Dual Metrics (App + DB)"
echo "🗄️ Database: PostgreSQL with dedicated postgres_exporter sidecar"
echo ""
echo "🎯 Ready for enterprise-grade demonstrations!"