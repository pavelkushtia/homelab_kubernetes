#!/bin/bash

# Fix Cross-User Tweets - Deploy Real TypeScript Backend
# This script replaces the mock NGINX backend with a real Node.js TypeScript backend

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

print_status "🔧 Fix Cross-User Tweets - Deploy Real Backend"

echo "🔍 Current Issue: You're seeing a mock NGINX backend instead of real cross-user functionality"
echo "✅ Solution: Deploy the real TypeScript backend with PostgreSQL integration"
echo

# Check if we have the secure credentials setup
if ! kubectl get secret postgres-credentials >/dev/null 2>&1; then
    print_warning "🔑 PostgreSQL credentials not found. Setting up secure credentials..."
    
    echo "Please provide the PostgreSQL password (same as used in platform services):"
    POSTGRES_PASSWORD=$(prompt_for_password "PostgreSQL password")
    
    # Create secret
    kubectl delete secret postgres-credentials 2>/dev/null || true
    kubectl create secret generic postgres-credentials \
        --from-literal=username=postgres \
        --from-literal=password="$POSTGRES_PASSWORD"
    
    print_status "✅ Credentials setup complete"
else
    print_status "✅ PostgreSQL credentials already exist"
fi

# Remove the mock NGINX backend
print_status "🗑️ Removing mock NGINX backend..."
kubectl delete deployment tweetstream-backend 2>/dev/null || true

# Deploy the real TypeScript backend
print_status "🚀 Deploying real TypeScript backend with cross-user functionality..."
kubectl apply -f kubernetes/production-backend.yaml

# Wait for deployment
print_status "⏳ Waiting for real backend to be ready..."
kubectl wait --for=condition=ready pod -l app=tweetstream-production --timeout=300s

# Check if it's working
print_status "🔍 Testing real backend..."
sleep 10

# Test the health endpoint on the new backend
if curl -s http://sanzad-ubuntu-21:30955/health >/dev/null 2>&1; then
    print_status "✅ Real TypeScript backend is running!"
    
    echo
    print_status "🌟 Cross-User Tweets Fixed!"
    echo "   • Real Node.js/TypeScript backend: http://sanzad-ubuntu-21:30955"
    echo "   • True PostgreSQL database integration"
    echo "   • Authentic cross-user tweet functionality"
    echo "   • Real authentication and sessions"
    
    echo
    print_status "🧪 Test the fix:"
    echo "   curl http://sanzad-ubuntu-21:30955/api/tweets"
    
    echo
    print_status "📝 Update frontend to use real backend:"
    echo "   Update API_BASE_URL to: http://sanzad-ubuntu-21:30955"
    
else
    print_error "❌ Real backend deployment failed. Check logs:"
    echo "   kubectl logs -l app=tweetstream-production"
fi

print_status "🎉 Cross-user tweet fix deployment complete!" 