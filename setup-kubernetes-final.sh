#!/bin/bash
# 🚀 MULTI-TENANT KUBERNETES PLATFORM - COMPLETE SETUP
# Enterprise-grade multi-tenant platform with auto-scaling and monitoring

echo "🚀 Starting Multi-Tenant Kubernetes Platform Setup..."

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
# PART 2: METRICS SERVER SETUP (CRITICAL FOR HPA)
# =============================================================================

echo "📊 PART 2: Installing Metrics Server for Auto-scaling"

# 6. INSTALL METRICS SERVER
echo "Installing Metrics Server (required for HPA)..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 7. PATCH FOR KIND
echo "Configuring Metrics Server for Kind cluster..."
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  }
]'

# 8. WAIT FOR METRICS SERVER
echo "Waiting for Metrics Server to be ready..."
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=120s

# 9. VERIFY METRICS COLLECTION
echo "Verifying metrics collection..."
kubectl top nodes
kubectl top pods -A

echo "✅ Metrics Server ready - HPA can now function properly"

# =============================================================================
# PART 3: MULTI-TENANT FOUNDATION
# =============================================================================

echo "🏢 PART 3: Multi-Tenant Foundation"

# 10. DEPLOY NAMESPACES & IDENTITIES
echo "Deploying namespaces and service accounts..."
kubectl apply -f kubernetes/01-namespaces/

# 11. DEPLOY SECURITY POLICIES
echo "Deploying security policies..."
kubectl apply -f kubernetes/02-security/

# 12. VERIFY FOUNDATION
echo "Verifying foundation..."
kubectl get namespaces | grep team-
kubectl get serviceaccounts -A | grep team-
kubectl get resourcequota -A
kubectl get networkpolicy -A

# =============================================================================
# PART 4: DATABASE DEPLOYMENT
# =============================================================================

echo "🗄️ PART 4: PostgreSQL Database Deployment"

# 13. DEPLOY POSTGRESQL
echo "Deploying PostgreSQL database..."
kubectl apply -f kubernetes/03-workloads/backend/postgres-deployment.yaml

# 14. WAIT FOR POSTGRESQL
echo "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgresql -n team-backend --timeout=180s

# 15. VERIFY POSTGRESQL 
echo "Verifying PostgreSQL deployment..."
kubectl get pods -n team-backend -l app=postgresql

# =============================================================================
# PART 5: APPLICATION DEPLOYMENT
# =============================================================================

echo "📦 PART 5: Application Deployment"

# 16. BUILD APPLICATIONS
echo "Building applications..."
echo "Building frontend..."
cd applications/frontend/react-store-demo && docker build -t react-store:latest . && cd ../../..

echo "Building backend..."
cd applications/backend/users-api && docker build -t users-api:latest . && cd ../../..

# 17. LOAD IMAGES IN KIND
echo "Loading images in Kind..."
kind load docker-image react-store:latest --name multi-tenant
kind load docker-image users-api:latest --name multi-tenant

# 18. DEPLOY APPLICATIONS
echo "Deploying applications..."
kubectl apply -f kubernetes/03-workloads/frontend/
kubectl apply -f kubernetes/03-workloads/backend/users-api-deployment.yaml
kubectl apply -f kubernetes/03-workloads/backend/users-api-service.yaml

# 19. DEPLOY ENTERPRISE FEATURES (HPA + PDB)
echo "Deploying auto-scaling and high availability..."
kubectl apply -f kubernetes/04-scaling/

# 20. WAIT FOR APPLICATION PODS
echo "🔍 Waiting for application pods..."
kubectl wait --for=condition=ready pod -l app=react-store -n team-frontend --timeout=300s
kubectl wait --for=condition=ready pod -l app=users-api -n team-backend --timeout=300s

# 21. VERIFY DEPLOYMENTS
echo "Verifying deployments..."
kubectl get pods -n team-frontend
kubectl get pods -n team-backend
kubectl get hpa -A
kubectl get pdb -A

# =============================================================================
# PART 6: MONITORING SETUP
# =============================================================================

echo "📊 PART 6: Complete Monitoring Setup"

# 22. SETUP GRAFANA DASHBOARDS
echo "Creating Grafana dashboards ConfigMap..."
kubectl create configmap grafana-platform-dashboards \
    --from-file=kubernetes/05-monitoring/grafana/dashboards/ \
    -n team-platform \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl label configmap grafana-platform-dashboards \
    grafana_dashboard=1 -n team-platform --overwrite

# 23. INSTALL PROMETHEUS STACK
echo "Installing Prometheus Stack via Helm..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1

helm install prometheus prometheus-community/kube-prometheus-stack \
    --namespace team-platform \
    --values kubernetes/05-monitoring/prometheus/prometheus-stack-values.yaml \
    --wait --timeout 10m

# 24. DEPLOY SERVICEMONITORS
echo "Deploying ServiceMonitors for metrics collection..."
kubectl apply -f kubernetes/05-monitoring/prometheus/backend-servicemonitor.yaml

# 25. WAIT FOR PROMETHEUS STACK
echo "Waiting for Prometheus Stack to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n team-platform --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n team-platform --timeout=300s

echo "✅ Complete monitoring stack deployed"

# =============================================================================
# PART 7: ACCESS SETUP & VERIFICATION
# =============================================================================

echo "🌐 PART 7: Access Setup & System Verification"

# 26. SETUP PORT-FORWARDS
echo "Setting up port-forwards..."
pkill -f "port-forward" 2>/dev/null || true
sleep 2

kubectl port-forward -n team-backend svc/users-api 3001:3000 &
kubectl port-forward -n team-frontend svc/react-store 3000:3000 &
kubectl port-forward svc/prometheus-grafana 3002:80 -n team-platform &
kubectl port-forward svc/prometheus-prometheus 9090:9090 -n team-platform &

# 27. WAIT FOR PORT-FORWARDS
echo "Waiting for port-forwards to establish..."
sleep 10

# 28. VERIFY APPLICATIONS
echo "Verifying applications..."
curl -s http://localhost:3001/api/health | jq '.' || curl -s http://localhost:3001/api/health
curl -s http://localhost:3001/api/products | jq '.metadata' || curl -s http://localhost:3001/api/products
curl -s http://localhost:3000 >/dev/null && echo "✅ Frontend accessible" || echo "❌ Frontend not accessible"

# 29. VERIFY MONITORING
echo "Verifying monitoring stack..."
curl -s http://localhost:9090/-/healthy >/dev/null && echo "✅ Prometheus accessible" || echo "❌ Prometheus not accessible"
curl -s -u admin:admin123 http://localhost:3002/api/health >/dev/null && echo "✅ Grafana accessible" || echo "❌ Grafana not accessible"

# 30. VERIFY HPA FUNCTIONALITY
echo "Verifying HPA functionality..."
kubectl get hpa -A
echo "✅ HPA should show real CPU/Memory values (not <unknown>)"

# 31. GENERATE INITIAL TRAFFIC
echo "🚀 Generating initial traffic for metrics population..."
for i in {1..30}; do
    curl -s http://localhost:3001/api/products >/dev/null || true
    curl -s http://localhost:3001/api/categories >/dev/null || true
    curl -s http://localhost:3001/api/server-info >/dev/null || true
    sleep 0.5
done

echo "✅ Initial traffic generated for dashboard population"

echo ""
echo "🎉 MULTI-TENANT KUBERNETES PLATFORM SETUP COMPLETE!"
echo ""
echo "🌐 Access URLs:"
echo "  Frontend:       http://localhost:3000"
echo "  Backend API:    http://localhost:3001"
echo "  Grafana:        http://localhost:3002     (admin / admin123)"
echo "  Prometheus:     http://localhost:9090"
echo ""
echo "🎯 Ready for Demo:"
echo "  ✅ Multi-tenant isolation (RBAC + Network Policies + Quotas)"
echo "  ✅ Auto-scaling (HPA) with Metrics Server"
echo "  ✅ High Availability (PDB)"
echo "  ✅ Real-time monitoring with Prometheus + Grafana"
echo "  ✅ Enterprise-grade security and resource governance"
echo ""
echo "🧹 Cleanup Commands:"
echo "  pkill -f 'port-forward'                      # Stop port-forwards"
echo "  helm uninstall prometheus -n team-platform   # Remove monitoring"
echo "  kind delete cluster --name multi-tenant     # Delete cluster"
echo ""
echo "🎯 Ready for enterprise-grade demonstrations!"