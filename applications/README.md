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
- **Container Registry**: `gpu-node:30500`
- **ArgoCD GitOps**: `http://gpu-node:30080`
- **Helm Repository**: `http://gpu-node:30800`

## 📦 Sample Applications

### 1. Simple Web Application (`simple-web.yaml`)
- **Purpose**: Basic NGINX web server demonstration
- **Access**: `http://gpu-node:30900`
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
docker build -t gpu-node:30500/myapp:v1.0.0 .
docker push gpu-node:30500/myapp:v1.0.0

# Use in Kubernetes
image: gpu-node:30500/myapp:v1.0.0
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

## 🏗️ Cluster Distribution Strategy

### **Application Deployment Strategy**
Applications are distributed across the 5-node cluster for optimal performance:

| Application Type | Node Selection | Reasoning |
|------------------|----------------|-----------|
| **Web Applications** | Worker nodes | Better resource availability |
| **API Services** | Worker nodes | Distributed load handling |
| **Data Processing** | Worker nodes | CPU-intensive workloads |
| **GPU Applications** | Master node (gpu-node) | GPU access required |
| **Monitoring/UI** | Worker nodes | Distributed access |

### **Resource Allocation**
- **Master Node (gpu-node)**: Control plane + GPU workloads
- **Worker Nodes**: All application workloads distributed automatically
- **Load Balancing**: Kubernetes scheduler optimizes placement

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
- **Simple Web**: `http://gpu-node:30900`
- **Monitoring**: `http://gpu-node:30300` (Grafana)
- **ArgoCD**: `http://gpu-node:30080`

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
- Build and push to local registry: `gpu-node:30500`
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