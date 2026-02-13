#!/usr/bin/env bash
set -euo pipefail

# ArgoCD 설치 (공식 Helm chart)
# Usage: ./scripts/argocd/install.sh

NAMESPACE="argocd"

echo "=== ArgoCD Install ==="

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

echo ""
echo "=== ArgoCD Installed ==="
echo ""
echo "Initial admin password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
