#!/bin/bash

# KubeRay Deployment Script using Official Helm Charts
set -e

echo "🚀 Deploying KubeRay using Official Helm Charts..."

# Configuration
KUBERAY_NAMESPACE="kuberay"
OFFICIAL_REPO="https://ray-project.github.io/kuberay-helm/"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if helm is available
    if ! command -v helm &> /dev/null; then
        print_warning "Helm is not installed. Installing Helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    print_status "Prerequisites check passed"
}

# Function to add official KubeRay Helm repository
add_helm_repository() {
    print_step "Adding official KubeRay Helm repository..."
    
    # Add the official KubeRay repository
    helm repo add kuberay $OFFICIAL_REPO
    helm repo update
    
    print_status "Official KubeRay repository added successfully"
}

# Function to create namespace
create_namespace() {
    print_step "Creating KubeRay namespace..."
    kubectl create namespace $KUBERAY_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    print_status "Namespace $KUBERAY_NAMESPACE created/updated"
}

# Function to deploy KubeRay operator
deploy_operator() {
    print_step "Deploying KubeRay operator using official chart..."
    
    # Deploy operator using official Helm chart
    helm install kuberay-operator kuberay/kuberay-operator \
        --namespace $KUBERAY_NAMESPACE \
        --wait \
        --timeout 5m
    
    print_status "KubeRay operator deployed successfully"
}

# Function to wait for operator
wait_for_operator() {
    print_step "Waiting for KubeRay operator to be ready..."
    
    kubectl wait --for=condition=available --timeout=300s \
        deployment/kuberay-operator -n $KUBERAY_NAMESPACE
    
    print_status "KubeRay operator is ready"
}

# Function to deploy Ray cluster
deploy_ray_cluster() {
    print_step "Deploying Ray cluster using official chart..."
    
    # Deploy Ray cluster using official Helm chart
    helm install ray-cluster kuberay/ray-cluster \
        --namespace $KUBERAY_NAMESPACE \
        --wait \
        --timeout 10m
    
    print_status "Ray cluster deployed successfully"
}

# Function to verify deployment
verify_deployment() {
    print_step "Verifying deployment..."
    
    # Check operator
    if kubectl get deployment kuberay-operator -n $KUBERAY_NAMESPACE &> /dev/null; then
        print_status "✅ KubeRay operator is running"
    else
        print_error "❌ KubeRay operator is not running"
        return 1
    fi
    
    # Check Ray cluster
    if kubectl get rayclusters -n $KUBERAY_NAMESPACE &> /dev/null; then
        print_status "✅ Ray cluster is created"
    else
        print_error "❌ Ray cluster is not created"
        return 1
    fi
    
    # Check Ray pods
    RAY_PODS=$(kubectl get pods -n $KUBERAY_NAMESPACE -l ray.io/cluster=raycluster-autoscaler --no-headers | wc -l)
    if [ $RAY_PODS -gt 0 ]; then
        print_status "✅ Ray pods are running ($RAY_PODS pods)"
    else
        print_error "❌ No Ray pods are running"
        return 1
    fi
    
    # Check pod distribution
    print_status "Pod distribution across nodes:"
    kubectl get pods -n $KUBERAY_NAMESPACE -l ray.io/cluster=raycluster-autoscaler -o wide
    
    print_status "✅ Deployment verification completed"
}

# Function to show access information
show_access_info() {
    print_step "Access Information"
    
    echo ""
    echo "🌐 Ray Dashboard:"
    echo "   kubectl port-forward -n $KUBERAY_NAMESPACE svc/raycluster-autoscaler-head-svc 8265:8265"
    echo "   Then open: http://localhost:8265"
    echo ""
    
    echo "📊 Ray Metrics:"
    echo "   kubectl port-forward -n $KUBERAY_NAMESPACE svc/raycluster-autoscaler-head-svc 8080:8080"
    echo "   Then open: http://localhost:8080"
    echo ""
    
    echo "🔗 Ray Client Connection:"
    echo "   ray.init(address=\"ray://raycluster-autoscaler-head-svc.$KUBERAY_NAMESPACE.svc.cluster.local:10001\")"
    echo ""
    
    echo "📋 Useful Commands:"
    echo "   kubectl get rayclusters -n $KUBERAY_NAMESPACE"
    echo "   kubectl get pods -n $KUBERAY_NAMESPACE -l ray.io/cluster=raycluster-autoscaler"
    echo "   kubectl logs -n $KUBERAY_NAMESPACE deployment/kuberay-operator"
    echo ""
}

# Function to show cluster status
show_cluster_status() {
    print_step "Cluster Status"
    
    echo ""
    echo "📊 KubeRay Resources:"
    kubectl get all -n $KUBERAY_NAMESPACE
    
    echo ""
    echo "🏗️ Ray Cluster Details:"
    kubectl get rayclusters -n $KUBERAY_NAMESPACE -o yaml | grep -A 10 "status:"
    
    echo ""
    echo "🌐 Services:"
    kubectl get svc -n $KUBERAY_NAMESPACE
}

# Function to cleanup (if needed)
cleanup() {
    print_step "Cleaning up KubeRay deployment..."
    
    # Delete Ray cluster
    helm uninstall ray-cluster -n $KUBERAY_NAMESPACE || true
    
    # Delete operator
    helm uninstall kuberay-operator -n $KUBERAY_NAMESPACE || true
    
    # Delete namespace
    kubectl delete namespace $KUBERAY_NAMESPACE || true
    
    print_status "Cleanup completed"
}

# Main deployment function
deploy_kuberay() {
    print_status "Starting KubeRay deployment using official charts..."
    
    check_prerequisites
    add_helm_repository
    create_namespace
    deploy_operator
    wait_for_operator
    deploy_ray_cluster
    verify_deployment
    show_access_info
    show_cluster_status
    
    print_status "🎉 KubeRay deployment completed successfully!"
    echo ""
    print_status "Next steps:"
    echo "1. Access the Ray dashboard to monitor your cluster"
    echo "2. Run the sample application: python sample-app.py"
    echo "3. Check the README.md for more usage examples"
    echo "4. Monitor resource usage and adjust scaling as needed"
}

# Parse command line arguments
case "${1:-deploy}" in
    "deploy")
        deploy_kuberay
        ;;
    "cleanup")
        cleanup
        ;;
    "status")
        show_cluster_status
        ;;
    "verify")
        verify_deployment
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [deploy|cleanup|status|verify|help]"
        echo ""
        echo "Commands:"
        echo "  deploy   - Deploy KubeRay using official charts (default)"
        echo "  cleanup  - Remove KubeRay deployment"
        echo "  status   - Show cluster status"
        echo "  verify   - Verify deployment"
        echo "  help     - Show this help message"
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac 