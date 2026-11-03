#!/usr/bin/env bash
set -euo pipefail
: "${KUBECONFIG:?Export the kubeconfig path from setup step 6 first.}"

k() {
  kubectl --context kind-docker-k8s-interview -n interview "$@"
}

probe="interview-http-check-$$"
cleanup() {
  k delete pod "$probe" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT

printf '=== Tool versions and node readiness ===\n'
kind version
kubectl version --client
kubectl --context kind-docker-k8s-interview \
  wait --for=condition=Ready nodes --all --timeout=120s
kubectl --context kind-docker-k8s-interview get nodes -o wide

printf '\n=== Deployment, pods, Service, and EndpointSlices ===\n'
k rollout status deployment/web --timeout=120s
k get deployment web -o yaml
k get pods --show-labels
k get service web -o yaml
k get endpointslices -l kubernetes.io/service-name=web -o yaml

replicas="$(k get deployment web -o jsonpath='{.spec.replicas} {.status.readyReplicas}')"
[[ "$replicas" == "2 2" ]] \
  || { printf 'FAIL: expected two desired and two ready replicas.\n' >&2; exit 1; }

image="$(k get deployment web -o jsonpath='{.spec.template.spec.containers[?(@.name=="web")].image}')"
[[ "$image" == "localhost/docker-k8s-interview-app:1.0" ]] \
  || { printf 'FAIL: keep the application image built during setup.\n' >&2; exit 1; }

service_port="$(k get service web -o jsonpath='{.spec.ports[?(@.port==80)].port}')"
[[ "$service_port" == 80 ]] \
  || { printf 'FAIL: the Service must expose port 80.\n' >&2; exit 1; }

printf '\n=== HTTP through web.interview.svc.cluster.local:80 ===\n'
k run "$probe" --image localhost/docker-k8s-interview-app:1.0 \
  --image-pull-policy=Never --restart=Never \
  --command -- python -c '
import json
from urllib.request import urlopen
base = "http://web.interview.svc.cluster.local:80"
with urlopen(base + "/healthz", timeout=10) as response:
    body = response.read().strip()
    assert response.status == 200 and body == b"ok"
    print("/healthz: HTTP", response.status, body.decode())
with urlopen(base + "/", timeout=10) as response:
    data = json.load(response)
    assert response.status == 200 and data["message"] == "Hello from Kubernetes"
    assert data["hostname"]
    print("/: HTTP", response.status, json.dumps(data))
print("Service HTTP checks passed.")
'
if ! k wait --for=jsonpath='{.status.phase}'=Succeeded \
  "pod/$probe" --timeout=60s; then
  k logs "$probe" >&2 || true
  printf 'FAIL: in-cluster HTTP verification did not succeed.\n' >&2
  exit 1
fi
k logs "$probe"
printf '\nVERIFICATION PASSED\n'
