# 302-goormgb-k8s-bootstrap Makefile
# k3s 클러스터 초기 설정을 위한 명령어 모음

.PHONY: help install-all install-eso install-cert-manager install-istio install-argocd \
        deploy-root-app clean-all disable-traefik fix-port-conflict \
        rbac-create-users ddns-test ddns-update

# 기본 타겟
help:
	@echo "=== k3s Bootstrap Commands ==="
	@echo ""
	@echo "초기 설치 (순서대로):"
	@echo "  make install-all       - 전체 설치 (ESO → cert-manager → Istio → ArgoCD → Root App)"
	@echo ""
	@echo "개별 설치:"
	@echo "  make install-eso       - External Secrets Operator 설치"
	@echo "  make bootstrap-aws     - AWS credentials 등록 (수동 입력)"
	@echo "  make install-cert-manager - cert-manager 설치"
	@echo "  make install-istio     - Istio 설치"
	@echo "  make install-argocd    - ArgoCD 설치"
	@echo "  make deploy-root-app   - ArgoCD Root Application 배포"
	@echo ""
	@echo "유틸리티:"
	@echo "  make disable-traefik   - k3s Traefik 비활성화 (Istio 전용 사용 시)"
	@echo "  make fix-port-conflict - 80/443 포트 충돌 해결"
	@echo "  make rbac-create-users - 팀원 kubeconfig 생성"
	@echo "  make ddns-test         - Route53 API 테스트"
	@echo "  make ddns-update       - DDNS 수동 업데이트"
	@echo ""
	@echo "정리:"
	@echo "  make clean-all         - 전체 초기화 (k3s 유지, 내부만 삭제)"

# === 전체 설치 ===
install-all: install-eso bootstrap-aws install-cert-manager install-istio install-argocd deploy-root-app
	@echo ""
	@echo "=== All components installed ==="
	@echo ""
	@echo "ArgoCD UI:"
	@echo "  URL: https://argocd.goormgb.space Istio Gateway 설정 후)"
	@echo "  Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"

# === 개별 설치 ===
install-eso:
	@echo "=== Installing ESO ==="
	./scripts/eso/install.sh

bootstrap-aws:
	@echo "=== Bootstrapping AWS credentials ==="
	./scripts/eso/bootstrap-aws.sh

install-cert-manager:
	@echo "=== Installing cert-manager ==="
	./scripts/cert-manager/install.sh

install-istio:
	@echo "=== Installing Istio ==="
	./scripts/istio/install.sh

install-argocd:
	@echo "=== Installing ArgoCD ==="
	./scripts/argocd/install.sh

deploy-root-app:
	@echo "=== Deploying Root Application ==="
	kubectl apply -f argocd-apps/root-application.yaml
	@echo ""
	@echo "Root Application deployed. ArgoCD will sync all apps from helm repo."

# === 유틸리티 ===
disable-traefik:
	./scripts/k3s/disable-traefik.sh

fix-port-conflict:
	./scripts/istio/fix-port-conflict.sh

rbac-create-users:
	./scripts/rbac/create-all-users.sh

ddns-test:
	./scripts/ddns/test-api.sh

ddns-update:
	./scripts/ddns/update-now.sh

# === 정리 ===
clean-all:
	./scripts/k3s/clean-all.sh
