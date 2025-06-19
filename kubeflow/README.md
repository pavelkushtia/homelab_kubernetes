# Kubeflow - ML Platform on Kubernetes

Part of the **[Kubernetes Infrastructure Repository](../README.md)** ecosystem.

## 🎯 Overview

Kubeflow provides a comprehensive machine learning platform on our Kubernetes infrastructure, leveraging the modernized platform services for ML workflows.

## 🏗️ Integration with Platform Services

This Kubeflow deployment integrates with our **Helm-based platform services**:

- **PostgreSQL**: For ML metadata, experiment tracking, and model versioning
- **Redis**: For caching ML artifacts and pipeline state
- **Kafka**: For ML pipeline event streaming and data ingestion
- **Monitoring**: Prometheus + Grafana for ML pipeline and model monitoring

## 🚀 Quick Start

```bash
# Ensure platform services are running
cd ../platform-services
./deploy-platform-services.sh

# Deploy Kubeflow
cd ../kubeflow
kubectl apply -k manifests/
```

## 🔧 ML Pipeline Integration

### Database Connection
- **Connection**: `postgresql.platform-services.svc.cluster.local:5432`
- **Database**: `shared_db` 
- **Credentials**: postgres/<configured-password>

### Caching Layer
- **Redis**: `redis-master.platform-services.svc.cluster.local:6379`
- **Usage**: Pipeline caching, artifact storage

### Event Streaming
- **Kafka**: `kafka.platform-services.svc.cluster.local:9092`
- **Usage**: ML data pipelines, model inference events

## 📊 Monitoring

ML pipeline metrics are automatically collected by our **Prometheus monitoring stack**:

- **Grafana Dashboard**: `http://sanzad-ubuntu-21:30300` (admin/<configured-password>)
- **Prometheus**: `http://sanzad-ubuntu-21:30090`
- **Custom ML Metrics**: Model accuracy, training time, inference latency

## 🔗 Related Components

- **[Platform Services](../platform-services/README.md)** - Shared infrastructure (PostgreSQL, Redis, Kafka, Monitoring)
- **[Infrastructure](../infrastructure/README.md)** - Container registry and GitOps platform
- **[KubeRay](../kuberay/README.md)** - Distributed computing for ML workloads
- **[Main Repository](../README.md)** - Complete Kubernetes ecosystem overview

---
**Status**: 📋 **PLANNED** - Integration with modernized platform services