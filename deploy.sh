#!/bin/bash

# TweetStream Deployment Script
# Modern deployment using platform services

set -e

echo "🚀 Starting TweetStream deployment..."

# Configuration
REGISTRY="sanzad-ubuntu-21:30500"
BACKEND_IMAGE="$REGISTRY/tweetstream-backend:latest"
FRONTEND_IMAGE="$REGISTRY/tweetstream-frontend:latest"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if platform services are running
check_platform_services() {
    print_status "Checking platform services..."
    
    if ! kubectl get pods -n platform-services | grep -q "postgresql.*Running"; then
        print_error "PostgreSQL platform service not running!"
        exit 1
    fi
    
    if ! kubectl get pods -n platform-services | grep -q "redis.*Running"; then
        print_error "Redis platform service not running!"
        exit 1
    fi
    
    if ! kubectl get pods -n platform-services | grep -q "kafka.*Running"; then
        print_error "Kafka platform service not running!"
        exit 1
    fi
    
    print_success "All platform services are running"
}

# Initialize database
init_database() {
    print_status "Initializing TweetStream database..."
    
    # Create database if it doesn't exist
    kubectl exec -n platform-services statefulset/postgresql -- psql -U postgres -c "CREATE DATABASE tweetstream;" 2>/dev/null || true
    
    # Run schema initialization
    kubectl exec -i -n platform-services statefulset/postgresql -- psql -U postgres -d tweetstream < backend/src/config/schema.sql
    
    print_success "Database schema initialized"
}

# Seed database with sample data
seed_database() {
    print_status "Seeding database with sample data..."
    
    # Run data seeding
    kubectl exec -i -n platform-services statefulset/postgresql -- psql -U postgres -d tweetstream < seed-data.sql
    
    print_success "Database seeded with sample data"
}

# Build backend image
build_backend() {
    print_status "Building backend image..."
    cd backend
    docker build -t $BACKEND_IMAGE .
    docker push $BACKEND_IMAGE
    cd ..
    print_success "Backend image built and pushed"
}

# Build frontend image
build_frontend() {
    print_status "Building frontend image..."
    cd frontend
    
    # Create basic React app files if they don't exist
    if [ ! -f "index.html" ]; then
        cat > index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>TweetStream</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF
    fi
    
    if [ ! -f "src/main.tsx" ]; then
        mkdir -p src
        cat > src/main.tsx << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import './index.css'

function App() {
  return (
    <div className="min-h-screen bg-gray-100 flex items-center justify-center">
      <div className="text-center">
        <h1 className="text-4xl font-bold text-blue-600 mb-4">TweetStream</h1>
        <p className="text-gray-600 mb-2">Modern Twitter-like Social Platform</p>
        <p className="text-sm text-gray-500 mb-4">Powered by Platform Services</p>
        <div className="bg-white p-6 rounded-lg shadow-lg max-w-md mx-auto">
          <h2 className="text-lg font-semibold mb-4">🚀 Features</h2>
          <ul className="text-left space-y-2 text-sm">
            <li>✅ Real-time updates with Kafka</li>
            <li>✅ Redis session management</li>
            <li>✅ PostgreSQL database</li>
            <li>✅ Modern React frontend</li>
            <li>✅ Kubernetes deployment</li>
          </ul>
        </div>
      </div>
    </div>
  )
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
EOF
    fi
    
    if [ ! -f "src/index.css" ]; then
        cat > src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
EOF
    fi
    
    docker build -t $FRONTEND_IMAGE .
    docker push $FRONTEND_IMAGE
    cd ..
    print_success "Frontend image built and pushed"
}

# Deploy to Kubernetes
deploy_kubernetes() {
    print_status "Deploying to Kubernetes..."
    
    # Apply deployments
    kubectl apply -f kubernetes/tweetstream-deployment.yaml
    
    # Apply ingress
    kubectl apply -f kubernetes/ingress/tweetstream-ingress.yaml
    
    # Apply NodePort services
    kubectl apply -f kubernetes/nodeport/tweetstream-nodeport.yaml
    
    print_success "Kubernetes resources deployed"
}

# Wait for deployment
wait_for_deployment() {
    print_status "Waiting for deployment to be ready..."
    
    kubectl wait --for=condition=available --timeout=300s deployment/tweetstream-backend
    kubectl wait --for=condition=available --timeout=300s deployment/tweetstream-frontend
    
    print_success "Deployment is ready"
}

# Show access information
show_access_info() {
    print_success "TweetStream deployed successfully!"
    echo ""
    echo "🌐 Access URLs:"
    echo "   Custom Domain: http://tweetstream.local (add to /etc/hosts)"
    echo "   Backend API:   http://sanzad-ubuntu-21:30950"
    echo "   Frontend:      http://sanzad-ubuntu-21:30951"
    echo ""
    echo "📊 Platform Services Integration:"
    echo "   PostgreSQL:    postgresql.platform-services.svc.cluster.local:5432"
    echo "   Redis:         redis-master.platform-services.svc.cluster.local:6379"
    echo "   Kafka:         kafka.platform-services.svc.cluster.local:9092"
    echo ""
    echo "👥 Sample Users (password: 'password123'):"
    echo "   john_doe, jane_smith, tech_guru, startup_founder, data_scientist"
    echo ""
    echo "🔧 Management Commands:"
    echo "   kubectl get pods -l app=tweetstream-backend"
    echo "   kubectl get pods -l app=tweetstream-frontend"
    echo "   kubectl logs -f deployment/tweetstream-backend"
    echo ""
    echo "🗄️ Database Access:"
    echo "   kubectl exec -it -n platform-services statefulset/postgresql -- psql -U postgres -d tweetstream"
    echo ""
}

# Main deployment flow
main() {
    check_platform_services
    init_database
    seed_database
    build_backend
    build_frontend
    deploy_kubernetes
    wait_for_deployment
    show_access_info
}

# Run deployment
main "$@" 