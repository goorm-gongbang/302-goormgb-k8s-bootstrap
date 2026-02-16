#!/usr/bin/env bash
set -euo pipefail

# kubeadm 클러스터 내 모든 앱/인프라 정리 (클러스터 자체는 유지)
# Usage: ./scripts/clean-ns.sh

NAMESPACES="dev-app dev data argocd cert-manager external-secrets istio-system istio-ingress monitoring staging calico-system calico-apiserver tigera-operator local-path-storage"

echo "=== Clean Namespaces ==="
echo ""
echo "This will REMOVE:"
echo "  - All ArgoCD Applications"
echo "  - All Helm releases"
echo "  - All app namespaces"
echo "  - Istio, Calico"
echo ""
echo "kubeadm cluster itself will be preserved."
echo ""
read -rp "Are you sure? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "=== Step 1: Stop ArgoCD (prevent resource recreation) ==="
kubectl delete applicationsets.argoproj.io --all -n argocd --wait=false 2>/dev/null || true
kubectl delete applications.argoproj.io --all -n argocd --wait=false 2>/dev/null || true
# ArgoCD controller 중지
kubectl scale deployment -n argocd --all --replicas=0 2>/dev/null || true
echo "Waiting for ArgoCD to stop..."
sleep 3

echo ""
echo "=== Step 2: Uninstall Helm releases ==="
for ns in $NAMESPACES kube-system; do
  for release in $(helm list -n "$ns" -q 2>/dev/null); do
    echo "  Uninstalling $release from $ns..."
    helm uninstall "$release" -n "$ns" --no-hooks --wait=false 2>/dev/null || true
  done
  kubectl delete secret -n "$ns" -l owner=helm --wait=false 2>/dev/null || true
done

echo ""
echo "=== Step 3: Delete Istio CRDs and uninstall ==="
kubectl delete virtualservice --all -A --wait=false 2>/dev/null || true
kubectl delete gateway --all -A --wait=false 2>/dev/null || true
kubectl delete destinationrule --all -A --wait=false 2>/dev/null || true
kubectl delete serviceentry --all -A --wait=false 2>/dev/null || true
kubectl delete envoyfilter --all -A --wait=false 2>/dev/null || true
kubectl delete peerauthentication --all -A --wait=false 2>/dev/null || true
kubectl delete authorizationpolicy --all -A --wait=false 2>/dev/null || true

ISTIOCTL=""
if command -v istioctl &>/dev/null; then
  ISTIOCTL="istioctl"
elif [[ -x "./istio-1.24.2/bin/istioctl" ]]; then
  ISTIOCTL="./istio-1.24.2/bin/istioctl"
fi

if [[ -n "$ISTIOCTL" ]]; then
  echo "  Using $ISTIOCTL"
  $ISTIOCTL uninstall --purge -y 2>/dev/null || true
fi

echo ""
echo "=== Step 4: Clean Calico/Tigera CRs (remove finalizers) ==="
for inst in $(kubectl get installation -o name 2>/dev/null); do
  echo "  Removing finalizers from $inst..."
  kubectl patch "$inst" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  kubectl delete "$inst" --wait=false 2>/dev/null || true
done

for api in $(kubectl get apiserver.operator.tigera.io -o name 2>/dev/null); do
  echo "  Removing finalizers from $api..."
  kubectl patch "$api" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  kubectl delete "$api" --wait=false 2>/dev/null || true
done

for pool in $(kubectl get ippool.crd.projectcalico.org -o name 2>/dev/null); do
  echo "  Removing finalizers from $pool..."
  kubectl patch "$pool" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  kubectl delete "$pool" --wait=false 2>/dev/null || true
done

for res in felixconfiguration bgpconfiguration ippoollist bgppeer; do
  for item in $(kubectl get "$res" -o name 2>/dev/null); do
    kubectl patch "$item" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
    kubectl delete "$item" --wait=false 2>/dev/null || true
  done
done

echo ""
echo "=== Step 5: Remove ExternalSecret finalizers (all namespaces) ==="
for ns in $NAMESPACES; do
  for es in $(kubectl get externalsecret -n "$ns" -o name 2>/dev/null); do
    echo "  Removing finalizer from $es in $ns..."
    kubectl patch "$es" -n "$ns" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  done
  kubectl delete externalsecrets.external-secrets.io --all -n "$ns" --wait=false 2>/dev/null || true
done

echo ""
echo "=== Step 6: Force delete all resources in namespaces ==="
for ns in $NAMESPACES; do
  if kubectl get ns "$ns" &>/dev/null; then
    echo "  Cleaning $ns..."

    # 컨트롤러 삭제 (순서 중요)
    kubectl delete hpa --all -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
    kubectl delete statefulset --all -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
    kubectl delete daemonset --all -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
    kubectl delete deployment --all -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
    kubectl delete replicaset --all -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
    kubectl delete job --all -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
    kubectl delete cronjob --all -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true

    # Pod finalizer 제거 후 삭제
    for pod in $(kubectl get pods -n "$ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
      kubectl patch pod "$pod" -n "$ns" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
    done
    kubectl delete pods --all -n "$ns" --force --grace-period=0 2>/dev/null || true

    # 기타 리소스
    kubectl delete pvc --all -n "$ns" --force --grace-period=0 2>/dev/null || true
    kubectl delete svc --all -n "$ns" 2>/dev/null || true
    kubectl delete secrets --all -n "$ns" 2>/dev/null || true
    kubectl delete configmaps --all -n "$ns" 2>/dev/null || true
    kubectl delete serviceaccount --all -n "$ns" 2>/dev/null || true
    kubectl delete rolebinding --all -n "$ns" 2>/dev/null || true
    kubectl delete role --all -n "$ns" 2>/dev/null || true
  fi
done

echo ""
echo "=== Step 7: Delete namespaces ==="
for ns in $NAMESPACES; do
  if kubectl get ns "$ns" &>/dev/null; then
    echo "  Deleting namespace $ns..."
    kubectl delete ns "$ns" --wait=false 2>/dev/null || true
  fi
done

echo ""
echo "=== Step 8: Force kill stuck pods ==="
for ns in $NAMESPACES; do
  for pod in $(kubectl get pods -n "$ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    echo "  Force deleting stuck pod: $ns/$pod"
    kubectl patch pod "$pod" -n "$ns" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
    kubectl delete pod "$pod" -n "$ns" --force --grace-period=0 2>/dev/null || true
  done
done

echo ""
echo "=== Step 9: Force finalize stuck namespaces ==="
sleep 2
for ns in $NAMESPACES; do
  if kubectl get ns "$ns" &>/dev/null; then
    status=$(kubectl get ns "$ns" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    if [[ "$status" == "Terminating" ]]; then
      echo "  $ns stuck in Terminating, force finalizing..."
      # 남은 리소스의 finalizer 모두 제거
      for resource in $(kubectl api-resources --verbs=list --namespaced -o name 2>/dev/null); do
        for item in $(kubectl get "$resource" -n "$ns" -o name 2>/dev/null); do
          kubectl patch "$item" -n "$ns" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
        done
      done
      # namespace finalize
      kubectl get ns "$ns" -o json 2>/dev/null | \
        jq 'del(.spec.finalizers)' | \
        kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - 2>/dev/null || true
    fi
  fi
done

echo ""
echo "=== Step 10: Delete CRDs ==="
for crd in $(kubectl get crd -o name 2>/dev/null | grep -E "external-secrets|istio|cert-manager|tigera|calico|projectcalico|argoproj"); do
  echo "  Deleting $crd..."
  kubectl patch "$crd" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  kubectl delete "$crd" --wait=false 2>/dev/null || true
done

echo ""
echo "=== Step 11: Final cleanup - retry stuck namespaces ==="
sleep 2
for ns in $NAMESPACES; do
  if kubectl get ns "$ns" &>/dev/null; then
    echo "  Final attempt to delete $ns..."
    kubectl get ns "$ns" -o json 2>/dev/null | \
      jq 'del(.spec.finalizers)' | \
      kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - 2>/dev/null || true
  fi
done

echo ""
echo "=== Step 12: Final verification ==="
sleep 2
FAILED=0
for ns in $NAMESPACES; do
  if kubectl get ns "$ns" &>/dev/null; then
    echo "  $ns still exists"
    FAILED=1
  fi
done

if [[ $FAILED -eq 1 ]]; then
  echo ""
  echo "Some namespaces still exist. Check manually:"
  echo "  kubectl get ns"
else
  echo "  All namespaces cleaned"
fi

echo ""
echo "=== Clean complete ==="
echo ""
echo "Next: make install-all"
