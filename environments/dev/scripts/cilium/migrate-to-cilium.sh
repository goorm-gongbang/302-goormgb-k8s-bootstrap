#!/usr/bin/env bash
set -euo pipefail

# Calico → Cilium 전체 마이그레이션 스크립트
# - Calico 제거
# - kube-proxy 제거
# - Cilium 설치
# - 모든 Pod 재시작

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║       Calico → Cilium Migration (eBPF Mode)                   ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  This script will:                                            ║"
echo "║  1. Uninstall Calico CNI                                      ║"
echo "║  2. Remove kube-proxy (Cilium replaces it)                    ║"
echo "║  3. Install Cilium with eBPF                                  ║"
echo "║  4. Restart all workload pods                                 ║"
echo "║                                                               ║"
echo "║  ⚠️  Expected downtime: 15-20 minutes                         ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# 현재 상태 확인
echo "=== Current Status ==="
echo ""
echo "Nodes:"
kubectl get nodes -o wide
echo ""
echo "CNI Status:"
if kubectl get ds -n calico-system calico-node &>/dev/null; then
  echo "  Calico: INSTALLED"
  kubectl get ds -n calico-system calico-node --no-headers 2>/dev/null | awk '{print "    Ready: " $4 "/" $2}'
elif kubectl get ds -n kube-system cilium &>/dev/null; then
  echo "  Cilium: INSTALLED"
  kubectl get ds -n kube-system cilium --no-headers 2>/dev/null | awk '{print "    Ready: " $4 "/" $2}'
else
  echo "  No CNI detected!"
fi
echo ""
echo "kube-proxy:"
if kubectl get ds -n kube-system kube-proxy &>/dev/null; then
  echo "  Status: RUNNING"
else
  echo "  Status: NOT FOUND"
fi
echo ""

read -p "Start migration? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 1
fi

START_TIME=$(date +%s)

# Phase 1: Backup
echo ""
echo "=== Phase 1: Backup current state ==="
BACKUP_DIR="/tmp/cni-migration-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

kubectl get pods -A -o wide > "$BACKUP_DIR/pods.txt"
kubectl get svc -A > "$BACKUP_DIR/services.txt"
kubectl get networkpolicy -A -o yaml > "$BACKUP_DIR/networkpolicies.yaml" 2>/dev/null || true
kubectl get nodes -o yaml > "$BACKUP_DIR/nodes.yaml"

echo "Backup saved to: $BACKUP_DIR"

# Phase 2: Uninstall Calico
echo ""
echo "=== Phase 2: Uninstall Calico ==="
if kubectl get ds -n calico-system calico-node &>/dev/null; then
  # Inline Calico removal (without prompts)

  # Helm release 삭제
  if helm status calico -n tigera-operator &>/dev/null; then
    helm uninstall calico -n tigera-operator --wait 2>/dev/null || true
  fi

  # CRs 삭제
  for cr in installation apiserver; do
    kubectl patch $cr default -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
    kubectl delete $cr default --force --grace-period=0 --wait=false 2>/dev/null || true
  done

  # IPPool 삭제
  for pool in $(kubectl get ippool -o name 2>/dev/null || true); do
    kubectl patch "$pool" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
    kubectl delete "$pool" --force --grace-period=0 2>/dev/null || true
  done

  # 네임스페이스 삭제
  for ns in calico-system calico-apiserver tigera-operator; do
    if kubectl get ns "$ns" &>/dev/null; then
      kubectl delete deploy,ds,sts,svc,cm,secret --all -n "$ns" --force --grace-period=0 2>/dev/null || true
      kubectl delete pods --all -n "$ns" --force --grace-period=0 2>/dev/null || true
      kubectl delete ns "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
    fi
  done

  # 노드 어노테이션 정리
  for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
    kubectl annotate node "$node" projectcalico.org/IPv4Address- 2>/dev/null || true
    kubectl annotate node "$node" projectcalico.org/IPv4VXLANTunnelAddr- 2>/dev/null || true
  done

  # CRD 삭제
  kubectl get crd -o name | grep -E "calico|tigera" | xargs kubectl delete --force --grace-period=0 2>/dev/null || true

  echo "Calico removed."
else
  echo "Calico not installed. Skipping."
fi

# Phase 3: Remove kube-proxy
echo ""
echo "=== Phase 3: Remove kube-proxy ==="
if kubectl get ds -n kube-system kube-proxy &>/dev/null; then
  kubectl -n kube-system delete ds kube-proxy || true
  kubectl -n kube-system delete cm kube-proxy || true
  echo "kube-proxy removed."
else
  echo "kube-proxy not found. Skipping."
fi

# Phase 4: Install Cilium
echo ""
echo "=== Phase 4: Install Cilium ==="
"$SCRIPT_DIR/install.sh"

# Phase 5: Restart all pods
echo ""
echo "=== Phase 5: Restart all workload pods ==="
echo "This ensures all pods use the new CNI..."

# 시스템 네임스페이스 제외
EXCLUDED_NS="kube-system|kube-public|kube-node-lease"

# Deployment 재시작
for deploy in $(kubectl get deploy -A --no-headers | grep -vE "^($EXCLUDED_NS)" | awk '{print $1 "/" $2}'); do
  ns=$(echo "$deploy" | cut -d'/' -f1)
  name=$(echo "$deploy" | cut -d'/' -f2)
  echo "  Restarting deployment: $ns/$name"
  kubectl rollout restart deploy/"$name" -n "$ns" 2>/dev/null || true
done

# StatefulSet 재시작
for sts in $(kubectl get sts -A --no-headers | grep -vE "^($EXCLUDED_NS)" | awk '{print $1 "/" $2}'); do
  ns=$(echo "$sts" | cut -d'/' -f1)
  name=$(echo "$sts" | cut -d'/' -f2)
  echo "  Restarting statefulset: $ns/$name"
  kubectl rollout restart sts/"$name" -n "$ns" 2>/dev/null || true
done

# DaemonSet 재시작 (시스템 제외)
for ds in $(kubectl get ds -A --no-headers | grep -vE "^($EXCLUDED_NS)" | awk '{print $1 "/" $2}'); do
  ns=$(echo "$ds" | cut -d'/' -f1)
  name=$(echo "$ds" | cut -d'/' -f2)
  echo "  Restarting daemonset: $ns/$name"
  kubectl rollout restart ds/"$name" -n "$ns" 2>/dev/null || true
done

# Phase 6: Verification
echo ""
echo "=== Phase 6: Verification ==="
echo ""

# Cilium 상태
echo "Cilium Status:"
kubectl -n kube-system exec -it ds/cilium -- cilium status --brief 2>/dev/null || {
  echo "  Cilium CLI not ready yet. Waiting..."
  sleep 10
  kubectl -n kube-system exec -it ds/cilium -- cilium status --brief 2>/dev/null || echo "  Still not ready. Check manually."
}

# Pod 상태
echo ""
echo "Pod Status:"
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null | head -20 || echo "  All pods running!"

# 소요 시간
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║               Migration Complete!                             ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  Duration: ${MINUTES}m ${SECONDS}s                                          "
echo "║  Backup: $BACKUP_DIR                                          "
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "1. Test connectivity:"
echo "   kubectl -n kube-system exec -it ds/cilium -- cilium connectivity test"
echo ""
echo "2. Access Hubble UI:"
echo "   kubectl port-forward -n kube-system svc/hubble-ui 12000:80"
echo ""
echo "3. Verify services:"
echo "   kubectl get svc -A"
echo "   curl -k https://<your-service>"
