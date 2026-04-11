# CA Prod EKS Bootstrap
# 사용법: make help

ENV := ca-prod
ROOT_DIR := $(shell cd ../.. && pwd)

.PHONY: help 00-setup-acm 01-install-all 02-db-init 03-ai-init sync-rbac

help:
	@echo "=== CA Prod EKS Bootstrap ==="
	@echo ""
	@echo "순서대로 실행:"
	@echo "  make 00-setup-acm      - ACM 인증서 발급 + DNS 검증 (첫 1회)"
	@echo "  make 01-install-all    - 전체 설치 (ESO → Karpenter → ArgoCD → Root App)"
	@echo "  make 02-db-init        - PostgreSQL 스키마/시드 데이터 초기화"
	@echo "  make 03-ai-init        - AI Defense DB 초기화"
	@echo ""
	@echo "유틸리티:"
	@echo "  make sync-rbac         - RBAC ConfigMap 수동 동기화"

00-setup-acm:
	@echo "=== CA Prod: ACM 인증서 발급 ==="
	./scripts/setup-acm.sh

01-install-all:
	@echo "=== CA Prod: Installing all components ==="
	./scripts/install-all.sh

02-db-init:
	@echo "=== CA Prod: DB 초기화 ==="
	$(ROOT_DIR)/db/db-init.sh $(ENV)

03-ai-init:
	@echo "=== CA Prod: AI Defense DB 초기화 ==="
	$(ROOT_DIR)/ai/ai-init.sh $(ENV)

sync-rbac:
	./scripts/sync-rbac.sh
