#!/bin/bash

echo "🚀 Deploying Clean Kubernetes Cluster"
echo "====================================="
echo
echo "Cluster Configuration:"
echo "- Master: gpu-node (192.168.1.79)"
echo "- Worker: worker-node1 (192.168.1.95)"
echo "- Worker: worker-node2 (192.168.1.132)"
echo "- Worker: worker-node3 (192.168.1.105)"
echo "- Worker: worker-node4 (192.168.1.137)"
echo

# Run the working playbook
echo "🔧 Running Kubernetes installation playbook..."
ansible-playbook -i inventory.ini working_k8s_install.yaml --become --ask-pass --ask-become-pass -e force_reset=true

if [ $? -eq 0 ]; then
    echo
    echo "✅ Cluster deployment completed!"
    echo
    echo "🎯 Post-installation steps:"
    echo "1. Set up kubectl for user:"
    echo "   mkdir -p ~/.kube"
    echo "   sudo cp /etc/kubernetes/admin.conf ~/.kube/config"
    echo "   sudo chown \$USER:\$USER ~/.kube/config"
    echo
    echo "2. Install CNI (if not already done):"
    echo "   kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml"
    echo
    echo "3. Join worker nodes (get join command):"
    echo "   kubeadm token create --print-join-command"
    echo
    echo "4. Verify cluster:"
    echo "   kubectl get nodes"
    echo "   kubectl get pods -n kube-system"
else
    echo "❌ Deployment failed. Check the output above for errors."
    exit 1
fi 