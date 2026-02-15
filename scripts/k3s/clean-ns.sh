#!/usr/bin/env bash
set -euo pipefail

# k3s 클러스터 내 모든 앱/인프라 정리 (k3s 자체는 유지)
# Usage: ./scripts/k3s/clean-ns.sh

NAMESPACES="dev-app dev data argocd cert-manager external-secrets istio-system monitoring staging"

echo "=== k3s Clean Namespaces ==="
echo ""
echo "This will REMOVE:"
echo "  - All ArgoCD Applications"
echo "  - All Helm releases"
echo "  - All app namespaces"
echo "  - Istio"
echo ""
echo "k3s cluster itself will be preserved."
echo ""
read -rp "Are you sure? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "=== Step 1: Stop ArgoCD auto-sync ==="
kubectl delete applicationsets.argoproj.io --all -n argocd --wait=false 2>/dev/null || true
kubectl delete applications.argoproj.io --all -n argocd --wait=false 2>/dev/null || true
echo "Waiting for Applications to be deleted..."
sleep 5

echo ""
echo "=== Step 2: Uninstall Helm releases ==="
# 모든 namespace의 helm release 삭제
for ns in $NAMESPACES kube-system; do
  for release in $(helm list -n "$ns" -q 2>/dev/null); do
    echo "  Uninstalling $release from $ns..."
    helm uninstall "$release" -n "$ns" --no-hooks --wait=false 2>/dev/null || true
  done
  # helm release secret 정리
  kubectl delete secret -n "$ns" -l owner=helm --wait=false 2>/dev/null || true
done

echo ""
echo "=== Step 3: Delete Istio CRDs and uninstall ==="
# Istio CRD 리소스 먼저 삭제
kubectl delete virtualservice --all -A --wait=false 2>/dev/null || true
kubectl delete gateway --all -A --wait=false 2>/dev/null || true
kubectl delete destinationrule --all -A --wait=false 2>/dev/null || true
kubectl delete serviceentry --all -A --wait=false 2>/dev/null || true
kubectl delete envoyfilter --all -A --wait=false 2>/dev/null || true
kubectl delete peerauthentication --all -A --wait=false 2>/dev/null || true
kubectl delete authorizationpolicy --all -A --wait=false 2>/dev/null || true

if command -v istioctl &>/dev/null; then
  istioctl uninstall --purge -y 2>/dev/null || true
fi

echo ""
echo "=== Step 4: Force delete all resources in namespaces ==="
for ns in $NAMESPACES; do
  if kubectl get ns "$ns" &>/dev/null; then
    echo "  Cleaning $ns..."

    # 컨트롤러 삭제 (순서 중요)
    kubectl delete hpa --all -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
    kubectl delete statefulset --all -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
    kubectl delete daemonset --all -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
    kubectl delete deployment --all -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
    kubectl delete replicaset --all -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
    kubectl delete job --all -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
    kubectl delete cronjob --all -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true

    # Pod finalizer 제거
    for pod in $(kubectl get pods -n "$ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
      kubectl patch pod "$pod" -n "$ns" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
    done
    kubectl delete pods --all -n "$ns" --force --grace-period=0 2>/dev/null || true

    # 기타 리소스
    kubectl delete pvc --all -n "$ns" --force --grace-period=0 2>/dev/null || true
    kubectl delete svc --all -n "$ns" 2>/dev/null || true
    kubectl delete externalsecrets.external-secrets.io --all -n "$ns" 2>/dev/null || true
    kubectl delete secrets --all -n "$ns" 2>/dev/null || true
    kubectl delete configmaps --all -n "$ns" 2>/dev/null || true
  fi
done

echo ""
echo "=== Step 5: Delete namespaces ==="
for ns in $NAMESPACES; do
  if kubectl get ns "$ns" &>/dev/null; then
    echo "  Deleting namespace $ns..."
    kubectl delete ns "$ns" --wait=false 2>/dev/null || true
  fi
done

echo ""
echo "=== Step 6: Wait and force finalize stuck namespaces ==="
sleep 5
for ns in $NAMESPACES; do
  if kubectl get ns "$ns" &>/dev/null; then
    status=$(kubectl get ns "$ns" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    if [[ "$status" == "Terminating" ]]; then
      echo "  $ns stuck in Terminating, removing finalizers..."
      kubectl get ns "$ns" -o json | \
        sed 's/"kubernetes"//g' | \
        kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - 2>/dev/null || true
    fi
  fi
done

echo ""
echo "=== Step 7: Final verification ==="
sleep 3
FAILED=0
for ns in $NAMESPACES; do
  if kubectl get ns "$ns" &>/dev/null; then
    echo "  ⚠️  $ns still exists (may take more time)"
    FAILED=1
  fi
done

if [[ $FAILED -eq 1 ]]; then
  echo ""
  echo "Some namespaces still deleting. Wait a moment and check:"
  echo "  kubectl get ns"
else
  echo "  ✅ All namespaces cleaned"
fi

echo ""
echo "=== Clean complete ==="
echo ""
echo "Next: make install-all"
