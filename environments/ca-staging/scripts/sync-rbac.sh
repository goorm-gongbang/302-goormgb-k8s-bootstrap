#!/usr/bin/env bash
set -euo pipefail

# ArgoCD RBAC ConfigMap 동기화
# ESO Secret(argocd-rbac-eso) → ConfigMap(argocd-rbac-cm)
#
# Usage:
#   ./staging/scripts/sync-rbac.sh
#
# AWS Secrets Manager 변경 후:
#   1. ESO가 1시간마다 Secret 자동 업데이트
#   2. 이 스크립트로 ConfigMap 동기화 필요

echo "=== Syncing ArgoCD RBAC ==="

# Secret 확인
if ! kubectl get secret argocd-rbac-eso -n argocd &>/dev/null; then
  echo "ERROR: argocd-rbac-eso secret not found"
  echo ""
  echo "Check:"
  echo "  kubectl get externalsecret -n argocd"
  echo "  aws secretsmanager get-secret-value --secret-id staging/argocd"
  exit 1
fi

# policy_csv 추출
policy=$(kubectl get secret argocd-rbac-eso -n argocd -o jsonpath='{.data.policy_csv}' | base64 -d)

if [[ -z "$policy" ]]; then
  echo "ERROR: policy_csv is empty"
  exit 1
fi

echo "Current RBAC policy:"
echo "$policy" | sed 's/^/  /'
echo ""

# ConfigMap 업데이트
kubectl create configmap argocd-rbac-cm -n argocd \
  --from-literal="policy.csv=$policy" \
  --from-literal="policy.default=role:none" \
  --from-literal="scopes=[email]" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "ConfigMap updated."

# ArgoCD server 재시작
echo "Restarting ArgoCD server..."
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd --timeout=60s

echo ""
echo "=== RBAC Sync Complete ==="
