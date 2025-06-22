#!/bin/bash

# ChartMuseum Setup Script for Helm Repository
set -e

echo "🚀 Setting up ChartMuseum for Helm Chart Repository..."

# Configuration
CHARTMUSEUM_NAMESPACE="helm-repository"
CHARTMUSEUM_PORT="30800"
CHARTMUSEUM_VERSION="v0.15.0"

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
    print_status "Creating ChartMuseum namespace..."
    kubectl create namespace $CHARTMUSEUM_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
}

# Function to deploy ChartMuseum
deploy_chartmuseum() {
    print_status "Deploying ChartMuseum..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: chartmuseum-pv
  labels:
    app: chartmuseum
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /opt/chartmuseum-data
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-role
          operator: In
          values:
          - worker

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: chartmuseum-pvc
  namespace: $CHARTMUSEUM_NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-storage

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chartmuseum
  namespace: $CHARTMUSEUM_NAMESPACE
  labels:
    app: chartmuseum
spec:
  replicas: 1
  selector:
    matchLabels:
      app: chartmuseum
  template:
    metadata:
      labels:
        app: chartmuseum
    spec:
      nodeSelector:
        node-role: worker
      containers:
      - name: chartmuseum
        image: chartmuseum/chartmuseum:$CHARTMUSEUM_VERSION
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: DISABLE_API
          value: "false"
        - name: ALLOW_OVERWRITE
          value: "true"
        - name: STORAGE
          value: "local"
        - name: STORAGE_LOCAL_ROOTDIR
          value: "/var/lib/chartmuseum"
        - name: DEBUG
          value: "true"
        volumeMounts:
        - name: chartmuseum-storage
          mountPath: /var/lib/chartmuseum
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          limits:
            cpu: 200m
            memory: 256Mi
          requests:
            cpu: 100m
            memory: 128Mi
      volumes:
      - name: chartmuseum-storage
        persistentVolumeClaim:
          claimName: chartmuseum-pvc

---
apiVersion: v1
kind: Service
metadata:
  name: chartmuseum
  namespace: $CHARTMUSEUM_NAMESPACE
  labels:
    app: chartmuseum
spec:
  selector:
    app: chartmuseum
  ports:
  - name: http
    port: 8080
    targetPort: 8080
    protocol: TCP
  type: ClusterIP

---
apiVersion: v1
kind: Service
metadata:
  name: chartmuseum-external
  namespace: $CHARTMUSEUM_NAMESPACE
  labels:
    app: chartmuseum
spec:
  selector:
    app: chartmuseum
  ports:
  - name: http
    port: 8080
    targetPort: 8080
    nodePort: $CHARTMUSEUM_PORT
    protocol: TCP
  type: NodePort
EOF
}

# Function to create storage directory
create_storage() {
    print_status "Creating ChartMuseum storage directory..."
    sudo mkdir -p /opt/chartmuseum-data
    sudo chmod 755 /opt/chartmuseum-data
}

# Function to install Helm if not present
install_helm() {
    if ! command -v helm &> /dev/null; then
        print_status "Installing Helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    else
        print_status "Helm is already installed"
        helm version
    fi
}

# Function to add ChartMuseum to Helm repos
configure_helm_repo() {
    print_status "Configuring Helm repository..."
    
    # Wait for ChartMuseum to be ready
    kubectl wait --namespace=$CHARTMUSEUM_NAMESPACE \
        --for=condition=available \
        --timeout=300s \
        deployment/chartmuseum
    
    sleep 10
    
    # Add the repository
    helm repo add local http://gpu-node:$CHARTMUSEUM_PORT --force-update
    helm repo update
    
    print_status "✅ ChartMuseum repository added to Helm"
}

# Function to test ChartMuseum
test_chartmuseum() {
    print_status "Testing ChartMuseum..."
    
    # Check if ChartMuseum is responding
    curl -f http://gpu-node:$CHARTMUSEUM_PORT/health || print_warning "ChartMuseum health check failed"
    
    # List charts (should be empty initially)
    curl -f http://gpu-node:$CHARTMUSEUM_PORT/api/charts || print_warning "ChartMuseum API test failed"
    
    kubectl get pods -n $CHARTMUSEUM_NAMESPACE
    kubectl get services -n $CHARTMUSEUM_NAMESPACE
}

# Function to create a sample chart and upload
create_sample_chart() {
    print_status "Creating and uploading sample chart..."
    
    # Create temporary directory
    mkdir -p /tmp/sample-charts
    cd /tmp/sample-charts
    
    # Create a simple sample chart
    helm create sample-app
    
    # Package the chart
    helm package sample-app
    
    # Upload to ChartMuseum using curl
    curl --data-binary "@sample-app-0.1.0.tgz" http://gpu-node:$CHARTMUSEUM_PORT/api/charts
    
    # Update Helm repo
    helm repo update
    
    # Verify chart is available
    helm search repo local/sample-app
    
    # Clean up
    cd /
    rm -rf /tmp/sample-charts
    
    print_status "✅ Sample chart uploaded successfully!"
}

# Function to display usage information
show_usage() {
    print_status "ChartMuseum Setup Complete!"
    echo ""
    echo "ChartMuseum Information:"
    echo "  - Web UI: http://gpu-node:$CHARTMUSEUM_PORT"
    echo "  - API: http://gpu-node:$CHARTMUSEUM_PORT/api/charts"
    echo "  - Health: http://gpu-node:$CHARTMUSEUM_PORT/health"
    echo ""
    echo "Helm Repository:"
    echo "  - Name: local"
    echo "  - URL: http://gpu-node:$CHARTMUSEUM_PORT"
    echo ""
    echo "Usage Examples:"
    echo "  # Search for charts"
    echo "  helm search repo local"
    echo ""
    echo "  # Install a chart"
    echo "  helm install my-app local/chart-name"
    echo ""
    echo "  # Upload a chart"
    echo "  curl --data-binary \"@chart-name-version.tgz\" http://gpu-node:$CHARTMUSEUM_PORT/api/charts"
    echo ""
    echo "  # Package and upload"
    echo "  helm package my-chart/"
    echo "  curl --data-binary \"@my-chart-version.tgz\" http://gpu-node:$CHARTMUSEUM_PORT/api/charts"
    echo "  helm repo update"
    echo ""
}

# Main execution
main() {
    print_status "Starting ChartMuseum setup..."
    
    # Check prerequisites
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Execute setup steps
    create_storage
    create_namespace
    deploy_chartmuseum
    install_helm
    configure_helm_repo
    test_chartmuseum
    create_sample_chart
    show_usage
    
    print_status "🎉 ChartMuseum setup completed successfully!"
}

# Script execution
main "$@" 