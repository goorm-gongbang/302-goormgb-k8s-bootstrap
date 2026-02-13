#!/usr/bin/env bash
set -euo pipefail

# k3s 클러스터 내 모든 Helm 릴리스 + 네임스페이스 정리
# k3s 자체는 유지, 내부만 초기화
#
# Usage: ./scripts/k3s/clean-all.sh

NAMESPACES="dev qa data argocd cert-manager external-secrets istio-system"
NS_DELETE_TIMEOUT=30  # 초

force_delete_ns() {
  local ns=$1
  echo "  ⏳ $ns stuck in Terminating, removing finalizers..."
  kubectl get ns "$ns" -o json | \
    sed 's/"kubernetes"//g' | \
    kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - 2>/dev/null || true
}

echo "=== k3s Clean All ==="
echo ""
echo "This will REMOVE:"
echo "  - All app Helm releases (dev, qa)"
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
# dev namespace의 모든 helm release 삭제
for release in $(helm list -n dev -q 2>/dev/null); do
  echo "  Removing $release from dev..."
  helm uninstall "$release" -n dev 2>/dev/null || true
done
# qa namespace의 모든 helm release 삭제
for release in $(helm list -n qa -q 2>/dev/null); do
  echo "  Removing $release from qa..."
  helm uninstall "$release" -n qa 2>/dev/null || true
done

echo ""
echo "--- Removing Data Services (PostgreSQL, Redis) ---"
helm uninstall postgresql -n data 2>/dev/null || true
helm uninstall redis -n data 2>/dev/null || true

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
echo "=== Clean complete ==="
echo ""
echo "Re-setup order:"
echo "  1. ./scripts/eso/install.sh && ./scripts/eso/bootstrap-aws.sh"
echo "  2. ./scripts/cert-manager/install.sh"
echo "  3. ./scripts/istio/install.sh"
echo "  4. ./scripts/argocd/install.sh"
echo "  5. kubectl apply -f argocd/root-application.yaml"
