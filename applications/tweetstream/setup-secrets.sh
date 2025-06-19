#!/bin/bash

# TweetStream Secrets Setup Script
# Creates Kubernetes secrets for database credentials

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

print_status "🔑 TweetStream Secrets Setup"

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

# Prompt for PostgreSQL password
print_status "🔐 PostgreSQL Credentials Setup"
echo "Enter the PostgreSQL password (same as used in platform services):"
POSTGRES_PASSWORD=$(prompt_for_password "PostgreSQL password")

# Validate password
if [ -z "$POSTGRES_PASSWORD" ]; then
    print_error "PostgreSQL password cannot be empty"
    exit 1
fi

# Create secret for PostgreSQL credentials
print_status "📝 Creating PostgreSQL credentials secret..."

# Delete existing secret if it exists
kubectl delete secret postgres-credentials 2>/dev/null || true

# Create new secret
kubectl create secret generic postgres-credentials \
    --from-literal=username=postgres \
    --from-literal=password="$POSTGRES_PASSWORD"

print_status "✅ Secret 'postgres-credentials' created successfully"

# Verify secret creation
if kubectl get secret postgres-credentials >/dev/null 2>&1; then
    print_status "🔍 Secret verification successful"
    echo "   Secret name: postgres-credentials"
    echo "   Namespace: default"
    echo "   Keys: username, password"
else
    print_error "Failed to verify secret creation"
    exit 1
fi

echo
print_status "📝 Next Steps:"
echo "   1. Deploy TweetStream with: kubectl apply -f kubernetes/production-backend.yaml"
echo "   2. The deployment will automatically use the credentials from the secret"
echo "   3. Check deployment status: kubectl get pods -l app=tweetstream-production"

echo
print_warning "🔒 Security Notes:"
echo "   - The password is now stored securely in Kubernetes secrets"
echo "   - Secrets are base64 encoded but not encrypted at rest by default"
echo "   - Consider enabling encryption at rest for production clusters"
echo "   - Never commit secrets to version control"

print_status "🎉 Secrets setup completed successfully!" 