# 302-goormgb-k8s-bootstrap

Kubernetes 클러스터에 ArgoCD 환경을 구성하는 부트스트랩 스크립트.

## 환경별 구성

| 환경 | 클러스터 | 디렉토리 | 사용법 |
|------|----------|----------|--------|
| dev | kubeadm (MiniPC) | [`dev/`](./dev/) | [dev/README.md](./dev/README.md) |
| staging | EKS (AWS) | [`staging/`](./staging/) | [staging/README.md](./staging/README.md) |
| prod | EKS (AWS) | (staging과 동일) | - |

## 레포 역할

```
┌────────────────────────────────────────────────────────────────────────────┐
│  301-goormgb-terraform        │  302 (이 레포)      │  303-goormgb-k8s-helm  │
│  ─────────────────────        │  ──────────────   │  ───────────────────── │
│  AWS 인프라 프로비저닝         │  클러스터 부트스트랩  │  GitOps 배포            │
│  (staging/prod)               │  (dev, staging)   │  (ArgoCD가 watch)      │
│  - VPC, RDS, ElastiCache      │  - 1회 실행         │  - 모든 환경             │
│  - EKS, Karpenter             │  - CNI, ESO, etc  │  - Helm 차트            │
└────────────────────────────────────────────────────────────────────────────┘
```

부트스트랩 실행 후, 모든 애플리케이션 변경은 303 레포에서 Git push로 진행합니다.

## 환경별 설치 항목

### dev (kubeadm)

| 순서 | 컴포넌트 |
|------|----------|
| 1 | Calico CNI |
| 2 | Local Path Provisioner |
| 3 | External Secrets Operator |
| 4 | cert-manager |
| 5 | Istio |
| 6 | Prometheus Operator CRDs |
| 7 | ArgoCD + Root Application |

### staging/prod (EKS)

| 순서 | 컴포넌트 |
|------|----------|
| 1 | External Secrets Operator |
| 2 | Karpenter |
| 3 | ArgoCD + Root Application |

> staging/prod는 VPC CNI, EBS CSI 등 AWS 네이티브 컴포넌트를 사용하므로 Calico, Local Path Provisioner, cert-manager가 불필요합니다.

## 디렉토리 구조

```
.
├── README.md               # 이 파일 (개요)
├── dev/                    # kubeadm 환경 (MiniPC)
│   ├── Makefile
│   ├── README.md           # dev 사용법
│   ├── scripts/
│   ├── argo-init/
│   └── manifests/
├── staging/                # EKS 환경 (AWS)
│   ├── Makefile
│   ├── README.md           # staging 사용법
│   ├── scripts/
│   ├── argo-init/
│   └── db/                 # DB 초기화 스크립트
└── db/                     # 공용 DB 스크립트 (optional)
```

## 관련 레포

| 레포 | 용도 |
|------|------|
| [301-goormgb-terraform](https://github.com/goorm-gongbang/301-goormgb-terraform) | EKS 클러스터 (staging/prod) - Terraform |
| **302-goormgb-k8s-bootstrap** | 클러스터 부트스트랩 (dev, staging) |
| [303-goormgb-k8s-helm](https://github.com/goorm-gongbang/303-goormgb-k8s-helm) | GitOps Helm 차트 (모든 환경) |
