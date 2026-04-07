#!/bin/bash
# ==================================================
# Prod EKS Clean-up Script
# ArgoCD, ESO, Karpenter 및 애플리케이션 리소스를
# 테라폼 프로비저닝 직후의 초기 상태로 싹 지웁니다.
# ==================================================
set -e

echo "⚠️  경고: 이 스크립트는 클러스터의 모든 애플리케이션, ArgoCD, ESO 데이터를 삭제합니다."
read -p "정말 진행하시겠습니까? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "취소되었습니다."
  exit 0
fi

echo "=================================================="
echo "  클러스터 초기화 시작..."
echo "=================================================="

# 1. ArgoCD 애플리케이션 삭제 (가장 중요: 인프라/클라우드 자원 정상 해제)
echo "=== 1. ArgoCD 애플리케이션 삭제 중 ==="
if kubectl get application root-prod -n argocd &>/dev/null; then
  echo "  (1) root-prod 애플리케이션 삭제 트리거..."
  kubectl delete -f "$(dirname "$0")/../argo-init/root-application.yaml" --ignore-not-found --timeout=30s || true
  
  echo "  (2) 삭제될 때까지 대기 시작 (AWS ALB, ExternalDNS 자원 정리 대기)"
  echo "  이 작업은 ALB 삭제 등으로 인해 최대 5~10분이 소요될 수 있습니다."
  
  for i in {1..30}; do
    APPS=$(kubectl get application -n argocd -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    if [ -z "$APPS" ]; then
      echo "  모든 엡 삭제 완료!"
      break
    fi
    echo "  아직 남아있는 앱들 삭제 대기 중... ($i/30)"
    sleep 10
  done

  # 타임아웃 났을 시 Finalizer 강제 제거
  if kubectl get application -n argocd &>/dev/null; then
    echo "  경고: 일부 앱이 삭제되지 않았습니다. Finalizer 강제 제거 중..."
    kubectl patch application -n argocd -p '{"metadata":{"finalizers":null}}' --type=merge --all 2>/dev/null || true
  fi
else
  echo "  root-prod 애플리케이션이 없으므로 통과합니다."
fi

echo ""

# 2. Webhook 무력화 (삭제 시 Webhook이 막는 현상 방지)
echo "=== 2. 방해되는 Webhook 사전 제거 중 ==="
WEBHOOKS=(
  "aws-load-balancer-webhook"
  "external-secrets-webhook"
  "karpenter-webhook"
  "istiod-default-validator"
  "istio-validator-istio-system"
)
for wh in "${WEBHOOKS[@]}"; do
  kubectl delete validatingwebhookconfigurations "$wh" --ignore-not-found 2>/dev/null || true
  kubectl delete mutatingwebhookconfigurations "$wh" --ignore-not-found 2>/dev/null || true
done
echo "  Webhook 제거 완료"
echo ""

# 3. Helm 설치 앱 제거 (ArgoCD 본체, ESO, Karpenter)
echo "=== 3. 핵심 컴포넌트(Helm) 제거 중 ==="
helm uninstall argo -n argocd 2>/dev/null || echo "  ArgoCD 이미 삭제됨"
helm uninstall external-secrets -n external-secrets 2>/dev/null || echo "  ESO 이미 삭제됨"
helm uninstall karpenter -n karpenter 2>/dev/null || echo "  Karpenter 이미 삭제됨"
echo ""

# 4. 잔여 네임스페이스 및 리소스 정리
echo "=== 4. 관련 네임스페이스 및 주요 리소스 삭제 중 ==="
NAMESPACES=("argocd" "external-secrets" "karpenter" "istio-system" "istio-ingress" "monitoring" "prod-webs")

for ns in "${NAMESPACES[@]}"; do
  echo "  $ns 네임스페이스 삭제 중..."
  kubectl delete namespace "$ns" --ignore-not-found --timeout=60s || true
  
  # 네임스페이스가 stuck 상태일 경우 대비 (finalizer 강제 삭제)
  if kubectl get namespace "$ns" &>/dev/null; then
    echo "  $ns 네임스페이스 강제 종료 중..."
    kubectl get namespace "$ns" -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - &>/dev/null || true
  fi
done
echo ""

# 5. CRD (Custom Resource Definitions) 강제 제거
echo "=== 5. 관련 CRD 정리 중 ==="
echo "  (CRD 삭제 시 연관된 클러스터 리소스도 일괄 소멸됩니다)"
CRDS_TO_DELETE=$(kubectl get crd | grep -E "argoproj.io|external-secrets.io|karpenter.sh|istio.io|monitoring.coreos.com" | awk '{print $1}' || echo "")

for crd in $CRDS_TO_DELETE; do
  kubectl delete crd "$crd" --ignore-not-found --timeout=10s 2>/dev/null || true
done
echo "  CRD 삭제 완료"
echo ""

# 6. ClusterRole & ClusterRoleBindings 정리
echo "=== 6. 클러스터 권한(RBAC) 찌꺼기 정리 중 ==="
kubectl delete clusterrole -l "app.kubernetes.io/part-of=argocd" --ignore-not-found 2>/dev/null || true
kubectl delete clusterrolebinding -l "app.kubernetes.io/part-of=argocd" --ignore-not-found 2>/dev/null || true
# 그 외 기타 네이밍 기반 삭제
kubectl delete clusterrole argocd-server argocd-application-controller argocd-repo-server external-secrets-controller karpenter-admin 2>/dev/null || true
kubectl delete clusterrolebinding argocd-server argocd-application-controller argocd-repo-server external-secrets-controller karpenter-admin 2>/dev/null || true
echo "  권한 정리 완료"

echo ""
echo "=================================================="
echo "  ✅ 클러스터 초기화 완료!"
echo "  EKS 클러스터가 테라폼 최초 생성 시점과 매우 유사한 상태로 되돌아갔습니다."
echo "=================================================="
