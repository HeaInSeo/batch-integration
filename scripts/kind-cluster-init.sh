#!/usr/bin/env bash
set -euo pipefail

# Purpose:
#   Recreate the shared kind cluster for the fast kind+tilt validation loop.
#   This script is intentionally placed under batch-integration so it survives
#   even if consumer fixture repos such as hello-operator are removed later.
#
# Default result:
#   - cluster name: batch-int-dev
#   - kubectl context: kind-batch-int-dev
#
# Notes:
#   - rootful podman + sudo are still required in this environment
#   - this script looks for `kind` in PATH first, then known local fallbacks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_ROOT="$(cd "${HUB_ROOT}/.." && pwd)"

CLUSTER_NAME="${CLUSTER_NAME:-batch-int-dev}"
KUBECONFIG_PATH="${HOME}/.kube/config"
CONTAINERS_CONF_PATH="${CONTAINERS_CONF_PATH:-}"

find_kind_bin() {
  if [[ -x "${WORKSPACE_ROOT}/hello-operator/bin/kind" ]]; then
    echo "${WORKSPACE_ROOT}/hello-operator/bin/kind"
    return 0
  fi
  if command -v kind >/dev/null 2>&1; then
    command -v kind
    return 0
  fi
  if [[ -x "/home/heain/bin/kind" ]]; then
    echo "/home/heain/bin/kind"
    return 0
  fi
  return 1
}

KIND_BIN="$(find_kind_bin || true)"
if [[ -z "${KIND_BIN}" ]]; then
  echo "ERROR: kind binary not found. Put kind in PATH or keep a local fallback binary." >&2
  exit 1
fi

echo "Using kind binary: ${KIND_BIN}"
echo "Checking for existing cluster..."
SUDO_KIND_ENV=(
  KIND_EXPERIMENTAL_PROVIDER=podman
  DOCKER_HOST=unix:///run/podman/podman.sock
)

if [[ -n "${CONTAINERS_CONF_PATH}" ]]; then
  echo "Using containers.conf override: ${CONTAINERS_CONF_PATH}"
  SUDO_KIND_ENV+=(CONTAINERS_CONF="${CONTAINERS_CONF_PATH}")
fi

if sudo env "${SUDO_KIND_ENV[@]}" \
    "${KIND_BIN}" get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "Cluster '${CLUSTER_NAME}' already exists. Skipping creation."
else
  echo "Creating kind cluster '${CLUSTER_NAME}' via rootful podman..."
  sudo env "${SUDO_KIND_ENV[@]}" \
    "${KIND_BIN}" create cluster --name "${CLUSTER_NAME}"
  echo "Cluster created."
fi

echo "Exporting kubeconfig to /tmp/kind-${CLUSTER_NAME}.yaml..."
sudo env "${SUDO_KIND_ENV[@]}" \
  KUBECONFIG=/root/.kube/config \
  "${KIND_BIN}" export kubeconfig \
  --name "${CLUSTER_NAME}" \
  --kubeconfig "/tmp/kind-${CLUSTER_NAME}.yaml"
sudo chmod 644 "/tmp/kind-${CLUSTER_NAME}.yaml"

echo "Merging kubeconfig into ${KUBECONFIG_PATH}..."
mkdir -p "${HOME}/.kube"
if [[ -f "${KUBECONFIG_PATH}" ]]; then
  KUBECONFIG="${KUBECONFIG_PATH}:/tmp/kind-${CLUSTER_NAME}.yaml" \
    kubectl config view --flatten > /tmp/merged-kubeconfig.yaml
  cp /tmp/merged-kubeconfig.yaml "${KUBECONFIG_PATH}"
else
  cp "/tmp/kind-${CLUSTER_NAME}.yaml" "${KUBECONFIG_PATH}"
fi

echo "Switching kubectl context to kind-${CLUSTER_NAME}..."
kubectl config use-context "kind-${CLUSTER_NAME}"

echo "Verifying cluster access..."
kubectl cluster-info
kubectl get nodes

echo ""
echo "Setup complete. Cluster 'kind-${CLUSTER_NAME}' is ready."
echo "Next:"
echo "  1. export PATH=\"${WORKSPACE_ROOT}/hello-operator/bin:\$PATH\"   # if tilt/ko are still there"
echo "  2. cd ${WORKSPACE_ROOT}/hello-operator"
echo "  3. tilt up --host 0.0.0.0 --port 10350"
