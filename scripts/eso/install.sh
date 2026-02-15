#!/usr/bin/env bash
set -euo pipefail

# External Secrets Operator 설치 (공식 Helm chart)
# Usage: ./scripts/eso/install.sh

NAMESPACE="external-secrets"

echo "=== External Secrets Operator Install ==="

# helm repo 추가
helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true
helm repo update

# namespace 생성
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# ESO 설치 (control-plane 노드에 배치)
helm upgrade --install external-secrets \
  external-secrets/external-secrets \
  -n "$NAMESPACE" \
  --set installCRDs=true \
  --set nodeSelector."node-role\.kubernetes\.io/control-plane"="" \
  --set webhook.nodeSelector."node-role\.kubernetes\.io/control-plane"="" \
  --set certController.nodeSelector."node-role\.kubernetes\.io/control-plane"="" \
  --wait

# CRD 등록 대기
echo "Waiting for CRDs to be registered..."
kubectl wait --for condition=established --timeout=60s \
  crd/clustersecretstores.external-secrets.io \
  crd/externalsecrets.external-secrets.io

echo ""
echo "ESO installed. Next steps:"
echo "  1. ./scripts/eso/bootstrap-aws.sh  (AWS 자격증명 등록)"
echo "  2. ArgoCD가 ClusterSecretStore를 helm repo에서 배포합니다."
