#!/usr/bin/env bash
set -euo pipefail

# AWS 자격증명 부트스트랩 (유일한 수동 secret)
#
# ESO, cert-manager(DNS-01), DDNS(Route53) 모두 같은 AWS 자격증명 사용.
# 각 네임스페이스에 secret을 생성함.
#
# Usage:
#   ./scripts/eso/bootstrap-aws.sh
#   AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=yyy ./scripts/eso/bootstrap-aws.sh

# 자격증명이 필요한 네임스페이스 + secret 이름
declare -A SECRETS=(
  ["external-secrets"]="eso-aws-credentials"
  ["cert-manager"]="route53-credentials"
  ["kube-system"]="route53-ddns-credentials"
)

echo "=== AWS Bootstrap ==="
echo ""
echo "Secrets will be created in:"
for NS in "${!SECRETS[@]}"; do
  echo "  - ${NS}/${SECRETS[$NS]}"
done
echo ""

# AWS Access Key ID
if [ -z "${AWS_ACCESS_KEY_ID:-}" ]; then
  read -rp "AWS Access Key ID: " AWS_ACCESS_KEY_ID
fi

# AWS Secret Access Key
if [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
  read -rsp "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
  echo ""
fi

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  echo "ERROR: Both AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are required"
  exit 1
fi

for NS in "${!SECRETS[@]}"; do
  SECRET_NAME="${SECRETS[$NS]}"

  # 네임스페이스 생성 (없으면)
  kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null

  # 기존 secret 삭제 (있으면)
  kubectl delete secret "$SECRET_NAME" -n "$NS" 2>/dev/null || true

  # ESO는 access-key, 나머지는 access-key-id 사용
  if [ "$NS" = "external-secrets" ]; then
    kubectl create secret generic "$SECRET_NAME" \
      --from-literal=access-key="$AWS_ACCESS_KEY_ID" \
      --from-literal=secret-access-key="$AWS_SECRET_ACCESS_KEY" \
      -n "$NS"
  else
    kubectl create secret generic "$SECRET_NAME" \
      --from-literal=access-key-id="$AWS_ACCESS_KEY_ID" \
      --from-literal=secret-access-key="$AWS_SECRET_ACCESS_KEY" \
      -n "$NS"
  fi

  echo "  Created: ${NS}/${SECRET_NAME}"
done

echo ""
echo "=== Creating ClusterSecretStore ==="

cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: ${AWS_REGION:-ap-northeast-2}
      auth:
        secretRef:
          accessKeyIDSecretRef:
            name: eso-aws-credentials
            namespace: external-secrets
            key: access-key
          secretAccessKeySecretRef:
            name: eso-aws-credentials
            namespace: external-secrets
            key: secret-access-key
EOF

echo "  Created: ClusterSecretStore/aws-secrets-manager"

echo ""
echo "Bootstrap complete."
