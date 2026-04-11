#!/usr/bin/env bash
set -euo pipefail

# ACM 인증서 발급 + DNS 검증 (CA 계정 ↔ 본계정)
#
# Usage:
#   ./scripts/setup-acm.sh
#
# 필요 프로파일:
#   ca    — CA 계정 (ACM 발급)
#   wonny — 본계정 (Route53 DNS 검증)

CA_PROFILE="${CA_PROFILE:-ca}"
MAIN_PROFILE="${MAIN_PROFILE:-wonny}"
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
DOMAIN="*.playball.one"
HOSTED_ZONE_ID="Z06217713T86C6U2PCR1J"

echo "=================================================="
echo "  ACM 인증서 발급 (CA 계정)"
echo "=================================================="
echo ""
echo "  Domain: $DOMAIN"
echo "  CA Profile: $CA_PROFILE"
echo "  Main Profile: $MAIN_PROFILE"
echo ""

# 기존 인증서 확인
EXISTING_ARN=$(aws acm list-certificates --profile "$CA_PROFILE" --region "$AWS_REGION" \
  --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn" --output text 2>/dev/null || echo "")

if [[ -n "$EXISTING_ARN" && "$EXISTING_ARN" != "None" ]]; then
  STATUS=$(aws acm describe-certificate --certificate-arn "$EXISTING_ARN" --profile "$CA_PROFILE" --region "$AWS_REGION" \
    --query 'Certificate.Status' --output text 2>/dev/null || echo "")
  if [[ "$STATUS" == "ISSUED" ]]; then
    echo "✓ 인증서 이미 발급됨: $EXISTING_ARN"
    echo ""
    echo "alb-ingress values에 이 ARN을 사용하세요:"
    echo "  certificateArn: $EXISTING_ARN"
    exit 0
  fi
  echo "기존 인증서 발견 (status: $STATUS): $EXISTING_ARN"
  CERT_ARN="$EXISTING_ARN"
else
  # 새 인증서 요청
  echo "ACM 인증서 요청 중..."
  CERT_ARN=$(aws acm request-certificate \
    --domain-name "$DOMAIN" \
    --validation-method DNS \
    --profile "$CA_PROFILE" \
    --region "$AWS_REGION" \
    --query 'CertificateArn' --output text)
  echo "  인증서 ARN: $CERT_ARN"
fi

# DNS 검증 레코드 조회 (생성 대기)
echo ""
echo "DNS 검증 레코드 조회 중..."
VALIDATION=""
for i in {1..10}; do
  VALIDATION=$(aws acm describe-certificate \
    --certificate-arn "$CERT_ARN" \
    --profile "$CA_PROFILE" \
    --region "$AWS_REGION" \
    --query 'Certificate.DomainValidationOptions[].[ResourceRecord.Name,ResourceRecord.Value]' \
    --output text 2>/dev/null)
  # None이 아닌 실제 값이 있는지 확인
  if [[ -n "$VALIDATION" ]] && ! echo "$VALIDATION" | grep -q "None"; then
    break
  fi
  echo "  대기 중... ($i/10)"
  sleep 3
done

if [[ -z "$VALIDATION" ]] || echo "$VALIDATION" | grep -q "None"; then
  echo "ERROR: DNS 검증 레코드를 가져올 수 없습니다."
  echo "  수동 확인: aws acm describe-certificate --certificate-arn $CERT_ARN --profile $CA_PROFILE --region $AWS_REGION"
  exit 1
fi

# Route53 변경 JSON 생성
CHANGES=""
while IFS=$'\t' read -r name value; do
  [[ -z "$name" ]] && continue
  if [[ -n "$CHANGES" ]]; then
    CHANGES="$CHANGES,"
  fi
  CHANGES="$CHANGES{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"$name\",\"Type\":\"CNAME\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"$value\"}]}}"
  echo "  $name → $value"
done <<< "$VALIDATION"

# 본계정 Route53에 DNS 검증 레코드 추가
echo ""
echo "본계정 Route53에 DNS 검증 레코드 추가 중..."
CHANGE_BATCH="{\"Changes\":[$CHANGES]}"

aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --profile "$MAIN_PROFILE" \
  --change-batch "$CHANGE_BATCH" > /dev/null

echo "  ✓ DNS 레코드 추가 완료"

# 발급 대기
echo ""
echo "인증서 발급 대기 중 (최대 5분)..."
if aws acm wait certificate-validated \
  --certificate-arn "$CERT_ARN" \
  --profile "$CA_PROFILE" \
  --region "$AWS_REGION" 2>/dev/null; then
  echo "  ✓ 인증서 발급 완료!"
else
  echo "  ! 타임아웃 — 수동 확인 필요"
  echo "    aws acm describe-certificate --certificate-arn $CERT_ARN --profile $CA_PROFILE --region $AWS_REGION"
fi

echo ""
echo "=================================================="
echo "  인증서 ARN: $CERT_ARN"
echo "=================================================="
echo ""
echo "alb-ingress values에 반영:"
echo "  certificateArn: $CERT_ARN"
