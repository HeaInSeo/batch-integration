#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REMOTE_SSH_TARGET="${REMOTE_SSH_TARGET:-seoy@100.123.80.48}"
REMOTE_TMP_DIR="${REMOTE_TMP_DIR:-/tmp/shift-left-observability-tailnet-proxy}"
REMOTE_INSTALL_DIR="${REMOTE_INSTALL_DIR:-/opt/shift-left-observability-tailnet-proxy}"
REMOTE_SERVICE_PATH="${REMOTE_SERVICE_PATH:-/etc/systemd/system/shift-left-observability-tailnet-proxy.service}"
TAILNET_PROXY_PORT="${TAILNET_PROXY_PORT:-8008}"
UPSTREAM_ADDR="${UPSTREAM_ADDR:-10.113.24.96}"
UPSTREAM_HOST_HEADER="${UPSTREAM_HOST_HEADER:-shift-left-observability.10.113.24.96.nip.io}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing command: $1" >&2
    exit 1
  }
}

need_cmd scp
need_cmd ssh

TEMPLATE_DIR="${ROOT_DIR}/deploy/vm-lab/shift-left-observability-tailnet-proxy"
[[ -f "${TEMPLATE_DIR}/nginx.conf" ]] || {
  echo "missing file: ${TEMPLATE_DIR}/nginx.conf" >&2
  exit 1
}
[[ -f "${TEMPLATE_DIR}/shift-left-observability-tailnet-proxy.service" ]] || {
  echo "missing file: ${TEMPLATE_DIR}/shift-left-observability-tailnet-proxy.service" >&2
  exit 1
}

bundle_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$bundle_dir"
}
trap cleanup EXIT

sed \
  -e "s|listen 8008 default_server;|listen ${TAILNET_PROXY_PORT} default_server;|" \
  -e "s|proxy_pass http://10.113.24.96;|proxy_pass http://${UPSTREAM_ADDR};|" \
  -e "s|proxy_set_header Host shift-left-observability.10.113.24.96.nip.io;|proxy_set_header Host ${UPSTREAM_HOST_HEADER};|" \
  "${TEMPLATE_DIR}/nginx.conf" > "${bundle_dir}/nginx.conf"

cp "${TEMPLATE_DIR}/shift-left-observability-tailnet-proxy.service" "${bundle_dir}/shift-left-observability-tailnet-proxy.service"

ssh "${REMOTE_SSH_TARGET}" "rm -rf '${REMOTE_TMP_DIR}'"
scp -r "${bundle_dir}" "${REMOTE_SSH_TARGET}:${REMOTE_TMP_DIR}"

ssh "${REMOTE_SSH_TARGET}" "set -euo pipefail
  NGINX_BIN=\$(command -v nginx || true)
  if [[ -z \"\${NGINX_BIN}\" ]]; then
    if command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y nginx
      NGINX_BIN=\$(command -v nginx || true)
    fi
  fi
  if [[ -z \"\${NGINX_BIN}\" ]]; then
    echo 'nginx binary not found on remote host after install attempt' >&2
    exit 1
  fi

  if systemctl list-unit-files | grep -q '^dev-space-tailnet-proxy.service'; then
    sudo systemctl disable --now dev-space-tailnet-proxy.service || true
  fi

  sudo install -d -m 0755 '${REMOTE_INSTALL_DIR}'
  sudo install -d -m 0755 /var/log/shift-left-observability-tailnet-proxy
  sudo install -m 0644 '${REMOTE_TMP_DIR}/nginx.conf' '${REMOTE_INSTALL_DIR}/nginx.conf'
  sed \
    -e \"s|__NGINX_BIN__|\${NGINX_BIN}|g\" \
    -e \"s|__INSTALL_DIR__|${REMOTE_INSTALL_DIR}|g\" \
    '${REMOTE_TMP_DIR}/shift-left-observability-tailnet-proxy.service' | sudo tee '${REMOTE_SERVICE_PATH}' >/dev/null
  if command -v getenforce >/dev/null 2>&1 && [[ \$(getenforce) != 'Disabled' ]]; then
    sudo setsebool -P httpd_can_network_connect 1
  fi
  sudo systemctl daemon-reload
  sudo systemctl enable --now shift-left-observability-tailnet-proxy.service
  sudo systemctl status --no-pager shift-left-observability-tailnet-proxy.service
  curl -sS -H 'Host: ${UPSTREAM_HOST_HEADER}' 'http://${UPSTREAM_ADDR}/' >/dev/null
  curl -sS 'http://127.0.0.1:${TAILNET_PROXY_PORT}/healthz'
"

echo "shift-left observability tailnet proxy is expected at http://100.123.80.48:${TAILNET_PROXY_PORT}/"
