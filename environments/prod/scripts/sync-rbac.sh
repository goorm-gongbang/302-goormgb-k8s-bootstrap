#!/usr/bin/env bash
set -euo pipefail

# ArgoCD RBAC ConfigMap 동기화
# ESO Secret(argocd-rbac-eso) → ConfigMap(argocd-rbac-cm)
#
# Usage:
#   ./prod/scripts/sync-rbac.sh
#
# AWS Secrets Manager 변경 후:
#   1. ESO가 1시간마다 Secret 자동 업데이트
#   2. 이 스크립트로 ConfigMap 동기화 필요

echo "=== ArgoCD RBAC 동기화 중 ==="

# Secret 확인
if ! kubectl get secret argocd-rbac-eso -n argocd &>/dev/null; then
  echo "오류: argocd-rbac-eso 시크릿을 찾을 수 없습니다"
  echo ""
  echo "확인:"
  echo "  kubectl get externalsecret -n argocd"
  echo "  aws secretsmanager get-secret-value --secret-id prod/oauth/rbac/argocd"
  exit 1
fi

# policy_csv 추출
policy=$(kubectl get secret argocd-rbac-eso -n argocd -o jsonpath='{.data.policy_csv}' | base64 -d)

if [[ -z "$policy" ]]; then
  echo "오류: policy_csv가 비어있습니다"
  exit 1
fi

echo "현재 RBAC 정책:"
echo "$policy" | sed 's/^/  /'
echo ""

# ConfigMap 업데이트
kubectl create configmap argocd-rbac-cm -n argocd \
  --from-literal="policy.csv=$policy" \
  --from-literal="policy.default=role:none" \
  --from-literal="scopes=[email]" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "ConfigMap 업데이트 완료."

# ArgoCD server 재시작
echo "ArgoCD 서버 재시작 중..."
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd --timeout=60s

echo ""
echo "=== RBAC 동기화 완료 ==="
