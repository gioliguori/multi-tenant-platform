# fatto da claude ma utile

#!/bin/bash
# 🔍 MULTI-TENANT KUBERNETES PLATFORM - COMPLETE VERIFICATION
# Comprehensive testing script before GitHub push

echo "🔍 Starting Multi-Tenant Platform Verification..."
echo "================================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Helper functions
pass() {
    echo -e "${GREEN}✅ PASS:${NC} $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "${RED}❌ FAIL:${NC} $1"
    FAILED=$((FAILED + 1))
}

warn() {
    echo -e "${YELLOW}⚠️  WARN:${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

info() {
    echo -e "${BLUE}ℹ️  INFO:${NC} $1"
}

# =============================================================================
# 1. CLUSTER HEALTH CHECK
# =============================================================================

echo ""
echo "🏗️ SECTION 1: CLUSTER HEALTH"
echo "=========================="

# Check cluster exists
if kind get clusters | grep -q "multi-tenant"; then
    pass "Kind cluster 'multi-tenant' exists"
else
    fail "Kind cluster 'multi-tenant' not found"
    echo "Run: kind create cluster --name multi-tenant --config kind-config.yaml"
    exit 1
fi

# Check nodes
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
if [ "$NODE_COUNT" -eq 3 ]; then
    pass "Cluster has 3 nodes (1 control-plane + 2 workers)"
else
    fail "Expected 3 nodes, found $NODE_COUNT"
fi

# Check nodes are Ready
NOT_READY=$(kubectl get nodes --no-headers | grep -v " Ready " | wc -l)
if [ "$NOT_READY" -eq 0 ]; then
    pass "All nodes are Ready"
else
    fail "$NOT_READY nodes are not Ready"
    kubectl get nodes
fi

# Check Calico
CALICO_PODS=$(kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers | grep "Running" | wc -l)
if [ "$CALICO_PODS" -eq 3 ]; then
    pass "Calico CNI is running on all nodes"
else
    fail "Calico CNI issues: only $CALICO_PODS/3 pods running"
fi

# =============================================================================
# 2. METRICS SERVER CHECK
# =============================================================================

echo ""
echo "📊 SECTION 2: METRICS SERVER"
echo "=========================="

# Check Metrics Server pod
if kubectl get pods -n kube-system -l k8s-app=metrics-server --no-headers | grep -q "Running"; then
    pass "Metrics Server pod is running"
else
    fail "Metrics Server pod is not running"
fi

# Check node metrics
if kubectl top nodes >/dev/null 2>&1; then
    pass "Node metrics are available"
else
    fail "Node metrics not available - HPA will not work"
fi

# Check pod metrics
if kubectl top pods -A >/dev/null 2>&1; then
    pass "Pod metrics are available"
else
    fail "Pod metrics not available"
fi

# =============================================================================
# 3. MULTI-TENANT FOUNDATION
# =============================================================================

echo ""
echo "🏢 SECTION 3: MULTI-TENANT FOUNDATION"
echo "=================================="

# Check namespaces
for ns in team-frontend team-backend team-platform; do
    if kubectl get namespace "$ns" >/dev/null 2>&1; then
        pass "Namespace $ns exists"
    else
        fail "Namespace $ns missing"
    fi
done

# Check ServiceAccounts
for sa in team-frontend-sa team-backend-sa team-platform-sa; do
    ns=$(echo $sa | cut -d'-' -f1-2)
    if kubectl get sa "$sa" -n "$ns" >/dev/null 2>&1; then
        pass "ServiceAccount $sa exists in $ns"
    else
        fail "ServiceAccount $sa missing in $ns"
    fi
done

# Check ResourceQuotas
QUOTAS=$(kubectl get resourcequota -A --no-headers | wc -l)
if [ "$QUOTAS" -ge 3 ]; then
    pass "ResourceQuotas configured ($QUOTAS found)"
else
    fail "Insufficient ResourceQuotas ($QUOTAS found, expected ≥3)"
fi

# Check NetworkPolicies
NETPOLS=$(kubectl get networkpolicy -A --no-headers | wc -l)
if [ "$NETPOLS" -ge 5 ]; then
    pass "NetworkPolicies configured ($NETPOLS found)"
else
    warn "Few NetworkPolicies ($NETPOLS found, expected ≥5)"
fi

# =============================================================================
# 4. APPLICATION DEPLOYMENT
# =============================================================================

echo ""
echo "📦 SECTION 4: APPLICATION DEPLOYMENT"
echo "================================"

# Check PostgreSQL
PG_READY=$(kubectl get pods -n team-backend -l app=postgresql --no-headers | grep "Running" | wc -l)
if [ "$PG_READY" -eq 1 ]; then
    pass "PostgreSQL is running"
else
    fail "PostgreSQL not running ($PG_READY/1 pods ready)"
fi

# Check Backend API
BACKEND_READY=$(kubectl get pods -n team-backend -l app=users-api --no-headers | grep "Running" | wc -l)
BACKEND_EXPECTED=$(kubectl get deployment users-api -n team-backend -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
if [ "$BACKEND_READY" -eq "$BACKEND_EXPECTED" ] && [ "$BACKEND_READY" -gt 0 ]; then
    pass "Backend API is running ($BACKEND_READY/$BACKEND_EXPECTED pods ready)"
else
    fail "Backend API issues ($BACKEND_READY/$BACKEND_EXPECTED pods ready)"
fi

# Check Frontend
FRONTEND_READY=$(kubectl get pods -n team-frontend -l app=react-store --no-headers | grep "Running" | wc -l)
FRONTEND_EXPECTED=$(kubectl get deployment react-store -n team-frontend -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
if [ "$FRONTEND_READY" -eq "$FRONTEND_EXPECTED" ] && [ "$FRONTEND_READY" -gt 0 ]; then
    pass "Frontend is running ($FRONTEND_READY/$FRONTEND_EXPECTED pods ready)"
else
    fail "Frontend issues ($FRONTEND_READY/$FRONTEND_EXPECTED pods ready)"
fi

# =============================================================================
# 5. ENTERPRISE FEATURES
# =============================================================================

echo ""
echo "🚀 SECTION 5: ENTERPRISE FEATURES"
echo "=============================="

# Check HPA
HPA_COUNT=$(kubectl get hpa -A --no-headers | wc -l)
if [ "$HPA_COUNT" -ge 2 ]; then
    pass "HPA configured ($HPA_COUNT found)"
    
    # Check HPA has real metrics (not <unknown>)
    if kubectl get hpa -A | grep -q "<unknown>"; then
        fail "HPA shows <unknown> metrics - Metrics Server issue"
    else
        pass "HPA shows real CPU/Memory metrics"
    fi
else
    fail "HPA not configured ($HPA_COUNT found, expected ≥2)"
fi

# Check PDB
PDB_COUNT=$(kubectl get pdb -A --no-headers | wc -l)
if [ "$PDB_COUNT" -ge 2 ]; then
    pass "PodDisruptionBudgets configured ($PDB_COUNT found)"
else
    fail "PDB not configured ($PDB_COUNT found, expected ≥2)"
fi

# =============================================================================
# 6. MONITORING STACK
# =============================================================================

echo ""
echo "📊 SECTION 6: MONITORING STACK"
echo "============================"

# Check Prometheus
if kubectl get pods -n team-platform -l app.kubernetes.io/name=prometheus --no-headers | grep -q "Running"; then
    pass "Prometheus is running"
else
    fail "Prometheus not running"
fi

# Check Grafana
if kubectl get pods -n team-platform -l app.kubernetes.io/name=grafana --no-headers | grep -q "Running"; then
    pass "Grafana is running"
else
    fail "Grafana not running"
fi

# Check ServiceMonitors
SM_COUNT=$(kubectl get servicemonitor -A --no-headers 2>/dev/null | wc -l)
if [ "$SM_COUNT" -gt 0 ]; then
    pass "ServiceMonitors configured ($SM_COUNT found)"
else
    warn "No ServiceMonitors found"
fi

# =============================================================================
# 7. ACCESS & CONNECTIVITY
# =============================================================================

echo ""
echo "🌐 SECTION 7: ACCESS & CONNECTIVITY"
echo "==============================="

# Check port-forwards are running
if pgrep -f "kubectl port-forward" >/dev/null; then
    pass "Port-forwards are active"
    
    # Test each service
    if curl -s http://localhost:3001/api/health >/dev/null 2>&1; then
        pass "Backend API accessible (http://localhost:3001)"
    else
        fail "Backend API not accessible"
    fi
    
    if curl -s http://localhost:3000 >/dev/null 2>&1; then
        pass "Frontend accessible (http://localhost:3000)"
    else
        fail "Frontend not accessible"
    fi
    
    if curl -s http://localhost:9090/-/healthy >/dev/null 2>&1; then
        pass "Prometheus accessible (http://localhost:9090)"
    else
        fail "Prometheus not accessible"
    fi
    
    if curl -s -u admin:admin123 http://localhost:3002/api/health >/dev/null 2>&1; then
        pass "Grafana accessible (http://localhost:3002)"
    else
        fail "Grafana not accessible"
    fi
else
    fail "No port-forwards running - services not accessible locally"
    info "Run: kubectl port-forward commands to enable local access"
fi

# =============================================================================
# 8. SECURITY VALIDATION
# =============================================================================

echo ""
echo "🔐 SECTION 8: SECURITY VALIDATION"
echo "=============================="

# Test RBAC isolation
RBAC_TEST=$(kubectl auth can-i get pods --namespace=team-backend --as=system:serviceaccount:team-frontend:team-frontend-sa 2>/dev/null)
if [ "$RBAC_TEST" = "no" ]; then
    pass "RBAC isolation working (frontend cannot access backend)"
else
    fail "RBAC isolation broken (frontend can access backend)"
fi

# Check Pod Security Standards
PSS_VIOLATIONS=$(kubectl get events -A | grep "violates PodSecurity" | wc -l)
if [ "$PSS_VIOLATIONS" -eq 0 ]; then
    pass "No Pod Security Standards violations"
else
    warn "$PSS_VIOLATIONS Pod Security Standards violations found"
fi

# =============================================================================
# 9. FUNCTIONAL TESTS
# =============================================================================

echo ""
echo "🧪 SECTION 9: FUNCTIONAL TESTS"
echo "============================"

# Test database connectivity
if curl -s http://localhost:3001/api/db-test | grep -q '"status":"success"' 2>/dev/null; then
    pass "Database connectivity test passed"
else
    fail "Database connectivity test failed"
fi

# Test API endpoints
if curl -s http://localhost:3001/api/products | grep -q '"products"' 2>/dev/null; then
    pass "Products API endpoint working"
else
    fail "Products API endpoint not working"
fi

# Test metrics endpoint
if curl -s http://localhost:3001/metrics | grep -q "http_requests_total" 2>/dev/null; then
    pass "Custom metrics endpoint working"
else
    fail "Custom metrics endpoint not working"
fi

# =============================================================================
# 10. DOCKER IMAGES CHECK
# =============================================================================

echo ""
echo "🐳 SECTION 10: DOCKER IMAGES"
echo "=========================="

# Check images exist in Kind
if docker exec multi-tenant-control-plane crictl images | grep -q "react-store"; then
    pass "Frontend image loaded in Kind"
else
    fail "Frontend image not found in Kind"
fi

if docker exec multi-tenant-control-plane crictl images | grep -q "users-api"; then
    pass "Backend image loaded in Kind"
else
    fail "Backend image not found in Kind"
fi

# =============================================================================
# SUMMARY REPORT
# =============================================================================

echo ""
echo "📋 VERIFICATION SUMMARY"
echo "======================"
echo -e "✅ ${GREEN}PASSED:${NC} $PASSED"
echo -e "❌ ${RED}FAILED:${NC} $FAILED"
echo -e "⚠️  ${YELLOW}WARNINGS:${NC} $WARNINGS"
echo ""

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
    echo -e "${GREEN}✅ Platform is ready for production demo${NC}"
    echo -e "${GREEN}✅ Safe to push to GitHub${NC}"
    echo ""
    echo "🌐 Access URLs:"
    echo "  Frontend:    http://localhost:3000"
    echo "  Backend API: http://localhost:3001"
    echo "  Grafana:     http://localhost:3002 (admin/admin123)"
    echo "  Prometheus:  http://localhost:9090"
    echo ""
    echo "🎯 Ready for demo scenarios:"
    echo "  1. RBAC Isolation Test"
    echo "  2. Network Policy Test"
    echo "  3. Resource Quota Test"
    echo "  4. Load Balancing Test"
    echo "  5. Auto-scaling (HPA) Test"
    exit 0
else
    echo -e "${RED}❌ $FAILED TESTS FAILED${NC}"
    echo -e "${RED}🚫 NOT READY for GitHub push${NC}"
    echo ""
    echo "🔧 Fix the failed tests before proceeding"
    exit 1
fi