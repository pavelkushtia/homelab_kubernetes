# Clean Kubernetes Cluster Setup

Part of the **[Kubernetes Infrastructure Repository](../README.md)** ecosystem providing **foundation cluster setup**.

## 🎯 Overview

This directory contains a **working, tested** Kubernetes cluster setup that creates the foundation 3-node cluster for our entire ecosystem, including the **modernized Helm-based platform services**.

## 🏗️ Cluster Configuration

| Node | Role | IP | Resources | Status |
|------|------|----|-----------| --------|
| **sanzad-ubuntu-21** | Master (Control Plane) | 192.168.1.93 | 4 CPU, 9GB RAM | ✅ Working |
| **sanzad-ubuntu-22** | Worker | 192.168.1.104 | 2 CPU, 5GB RAM | ✅ Working |
| **worker-node1** | Worker | 192.168.1.95 | 2 CPU, 6.6GB RAM | ✅ Working |

## 🚀 Complete Infrastructure Deployment

### 1. Deploy Foundation Cluster
```bash
cd clean_k8s_cluster/
./deploy_cluster.sh
```

### 2. Deploy Platform Services (RECOMMENDED)
```bash
cd ../platform-services/
./deploy-platform-services.sh
```

### 3. Deploy Development Infrastructure (Optional)
```bash
cd ../infrastructure/
./setup-infrastructure.sh
```

## 📦 What This Cluster Supports

After cluster deployment, you can run our entire ecosystem:

### **✅ Platform Services (Helm-Based)**
- PostgreSQL 17.5.0 with enterprise features
- Redis 8.0.2 with optimized configuration  
- Apache Kafka 4.0.0 with KRaft mode
- Prometheus + Grafana monitoring stack
- **90% configuration reduction** vs custom YAML

### **✅ Development Platform**
- Local container registry (`sanzad-ubuntu-21:30500`)
- ArgoCD GitOps platform (`http://sanzad-ubuntu-21:30080`)
- ChartMuseum Helm repository (`http://sanzad-ubuntu-21:30800`)

### **✅ Sample Applications**
- Reference microservice implementations
- Integration with platform services
- GitOps deployment patterns

## 📁 Files

- **`inventory.ini`** - Ansible inventory with node configuration
- **`working_k8s_install.yaml`** - Comprehensive, tested playbook (645 lines)
- **`deploy_cluster.sh`** - Simple deployment script
- **`README.md`** - This documentation

## 🔧 Manual Deployment

If you prefer step-by-step:

```bash
# Run the ansible playbook
ansible-playbook -i inventory.ini working_k8s_install.yaml --become --ask-become-pass -e force_reset=true

# Set up kubectl for your user
mkdir -p ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $USER:$USER ~/.kube/config

# Install CNI network plugin
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

# Generate join command for workers
kubeadm token create --print-join-command

# Join worker nodes (run on each worker)
ssh user@worker-ip "sudo kubeadm join ..."
```

## ✅ Verification

```bash
# Check cluster status
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Get cluster info
kubectl cluster-info

# Test with platform services
cd ../platform-services/
./deploy-platform-services.sh
kubectl get pods -n platform-services
```

## 🎁 What's Included

- **Complete system configuration** (swap, kernel modules, sysctl)
- **Containerd runtime** with proper systemd cgroup configuration
- **Kubernetes v1.28.0** components (kubelet, kubeadm, kubectl)
- **Calico CNI** for pod networking
- **CoreDNS** for service discovery
- **Firewall configuration** for required ports
- **Clean /etc/hosts** setup for node resolution
- **Comprehensive cleanup** of previous installations
- **Ready for Helm deployments** and platform services

## 🛠 Troubleshooting

If deployment fails:

1. **Check node connectivity:**
   ```bash
   ansible -i inventory.ini all -m ping
   ```

2. **Verify prerequisites:**
   ```bash
   ansible -i inventory.ini all -m shell -a "free -h"  # Check memory
   ansible -i inventory.ini all -m shell -a "nproc"    # Check CPUs
   ```

3. **Force clean reset:**
   ```bash
   ansible-playbook -i inventory.ini working_k8s_install.yaml --become --ask-become-pass -e force_reset=true
   ```

## 💡 Notes

- **Sudo password:** Interactive prompt (secure setup)
- **SSH key:** Uses ~/.ssh/id_rsa for worker node access
- **Network:** Pod CIDR 192.168.0.0/16, Service CIDR 10.96.0.0/12
- **Force reset:** Use `-e force_reset=true` to reset existing clusters
- **Storage Class:** Automatically compatible with platform services local storage

## 🎉 Success Indicators

When successful, you should see:
- All nodes showing `Ready` status
- All system pods `Running` 
- API server accessible at https://192.168.1.93:6443
- kubectl commands working without sudo
- **Ready for platform services deployment**

## 🔗 Next Steps

After cluster deployment:

1. **Deploy Platform Services**: `cd ../platform-services && ./deploy-platform-services.sh`
2. **Access Monitoring**: `http://sanzad-ubuntu-21:30300` (Grafana)
3. **Deploy Applications**: `cd ../applications && kubectl apply -f simple-web.yaml`
4. **Setup GitOps**: `cd ../infrastructure && ./setup-infrastructure.sh`

## 🔗 Related Components

- **[Platform Services](../platform-services/README.md)** - 90% simplified shared infrastructure
- **[Infrastructure](../infrastructure/README.md)** - Container registry and GitOps platform
- **[Applications](../applications/README.md)** - Sample deployments
- **[Main Repository](../README.md)** - Complete Kubernetes ecosystem overview

---
**Status**: ✅ **PRODUCTION READY** - Foundation for entire ecosystem  
**Last tested:** June 1, 2025  
**Kubernetes version:** v1.28.0  
**Container runtime:** containerd 1.7.27  
**CNI plugin:** Calico v3.27.0