#!/usr/bin/env bash
set -euo pipefail

# Calico CNI 설치 for kubeadm cluster
# - Tigera Operator 방식
# - VXLAN encapsulation
# - nodeAddressAutodetection: enp3s0 인터페이스 사용 (WireGuard 제외)

CALICO_VERSION="${CALICO_VERSION:-v3.29.3}"
POD_CIDR="${POD_CIDR:-10.244.0.0/16}"
NODE_INTERFACE="${NODE_INTERFACE:-enp3s0}"

echo "=== Installing Calico CNI ==="
echo "  Version: $CALICO_VERSION"
echo "  Pod CIDR: $POD_CIDR"
echo "  Node Interface: $NODE_INTERFACE"
echo ""

# Step 1: Tigera Operator 설치
echo "=== Step 1: Installing Tigera Operator ==="
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml" || true

echo "Waiting for Tigera Operator to be ready..."
kubectl wait --for=condition=Available deployment/tigera-operator -n tigera-operator --timeout=120s

# Step 2: Custom Resources (Installation CR) 생성
echo ""
echo "=== Step 2: Creating Calico Installation ==="

cat <<EOF | kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - cidr: ${POD_CIDR}
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
    nodeAddressAutodetectionV4:
      interface: ${NODE_INTERFACE}
EOF

# Step 3: API Server 설치 (kubectl get caliconetworkpolicies 등 사용 위해)
echo ""
echo "=== Step 3: Creating Calico APIServer ==="
cat <<EOF | kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}
EOF

# Step 4: 대기
echo ""
echo "=== Step 4: Waiting for Calico to be ready ==="
echo "Waiting for calico-system namespace..."
until kubectl get ns calico-system &>/dev/null; do
  sleep 2
done

echo "Waiting for calico-node DaemonSet..."
kubectl rollout status daemonset/calico-node -n calico-system --timeout=180s || {
  echo ""
  echo "⚠️  calico-node not ready yet. Check status:"
  echo "  kubectl get pods -n calico-system"
  echo "  kubectl logs -n calico-system -l k8s-app=calico-node"
  exit 1
}

echo ""
echo "=== Calico Installation Complete ==="
echo ""
kubectl get pods -n calico-system
echo ""
echo "Verify node IPs:"
kubectl get nodes -o wide
