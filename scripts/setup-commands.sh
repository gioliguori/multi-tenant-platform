#!/bin/bash
# 🚀 MULTI-TENANT KUBERNETES PLATFORM - SIMPLE SETUP
# Created: 2025-06-21
# Purpose: Deploy multi-tenant platform with external PostgreSQL database

echo "🚀 Starting Multi-Tenant Platform Setup with External Database..."

# =============================================================================
# PART 1: CONTAINERLAB + KIND SETUP
# =============================================================================

echo "📡 PART 1: Infrastructure Setup"

# 1. START CONTAINERLAB (nel DevContainer)
echo "Starting ContainerLab topology..."
sudo containerlab deploy -t topology.clab.yml

# 2. VERIFICA CONTAINERLAB
echo "Verifying ContainerLab deployment..."
sudo containerlab inspect -t topology.clab.yml
docker ps | grep clab-topology

# 3. TEST CONNETTIVITÀ CONTAINERLAB
echo "Testing ContainerLab connectivity..."
docker exec clab-topology-h1 ping -c 3 192.168.102.2
# Expected: 0% packet loss

# 4. CREATE KIND CLUSTER (su macOS Host)
echo "Creating Kind cluster..."
kind create cluster --name multi-tenant --config kind-config.yaml

# 5. VERIFICA KIND NODES
echo "Verifying Kind cluster..."
kubectl get nodes
# Expected: 3 nodes (NotReady - manca CNI)

# 6. CONNETTI KIND A CONTAINERLAB NETWORK
echo "Connecting Kind to ContainerLab network..."
docker network connect clab multi-tenant-control-plane
docker network connect clab multi-tenant-worker
docker network connect clab multi-tenant-worker2

# 7. CONFIGURA ROUTING KIND → CONTAINERLAB
echo "Configuring routing Kind → ContainerLab..."
docker exec multi-tenant-control-plane bash -c "
  apt-get update -qq && apt-get install -y -qq iputils-ping iproute2
  ip route add 192.168.101.0/24 via 172.20.20.6
  ip route add 192.168.102.0/24 via 172.20.20.7
  sysctl -w net.ipv4.ip_forward=1
"

docker exec multi-tenant-worker bash -c "
  apt-get update -qq && apt-get install -y -qq iputils-ping iproute2
  ip route add 192.168.101.0/24 via 172.20.20.6
  ip route add 192.168.102.0/24 via 172.20.20.7
  sysctl -w net.ipv4.ip_forward=1
"

docker exec multi-tenant-worker2 bash -c "
  apt-get update -qq && apt-get install -y -qq iputils-ping iproute2
  ip route add 192.168.101.0/24 via 172.20.20.6
  ip route add 192.168.102.0/24 via 172.20.20.7
  sysctl -w net.ipv4.ip_forward=1
"

# 8. INSTALLA CALICO CNI
echo "Installing Calico CNI..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/calico.yaml

# 9. WAIT FOR CALICO
echo "🔍 Waiting for Calico installation..."
echo "Watch Calico pods: kubectl get pods -n kube-system -w"
echo "Wait until all calico-* pods are Running, then press Ctrl+C"
kubectl get pods -n kube-system | grep calico

# 10. WAIT FOR NODES READY
echo "🔍 Waiting for nodes to become Ready..."
echo "Watch nodes: kubectl get nodes -w"
echo "Wait until all nodes are Ready, then press Ctrl+C"

# 11. TEST CONNETTIVITÀ KIND → CONTAINERLAB
echo "Testing Kind → ContainerLab connectivity..."
docker exec multi-tenant-control-plane ping -c 3 192.168.101.2
# Expected: 0% packet loss

# =============================================================================
# PART 2: EXTERNAL DATABASE SETUP (SIMPLIFIED)
# =============================================================================

echo "🗄️ PART 2: External Database Setup"

# 12. VERIFY DATABASE (NO LONGER NEEDED - AUTO-CONFIGURED)
echo "PostgreSQL automatically configured with pg_hba.conf bind mount"

# 13. TEST DATABASE FROM KIND
echo "Testing database connection from Kind..."
docker exec multi-tenant-control-plane bash -c "
  apt-get update -qq && apt-get install -y -qq postgresql-client
  PGPASSWORD=secret123 psql -h 172.20.20.15 -U api -d techstore -c 'SELECT COUNT(*) FROM products;'
"
# Expected: 16 products

# =============================================================================
# PART 3: MULTI-TENANT PLATFORM SETUP
# =============================================================================

echo "🏢 PART 3: Multi-Tenant Platform Setup"

# 14. DEPLOY MULTI-TENANT FOUNDATION
echo "Deploying multi-tenant foundation..."
kubectl apply -f multi-tenant-config/01-foundation/
kubectl apply -f multi-tenant-config/02-security/

# 15. VERIFICA NAMESPACES
echo "Verifying namespaces..."
kubectl get namespaces | grep team-
# Expected: team-frontend, team-backend, team-platform

# 16. VERIFICA RBAC & QUOTAS
echo "Verifying RBAC and quotas..."
kubectl get serviceaccounts -A | grep team-
kubectl get resourcequota -A
kubectl get networkpolicy -A

# 17. BUILD & DEPLOY APPLICATIONS
echo "Building applications..."
cd applications/frontend/react-store-demo && docker build -t react-store:latest .
cd ../../../applications/backend/users-api && docker build -t users-api:latest .
cd ../../..

# 18. LOAD IMAGES IN KIND
echo "Loading images in Kind..."
kind load docker-image react-store:latest --name multi-tenant
kind load docker-image users-api:latest --name multi-tenant

# 19. DEPLOY WORKLOADS
echo "Deploying workloads..."
kubectl apply -f kubernetes/workloads/frontend/
kubectl apply -f kubernetes/workloads/backend/
kubectl apply -f kubernetes/enterprise/

# 20. WAIT FOR PODS
echo "🔍 Waiting for pods deployment..."
echo "Watch pods: kubectl get pods -A -w"
echo "Wait until all team-frontend and team-backend pods are Running, then press Ctrl+C"

# 21. VERIFICA DEPLOYMENT
echo "Verifying deployment..."
kubectl get pods -n team-frontend
kubectl get pods -n team-backend
# Expected: tutti 1/1 Running

# 22. VERIFICA ENTERPRISE FEATURES
echo "Verifying enterprise features..."
kubectl get hpa -A
kubectl get pdb -A
# Expected: HPA e PDB attivi

# =============================================================================
# PART 4: ACCESS SETUP & TESTING
# =============================================================================

echo "🌐 PART 4: Access Setup & Testing"

# 23. SETUP ACCESS
echo "Setting up port-forwards..."
pkill -f "port-forward" 2>/dev/null || true
kubectl port-forward -n team-backend svc/users-api 3001:3000 &
kubectl port-forward -n team-frontend svc/react-store 3000:3000 &

# 24. WAIT FOR PORT-FORWARD
echo "Waiting for port-forwards to establish..."
sleep 5

# 25. TEST BACKEND INTERNAL
echo "Testing backend internal catalog..."
curl http://localhost:3001/api/health
curl http://localhost:3001/api/products

# 26. TEST BACKEND EXTERNAL DATABASE
echo "Testing backend external database..."
curl http://localhost:3001/api/products/external
curl http://localhost:3001/api/db-test

# 27. TEST FRONTEND
echo "Testing frontend..."
echo "Opening frontend: http://localhost:3000"
# open http://localhost:3000  # Uncomment on macOS

# =============================================================================
# PART 5: DEMO SCENARIOS
# =============================================================================

echo "🎬 PART 5: Demo Scenarios"

# 28. DEMO LOAD BALANCING
echo "🎯 LOAD BALANCING DEMO"
echo "Testing load balancing across backend pods..."
for i in {1..5}; do
    echo -n "Request $i: "
    kubectl run curl-test-$i --image=curlimages/curl --rm -i --restart=Never --quiet -- \
        curl -s http://users-api.team-backend.svc.cluster.local:3000/api/server-info 2>/dev/null | \
        grep -o '"hostname":"[^"]*"' | cut -d'"' -f4 || echo "failed"
    sleep 1
done

# 29. DEMO NETWORK ISOLATION
echo "🛡️ NETWORK ISOLATION DEMO"
echo "Testing network isolation (should timeout)..."
kubectl run curl-test --image=curlimages/curl -n team-frontend --rm -it --restart=Never -- \
    curl --max-time 5 http://users-api.team-backend.svc.cluster.local:3000/api/health || echo "Correctly blocked by network policy"

# 30. DEMO DATABASE SOURCE DISTINCTION
echo "🗄️ DATABASE SOURCE DEMO"
echo "Internal catalog source:"
curl -s http://localhost:3001/api/products | jq '.metadata.source'

echo "External database source:"
curl -s http://localhost:3001/api/products/external | jq '.metadata.source'

# 31. DEMO INFRASTRUCTURE RESILIENCE
echo "🔥 INFRASTRUCTURE RESILIENCE DEMO"
echo "Normal state - external database:"
curl -s http://localhost:3001/api/products/external | jq '.metadata.connection_status'

echo "Simulating spine1 failure..."
docker stop clab-topology-spine1

echo "Database still reachable via management network:"
curl -s http://localhost:3001/api/products/external | jq '.metadata.connection_status'

echo "Restoring spine1..."
docker start clab-topology-spine1

echo "✅ DEMO READY!"
echo "Frontend: http://localhost:3000"
echo "Backend: http://localhost:3001"
echo ""
echo "🎯 Available Demo Endpoints:"
echo "  GET /api/products - Internal catalog (4 products)"
echo "  GET /api/products/external - External PostgreSQL (15+ products)"
echo "  GET /api/server-info - Load balancing demo"
echo "  GET /api/db-test - Database connection test"
echo "  GET /api/health - Health check"

# =============================================================================
# VERIFICATION COMMANDS
# =============================================================================

echo ""
echo "🔍 VERIFICATION COMMANDS:"
echo "  kubectl get pods -A                          # All pods status"
echo "  kubectl get nodes -o wide                    # Nodes status"
echo "  docker ps | grep clab                        # ContainerLab containers"
echo "  kubectl get networkpolicy -A                 # Network policies"
echo "  kubectl get resourcequota -A                 # Resource quotas"
echo "  curl http://localhost:3001/api/products      # Internal products"
echo "  curl http://localhost:3001/api/products/external  # External products"

echo ""
echo "🎉 MULTI-TENANT PLATFORM WITH EXTERNAL DATABASE SETUP COMPLETE!"