#!/usr/bin/env bash
set -euo pipefail

# kubeadm 클러스터 내 모든 앱/인프라 정리 (클러스터 자체는 유지)
# Usage: ./scripts/clean-ns.sh

NAMESPACES="dev-app dev data argocd cert-manager external-secrets istio-system istio-ingress monitoring staging calico-system calico-apiserver tigera-operator local-path-storage"

echo "=== Clean Namespaces ==="
echo ""
echo "This will REMOVE:"
echo "  - All ArgoCD Applications"
echo "  - All Helm releases"
echo "  - All app namespaces"
echo "  - Istio, Calico, CRDs"
echo ""
echo "kubeadm cluster itself will be preserved."
echo ""
read -rp "Are you sure? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "=== Step 1: Delete ArgoCD apps (cascade) ==="
# Cascade 삭제로 하위 리소스 연쇄 삭제
kubectl delete applicationsets.argoproj.io --all -n argocd --cascade=foreground --timeout=30s 2>/dev/null || true
kubectl delete applications.argoproj.io --all -n argocd --cascade=foreground --timeout=30s 2>/dev/null || true

echo ""
echo "=== Step 2: Uninstall all Helm releases ==="
helm list -A -q 2>/dev/null | xargs -L1 -I{} sh -c 'ns=$(helm list -A --filter "^{}$" -o json 2>/dev/null | jq -r ".[0].namespace // empty"); [ -n "$ns" ] && helm uninstall "{}" -n "$ns" --no-hooks --wait=false 2>/dev/null || true' || true

echo ""
echo "=== Step 3: Stop controllers ==="
kubectl scale deployment -n argocd --all --replicas=0 2>/dev/null || true
kubectl scale deployment -n external-secrets --all --replicas=0 2>/dev/null || true
kubectl scale deployment -n cert-manager --all --replicas=0 2>/dev/null || true
kubectl scale deployment -n tigera-operator --all --replicas=0 2>/dev/null || true
sleep 2

echo ""
echo "=== Step 4: Istio uninstall ==="
ISTIOCTL=""
if command -v istioctl &>/dev/null; then
  ISTIOCTL="istioctl"
elif [[ -x "./istio-1.24.2/bin/istioctl" ]]; then
  ISTIOCTL="./istio-1.24.2/bin/istioctl"
fi
if [[ -n "$ISTIOCTL" ]]; then
  echo "  Using $ISTIOCTL"
  $ISTIOCTL uninstall --purge -y 2>/dev/null || true
fi

echo ""
echo "=== Step 5: Delete Calico resources ==="

# Tigera Operator 먼저 중지 (리소스 재생성 방지)
kubectl scale deployment -n tigera-operator --all --replicas=0 2>/dev/null || true

# Calico namespace 내 리소스 먼저 삭제
for ns in calico-system calico-apiserver; do
  kubectl delete deploy,ds,sts,rs,job --all -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
  kubectl delete pods --all -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
done

# IPPool 삭제
for pool in $(kubectl get ippool -o name 2>/dev/null || true); do
  kubectl patch "$pool" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
  kubectl delete "$pool" --force --grace-period=0 --wait=false 2>/dev/null || true
done

# Installation/APIServer CR 삭제 (finalizer를 빈 배열로)
kubectl patch installation default -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
kubectl delete installation default --force --grace-period=0 --wait=false 2>/dev/null || true
kubectl patch apiserver default -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
kubectl delete apiserver default --force --grace-period=0 --wait=false 2>/dev/null || true

# 삭제 완료 대기 (최대 20초)
echo "  Waiting for Calico CRs to be deleted..."
for i in {1..10}; do
  if ! kubectl get installation default &>/dev/null && ! kubectl get apiserver default &>/dev/null; then
    echo "  Calico CRs deleted"
    break
  fi
  kubectl patch installation default -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
  kubectl patch apiserver default -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
  sleep 2
done

# tigera-operator namespace 정리
kubectl delete deploy,ds,sts,rs,job --all -n tigera-operator --force --grace-period=0 --wait=false 2>/dev/null || true
kubectl delete pods --all -n tigera-operator --force --grace-period=0 --wait=false 2>/dev/null || true

echo ""
echo "=== Step 6: Delete namespaces and force finalize ==="
for ns in $NAMESPACES; do
  if kubectl get ns "$ns" &>/dev/null; then
    echo "  Processing $ns..."
    # 1. 삭제 명령 (비동기)
    kubectl delete ns "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
    # 2. 바로 Finalizer 제거 API 호출
    kubectl get ns "$ns" -o json 2>/dev/null | \
      jq '.spec.finalizers = null' | \
      kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - 2>/dev/null || true
  fi
done

echo ""
echo "=== Step 7: Delete CRDs ==="
# CRD finalizer 제거 후 삭제
for crd in $(kubectl get crd -o name 2>/dev/null | grep -E "istio|cert-manager|argoproj|tigera|calico|projectcalico|external-secrets"); do
  kubectl patch "$crd" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  kubectl delete "$crd" --wait=false 2>/dev/null || true
done

# CRD가 완전히 삭제될 때까지 대기 (최대 30초)
echo "  Waiting for CRDs to be deleted..."
for i in {1..15}; do
  if ! kubectl get crd -o name 2>/dev/null | grep -qE "istio|cert-manager|argoproj|tigera|calico|projectcalico|external-secrets"; then
    echo "  All CRDs deleted"
    break
  fi
  echo "  Waiting... ($i/15)"
  # 남은 CRD finalizer 제거 재시도
  for crd in $(kubectl get crd -o name 2>/dev/null | grep -E "istio|cert-manager|argoproj|tigera|calico|projectcalico|external-secrets" 2>/dev/null || true); do
    kubectl patch "$crd" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  done
  sleep 2
done

echo ""
echo "=== Step 8: Force delete orphan pods ==="
for ns in $NAMESPACES; do
  kubectl delete pods --all -n "$ns" --force --grace-period=0 2>/dev/null || true
done

echo ""
echo "=== Step 9: Final verification ==="
sleep 2
REMAINING=""
for ns in $NAMESPACES; do
  if kubectl get ns "$ns" &>/dev/null; then
    REMAINING="$REMAINING $ns"
  fi
done

if [[ -n "$REMAINING" ]]; then
  echo "  Remaining namespaces:$REMAINING"
  echo "  Retrying finalize..."
  for ns in $REMAINING; do
    kubectl get ns "$ns" -o json 2>/dev/null | \
      jq '.spec.finalizers = null' | \
      kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - 2>/dev/null || true
  done
  sleep 2
fi

# 최종 확인
FAILED=0
for ns in $NAMESPACES; do
  if kubectl get ns "$ns" &>/dev/null; then
    echo "  $ns still exists"
    FAILED=1
  fi
done

if [[ $FAILED -eq 0 ]]; then
  echo "  All namespaces cleaned"
fi

echo ""
echo "=== Clean complete ==="
echo ""
echo "Next: make install-all"
