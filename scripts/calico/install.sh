#!/usr/bin/env bash
set -euo pipefail

# Calico CNI 설치 for kubeadm cluster
# - Tigera Operator 방식
# - VXLAN encapsulation
# - nodeAddressAutodetection: CIDR 기반 (노드별 인터페이스명 달라도 OK)

CALICO_VERSION="${CALICO_VERSION:-v3.29.3}"
POD_CIDR="${POD_CIDR:-10.244.0.0/16}"
NODE_CIDR="${NODE_CIDR:-192.168.45.0/24}"
TIMEOUT="${TIMEOUT:-300}"

echo "=== Installing Calico CNI ==="
echo "  Version: $CALICO_VERSION"
echo "  Pod CIDR: $POD_CIDR"
echo "  Node CIDR: $NODE_CIDR (for IP autodetection)"
echo "  Timeout: ${TIMEOUT}s"
echo ""

# 이미 Calico가 정상 동작 중인지 확인
if kubectl get daemonset -n calico-system calico-node &>/dev/null; then
  READY=$(kubectl get daemonset -n calico-system calico-node -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
  DESIRED=$(kubectl get daemonset -n calico-system calico-node -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
  if [[ "$READY" == "$DESIRED" && "$READY" != "0" ]]; then
    echo "✅ Calico already installed and healthy ($READY/$DESIRED nodes ready)"
    echo "   Skipping installation."
    kubectl get pods -n calico-system
    exit 0
  fi
fi

# Step 0: 노드 어노테이션 정리 (WireGuard IP 충돌 방지)
echo "=== Step 0: Cleaning node annotations ==="
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  kubectl annotate node "$node" projectcalico.org/IPv4Address- 2>/dev/null || true
  kubectl annotate node "$node" projectcalico.org/IPv4VXLANTunnelAddr- 2>/dev/null || true
done
echo "Node annotations cleaned."

# Step 1: Tigera Operator 설치
echo ""
echo "=== Step 1: Installing Tigera Operator ==="
kubectl apply --server-side --force-conflicts -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"

echo "Waiting for Tigera Operator deployment..."
kubectl wait --for=condition=Available deployment/tigera-operator -n tigera-operator --timeout=${TIMEOUT}s

echo "Waiting for Installation CRD..."
for i in {1..60}; do
  if kubectl get crd installations.operator.tigera.io &>/dev/null; then
    kubectl wait --for=condition=Established crd/installations.operator.tigera.io --timeout=30s && break
  fi
  echo "  Waiting for CRD... ($i/60)"
  sleep 3
done

# Step 2: Installation CR 생성
echo ""
echo "=== Step 2: Creating Calico Installation ==="

INSTALL_NEEDED=false
if ! kubectl get installation default &>/dev/null; then
  INSTALL_NEEDED=true
else
  STATUS=$(kubectl get installation default -o jsonpath='{.status.conditions[?(@.type=="Degraded")].status}' 2>/dev/null || echo "Unknown")
  if [[ "$STATUS" == "True" ]]; then
    echo "Installation is Degraded, recreating..."
    kubectl patch installation default -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
    kubectl delete installation default --force --grace-period=0 2>/dev/null || true
    sleep 5
    INSTALL_NEEDED=true
  else
    echo "Installation already exists, checking status..."
  fi
fi

if [[ "$INSTALL_NEEDED" == "true" ]]; then
  cat <<EOF | kubectl create -f -
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
      cidrs:
      - ${NODE_CIDR}
EOF
fi

# Step 3: APIServer 설치
echo ""
echo "=== Step 3: Creating Calico APIServer ==="
for i in {1..30}; do
  if kubectl get crd apiservers.operator.tigera.io &>/dev/null; then
    kubectl wait --for=condition=Established crd/apiservers.operator.tigera.io --timeout=30s && break
  fi
  sleep 2
done

if ! kubectl get apiserver default &>/dev/null; then
  cat <<EOF | kubectl create -f -
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}
EOF
else
  echo "APIServer already exists, skipping..."
fi

# Step 4: calico-system namespace 대기
echo ""
echo "=== Step 4: Waiting for Calico to be ready ==="
echo "Waiting for calico-system namespace..."
for i in {1..90}; do
  if kubectl get ns calico-system &>/dev/null; then
    echo "  calico-system namespace created."
    break
  fi
  echo "  Waiting for namespace... ($i/90)"
  sleep 2
done

if ! kubectl get ns calico-system &>/dev/null; then
  echo "❌ calico-system namespace not created."
  echo "Installation status:"
  kubectl get installation default -o yaml | grep -A15 status || true
  exit 1
fi

# Step 5: calico-node DaemonSet 대기
echo ""
echo "Waiting for calico-node DaemonSet to be created..."
for i in {1..60}; do
  if kubectl get daemonset -n calico-system calico-node &>/dev/null; then
    echo "  calico-node DaemonSet found."
    break
  fi
  echo "  Waiting for DaemonSet... ($i/60)"
  sleep 3
done

echo "Waiting for calico-node to be ready (timeout: ${TIMEOUT}s)..."
kubectl rollout status daemonset/calico-node -n calico-system --timeout=${TIMEOUT}s || {
  echo ""
  echo "⚠️  calico-node not fully ready yet."
  echo ""
  echo "Current status:"
  kubectl get pods -n calico-system
  echo ""
  echo "Check logs if needed:"
  echo "  kubectl logs -n calico-system -l k8s-app=calico-node --tail=50"
  echo ""
  echo "Continuing anyway... (may work after a moment)"
}

echo ""
echo "=== Calico Installation Complete ==="
echo ""
kubectl get pods -n calico-system
echo ""
echo "Node IPs:"
kubectl get nodes -o wide
