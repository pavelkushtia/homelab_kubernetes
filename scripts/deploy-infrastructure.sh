#!/bin/bash

# Master Infrastructure Deployment Script
set -e

echo "🚀 Deploying Complete Infrastructure Stack..."

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
# SUDO_PASS - Will prompt interactively for security

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check if cluster has nodes
    NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
    if [ "$NODE_COUNT" -lt 1 ]; then
        print_error "No nodes found in cluster"
        exit 1
    fi
    
    print_status "✅ Prerequisites check passed"
    echo "Cluster Info:"
    kubectl cluster-info
    echo ""
    kubectl get nodes
    echo ""
}

# Function to deploy container registry
deploy_container_registry() {
    print_header "Deploying Container Registry"
    
    cd "$PROJECT_ROOT/infrastructure/container-registry"
    chmod +x setup-registry.sh
    ./setup-registry.sh
    
    print_status "✅ Container Registry deployed successfully"
}

# Function to deploy ArgoCD
deploy_argocd() {
    print_header "Deploying ArgoCD"
    
    cd "$PROJECT_ROOT/infrastructure/argocd"
    chmod +x install-argocd.sh
    ./install-argocd.sh
    
    print_status "✅ ArgoCD deployed successfully"
}

# Function to deploy Helm repository
deploy_helm_repository() {
    print_header "Deploying Helm Repository (ChartMuseum)"
    
    cd "$PROJECT_ROOT/infrastructure/helm-repository"
    chmod +x setup-chart-museum.sh
    ./setup-chart-museum.sh
    
    print_status "✅ Helm Repository deployed successfully"
}

# Function to setup library charts
setup_library_charts() {
    print_header "Setting up Library Charts"
    
    cd "$PROJECT_ROOT/infrastructure/helm-repository/library-charts"
    
    # Package microservice library chart
    print_status "Packaging microservice library chart..."
    helm package microservice/
    
    # Upload to ChartMuseum
    print_status "Uploading library charts to repository..."
    curl --data-binary "@microservice-1.0.0.tgz" http://sanzad-ubuntu-21:30800/api/charts
    
    # Update Helm repo
    helm repo update
    
    # Verify charts are available
    helm search repo local
    
    print_status "✅ Library charts setup completed"
}

# Function to deploy sample application
deploy_sample_application() {
    print_header "Deploying Sample Application"
    
    cd "$PROJECT_ROOT/applications/sample-microservice"
    
    # Create sample Docker image for testing
    print_status "Creating sample application image..."
    mkdir -p /tmp/sample-app
    
    cat > /tmp/sample-app/Dockerfile <<EOF
FROM node:18-alpine
WORKDIR /app
COPY package.json .
RUN npm install
COPY . .
EXPOSE 8080
CMD ["npm", "start"]
EOF

    cat > /tmp/sample-app/package.json <<EOF
{
  "name": "sample-api",
  "version": "1.0.0",
  "description": "Sample API for testing",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.0"
  }
}
EOF

    cat > /tmp/sample-app/server.js <<EOF
const express = require('express');
const app = express();
const PORT = process.env.PORT || 8080;

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.get('/ready', (req, res) => {
  res.json({ status: 'ready', timestamp: new Date().toISOString() });
});

app.get('/', (req, res) => {
  res.json({ 
    message: 'Sample Microservice API',
    version: '1.0.0',
    env: process.env.NODE_ENV || 'development'
  });
});

app.listen(PORT, () => {
  console.log(\`Sample API server running on port \${PORT}\`);
});
EOF

    # Build and push sample image
    cd /tmp/sample-app
    echo "$SUDO_PASS" | sudo -S docker build -t sanzad-ubuntu-21:30500/sample/api:1.0.0 .
    echo "$SUDO_PASS" | sudo -S docker push sanzad-ubuntu-21:30500/sample/api:1.0.0
    
    # Clean up
    rm -rf /tmp/sample-app
    
    # Deploy using Helm
    cd "$PROJECT_ROOT/applications/sample-microservice"
    helm dependency update
    helm upgrade --install sample-app . --namespace sample-app --create-namespace
    
    print_status "✅ Sample application deployed successfully"
}

# Function to create ArgoCD application for sample app
create_argocd_application() {
    print_header "Creating ArgoCD Application"
    
    cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-microservice
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: file://$(realpath "$PROJECT_ROOT")
    targetRevision: HEAD
    path: applications/sample-microservice
  destination:
    server: https://kubernetes.default.svc
    namespace: sample-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

    print_status "✅ ArgoCD application created"
}

# Function to display final status
show_final_status() {
    print_header "Infrastructure Deployment Complete!"
    
    echo "🎉 All components deployed successfully!"
    echo ""
    echo "📊 Access Information:"
    echo "  • Container Registry: http://sanzad-ubuntu-21:30500"
    echo "  • ArgoCD Web UI: http://sanzad-ubuntu-21:30080"
    echo "  • Helm Repository: http://sanzad-ubuntu-21:30800"
    echo ""
    echo "🔐 Credentials:"
    echo "  • ArgoCD Username: admin"
    ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Check ArgoCD pod name")
    echo "  • ArgoCD Password: $ARGOCD_PASSWORD"
    echo ""
    echo "📚 Quick Commands:"
    echo "  # View all infrastructure"
    echo "  kubectl get pods --all-namespaces"
    echo ""
    echo "  # Check sample application"
    echo "  kubectl get pods -n sample-app"
    echo ""
    echo "  # Access sample API"
    echo "  kubectl port-forward -n sample-app svc/sample-api 8080:80"
    echo "  # Then visit: http://localhost:8080"
    echo ""
    echo "  # List available Helm charts"
    echo "  helm search repo local"
    echo ""
    
    # Show current cluster status
    echo "🔍 Current Cluster Status:"
    kubectl get pods --all-namespaces | grep -E "(container-registry|argocd|helm-repository|sample-app)"
}

# Main execution
main() {
    print_header "Starting Infrastructure Deployment"
    
    check_prerequisites
    deploy_container_registry
    deploy_argocd
    deploy_helm_repository
    setup_library_charts
    deploy_sample_application
    create_argocd_application
    show_final_status
    
    print_status "🚀 Infrastructure deployment completed successfully!"
}

# Handle script interruption
trap 'print_error "Deployment interrupted"; exit 1' INT TERM

# Script execution
main "$@" 