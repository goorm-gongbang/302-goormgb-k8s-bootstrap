# 302-goormgb-k8s-bootstrap

Kubernetes 클러스터에 ArgoCD 환경을 구성하는 부트스트랩 스크립트.

## 환경별 구성

| 환경 | 클러스터 | 계정 | 디렉토리 |
|------|----------|------|----------|
| dev | kubeadm (MiniPC) | - | [`environments/dev/`](./environments/dev/) |
| staging | EKS (AWS) | 메인 (497) | [`environments/staging/`](./environments/staging/) |
| prod | EKS (AWS) | 메인 (497) | [`environments/prod/`](./environments/prod/) |
| ca-staging | EKS (AWS) | CA (406) | [`environments/ca-staging/`](./environments/ca-staging/) |
| ca-prod | EKS (AWS) | CA (406) | [`environments/ca-prod/`](./environments/ca-prod/) |

## 사용법

각 환경 디렉토리에서 make 실행:

```bash
cd environments/ca-staging   # 원하는 환경으로 이동
make help              # 사용 가능한 명령어 확인

make 00-setup-acm      # 0. ACM 인증서 발급 + DNS 검증 (CA 환경, 첫 1회)
make 01-install-all    # 1. 전체 설치 (ESO → Karpenter → ArgoCD → Root App)
make 02-db-init        # 2. PostgreSQL 초기화
make 03-ai-init        # 3. AI Defense DB 초기화
```

CA 환경(`ca-staging`, `ca-prod`)은 ACM 자동 발급, Bastion SSM 포트포워딩, Secrets Manager 자동 조회.
기존 환경(`staging`, `prod`, `dev`)은 환경변수 수동 설정.

## 레포 역할

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  301-playball-terraform       │  302 (이 레포)       │  303-goormgb-k8s-helm  │
│  ─────────────────────        │  ──────────────    │  ───────────────────── │
│  AWS 인프라 프로비저닝         │  클러스터 부트스트랩   │  GitOps 배포            │
│  (CA staging/prod)            │  (전 환경)           │  (ArgoCD가 watch)      │
│  - VPC, RDS, ElastiCache      │  - 1회 실행          │  - 모든 환경             │
│  - EKS, Karpenter             │  - ESO, ArgoCD 등   │  - Helm 차트            │
└──────────────────────────────────────────────────────────────────────────────┘
```

부트스트랩 실행 후, 모든 애플리케이션 변경은 303 레포에서 Git push로 진행합니다.

## 환경별 설치 항목

### dev (kubeadm)

| 순서 | 컴포넌트 |
|------|----------|
| 1 | Cilium CNI |
| 2 | Local Path Provisioner |
| 3 | External Secrets Operator |
| 4 | cert-manager |
| 5 | Istio |
| 6 | Prometheus Operator CRDs |
| 7 | ArgoCD + Root Application |

### ca-staging/ca-prod (EKS, CA 계정)

| make | 컴포넌트 |
|------|----------|
| 00-setup-acm | ACM 인증서 발급 + DNS 검증 (cross-account) |
| 01-install-all | ESO → ClusterSecretStore → Karpenter → ArgoCD → Root App → ExternalSecret refresh |
| 02-db-init | PostgreSQL 스키마/시드 (Bastion SSM + Secrets Manager 자동) |
| 03-ai-init | AI Defense DB/유저 생성 + 스키마 (Bastion SSM + Secrets Manager 자동) |

### staging/prod (EKS, 메인 계정)

| make | 컴포넌트 |
|------|----------|
| 01-install-all | ESO → ClusterSecretStore → Karpenter → ArgoCD → Root App |
| 02-db-init | PostgreSQL 스키마/시드 (환경변수 수동 설정) |
| 03-ai-init | AI Defense DB 초기화 (환경변수 수동 설정) |

> EKS 환경은 VPC CNI, EBS CSI 등 AWS 네이티브 컴포넌트를 사용하므로 Cilium, Local Path Provisioner, cert-manager가 불필요합니다.

## 디렉토리 구조

```
.
├── README.md
├── db/                          # 공용 DB 초기화 (전 환경 공유)
│   ├── db-init.sh               # ./db/db-init.sh <환경>
│   ├── 01-schema.sql
│   ├── 02-seed-data.sql
│   └── 03-matches.sql
├── ai/                          # 공용 AI Defense DB 초기화
│   ├── ai-init.sh               # ./ai/ai-init.sh <환경>
│   └── 01-postgresql-policy-control-plane.sql
└── environments/
    ├── dev/                     # kubeadm (MiniPC)
    ├── staging/                 # EKS 메인계정
    ├── prod/                    # EKS 메인계정
    ├── ca-staging/              # EKS CA계정
    └── ca-prod/                 # EKS CA계정
```

## 관련 레포

| 레포 | 용도 |
|------|------|
| [301-playball-terraform](https://github.com/goorm-gongbang/301-playball-terraform) | AWS 인프라 (CA계정) - Terraform |
| **302-goormgb-k8s-bootstrap** | 클러스터 부트스트랩 (전 환경) |
| [303-goormgb-k8s-helm](https://github.com/goorm-gongbang/303-goormgb-k8s-helm) | GitOps Helm 차트 (모든 환경) |
