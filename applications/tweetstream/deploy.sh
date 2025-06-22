#!/bin/bash

# TweetStream Application Deployment Script
# Deploys a complete social media platform on Kubernetes

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

print_status "🐦 TweetStream Application Deployment Starting..."

# Check prerequisites
if ! command_exists kubectl; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info >/dev/null 2>&1; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_status "✅ Prerequisites check passed"

# Check if platform services are running
print_status "🔍 Checking platform services..."
if ! kubectl get namespace platform-services >/dev/null 2>&1; then
    print_error "Platform services namespace not found. Please deploy platform services first."
    exit 1
fi

# Check PostgreSQL
if ! kubectl get pods -n platform-services -l app.kubernetes.io/name=postgresql | grep -q Running; then
    print_error "PostgreSQL is not running in platform-services namespace"
    exit 1
fi

print_status "✅ Platform services verification passed"

# Prompt for database password
print_status "🔑 Database Configuration Required"
echo "Please provide the PostgreSQL password used in platform services:"
DB_PASSWORD=$(prompt_for_password "PostgreSQL password")

# Validate password
if [ -z "$DB_PASSWORD" ]; then
    print_error "Database password cannot be empty"
    exit 1
fi

print_status "📦 Deploying TweetStream application..."

# Deploy application
kubectl apply -f kubernetes/tweetstream-deployment.yaml

print_status "🗄️ Setting up database..."

# Test database connection
print_status "🔗 Testing database connection..."
if ! kubectl exec -n platform-services statefulset/postgresql -- env PGPASSWORD="$DB_PASSWORD" psql -U postgres -c "SELECT 1;" >/dev/null 2>&1; then
    print_error "Failed to connect to PostgreSQL. Please check the password."
    exit 1
fi

# Create database
print_status "📊 Creating tweetstream database..."
kubectl exec -n platform-services statefulset/postgresql -- env PGPASSWORD="$DB_PASSWORD" psql -U postgres -c "CREATE DATABASE tweetstream;" 2>/dev/null || true

# Apply schema
if [ -f "backend/src/config/schema.sql" ]; then
    print_status "🏗️ Applying database schema..."
    kubectl exec -i -n platform-services statefulset/postgresql -- env PGPASSWORD="$DB_PASSWORD" psql -U postgres -d tweetstream < backend/src/config/schema.sql
fi

# Insert seed data
if [ -f "seed-data.sql" ]; then
    print_status "🌱 Inserting seed data..."
    kubectl exec -i -n platform-services statefulset/postgresql -- env PGPASSWORD="$DB_PASSWORD" psql -U postgres -d tweetstream < seed-data.sql
fi

# Wait for pods to be ready
print_status "⏳ Waiting for application pods to be ready..."
kubectl wait --for=condition=ready pod -l app=tweetstream-backend --timeout=300s
kubectl wait --for=condition=ready pod -l app=tweetstream-frontend --timeout=300s

print_status "✅ TweetStream deployment completed successfully!"

echo
print_status "🌐 Application Access Information:"
echo "   Frontend: http://gpu-node:30951"
echo "   Backend API: http://gpu-node:30950"
echo "   Health Check: curl http://gpu-node:30950/health"

echo
print_status "👥 Sample Users (password: 'password123'):"
echo "   • john_doe - TypeScript Developer"
echo "   • jane_smith - Product Manager (verified)"
echo "   • tech_guru - Full-stack Developer"

echo
print_status "📝 Next Steps:"
echo "   1. Access the frontend to start using TweetStream"
echo "   2. Check API health: curl http://gpu-node:30950/health"
echo "   3. Monitor application: kubectl get pods"

echo
print_warning "🔑 Security Note: Database password is not stored. Keep it secure!"

print_status "🎉 TweetStream is now ready to use!" 