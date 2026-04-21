#!/usr/bin/env bash
set -euo pipefail

# Sealed Secrets 마스터 키 백업
# 키 분실 시 기존 SealedSecret 복호화 불가 → 백업 필수
# SSM Parameter Store (Standard tier = 무료)에 저장

CONTROLLER_NAME="sealed-secrets"
CONTROLLER_NS="kube-system"
AWS_PROFILE="${AWS_PROFILE:-wonny}"
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
SSM_PARAM="/sealed-secrets/dev/sealing-key"

echo "=== Sealed Secrets Key Backup ==="

# 마스터 키 추출
echo "Extracting sealing key from cluster..."
KEY_JSON=$(kubectl get secret -n "$CONTROLLER_NS" -l sealedsecrets.bitnami.com/sealed-secrets-key=active -o json)

if [ -z "$KEY_JSON" ] || [ "$KEY_JSON" = "null" ]; then
  echo "ERROR: Sealing key not found. Is sealed-secrets controller installed?"
  exit 1
fi

echo "Backing up to SSM Parameter Store: $SSM_PARAM"
aws ssm put-parameter \
  --name "$SSM_PARAM" \
  --type SecureString \
  --value "$KEY_JSON" \
  --overwrite \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION"

echo ""
echo "=== 백업 완료 ==="
echo "  SSM Parameter: $SSM_PARAM"
echo "  Profile: $AWS_PROFILE"
echo ""
echo "복원 방법:"
echo "  aws ssm get-parameter --name $SSM_PARAM --with-decryption --profile $AWS_PROFILE --region $AWS_REGION --query Parameter.Value --output text | kubectl apply -f -"
