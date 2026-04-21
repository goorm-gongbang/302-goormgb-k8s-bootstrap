#!/usr/bin/env bash
set -euo pipefail

# 기존 K8s Secret → SealedSecret 변환 스크립트
# ESO → Sealed Secrets 마이그레이션용
# Usage: ./scripts/sealed-secrets/seal-existing-secrets.sh

CONTROLLER_NAME="sealed-secrets"
CONTROLLER_NS="kube-system"
OUTPUT_DIR="${1:-./sealed-output}"

echo "=== Existing Secrets → SealedSecret 변환 ==="

# 공개키 추출
CERT_FILE=$(mktemp /tmp/sealed-cert-XXXXXX.pem)
kubeseal --fetch-cert \
  --controller-name="$CONTROLLER_NAME" \
  --controller-namespace="$CONTROLLER_NS" \
  > "$CERT_FILE"

echo "Public cert: $CERT_FILE"
mkdir -p "$OUTPUT_DIR"

# 변환 대상 시크릿 목록 (ESO가 생성한 것들)
declare -A SECRETS=(
  ["dev-webs/service-config"]="service-config"
  ["dev-webs/mail-config"]="mail-config"
  ["dev-ai/ai-service-config"]="ai-service-config"
  ["monitoring/ai-service-config"]="ai-service-config-monitoring"
  ["cert-manager/cloudflare-cert-manager-credentials"]="cloudflare-cert-manager"
  ["istio-system/cloudflare-ddns-credentials"]="cloudflare-ddns"
  ["istio-system/oauth2-proxy-secrets"]="oauth2-proxy-secrets"
  ["istio-system/oauth2-proxy-emails"]="oauth2-proxy-emails"
  ["data/postgresql-credentials"]="postgresql-credentials"
  ["data/postgresql-backup-s3"]="postgresql-backup-s3"
  ["data/cloudbeaver-oauth"]="cloudbeaver-oauth"
  ["data/cloudbeaver-emails"]="cloudbeaver-emails"
  ["data/redisinsight-oauth"]="redisinsight-oauth"
  ["data/redisinsight-emails"]="redisinsight-emails"
  ["argocd/argocd-google-oauth"]="argocd-google-oauth"
  ["argocd/repo-goormgb-helm"]="repo-goormgb-helm"
)

for ns_secret in "${!SECRETS[@]}"; do
  ns="${ns_secret%%/*}"
  secret="${ns_secret##*/}"
  filename="${SECRETS[$ns_secret]}"

  echo -n "  $ns/$secret → $filename.yaml ... "

  # Secret 추출 (managedFields, resourceVersion 등 제거)
  if kubectl get secret "$secret" -n "$ns" -o yaml 2>/dev/null | \
     yq 'del(.metadata.managedFields, .metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp, .metadata.annotations["kubectl.kubernetes.io/last-applied-configuration"], .metadata.ownerReferences)' | \
     kubeseal --cert "$CERT_FILE" --format yaml \
     > "$OUTPUT_DIR/$filename.yaml" 2>/dev/null; then
    echo "OK"
  else
    echo "SKIP (not found or error)"
  fi
done

rm -f "$CERT_FILE"

echo ""
echo "=== 변환 완료 ==="
echo "출력 디렉토리: $OUTPUT_DIR"
echo ""
echo "다음 단계:"
echo "  1. 출력 파일을 303 helm 레포의 dev/sealed-secrets/ 에 복사"
echo "  2. ArgoCD sync"
echo "  3. ESO 제거"
