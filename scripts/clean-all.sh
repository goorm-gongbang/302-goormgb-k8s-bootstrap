#!/usr/bin/env bash
set -euo pipefail

# 클러스터 완전 초기화 (kubeadm 유지)
# ArgoCD, cert-manager 포함 모든 것 삭제 후 install-all 가능한 상태로
# Usage: ./scripts/clean-all.sh

# 삭제할 네임스페이스 (kube-system, kube-public, kube-node-lease, default 제외)
NAMESPACES="argocd cert-manager dev-webs dev-ai dev-app data infra monitoring istio-system istio-ingress external-secrets calico-system calico-apiserver tigera-operator local-path-storage staging prod"

echo "=== Clean All (Keep kubeadm) ==="
echo ""
echo "This will COMPLETELY REMOVE everything except kubeadm base:"
echo "  - ArgoCD (including all apps)"
echo "  - cert-manager"
echo "  - Istio, Calico, ESO"
echo "  - All app namespaces"
echo "  - All CRDs"
echo "  - All Helm releases"
echo ""
echo "kubeadm cluster will be preserved."
echo ""
read -rp "Are you sure? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "=== Step 1: Delete ALL ArgoCD apps and ApplicationSets ==="
# Finalizer 제거 후 강제 삭제
for app in $(kubectl get applications.argoproj.io -n argocd -o name 2>/dev/null || true); do
  kubectl patch "$app" -n argocd -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  kubectl delete "$app" -n argocd --force --grace-period=0 --wait=false 2>/dev/null || true
done
for appset in $(kubectl get applicationsets.argoproj.io -n argocd -o name 2>/dev/null || true); do
  kubectl patch "$appset" -n argocd -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  kubectl delete "$appset" -n argocd --force --grace-period=0 --wait=false 2>/dev/null || true
done
echo "  Apps deleted"

echo ""
echo "=== Step 2: Uninstall ALL Helm releases ==="
for release in $(helm list -A -q 2>/dev/null || true); do
  ns=$(helm list -A --filter "^${release}$" -o json 2>/dev/null | jq -r ".[0].namespace // empty")
  if [[ -n "$ns" ]]; then
    echo "  Uninstalling $release from $ns"
    helm uninstall "$release" -n "$ns" --no-hooks --wait=false 2>/dev/null || true
  fi
done

echo ""
echo "=== Step 3: Delete stuck resources in namespaces ==="
# Helm uninstall 후에도 남는 리소스 강제 삭제
for ns in monitoring data; do
  if kubectl get ns "$ns" &>/dev/null; then
    echo "  Cleaning $ns..."
    kubectl delete deploy,sts,rs,job --all -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
    kubectl delete pods --all -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
  fi
done

echo ""
echo "=== Step 4: Stop all controllers ==="
kubectl scale deployment -n argocd --all --replicas=0 2>/dev/null || true
kubectl scale deployment -n cert-manager --all --replicas=0 2>/dev/null || true
kubectl scale deployment -n external-secrets --all --replicas=0 2>/dev/null || true
kubectl scale deployment -n tigera-operator --all --replicas=0 2>/dev/null || true
kubectl scale deployment -n istio-system --all --replicas=0 2>/dev/null || true
sleep 3

echo ""
echo "=== Step 5: Istio uninstall ==="
ISTIOCTL=""
if command -v istioctl &>/dev/null; then
  ISTIOCTL="istioctl"
elif [[ -x "./istio-1.24.2/bin/istioctl" ]]; then
  ISTIOCTL="./istio-1.24.2/bin/istioctl"
fi
if [[ -n "$ISTIOCTL" ]]; then
  $ISTIOCTL uninstall --purge -y 2>/dev/null || true
fi

echo ""
echo "=== Step 6: Delete Calico resources ==="
# IPPool, Installation, APIServer CR 삭제
for pool in $(kubectl get ippool -o name 2>/dev/null || true); do
  kubectl patch "$pool" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
  kubectl delete "$pool" --force --grace-period=0 --wait=false 2>/dev/null || true
done
kubectl patch installation default -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
kubectl delete installation default --force --grace-period=0 --wait=false 2>/dev/null || true
kubectl patch apiserver default -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
kubectl delete apiserver default --force --grace-period=0 --wait=false 2>/dev/null || true

# 대기
for i in {1..10}; do
  if ! kubectl get installation default &>/dev/null && ! kubectl get apiserver default &>/dev/null; then
    echo "  Calico CRs deleted"
    break
  fi
  kubectl patch installation default -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
  kubectl patch apiserver default -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
  sleep 2
done

echo ""
echo "=== Step 7: Delete PVCs with finalizers ==="
for ns in $NAMESPACES; do
  for pvc in $(kubectl get pvc -n "$ns" -o name 2>/dev/null || true); do
    echo "  Removing finalizers from $pvc in $ns..."
    kubectl patch "$pvc" -n "$ns" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
    kubectl delete "$pvc" -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
  done
done

# PVC 완전 삭제 대기
echo "  Waiting for PVCs to be fully deleted..."
for i in {1..30}; do
  remaining=$(kubectl get pvc -A --no-headers 2>/dev/null | grep -E "data|monitoring" | wc -l)
  if [[ "$remaining" -eq 0 ]]; then
    echo "  All data/monitoring PVCs deleted"
    break
  fi
  echo "  Waiting for $remaining PVCs to delete... ($i/30)"
  # 남아있는 PVC들 finalizer 재시도
  for ns in data monitoring; do
    for pvc in $(kubectl get pvc -n "$ns" -o name 2>/dev/null || true); do
      kubectl patch "$pvc" -n "$ns" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
    done
  done
  sleep 2
done

# PVC 삭제 확인
echo ""
echo "=== PVC Status Check ==="
remaining_pvcs=$(kubectl get pvc -A --no-headers 2>/dev/null | grep -vE "^kube-system" || true)
if [[ -z "$remaining_pvcs" ]]; then
  echo "  All PVCs deleted successfully"
else
  echo "  Warning: Some PVCs still remain:"
  echo "$remaining_pvcs"
fi

echo ""
echo "=== Step 8: Delete all namespaces ==="
for ns in $NAMESPACES; do
  if kubectl get ns "$ns" &>/dev/null; then
    echo "  Deleting $ns..."
    # 내부 리소스 먼저 삭제 (PVC finalizer 제거 포함)
    for pvc in $(kubectl get pvc -n "$ns" -o name 2>/dev/null || true); do
      kubectl patch "$pvc" -n "$ns" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
    done
    kubectl delete deploy,ds,sts,rs,job,svc,cm,secret,pvc --all -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
    kubectl delete pods --all -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
    # namespace 삭제
    kubectl delete ns "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
    # Finalizer 제거
    kubectl get ns "$ns" -o json 2>/dev/null | \
      jq '.spec.finalizers = null' | \
      kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - 2>/dev/null || true
  fi
done

echo ""
echo "=== Step 9: Delete ALL CRDs ==="
# ArgoCD CRDs
for crd in $(kubectl get crd -o name 2>/dev/null | grep -E "argoproj" || true); do
  kubectl patch "$crd" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  kubectl delete "$crd" --wait=false 2>/dev/null || true
done
# cert-manager CRDs
for crd in $(kubectl get crd -o name 2>/dev/null | grep -E "cert-manager" || true); do
  kubectl patch "$crd" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  kubectl delete "$crd" --wait=false 2>/dev/null || true
done
# Istio CRDs
for crd in $(kubectl get crd -o name 2>/dev/null | grep -E "istio" || true); do
  kubectl patch "$crd" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  kubectl delete "$crd" --wait=false 2>/dev/null || true
done
# Calico CRDs
for crd in $(kubectl get crd -o name 2>/dev/null | grep -E "tigera|calico|projectcalico" || true); do
  kubectl patch "$crd" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  kubectl delete "$crd" --wait=false 2>/dev/null || true
done
# ESO CRDs
for crd in $(kubectl get crd -o name 2>/dev/null | grep -E "external-secrets" || true); do
  kubectl patch "$crd" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  kubectl delete "$crd" --wait=false 2>/dev/null || true
done
# Prometheus Operator CRDs (monitoring.coreos.com)
for crd in $(kubectl get crd -o name 2>/dev/null | grep -E "monitoring.coreos.com" || true); do
  kubectl patch "$crd" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  kubectl delete "$crd" --wait=false 2>/dev/null || true
done

echo "  Waiting for CRDs..."
sleep 5

echo ""
echo "=== Step 10: Delete cluster-scoped resources ==="
# ClusterRole, ClusterRoleBinding 삭제 (system 제외)
kubectl delete clusterrole -l app.kubernetes.io/managed-by=Helm 2>/dev/null || true
kubectl delete clusterrolebinding -l app.kubernetes.io/managed-by=Helm 2>/dev/null || true
# ArgoCD 관련
kubectl delete clusterrole -l app.kubernetes.io/part-of=argocd 2>/dev/null || true
kubectl delete clusterrolebinding -l app.kubernetes.io/part-of=argocd 2>/dev/null || true
# cert-manager 관련
kubectl delete clusterrole -l app.kubernetes.io/instance=cert-manager 2>/dev/null || true
kubectl delete clusterrolebinding -l app.kubernetes.io/instance=cert-manager 2>/dev/null || true
# Istio 관련
kubectl delete clusterrole -l app=istiod 2>/dev/null || true
kubectl delete clusterrolebinding -l app=istiod 2>/dev/null || true
# Webhook configs
kubectl delete validatingwebhookconfigurations -l app.kubernetes.io/managed-by=Helm 2>/dev/null || true
kubectl delete mutatingwebhookconfigurations -l app.kubernetes.io/managed-by=Helm 2>/dev/null || true
kubectl delete validatingwebhookconfigurations istiod-default-validator 2>/dev/null || true

echo ""
echo "=== Step 11: Final namespace cleanup ==="
sleep 3
for ns in $NAMESPACES; do
  if kubectl get ns "$ns" &>/dev/null; then
    echo "  Force finalizing $ns..."
    kubectl get ns "$ns" -o json 2>/dev/null | \
      jq '.spec.finalizers = null' | \
      kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - 2>/dev/null || true
  fi
done

echo ""
echo "=== Step 12: Verify ==="
sleep 2
echo "Remaining namespaces:"
kubectl get ns
echo ""
echo "Remaining CRDs (non-system):"
kubectl get crd 2>/dev/null | grep -vE "^NAME|node.k8s.io" || echo "  None"

echo ""
echo "=== Clean All Complete ==="
echo ""
echo "Cluster is now in clean kubeadm state."
echo "Next: make install-all"
