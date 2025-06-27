#!/bin/bash
# 🚀 Multi-Tenant Platform - Quick Setup Script
# Esegue l'installazione completa in modo automatizzato

set -e  # Exit on error

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funzioni helper
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    command -v docker >/dev/null 2>&1 || { log_error "Docker required but not installed."; exit 1; }
    command -v kind >/dev/null 2>&1 || { log_error "Kind required but not installed."; exit 1; }
    command -v kubectl >/dev/null 2>&1 || { log_error "kubectl required but not installed."; exit 1; }
    command -v helm >/dev/null 2>&1 || { log_error "Helm required but not installed."; exit 1; }
    
    log_info "All prerequisites satisfied ✓"
}

# Cleanup precedente
cleanup_previous() {
    log_info "Cleaning up previous installation..."
    
    pkill -f 'port-forward' 2>/dev/null || true
    kind delete cluster --name multi-tenant 2>/dev/null || true
    
    log_info "Cleanup completed ✓"
}

# Wait for condition
wait_for() {
    local name=$1
    local check_command=$2
    local max_attempts=30
    local attempt=0
    
    log_info "Waiting for $name..."
    
    while [ $attempt -lt $max_attempts ]; do
        if eval $check_command; then
            log_info "$name ready ✓"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done
    
    log_error "$name failed to become ready"
    return 1
}

# MAIN SETUP
main() {
    log_info "🚀 Starting Multi-Tenant Platform Setup..."
    
    check_prerequisites
    cleanup_previous
    
    # Step 1: ContainerLab
    log_warn "⚠️  Make sure ContainerLab is running in DevContainer!"
    read -p "Is ContainerLab already deployed? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "Please deploy ContainerLab first in DevContainer:"
        echo "sudo containerlab deploy -t topology.clab.yml"
        exit 1
    fi
    
    # Step 2: Kind Cluster
    log_info "Creating Kind cluster..."
    kind create cluster --name multi-tenant --config kind-config.yaml
    
    # Step 3: Connect Networks
    log_info "Connecting networks..."
    for node in control-plane worker worker2; do
        docker network connect clab multi-tenant-$node 2>/dev/null || true
        
        docker exec multi-tenant-$node bash -c "
            apt-get update -qq && apt-get install -y -qq iputils-ping iproute2
            ip route add 192.168.101.0/24 via 172.20.20.6
            ip route add 192.168.102.0/24 via 172.20.20.7
            sysctl -w net.ipv4.ip_forward=1
        " >/dev/null 2>&1
    done
    
    # Step 4: Install CNI
    log_info "Installing Calico CNI..."
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/calico.yaml >/dev/null
    
    wait_for "Calico pods" "kubectl get pods -n kube-system | grep calico | grep -v Running; [ \$? -eq 1 ]"
    wait_for "Nodes ready" "kubectl get nodes | grep -v Ready | grep -v NAME; [ \$? -eq 1 ]"
    
    # Step 5: Multi-tenant Foundation
    log_info "Deploying multi-tenant foundation..."
    kubectl apply -f multi-tenant-config/01-foundation/ >/dev/null
    kubectl apply -f multi-tenant-config/02-security/ >/dev/null
    
    # Step 6: Build & Deploy Apps
    log_info "Building applications..."
    docker build -t react-store:latest applications/frontend/react-store-demo/ >/dev/null 2>&1
    docker build -t users-api:latest applications/backend/users-api/ >/dev/null 2>&1
    
    log_info "Loading images to Kind..."
    kind load docker-image react-store:latest --name multi-tenant
    kind load docker-image users-api:latest --name multi-tenant
    
    log_info "Deploying workloads..."
    kubectl apply -f kubernetes/workloads/frontend/ >/dev/null
    kubectl apply -f kubernetes/workloads/backend/ >/dev/null
    kubectl apply -f kubernetes/enterprise/ >/dev/null
    
    wait_for "Application pods" "kubectl get pods -n team-frontend | grep -v Running | grep -v NAME; [ \$? -eq 1 ]"
    
    # Step 7: Monitoring Stack
    log_info "Setting up monitoring..."
    
    # Create dashboard ConfigMap
    kubectl create configmap grafana-platform-dashboards \
        --from-file=monitoring/dashboards/ \
        -n team-platform \
        --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    
    kubectl label configmap grafana-platform-dashboards \
        grafana_dashboard=1 -n team-platform --overwrite >/dev/null
    
    # Install Prometheus
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1
    helm repo update >/dev/null 2>&1
    
    log_info "Installing Prometheus stack (this may take a few minutes)..."
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace team-platform \
        --values monitoring/helm-values/prometheus-stack-values.yaml \
        --wait --timeout 10m >/dev/null
    
    # Deploy ServiceMonitor
    kubectl apply -f kubernetes/monitoring/ >/dev/null 2>&1 || true
    
    # Step 8: Setup Access
    log_info "Setting up port forwards..."
    kubectl port-forward -n team-backend svc/users-api 3001:3000 >/dev/null 2>&1 &
    kubectl port-forward -n team-frontend svc/react-store 3000:3000 >/dev/null 2>&1 &
    kubectl port-forward svc/prometheus-grafana 3002:80 -n team-platform >/dev/null 2>&1 &
    kubectl port-forward svc/prometheus-prometheus 9090:9090 -n team-platform >/dev/null 2>&1 &
    
    sleep 5
    
    # Step 9: Verification
    log_info "Verifying services..."
    
    curl -s http://localhost:3001/api/health >/dev/null && log_info "Backend API ✓" || log_error "Backend API ✗"
    curl -s http://localhost:3000 >/dev/null && log_info "Frontend ✓" || log_error "Frontend ✗"
    curl -s -u admin:admin123 http://localhost:3002/api/health >/dev/null && log_info "Grafana ✓" || log_error "Grafana ✗"
    curl -s http://localhost:9090/-/healthy >/dev/null && log_info "Prometheus ✓" || log_error "Prometheus ✗"
    
    # Generate initial traffic
    log_info "Generating initial traffic for metrics..."
    for i in {1..10}; do
        curl -s http://localhost:3001/api/products/external >/dev/null || true
        sleep 1
    done
    
    # Success!
    echo
    log_info "🎉 SETUP COMPLETED SUCCESSFULLY! 🎉"
    echo
    echo "📍 Access points:"
    echo "   Frontend:   http://localhost:3000"
    echo "   Backend:    http://localhost:3001"
    echo "   Grafana:    http://localhost:3002 (admin/admin123)"
    echo "   Prometheus: http://localhost:9090"
    echo
    echo "📚 Next steps:"
    echo "   - Open Grafana and explore dashboards"
    echo "   - Run demo scenarios from documentation"
    echo "   - Check 'kubectl get pods -A' for pod status"
    echo
}

# Run main function
main "$@"