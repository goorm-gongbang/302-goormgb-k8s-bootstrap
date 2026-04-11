#!/usr/bin/env bash
set -euo pipefail

# Calico CNI 제거 스크립트
# - Cilium 마이그레이션 전 실행
# - 모든 Calico 리소스 정리

echo "=== Uninstalling Calico CNI ==="
echo ""
echo "⚠️  WARNING: This will disrupt network connectivity!"
echo "   All pods will lose network until new CNI is installed."
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 1
fi

# Step 1: Helm release 확인 및 삭제
echo ""
echo "=== Step 1: Removing Helm release ==="
if helm status calico -n tigera-operator &>/dev/null; then
  echo "Uninstalling Helm release..."
  helm uninstall calico -n tigera-operator --wait || true
else
  echo "No Helm release found. Checking raw manifest installation..."
fi

# Step 2: Installation/APIServer CR 삭제
echo ""
echo "=== Step 2: Removing Calico CRs ==="

# Finalizer 제거 및 삭제
for cr in installation apiserver; do
  if kubectl get $cr default &>/dev/null; then
    echo "Removing $cr default..."
    kubectl patch $cr default -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
    kubectl delete $cr default --force --grace-period=0 --wait=false 2>/dev/null || true
  fi
done

# IPPool 삭제
echo "Removing IPPools..."
for pool in $(kubectl get ippool -o name 2>/dev/null || true); do
  kubectl patch "$pool" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  kubectl delete "$pool" --force --grace-period=0 2>/dev/null || true
done

# Step 3: Calico 네임스페이스 정리
echo ""
echo "=== Step 3: Cleaning Calico namespaces ==="

for ns in calico-system calico-apiserver tigera-operator; do
  if kubectl get ns "$ns" &>/dev/null; then
    echo "Cleaning namespace: $ns"
    kubectl delete deploy,ds,sts,svc,cm,secret --all -n "$ns" --force --grace-period=0 2>/dev/null || true
    kubectl delete pods --all -n "$ns" --force --grace-period=0 2>/dev/null || true
    kubectl delete ns "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
  fi
done

# Step 4: 노드 어노테이션 정리
echo ""
echo "=== Step 4: Cleaning node annotations ==="
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  echo "Cleaning node: $node"
  kubectl annotate node "$node" projectcalico.org/IPv4Address- 2>/dev/null || true
  kubectl annotate node "$node" projectcalico.org/IPv4VXLANTunnelAddr- 2>/dev/null || true
done

# Step 5: Calico CRD 삭제 (선택적)
echo ""
echo "=== Step 5: Removing Calico CRDs ==="
read -p "Delete Calico CRDs? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  CALICO_CRDS=$(kubectl get crd -o name | grep -E "calico|tigera" || true)
  if [[ -n "$CALICO_CRDS" ]]; then
    echo "$CALICO_CRDS" | xargs kubectl delete --force --grace-period=0 2>/dev/null || true
    echo "Calico CRDs deleted."
  else
    echo "No Calico CRDs found."
  fi
else
  echo "Keeping Calico CRDs."
fi

# Step 6: 각 노드에서 iptables 정리 안내
echo ""
echo "=== Step 6: iptables cleanup (manual) ==="
echo "Run on each node to clean up iptables rules:"
echo ""
echo "  # SSH into each node and run:"
echo "  sudo iptables-save | grep -v KUBE | sudo iptables-restore"
echo "  sudo iptables-save | grep -v cali | sudo iptables-restore"
echo ""

# 최종 상태
echo ""
echo "=== Calico Uninstall Complete ==="
echo ""
echo "Remaining Calico resources:"
kubectl get all -A 2>/dev/null | grep -E "calico|tigera" || echo "None"
echo ""
echo "Next steps:"
echo "1. Clean iptables on each node (see above)"
echo "2. Delete kube-proxy if Cilium will replace it:"
echo "   kubectl -n kube-system delete ds kube-proxy"
echo "   kubectl -n kube-system delete cm kube-proxy"
echo "3. Install Cilium:"
echo "   ./cilium/install.sh"
