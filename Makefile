# 302-goormgb-k8s-bootstrap Makefile
# kubeadm 클러스터 초기 설정을 위한 명령어 모음

.PHONY: help install-all install-calico install-eso install-cert-manager install-istio install-argocd \
        deploy-root-app setup-github-ssh wait-sync run-ddns clean-ns clean-cluster fix-port-conflict \
        rbac-create-users ddns-test ddns-update

# 기본 타겟
help:
	@echo "=== kubeadm Bootstrap Commands ==="
	@echo ""
	@echo "초기 설치 (순서대로):"
	@echo "  make install-all       - 전체 설치 (Calico → ESO → cert-manager → Istio → ArgoCD → Root App)"
	@echo ""
	@echo "개별 설치:"
	@echo "  make install-calico    - Calico CNI 설치 (kubeadm 필수)"
	@echo "  make install-eso       - External Secrets Operator 설치"
	@echo "  make bootstrap-aws     - AWS credentials 등록 (수동 입력)"
	@echo "  make install-cert-manager - cert-manager 설치"
	@echo "  make install-istio     - Istio 설치"
	@echo "  make install-argocd    - ArgoCD 설치"
	@echo "  make setup-github-ssh  - GitHub SSH Key 설정 (ExternalSecret)"
	@echo "  make deploy-root-app   - ArgoCD Root Application 배포"
	@echo ""
	@echo "유틸리티:"
	@echo "  make fix-port-conflict - 80/443 포트 충돌 해결"
	@echo "  make rbac-create-users - 팀원 kubeconfig 생성"
	@echo "  make ddns-test         - Route53 API 테스트"
	@echo "  make ddns-update       - DDNS 수동 업데이트"
	@echo ""
	@echo "정리:"
	@echo "  make clean-ns          - namespace별 정리 (kubeadm 유지, 멀티노드용)"
	@echo "  make clean-cluster     - kubeadm 완전 초기화 (kubeadm reset)"

# === 전체 설치 ===
install-all: install-calico install-eso bootstrap-aws install-cert-manager install-istio install-argocd setup-github-ssh deploy-root-app wait-sync run-ddns
	@echo ""
	@echo "=== All components installed ==="
	@echo ""
	@echo "ArgoCD UI:"
	@echo "  URL: https://argocd.goormgb.space"
	@echo "  Login: Google OAuth (등록된 이메일만 접근 가능)"

wait-sync:
	@echo "=== Waiting for ArgoCD to sync apps (60s) ==="
	@sleep 10
	@kubectl wait --for=condition=Healthy application/root -n argocd --timeout=60s 2>/dev/null || true
	@kubectl wait --for=condition=Healthy application/ddns-route53 -n argocd --timeout=60s 2>/dev/null || echo "DDNS app not synced yet, continuing..."

run-ddns:
	@echo "=== Running DDNS Update ==="
	@./scripts/ddns/update-now.sh || echo "DDNS update skipped (CronJob may not be ready yet). Run 'make ddns-update' later."

# === 개별 설치 ===
install-calico:
	@echo "=== Installing Calico CNI ==="
	./scripts/calico/install.sh

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

setup-github-ssh:
	@echo "=== Setting up GitHub SSH Key (ExternalSecret) ==="
	kubectl apply -f argo-init/external-secret-github.yaml
	@echo "Waiting for ExternalSecret to sync..."
	@sleep 5
	@kubectl get externalsecret repo-goormgb-helm -n argocd || echo "ExternalSecret not ready yet. Check: kubectl get externalsecret -n argocd"

deploy-root-app:
	@echo "=== Deploying Root Application ==="
	kubectl apply -f argo-init/root-application.yaml
	@echo ""
	@echo "Root Application deployed. ArgoCD will sync all apps from helm repo."

# === 유틸리티 ===
fix-port-conflict:
	./scripts/istio/fix-port-conflict.sh

rbac-create-users:
	./scripts/rbac/create-all-users.sh

ddns-test:
	./scripts/ddns/test-api.sh

ddns-update:
	./scripts/ddns/update-now.sh

# === 정리 ===
clean-ns:
	./scripts/clean-ns.sh

clean-cluster:
	./scripts/clean-cluster.sh
