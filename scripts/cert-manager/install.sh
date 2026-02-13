#!/usr/bin/env bash
set -euo pipefail

# cert-manager 설치 (공식 Helm chart)
# Usage: ./scripts/cert-manager/install.sh

NAMESPACE="cert-manager"

echo "=== cert-manager Install ==="

# helm repo 추가
helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
helm repo update

# cert-manager 설치 (CRDs 포함)
helm upgrade --install cert-manager jetstack/cert-manager \
  -n "$NAMESPACE" \
  --create-namespace \
  --set installCRDs=true \
  --wait

echo ""
echo "cert-manager installed."
echo "ClusterIssuer/Certificate는 ArgoCD가 helm repo에서 배포합니다."
