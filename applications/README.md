# Applications - Sample Deployments

Part of the **[Kubernetes Infrastructure Repository](../README.md)** ecosystem.

## 🎯 Overview

This directory contains sample applications demonstrating how to build and deploy cloud-native applications using our modernized **Helm-based platform services** and **development infrastructure**.

## 🏗️ Integration with Platform Services

All applications can leverage our **enterprise-grade platform services**:

### **Shared Infrastructure (platform-services/)**
- **PostgreSQL 17.5.0**: `postgresql.platform-services.svc.cluster.local:5432`
- **Redis 8.0.2**: `redis-master.platform-services.svc.cluster.local:6379`
- **Kafka 4.0.0**: `kafka.platform-services.svc.cluster.local:9092`
- **Monitoring**: Prometheus + Grafana with custom dashboards

### **Development Platform (infrastructure/)**
- **Container Registry**: `sanzad-ubuntu-21:30500`
- **ArgoCD GitOps**: `http://sanzad-ubuntu-21:30080`
- **Helm Repository**: `http://sanzad-ubuntu-21:30800`

## 📦 Sample Applications

### 1. Simple Web Application (`simple-web.yaml`)
- **Purpose**: Basic NGINX web server demonstration
- **Access**: `http://sanzad-ubuntu-21:30900`
- **Features**: Static content serving, basic Kubernetes patterns

### 2. Sample Microservice (`sample-microservice/`)
- **Purpose**: Helm chart demonstrating microservice patterns
- **Integration**: Uses library charts and platform services
- **Features**: 
  - Database connectivity (PostgreSQL)
  - Caching layer (Redis)
  - Event streaming (Kafka)
  - Monitoring integration

## 🚀 Deployment Patterns

### Using Platform Services
```yaml
# Example database connection
env:
  - name: DATABASE_URL
    value: "postgresql://postgres:postgres%40123@postgresql.platform-services.svc.cluster.local:5432/shared_db"
  - name: REDIS_URL
    value: "redis://redis-master.platform-services.svc.cluster.local:6379"
  - name: KAFKA_BROKERS
    value: "kafka.platform-services.svc.cluster.local:9092"
```

### Using Container Registry
```bash
# Build and push
docker build -t sanzad-ubuntu-21:30500/myapp:v1.0.0 .
docker push sanzad-ubuntu-21:30500/myapp:v1.0.0

# Use in Kubernetes
image: sanzad-ubuntu-21:30500/myapp:v1.0.0
```

### Using ArgoCD GitOps
```yaml
# ArgoCD Application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  source:
    repoURL: <your-repo>
    path: applications/my-app
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## 🛠️ Development Workflow

### 1. Ensure Platform Services Running
```bash
cd ../platform-services
./deploy-platform-services.sh
```

### 2. Deploy Sample Application
```bash
# Direct deployment
kubectl apply -f simple-web.yaml

# Helm-based deployment
cd sample-microservice
helm install my-app . --namespace my-app --create-namespace
```

### 3. Access Applications
- **Simple Web**: `http://sanzad-ubuntu-21:30900`
- **Monitoring**: `http://sanzad-ubuntu-21:30300` (Grafana)
- **ArgoCD**: `http://sanzad-ubuntu-21:30080`

## 📊 Monitoring Integration

Applications automatically benefit from our **90% simplified monitoring stack**:

- **Metrics Collection**: Prometheus scrapes application metrics
- **Visualization**: Pre-built Grafana dashboards
- **Alerting**: Custom alerts for application health
- **Tracing**: Ready for distributed tracing integration

## 🎯 Best Practices

### ✅ Use Platform Services
- Leverage shared PostgreSQL, Redis, Kafka instead of embedded services
- Connect to `*.platform-services.svc.cluster.local` internal URLs

### ✅ Use Container Registry
- Build and push to local registry: `sanzad-ubuntu-21:30500`
- Faster pulls, no external dependencies

### ✅ Use GitOps
- Deploy via ArgoCD for automated rollbacks and multi-environment support
- Store configurations in Git for version control

### ✅ Use Helm
- Leverage library charts for common patterns
- Use our ChartMuseum repository for chart distribution

## 🔗 Related Components

- **[Platform Services](../platform-services/README.md)** - 90% simplified shared infrastructure
- **[Infrastructure](../infrastructure/README.md)** - Container registry and GitOps platform
- **[Library Charts](../infrastructure/library-charts/README.md)** - Reusable Helm patterns
- **[Main Repository](../README.md)** - Complete Kubernetes ecosystem overview

---
**Status**: ✅ **READY** - Integrated with modernized platform services

## 🚀 Next Steps

1. **Explore sample applications** to understand integration patterns
2. **Create your own applications** using platform services
3. **Use ArgoCD** for GitOps deployment workflows  
4. **Monitor everything** with integrated Prometheus + Grafana 