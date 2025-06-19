#!/bin/bash

# ArgoCD Installation Script for Kubernetes v1.28
set -e

echo "🚀 Installing ArgoCD on Kubernetes cluster..."

# Configuration
ARGOCD_NAMESPACE="argocd"
ARGOCD_VERSION="v2.8.4"  # Compatible with k8s v1.28
ARGOCD_SERVER_PORT="30080"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Function to create namespace
create_namespace() {
    print_status "Creating ArgoCD namespace..."
    kubectl create namespace $ARGOCD_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
}

# Function to install ArgoCD
install_argocd() {
    print_status "Installing ArgoCD $ARGOCD_VERSION..."
    
    # Download and apply ArgoCD manifests
    kubectl apply -n $ARGOCD_NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml
    
    # Wait for ArgoCD components to be ready
    print_status "Waiting for ArgoCD components to be ready..."
    kubectl wait --namespace=$ARGOCD_NAMESPACE \
        --for=condition=available \
        --timeout=600s \
        deployment/argocd-server
        
    kubectl wait --namespace=$ARGOCD_NAMESPACE \
        --for=condition=available \
        --timeout=600s \
        deployment/argocd-repo-server
        
    kubectl wait --namespace=$ARGOCD_NAMESPACE \
        --for=condition=available \
        --timeout=600s \
        deployment/argocd-dex-server
}

# Function to expose ArgoCD server
expose_argocd() {
    print_status "Exposing ArgoCD server..."
    
    # Create NodePort service for external access
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: argocd-server-nodeport
  namespace: $ARGOCD_NAMESPACE
  labels:
    app.kubernetes.io/component: server
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
spec:
  type: NodePort
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: 8080
    nodePort: $ARGOCD_SERVER_PORT
  - name: https
    port: 443
    protocol: TCP
    targetPort: 8080
    nodePort: 30443
  selector:
    app.kubernetes.io/name: argocd-server
EOF
}

# Function to configure ArgoCD
configure_argocd() {
    print_status "Configuring ArgoCD..."
    
    # Update ArgoCD server configuration to disable TLS for NodePort
    kubectl patch configmap argocd-cmd-params-cm -n $ARGOCD_NAMESPACE --type merge -p '{
        "data": {
            "server.insecure": "true"
        }
    }'
    
    # Restart ArgoCD server to apply config changes
    kubectl rollout restart deployment/argocd-server -n $ARGOCD_NAMESPACE
    kubectl rollout status deployment/argocd-server -n $ARGOCD_NAMESPACE
}

# Function to create RBAC configuration
create_rbac() {
    print_status "Creating ArgoCD RBAC configuration..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: $ARGOCD_NAMESPACE
  labels:
    app.kubernetes.io/name: argocd-rbac-cm
    app.kubernetes.io/part-of: argocd
data:
  policy.default: role:admin
  policy.csv: |
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    p, role:admin, certificates, *, *, allow
    p, role:admin, accounts, *, *, allow
    p, role:admin, gpgkeys, *, *, allow
    g, argocd-admin, role:admin
EOF
}

# Function to get ArgoCD admin password
get_admin_password() {
    print_status "Retrieving ArgoCD admin password..."
    
    # Wait for secret to be created
    kubectl wait --namespace=$ARGOCD_NAMESPACE \
        --for=condition=Ready \
        --timeout=300s \
        secret/argocd-initial-admin-secret 2>/dev/null || true
    
    # Get the admin password
    ADMIN_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n $ARGOCD_NAMESPACE -o jsonpath="{.data.password}" | base64 -d)
    
    if [ -z "$ADMIN_PASSWORD" ]; then
        print_warning "Could not retrieve admin password from secret, using default method..."
        ADMIN_PASSWORD=$(kubectl get pods -n $ARGOCD_NAMESPACE -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2)
    fi
}

# Function to install ArgoCD CLI
install_argocd_cli() {
    print_status "Installing ArgoCD CLI..."
    
    # Download ArgoCD CLI
    curl -sSL -o /tmp/argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/$ARGOCD_VERSION/argocd-linux-amd64
    sudo install -m 555 /tmp/argocd-linux-amd64 /usr/local/bin/argocd
    rm /tmp/argocd-linux-amd64
    
    # Verify installation
    argocd version --client
}

# Function to test ArgoCD installation
test_argocd() {
    print_status "Testing ArgoCD installation..."
    
    # Check pods
    kubectl get pods -n $ARGOCD_NAMESPACE
    
    # Check services
    kubectl get services -n $ARGOCD_NAMESPACE
    
    # Test API endpoint
    sleep 10
    curl -f http://sanzad-ubuntu-21:$ARGOCD_SERVER_PORT/api/version || print_warning "API endpoint test failed"
}

# Function to create sample application
create_sample_app() {
    print_status "Creating sample ArgoCD application..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-app
  namespace: $ARGOCD_NAMESPACE
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
}

# Function to display usage information
show_usage() {
    print_status "ArgoCD Installation Complete!"
    echo ""
    echo "ArgoCD Information:"
    echo "  - Web UI: http://sanzad-ubuntu-21:$ARGOCD_SERVER_PORT"
    echo "  - Username: admin"
    echo "  - Password: $ADMIN_PASSWORD"
    echo ""
    echo "ArgoCD CLI Login:"
    echo "  argocd login sanzad-ubuntu-21:$ARGOCD_SERVER_PORT --insecure"
    echo ""
    echo "Useful Commands:"
    echo "  # List applications"
    echo "  argocd app list"
    echo ""
    echo "  # Sync an application"
    echo "  argocd app sync <app-name>"
    echo ""
    echo "  # Create an application"
    echo "  argocd app create <app-name> --repo <repo-url> --path <path> --dest-server https://kubernetes.default.svc --dest-namespace <namespace>"
    echo ""
}

# Main execution
main() {
    print_status "Starting ArgoCD installation..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Execute installation steps
    create_namespace
    install_argocd
    expose_argocd
    configure_argocd
    create_rbac
    get_admin_password
    install_argocd_cli
    test_argocd
    create_sample_app
    show_usage
    
    print_status "🎉 ArgoCD installation completed successfully!"
}

# Script execution
main "$@" 