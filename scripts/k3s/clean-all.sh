#!/usr/bin/env bash
set -euo pipefail

# k3s 클러스터 내 모든 Helm 릴리스 + 네임스페이스 정리
# k3s 자체는 유지, 내부만 초기화
#
# Usage: ./scripts/k3s/clean-all.sh

NAMESPACES="dev-app dev data argocd cert-manager external-secrets istio-system monitoring staging"
NS_DELETE_TIMEOUT=30  # 초

force_delete_ns() {
  local ns=$1
  echo "  ⏳ $ns stuck in Terminating, removing finalizers..."
  kubectl get ns "$ns" -o json | \
    sed 's/"kubernetes"//g' | \
    kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - 2>/dev/null || true

  # 실제 삭제될 때까지 대기
  echo "  ⏳ Waiting for $ns to be fully deleted..."
  local wait_count=0
  while kubectl get ns "$ns" &>/dev/null; do
    sleep 1
    ((wait_count++))
    if [[ $wait_count -ge 60 ]]; then
      echo "  ❌ $ns deletion timeout (60s)"
      return 1
    fi
  done
  echo "  ✅ $ns deleted"
}

echo "=== k3s Clean All ==="
echo ""
echo "This will REMOVE:"
echo "  - All app Helm releases (dev)"
echo "  - All infra Helm releases (ArgoCD, DDNS, WAF, cert-manager, ESO)"
echo "  - Istio"
echo "  - All related namespaces"
echo ""
read -rp "Are you sure? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "--- Removing app releases ---"
# dev-app namespace의 모든 helm release 삭제
for release in $(helm list -n dev-app -q 2>/dev/null); do
  echo "  Removing $release from dev-app..."
  helm uninstall "$release" -n dev-app 2>/dev/null || true
done
# 구버전 dev namespace도 정리
for release in $(helm list -n dev -q 2>/dev/null); do
  echo "  Removing $release from dev..."
  helm uninstall "$release" -n dev 2>/dev/null || true
done

echo ""
echo "--- Removing Data Services (PostgreSQL, Redis) ---"
helm uninstall postgresql -n data 2>/dev/null || true
helm uninstall redis -n data 2>/dev/null || true

echo ""
echo "--- Removing Monitoring Stack ---"
helm uninstall prometheus-stack -n monitoring 2>/dev/null || true
helm uninstall loki -n monitoring 2>/dev/null || true
helm uninstall tempo -n monitoring 2>/dev/null || true

echo ""
echo "--- Removing ArgoCD ---"
helm uninstall argocd-config -n argocd 2>/dev/null || true
helm uninstall argocd -n argocd 2>/dev/null || true

echo ""
echo "--- Removing DDNS ---"
helm uninstall ddns-route53 -n kube-system 2>/dev/null || true

echo ""
echo "--- Removing WAF ---"
helm uninstall waf -n istio-system 2>/dev/null || true

echo ""
echo "--- Removing cert-manager ---"
helm uninstall cert-manager-config -n cert-manager 2>/dev/null || true
helm uninstall cert-manager -n cert-manager 2>/dev/null || true

echo ""
echo "--- Removing ESO ---"
helm uninstall eso-config -n external-secrets 2>/dev/null || true
helm uninstall external-secrets -n external-secrets 2>/dev/null || true

echo ""
echo "--- Removing Istio ---"
if command -v istioctl &>/dev/null; then
  istioctl uninstall --purge -y 2>/dev/null || true
fi

echo ""
echo "--- Deleting namespaces (timeout: ${NS_DELETE_TIMEOUT}s per ns) ---"
for ns in $NAMESPACES; do
  if kubectl get ns "$ns" &>/dev/null; then
    echo "  Deleting $ns..."
    timeout "$NS_DELETE_TIMEOUT" kubectl delete ns "$ns" --ignore-not-found 2>/dev/null || force_delete_ns "$ns"
  fi
done

echo ""
echo "--- Verifying all namespaces deleted ---"
FAILED=0
for ns in $NAMESPACES; do
  if kubectl get ns "$ns" &>/dev/null; then
    echo "  ❌ $ns still exists!"
    FAILED=1
  fi
done

if [[ $FAILED -eq 1 ]]; then
  echo ""
  echo "❌ Some namespaces not fully deleted. Run clean-all again or delete manually."
  exit 1
fi

echo "  ✅ All namespaces cleaned"
echo ""
echo "=== Clean complete ==="
echo ""
echo "Re-setup: make install-all"
