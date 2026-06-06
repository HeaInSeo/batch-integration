# Batch Integration Exit Sprint 9 2026-05-12

기준일:
- `2026-05-12`

목표:
- `batch-integration`의 활성 진입점 두 개를 실제 owner repo로 넘긴다.
- `apply-jumi-ah-dev`는 `infra-lab` owner로,
  `run-jumi-ah-dev-live-smoke-eval`는 `JUMI` owner로 정리한다.

## Owner 이동

`infra-lab` owner:
- [k8s/jumi-ah-dev/namespace.yaml](/opt/go/src/github.com/HeaInSeo/infra-lab/k8s/jumi-ah-dev/namespace.yaml:1)
- [k8s/jumi-ah-dev/kustomization.yaml](/opt/go/src/github.com/HeaInSeo/infra-lab/k8s/jumi-ah-dev/kustomization.yaml:1)
- [scripts/host/apply-jumi-ah-dev.sh](/opt/go/src/github.com/HeaInSeo/infra-lab/scripts/host/apply-jumi-ah-dev.sh:1)

`JUMI` owner:
- [scripts/run-jumi-ah-dev-live-smoke-eval.sh](/opt/go/src/github.com/HeaInSeo/JUMI/scripts/run-jumi-ah-dev-live-smoke-eval.sh:1)

`batch-integration` 잔여 진입점:
- [scripts/apply-jumi-ah-dev.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/apply-jumi-ah-dev.sh:1)
- [scripts/run-jumi-ah-dev-live-smoke-eval.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/run-jumi-ah-dev-live-smoke-eval.sh:1)

설명:
- 위 두 스크립트는 이제 owner가 아니라 delegate shim이다.
- `batch-integration/deploy/jumi-ah-dev`는 비워져 제거됐다.

## 구현 정리

`JUMI` owner live smoke script 조정:
- summary 생성은 [generate-kubeslint-jumi-ah-summary.sh](/opt/go/src/github.com/HeaInSeo/JUMI/scripts/generate-kubeslint-jumi-ah-summary.sh:1) 직접 호출
- gate 평가는 `slint-gate` CLI 직접 호출
- publish는 owner가 아니라 caller가 `PUBLISH_SHIFT_LEFT_OBSERVABILITY_SCRIPT`로 명시적으로 넘김
- 기본 artifact 출력 경로는 `JUMI/artifacts/devspace/...` 기준으로 바뀜

`infra-lab` owner apply script 조정:
- overlay root를 [k8s/jumi-ah-dev](/opt/go/src/github.com/HeaInSeo/infra-lab/k8s/jumi-ah-dev:1) 기준으로 사용
- 앱별 manifest는 `JUMI`와 `artifact-handoff` owner 자산을 계속 합성

## 로컬 검증

`Code Ready`:
- `bash -n` for
  - `JUMI/scripts/run-jumi-ah-dev-live-smoke-eval.sh`
  - `infra-lab/scripts/host/apply-jumi-ah-dev.sh`
  - `batch-integration/scripts/run-jumi-ah-dev-live-smoke-eval.sh`
  - `batch-integration/scripts/apply-jumi-ah-dev.sh`

## 원격 검증

원격 baseline:
- `infra-lab`: `?? profiles/remote-seoy/`
- `JUMI`: `?? executor/`, `?? handoff/`, `?? tools/`
- 이번 검증은 remote worktree를 덮지 않고 local owner 자산을 stage해서 수행

실행 1:
- `bash scripts/apply-jumi-ah-dev.sh`

결과:
- `namespace/jumi-ah-dev unchanged`
- `deployment.apps/jumi unchanged`
- `deployment.apps/artifact-handoff unchanged`
- `applied jumi-ah-dev overlay to infra-lab shared VM`

실행 2:
- `env PUBLISH_SHIFT_LEFT_OBSERVABILITY=false bash scripts/run-jumi-ah-dev-live-smoke-eval.sh`

결과:
- `runId=jumi-ah-dev-live-smoke-20260512T092704Z`
- terminal status: `Succeeded`
- summary results: `16`
- gate result: `PASS`
- overall message: `Policy checks passed.`

## 결론

- `Code Ready`: 완료
- `Remote Validated`: 완료

이번 조각으로 `batch-integration`의 현재 활성 운영 진입점 대부분은 delegate-only가 됐다.

다음 남은 축:
- `vm-lab` legacy 스크립트/manifest 정리
- `generate-kubeslint-vm-lab-summary.sh`, `run-kubeslint-vm-lab-gate.sh` 같은 thin wrapper의 최종 처리
- `batch-integration` 제거 직전 마지막 shim 목록 확정

