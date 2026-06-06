# Batch Integration Exit Sprint 10 2026-05-12

기준일:
- `2026-05-12`

목표:
- `vm-lab` legacy 경로를 active path에서 내리고, 남아 있는 heavy wrapper를 thin delegate로 줄인다.
- 정적 smoke summary fixture owner를 `JUMI`로 옮겨 `JUMI` 기본 요약 경로가 owner 자산만 보도록 맞춘다.

## 변경 사항

`JUMI` owner 자산:
- [deploy/devspace/fixtures/kube-slint-jumi-ah-smoke-metrics.json](/opt/go/src/github.com/HeaInSeo/JUMI/deploy/devspace/fixtures/kube-slint-jumi-ah-smoke-metrics.json:1)

설명:
- 기존 `batch-integration/deploy/vm-lab/fixtures/kube-slint-jumi-ah-smoke-metrics.json`의 static smoke summary fixture를 `JUMI` owner 경로로 복사하고,
  metadata source와 smoke fixture path를 `JUMI` 기준으로 보정했다.

`batch-integration` 경량화:
- [scripts/generate-kubeslint-vm-lab-summary.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/generate-kubeslint-vm-lab-summary.sh:1)
  - 기본 fixture 경로를 `JUMI/deploy/devspace/...` 기준으로 변경
- [scripts/run-vm-lab-live-smoke-eval.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/run-vm-lab-live-smoke-eval.sh:1)
  - 기존 heavy logic 제거
  - deprecated 경고 후 active path인 `run-jumi-ah-dev-live-smoke-eval.sh`로 delegate

## 로컬 검증

`Code Ready`:
- `bash -n scripts/run-vm-lab-live-smoke-eval.sh`: `PASS`
- `bash -n scripts/generate-kubeslint-vm-lab-summary.sh`: `PASS`
- `go test .` in `JUMI/tools/kubeslint-smoke-summary`: `PASS`
- `env FIXTURE_PATH=.../JUMI/deploy/devspace/fixtures/kube-slint-jumi-ah-smoke-metrics.json OUTPUT_PATH=/tmp/... PROFILE=smoke bash JUMI/scripts/generate-kubeslint-jumi-ah-summary.sh`: `PASS`

## 원격 검증

실행:
- `env PUBLISH_SHIFT_LEFT_OBSERVABILITY=false bash scripts/run-vm-lab-live-smoke-eval.sh`

결과:
- deprecated 경고 출력 후 active path로 정상 위임
- `runId=jumi-ah-dev-live-smoke-20260512T114918Z`
- terminal status: `Succeeded`
- summary results: `16`
- gate result: `PASS`
- overall message: `Policy checks passed.`

## 결론

- `Code Ready`: 완료
- `Remote Validated`: 완료

이번 조각으로 `vm-lab` live wrapper는 더 이상 독립 로직을 갖지 않는다.

남은 일:
- `apply-vm-lab-manifests.sh`, `build-vm-lab-images*.sh`, `run-vm-lab-smoke-eval.sh`, `deploy/vm-lab/README.md` 같은 legacy 축의 최종 처리
- `batch-integration` 삭제 직전 남길 shim 목록 확정

