#!/bin/bash

# Platform Services Deployment Script
# This script deploys PostgreSQL, Redis, Kafka, and Monitoring to Kubernetes using Helm

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to prompt for password securely
prompt_for_password() {
    local prompt_text="$1"
    local password
    echo -n "$prompt_text: "
    read -s password
    echo
    echo "$password"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

print_status "🚀 Platform Services Deployment Starting..."

# Check prerequisites
if ! command_exists kubectl; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

if ! command_exists helm; then
    print_error "helm is not installed or not in PATH"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info >/dev/null 2>&1; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_status "✅ Prerequisites check passed"

# Prompt for passwords
print_status "🔑 Password Configuration Required"
echo "Please provide passwords for the platform services:"
echo

POSTGRES_PASSWORD=$(prompt_for_password "PostgreSQL password")
GRAFANA_PASSWORD=$(prompt_for_password "Grafana admin password")

# Validate passwords
if [ -z "$POSTGRES_PASSWORD" ]; then
    print_error "PostgreSQL password cannot be empty"
    exit 1
fi

if [ -z "$GRAFANA_PASSWORD" ]; then
    print_error "Grafana password cannot be empty"
    exit 1
fi

# Create namespace
print_status "📦 Creating platform-services namespace..."
kubectl create namespace platform-services --dry-run=client -o yaml | kubectl apply -f -

# Create storage class if it doesn't exist
echo "💾 Creating storage class..."
kubectl apply -f storage-class.yaml

# Add Helm repositories
print_status "📚 Adding Helm repositories..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Deploy persistent volumes
echo "💾 Creating persistent volumes..."
kubectl apply -f persistent-volumes/postgresql-pv.yaml
kubectl apply -f persistent-volumes/monitoring-pv.yaml
kubectl apply -f messaging/kafka-pv.yaml

# Deploy PostgreSQL with user-provided password
print_status "🗄️ Deploying PostgreSQL..."
helm upgrade --install postgresql bitnami/postgresql \
  --namespace platform-services \
  --set global.postgresql.auth.postgresPassword="$POSTGRES_PASSWORD" \
  --set primary.service.type=NodePort \
  --set primary.service.nodePorts.postgresql=30432 \
  --set primary.persistence.enabled=true \
  --set primary.persistence.size=8Gi

# Deploy Redis
print_status "⚡ Deploying Redis..."
helm upgrade --install redis bitnami/redis \
  --namespace platform-services \
  --set auth.enabled=false \
  --set master.service.type=NodePort \
  --set master.service.nodePorts.redis=30379 \
  --set master.persistence.enabled=true \
  --set master.persistence.size=4Gi

# Deploy Kafka
print_status "📡 Deploying Kafka..."
helm upgrade --install kafka bitnami/kafka \
  --namespace platform-services \
  --set service.type=NodePort \
  --set service.nodePorts.client=30092 \
  --set persistence.enabled=true \
  --set persistence.size=4Gi \
  --set zookeeper.persistence.enabled=true \
  --set zookeeper.persistence.size=2Gi

# Deploy Monitoring Stack with user-provided password
print_status "📊 Deploying Monitoring Stack (Prometheus + Grafana)..."
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace platform-services \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30090 \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30300 \
  --set grafana.adminPassword="$GRAFANA_PASSWORD" \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.size=2Gi

# Patch PVC for storage class (workaround for Helm chart issue)
kubectl patch pvc data-kafka-controller-0 -n platform-services -p '{"spec":{"storageClassName":"local-storage"}}' 2>/dev/null || true

# Apply external access services
echo "🌐 Creating external access services..."
kubectl apply -f external-services/postgresql-external.yaml
kubectl apply -f external-services/redis-external.yaml
kubectl apply -f external-services/monitoring-external.yaml
kubectl apply -f messaging/kafka-external.yaml

# Wait for deployments
print_status "⏳ Waiting for services to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n platform-services --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis -n platform-services --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n platform-services --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kafka -n platform-services --timeout=300s

print_status "✅ Platform Services Deployment Complete!"

echo
print_status "🌐 Service Access Information:"
echo "   PostgreSQL: gpu-node:30432 (postgres/<your-password>)"
echo "   Redis: gpu-node:30379"
echo "   Kafka: gpu-node:30092"
echo "   Prometheus: http://gpu-node:30090"
echo "   Grafana: http://gpu-node:30300 (admin/<your-password>)"

echo
print_status "📝 Next Steps:"
echo "   1. Verify services: kubectl get pods -n platform-services"
echo "   2. Access Grafana dashboard to configure monitoring"
echo "   3. Deploy applications that use these platform services"

echo
print_warning "🔑 Security Note: Passwords are not stored in this script. Keep them secure!"

print_status "🎉 Platform deployment completed successfully!" 