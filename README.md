# 302-goormgb-k8s-bootstrap

k3s 클러스터와 ArgoCD 부트스트랩을 위한 최소한의 스크립트.

## 개요

이 레포는 **미니PC에 직접 clone**하여 초기 설정에만 사용합니다.
이후 모든 배포는 ArgoCD가 [302-goormgb-helm](https://github.com/goorm-gongbang/302-goormgb-helm) 레포를 watch하여 처리합니다.

```
[이 레포]                    [helm 레포]
k8s-bootstrap               302-goormgb-helm
    │                            │
    │ 수동 실행                    │ ArgoCD가 watch
    ▼                            ▼
┌─────────────────────────────────────────┐
│           k3s Cluster (MiniPC)          │
│  ┌─────────┐                            │
│  │ ArgoCD  │ ──── sync ───► Helm Apps   │
│  └─────────┘                            │
└─────────────────────────────────────────┘
```

## 사용법

### 1. 초기 설치 (순서대로)

```bash
# k3s 설치 (별도 - curl 명령)
curl -sfL https://get.k3s.io | sh -

# istio 설치
./scripts/istio/install.sh

# cert-manager 설치
./scripts/cert-manager/install.sh

# ESO 설치 및 AWS credentials 등록
./scripts/eso/install.sh
./scripts/eso/bootstrap-aws.sh

# ArgoCD 설치
./scripts/argocd/install.sh

# RBAC 사용자 생성 (선택)
./scripts/rbac/create-all-users.sh
```

### 2. ArgoCD App of Apps 등록

```bash
kubectl apply -f argocd-apps/root-application.yaml
```

이후 ArgoCD가 helm 레포를 sync하여 모든 앱을 배포합니다.

### 3. 정리 (초기화)

```bash
./scripts/k3s/clean-all.sh
```

## 디렉토리 구조

```
.
├── scripts/
│   ├── argocd/
│   │   └── install.sh           # ArgoCD Helm 설치
│   ├── cert-manager/
│   │   └── install.sh           # cert-manager Helm 설치
│   ├── eso/
│   │   ├── install.sh           # External Secrets Operator 설치
│   │   └── bootstrap-aws.sh     # AWS credentials 부트스트랩
│   ├── istio/
│   │   ├── install.sh           # Istio 설치
│   │   ├── uninstall.sh         # Istio 제거
│   │   └── fix-port-conflict.sh # 포트 충돌 해결
│   ├── k3s/
│   │   ├── clean-all.sh         # 전체 초기화
│   │   └── disable-traefik.sh   # Traefik 비활성화
│   ├── rbac/
│   │   ├── create-all-users.sh      # 팀원 kubeconfig 일괄 생성
│   │   └── create-user-kubeconfig.sh # 개별 kubeconfig 생성
│   └── ddns/
│       ├── test-api.sh          # Route53 API 테스트
│       └── update-now.sh        # DDNS 수동 업데이트
└── argocd-apps/
    └── root-application.yaml    # App of Apps 루트
```

## 관련 레포

- **302-goormgb-helm**: Helm 차트 및 ArgoCD 앱 정의
