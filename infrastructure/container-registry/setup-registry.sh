#!/bin/bash

# Container Registry Setup Script for Kubernetes Cluster
set -e

echo "🚀 Setting up Container Registry for Kubernetes cluster..."

# Configuration
REGISTRY_NAMESPACE="container-registry"
REGISTRY_PORT="30500"
NODES=("sanzad-ubuntu-21" "sanzad-ubuntu-22" "worker-node1")
# SUDO_PASS - Will prompt interactively for security

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

# Function to create directories on all nodes
create_directories() {
    print_status "Creating registry directories on all nodes..."
    
    for node in "${NODES[@]}"; do
        print_status "Setting up directories on $node..."
        ssh -o StrictHostKeyChecking=no "$node" "
            sudo mkdir -p /opt/registry-data
            sudo chmod 755 /opt/registry-data
            sudo mkdir -p /etc/docker
        " || print_warning "Could not SSH to $node, skipping..."
    done
}

# Function to configure Docker daemon on all nodes
configure_docker_daemon() {
    print_status "Configuring Docker daemon on all nodes..."
    
    for node in "${NODES[@]}"; do
        print_status "Configuring Docker on $node..."
        ssh -o StrictHostKeyChecking=no "$node" "
            # Create docker daemon configuration
            sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  \"insecure-registries\": [
    \"sanzad-ubuntu-21:30500\",
    \"sanzad-ubuntu-22:30500\", 
    \"worker-node1:30500\",
    \"localhost:30500\",
    \"127.0.0.1:30500\"
  ],
  \"log-driver\": \"json-file\",
  \"log-opts\": {
    \"max-size\": \"10m\",
    \"max-file\": \"3\"
  }
}
EOF
            
            # Restart Docker
            sudo systemctl daemon-reload
            sudo systemctl restart docker
            
            # Wait for Docker to be ready
            sleep 5
            sudo systemctl status docker --no-pager -l
        " || print_warning "Could not configure Docker on $node"
    done
}

# Function to deploy registry to Kubernetes
deploy_registry() {
    print_status "Deploying container registry to Kubernetes..."
    
    # Apply the registry deployment
    kubectl apply -f $(dirname "$0")/registry-deployment.yaml
    
    # Wait for deployment to be ready
    print_status "Waiting for registry deployment to be ready..."
    kubectl wait --namespace=container-registry \
        --for=condition=available \
        --timeout=300s \
        deployment/docker-registry
}

# Function to test registry
test_registry() {
    print_status "Testing container registry..."
    
    # Wait a bit more for service to be fully ready
    sleep 10
    
    # Test registry endpoint
    for node in "${NODES[@]}"; do
        print_status "Testing registry access from $node..."
        ssh -o StrictHostKeyChecking=no "$node" "
            curl -f http://localhost:30500/v2/ || curl -f http://sanzad-ubuntu-21:30500/v2/
        " && print_status "✅ Registry accessible from $node" || print_warning "❌ Registry not accessible from $node"
    done
    
    # Test from kubectl
    kubectl get pods -n container-registry
    kubectl get services -n container-registry
}

# Function to create test image and push
create_test_image() {
    print_status "Creating and pushing test image..."
    
    # Create a simple test image
    mkdir -p /tmp/registry-test
    cat > /tmp/registry-test/Dockerfile <<EOF
FROM alpine:latest
RUN echo "Container Registry Test" > /test.txt
CMD ["cat", "/test.txt"]
EOF

    # Build and push test image
    cd /tmp/registry-test
    sudo docker build -t localhost:30500/test/hello-registry:v1.0.0 .
    sudo docker push localhost:30500/test/hello-registry:v1.0.0
    
    # Clean up
    rm -rf /tmp/registry-test
    
    print_status "✅ Test image pushed successfully!"
}

# Function to display usage information
show_usage() {
    print_status "Container Registry Setup Complete!"
    echo ""
    echo "Registry Information:"
    echo "  - Internal URL: docker-registry.container-registry.svc.cluster.local:5000"
    echo "  - External URL: <any-node>:30500"
    echo "  - Web UI: http://sanzad-ubuntu-21:30500/v2/_catalog"
    echo ""
    echo "Usage Examples:"
    echo "  # Tag an image for the registry"
    echo "  sudo docker tag myapp:latest sanzad-ubuntu-21:30500/myapp:v1.0.0"
    echo ""
    echo "  # Push an image"
    echo "  sudo docker push sanzad-ubuntu-21:30500/myapp:v1.0.0"
    echo ""
    echo "  # Pull an image"
    echo "  sudo docker pull sanzad-ubuntu-21:30500/myapp:v1.0.0"
    echo ""
    echo "Kubernetes Deployment:"
    echo "  # Use in Pod spec"
    echo "  image: sanzad-ubuntu-21:30500/myapp:v1.0.0"
    echo ""
}

# Main execution
main() {
    print_status "Starting container registry setup..."
    
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
    
    # Execute setup steps
    create_directories
    configure_docker_daemon
    deploy_registry
    test_registry
    create_test_image
    show_usage
    
    print_status "🎉 Container Registry setup completed successfully!"
}

# Script execution
main "$@" 