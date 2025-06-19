# 🧪 TweetStream Testing Guide

## Overview
This guide covers testing both the current working system and the new secure deployment process with interactive password management.

## ✅ Current System Status

**Frontend**: ✅ Running on http://sanzad-ubuntu-21:30951  
**Backend**: ✅ Running on http://sanzad-ubuntu-21:30950  
**Database**: ✅ Connected and serving data  

## 🔍 Quick Health Checks

### 1. Backend API Test
```bash
# Health check
curl http://sanzad-ubuntu-21:30950/health

# Expected response: JSON with "status":"healthy"
```

### 2. Frontend Test
```bash
# Check frontend accessibility
curl -I http://sanzad-ubuntu-21:30951

# Expected: HTTP/1.1 200 OK
```

### 3. API Data Test
```bash
# Test tweets endpoint
curl http://sanzad-ubuntu-21:30950/api/tweets

# Expected: JSON array with tweets data
```

### 4. Database Connectivity Test (Interactive)
```bash
# Test PostgreSQL connection (will prompt for password)
kubectl run pg-test --image=postgres:15-alpine --rm -it --restart=Never -- \
  psql -h 10.110.47.87 -p 5432 -U postgres -c "SELECT 'Connection Success' as status;"

# Enter the current PostgreSQL password when prompted
```

## 🔒 Testing Secure Deployment Process

### 1. Set Up Secure Credentials
```bash
# Run the interactive secrets setup
./setup-secrets.sh

# This will:
# - Prompt for PostgreSQL password
# - Create Kubernetes secret 'postgres-credentials'
# - Validate secret creation
```

### 2. Test Production Deployment
```bash
# Deploy using secure credentials
kubectl apply -f kubernetes/production-backend.yaml

# Check deployment status
kubectl get pods -l app=tweetstream-production

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=tweetstream-production --timeout=300s
```

### 3. Test New Secure Deployment
```bash
# Test new production backend (port 30955)
curl http://sanzad-ubuntu-21:30955/health

# Expected: Healthy response from secure deployment
```

### 4. Full Application Deployment Test
```bash
# Run complete secure deployment
./deploy.sh

# This will:
# - Prompt for database password
# - Test connectivity
# - Deploy application
# - Set up database schema
# - Insert sample data
```

## 🔧 Troubleshooting Tests

### Check Kubernetes Secrets
```bash
# Verify secrets exist
kubectl get secrets postgres-credentials

# Check secret content (base64 encoded)
kubectl get secret postgres-credentials -o yaml
```

### Debug Pod Issues
```bash
# Check pod logs
kubectl logs -l app=tweetstream-production

# Describe pod for events
kubectl describe pod -l app=tweetstream-production
```

### Database Connection Debug
```bash
# Test direct database connection
kubectl run debug-pg --image=postgres:15-alpine --rm -it --restart=Never -- \
  psql -h 10.110.47.87 -p 5432 -U postgres -d tweetstream \
  -c "SELECT COUNT(*) as user_count FROM users;"
```

## 📊 Performance Tests

### API Load Test
```bash
# Simple load test
for i in {1..10}; do
  curl -s http://sanzad-ubuntu-21:30950/health > /dev/null && echo "Request $i: OK"
done
```

### Database Performance Test
```bash
# Test database query performance
time kubectl exec -n platform-services postgresql-0 -- \
  psql -U postgres -d tweetstream \
  -c "SELECT COUNT(*) FROM tweets;"
```

## 🌐 Browser Testing

1. **Frontend Access**: http://sanzad-ubuntu-21:30951
   - Should show TweetStream interface
   - Login/Register should work
   - Timeline should display tweets

2. **API Direct Access**: http://sanzad-ubuntu-21:30950
   - `/health` - Health status
   - `/api/tweets` - All tweets
   - `/api/users` - User list

## 📝 Test Scenarios

### Scenario 1: New User Registration
1. Access frontend: http://sanzad-ubuntu-21:30951
2. Click "Register"
3. Create new user account
4. Verify login works
5. Post a new tweet
6. Check if tweet appears in timeline

### Scenario 2: Secure Deployment
1. Run `./setup-secrets.sh` with current password
2. Deploy with `kubectl apply -f kubernetes/production-backend.yaml`
3. Verify new deployment works on port 30955
4. Compare functionality with original deployment

### Scenario 3: Password Security Test
1. Try to find any hardcoded passwords:
   ```bash
   grep -r "postgres@123\|grafana@123\|XXXX" . --exclude-dir=backup_file_do_no_use
   ```
2. Expected result: No matches found (all passwords use interactive prompts)

## ✅ Success Criteria

**✅ All tests pass if:**
- Health endpoints return 200 OK
- Frontend loads without errors
- API returns valid JSON data
- Database queries execute successfully
- Secure deployment creates pods without crashes
- No hardcoded passwords found in codebase

## 🚨 Common Issues & Solutions

**Issue**: Cross-user tweets not working (mock data)  
**Solution**: Run `./fix-cross-user-tweets.sh` to deploy real TypeScript backend

**Issue**: Pod in CrashLoopBackOff  
**Solution**: Check if database credentials are correct

**Issue**: "Connection refused" errors  
**Solution**: Verify platform services are running

**Issue**: Empty API responses  
**Solution**: Check database has data and connectivity

**Issue**: Frontend not loading  
**Solution**: Verify NodePort service is accessible

**Issue**: NGINX serving static responses instead of real API  
**Solution**: Deploy production backend with `kubectl apply -f kubernetes/production-backend.yaml`

## 📞 Support Commands

```bash
# Quick system overview
kubectl get pods,svc | grep tweetstream

# Platform services status
kubectl get pods -n platform-services

# Check all secrets
kubectl get secrets

# View application logs
kubectl logs -l app=tweetstream-backend -f
```

---
**Last Updated**: June 6, 2025  
**Status**: Production Ready with Secure Credentials  
**Test Coverage**: Frontend, Backend, Database, Security, Performance 