#!/usr/bin/env bash
set -euo pipefail

# Sealed Secrets Controller 설치
# ESO(External Secrets Operator) 대체 — AWS Secrets Manager 비용 제거
# Usage: ./scripts/sealed-secrets/install.sh

NAMESPACE="kube-system"

echo "=== Sealed Secrets Controller Install ==="

# helm repo
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets 2>/dev/null || true
helm repo update sealed-secrets

# 설치 (control-plane 노드에 배치)
helm upgrade --install sealed-secrets \
  sealed-secrets/sealed-secrets \
  -n "$NAMESPACE" \
  --set nodeSelector."node-role\.kubernetes\.io/control-plane"="" \
  --set tolerations[0].key="node-role.kubernetes.io/control-plane" \
  --set tolerations[0].operator="Exists" \
  --set tolerations[0].effect="NoSchedule" \
  --wait --timeout=3m

echo "Waiting for controller to be ready..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=sealed-secrets \
  -n "$NAMESPACE" --timeout=60s

echo ""
echo "=== Sealed Secrets 설치 완료 ==="
echo ""
echo "공개키 추출:"
echo "  kubeseal --fetch-cert --controller-name=sealed-secrets --controller-namespace=kube-system > pub-cert.pem"
echo ""
echo "키 백업 (필수! 키 분실 시 기존 SealedSecret 복호화 불가):"
echo "  ./scripts/sealed-secrets/backup-key.sh"
echo ""
echo "시크릿 암호화 예시:"
echo "  echo -n 'my-password' | kubeseal --raw --cert pub-cert.pem --scope cluster-wide"
