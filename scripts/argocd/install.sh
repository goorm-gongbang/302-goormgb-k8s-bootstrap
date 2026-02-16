#!/usr/bin/env bash
set -euo pipefail

# ArgoCD 설치 (공식 Helm chart)
# Usage: ./scripts/argocd/install.sh

NAMESPACE="argocd"

echo "=== ArgoCD Install ==="

# 기존 ArgoCD CRD가 terminating 상태면 완전히 삭제될 때까지 대기
if kubectl get crd applications.argoproj.io &>/dev/null; then
  status=$(kubectl get crd applications.argoproj.io -o jsonpath='{.metadata.deletionTimestamp}' 2>/dev/null || echo "")
  if [[ -n "$status" ]]; then
    echo "ArgoCD CRDs are terminating, waiting for deletion..."
    for i in {1..30}; do
      if ! kubectl get crd applications.argoproj.io &>/dev/null; then
        echo "  CRDs deleted"
        break
      fi
      echo "  Waiting... ($i/30)"
      # finalizer 제거 시도
      kubectl patch crd applications.argoproj.io -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
      sleep 2
    done
  fi
fi

# namespace 먼저 생성 (--create-namespace 버그 대응)
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# helm repo 추가
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update

# ArgoCD 설치
# --insecure: ArgoCD 자체 TLS 비활성화
# 이유: Istio Gateway에서 TLS 종료 후 HTTP로 ArgoCD에 연결
# 구조: Client → HTTPS → Istio Gateway → HTTP → ArgoCD
helm upgrade --install argocd argo/argo-cd \
  -n "$NAMESPACE" \
  --create-namespace \
  --set 'server.extraArgs={--insecure}' \
  --wait

# ArgoCD CRD가 ready인지 확인
echo "Waiting for ArgoCD CRDs to be ready..."
for i in {1..30}; do
  if kubectl get crd applications.argoproj.io &>/dev/null; then
    echo "  ArgoCD CRDs ready"
    break
  fi
  echo "  Waiting for CRDs... ($i/30)"
  sleep 2
done

# Application CRD가 실제로 사용 가능한지 확인
kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=60s 2>/dev/null || true

echo ""
echo "=== ArgoCD Installed ==="
echo ""
echo "Initial admin password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
