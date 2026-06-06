# SF Observability Extraction Sprint 8 2026-05-12

기준일:
- `2026-05-12`

목표:
- `shift-left-observability` publish/site/proxy 자산 owner를 `batch-integration`에서 `infra-lab`로 넘긴다.
- 기존 `batch-integration` 진입점은 delegate shim으로만 남기고, 실제 자산 owner 경로를 원격까지 검증한다.

## Owner 이동

`infra-lab` 새 owner 자산:
- [k8s/shift-left-observability/deployment.yaml](/opt/go/src/github.com/HeaInSeo/infra-lab/k8s/shift-left-observability/deployment.yaml:1)
- [k8s/shift-left-observability/httproute.yaml](/opt/go/src/github.com/HeaInSeo/infra-lab/k8s/shift-left-observability/httproute.yaml:1)
- [k8s/shift-left-observability/kustomization.yaml](/opt/go/src/github.com/HeaInSeo/infra-lab/k8s/shift-left-observability/kustomization.yaml:1)
- [k8s/shift-left-observability/namespace.yaml](/opt/go/src/github.com/HeaInSeo/infra-lab/k8s/shift-left-observability/namespace.yaml:1)
- [k8s/shift-left-observability/service.yaml](/opt/go/src/github.com/HeaInSeo/infra-lab/k8s/shift-left-observability/service.yaml:1)
- [k8s/shift-left-observability/site/index.html](/opt/go/src/github.com/HeaInSeo/infra-lab/k8s/shift-left-observability/site/index.html:1)
- [scripts/host/publish-shift-left-observability.sh](/opt/go/src/github.com/HeaInSeo/infra-lab/scripts/host/publish-shift-left-observability.sh:1)
- [scripts/host/install-shift-left-observability-tailnet-proxy.sh](/opt/go/src/github.com/HeaInSeo/infra-lab/scripts/host/install-shift-left-observability-tailnet-proxy.sh:1)
- [scripts/host/shift-left-observability-tailnet-proxy/nginx.conf](/opt/go/src/github.com/HeaInSeo/infra-lab/scripts/host/shift-left-observability-tailnet-proxy/nginx.conf:1)
- [scripts/host/shift-left-observability-tailnet-proxy/shift-left-observability-tailnet-proxy.service](/opt/go/src/github.com/HeaInSeo/infra-lab/scripts/host/shift-left-observability-tailnet-proxy/shift-left-observability-tailnet-proxy.service:1)

`batch-integration` 잔여 진입점:
- [scripts/publish-shift-left-observability.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/publish-shift-left-observability.sh:1)
- [scripts/install-shift-left-observability-tailnet-proxy.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/install-shift-left-observability-tailnet-proxy.sh:1)

설명:
- 위 두 스크립트는 이제 owner가 아니라 delegate shim이다.
- 실제 배포/설치 자산과 로직은 `infra-lab` 쪽이 owner다.
- `infra-lab` owner publish script는 summary/gate 입력 파일을 기본 경로로 숨기지 않고,
  caller가 `SLI_SUMMARY_PATH`, `GATE_SUMMARY_PATH`로 넘기도록 바꿨다.
- 현재 `batch-integration` shim은 기존 artifact 경로를 명시적으로 전달한다.

## 로컬 검증

`Code Ready`:
- `bash -n` for
  - `infra-lab/scripts/host/publish-shift-left-observability.sh`
  - `infra-lab/scripts/host/install-shift-left-observability-tailnet-proxy.sh`
  - `batch-integration/scripts/publish-shift-left-observability.sh`
  - `batch-integration/scripts/install-shift-left-observability-tailnet-proxy.sh`
- delegate shim과 owner script 모두 syntax `PASS`

## 원격 검증

원격 baseline:
- `infra-lab` remote worktree: `?? profiles/remote-seoy/`
- 이번 검증은 원격 repo를 수정하지 않고, 로컬 owner 자산을 `scp/apply`하는 방식으로 수행

실행:
1. `bash scripts/publish-shift-left-observability.sh`
2. `bash scripts/install-shift-left-observability-tailnet-proxy.sh`

결과:
- `namespace/shift-left-observability` unchanged
- `configmap/shift-left-observability-site` configured
- `deployment/shift-left-observability` rollout `success`
- `shift-left-observability-tailnet-proxy.service` active
- `http://100.123.80.48:8008/healthz` returned `ok` during install validation

## 결론

- `Code Ready`: 완료
- `Remote Validated`: 완료

이번 조각으로 `SF Observability` publish/site/proxy 자산의 실제 owner는 `infra-lab`로 넘어갔다.

남은 일:
- `batch-integration`의 delegate shim 추가 축소
- 삭제 직전까지 필요한 최소 wrapper만 남기고 Sprint 6으로 넘어가기
