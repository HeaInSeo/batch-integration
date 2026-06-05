#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OWNER_ROOT="$(cd "${ROOT_DIR}/.." && pwd)"
REMOTE_SSH_TARGET="${REMOTE_SSH_TARGET:-seoy@100.123.80.48}"
REMOTE_KUBECONFIG="${REMOTE_KUBECONFIG:-/opt/go/src/github.com/HeaInSeo/infra-lab/kubeconfig}"
REMOTE_TMP_DIR="${REMOTE_TMP_DIR:-/tmp/jumi-ah-dev-deploy}"
OVERLAY_DIR="${OVERLAY_DIR:-${ROOT_DIR}/deploy/vm-lab/jumi-ah-dev}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing command: $1" >&2
    exit 1
  }
}

need_cmd scp
need_cmd ssh

ssh -F /dev/null -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${REMOTE_SSH_TARGET}" \
  "rm -rf '${REMOTE_TMP_DIR}' && mkdir -p '${REMOTE_TMP_DIR}/deploy/jumi-ah-dev'"

scp -F /dev/null -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "${OVERLAY_DIR}/namespace.yaml" \
  "${OVERLAY_DIR}/kustomization.yaml" \
  "${OWNER_ROOT}/JUMI/deploy/devspace/jumi-ah-dev/jumi.yaml" \
  "${OWNER_ROOT}/JUMI/deploy/devspace/patch-jumi-deployment.yaml" \
  "${OWNER_ROOT}/artifact-handoff/deploy/devspace/jumi-ah-dev/artifact-handoff.yaml" \
  "${OWNER_ROOT}/artifact-handoff/deploy/devspace/patch-artifact-handoff-deployment.yaml" \
  "${REMOTE_SSH_TARGET}:${REMOTE_TMP_DIR}/deploy/jumi-ah-dev/"

ssh -F /dev/null -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${REMOTE_SSH_TARGET}" "
  export KUBECONFIG='${REMOTE_KUBECONFIG}'
  kubectl get ns jumi-ah-dev >/dev/null 2>&1 || true
  kubectl apply -f '${REMOTE_TMP_DIR}/deploy/jumi-ah-dev/namespace.yaml'
  if ! kubectl -n jumi-ah-dev get secret harbor-regcred >/dev/null 2>&1; then
    kubectl -n batch-int-dev get secret harbor-regcred -o yaml > '${REMOTE_TMP_DIR}/harbor-regcred.yaml'
    sed -i 's/namespace: batch-int-dev/namespace: jumi-ah-dev/' '${REMOTE_TMP_DIR}/harbor-regcred.yaml'
    sed -i '/resourceVersion:/d;/uid:/d;/creationTimestamp:/d;/selfLink:/d;/managedFields:/d' '${REMOTE_TMP_DIR}/harbor-regcred.yaml'
    kubectl apply -f '${REMOTE_TMP_DIR}/harbor-regcred.yaml'
  fi
  kubectl apply -k '${REMOTE_TMP_DIR}/deploy/jumi-ah-dev'
  kubectl -n jumi-ah-dev get deploy,svc,sa
"

echo 'applied jumi-ah-dev overlay to vm-lab cluster'
