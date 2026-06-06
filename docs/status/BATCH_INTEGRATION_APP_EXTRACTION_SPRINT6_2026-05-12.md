# Batch Integration App Extraction Sprint 6 2026-05-12

기준일:
- `2026-05-12`

목적:
- `batch-integration`에 남아 있던 JUMI/AH 전용 summary 생성기와 policy 복사본을 제거한다.
- owner repo를 `JUMI`로 더 명확히 고정하고, `batch-integration`에는 delegate 경로만 남긴다.

## 이번 스프린트에서 owner 이동한 자산

### JUMI repo로 이동

추가:
- [JUMI/tools/kubeslint-smoke-summary/go.mod](/opt/go/src/github.com/HeaInSeo/JUMI/tools/kubeslint-smoke-summary/go.mod:1)
- [JUMI/tools/kubeslint-smoke-summary/main.go](/opt/go/src/github.com/HeaInSeo/JUMI/tools/kubeslint-smoke-summary/main.go:1)
- [JUMI/tools/kubeslint-smoke-summary/spec_profiles.go](/opt/go/src/github.com/HeaInSeo/JUMI/tools/kubeslint-smoke-summary/spec_profiles.go:1)
- [JUMI/scripts/generate-kubeslint-jumi-ah-summary.sh](/opt/go/src/github.com/HeaInSeo/JUMI/scripts/generate-kubeslint-jumi-ah-summary.sh:1)
- [JUMI/policy/devspace/jumi-ah-smoke-thresholds.yaml](/opt/go/src/github.com/HeaInSeo/JUMI/policy/devspace/jumi-ah-smoke-thresholds.yaml:1)
- [JUMI/policy/devspace/jumi-ah-live-thresholds.yaml](/opt/go/src/github.com/HeaInSeo/JUMI/policy/devspace/jumi-ah-live-thresholds.yaml:1)

의미:
- JUMI/AH 전용 smoke summary builder와 threshold policy owner를 `JUMI`로 이동
- `batch-integration`은 더 이상 이 app-specific 자산의 canonical source가 아님

## batch-integration 쪽 변경

변경:
- [generate-kubeslint-vm-lab-summary.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/generate-kubeslint-vm-lab-summary.sh:1)
  - 이제 직접 tool을 실행하지 않고 `JUMI/scripts/generate-kubeslint-jumi-ah-summary.sh`로 delegate
- [run-kubeslint-vm-lab-gate.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/run-kubeslint-vm-lab-gate.sh:1)
  - 기본 policy 경로를 `JUMI/policy/devspace/jumi-ah-smoke-thresholds.yaml`로 변경
- [run-jumi-ah-dev-live-smoke-eval.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/run-jumi-ah-dev-live-smoke-eval.sh:1)
  - 기본 policy 경로를 `JUMI/policy/devspace/jumi-ah-live-thresholds.yaml`로 변경
  - local gate 단계에 사용할 `LOCAL_SLINT_GATE_BIN` 기본값 추가
- [run-vm-lab-live-smoke-eval.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/run-vm-lab-live-smoke-eval.sh:1)
  - 기본 policy 경로를 `JUMI/policy/devspace/jumi-ah-live-thresholds.yaml`로 변경
- [publish-shift-left-observability.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/publish-shift-left-observability.sh:1)
  - 기본 policy 경로를 `JUMI/policy/devspace/jumi-ah-live-thresholds.yaml`로 변경

삭제:
- `batch-integration/tools/kubeslint-smoke-summary/*`
- `batch-integration/policy/vm-lab/jumi-ah-smoke-thresholds.yaml`
- `batch-integration/policy/vm-lab/jumi-ah-live-thresholds.yaml`

## 검증

### Code Ready

완료:
- `go test .` in `JUMI/tools/kubeslint-smoke-summary` PASS
- `bash -n`
  - `JUMI/scripts/generate-kubeslint-jumi-ah-summary.sh`
  - `batch-integration/scripts/generate-kubeslint-vm-lab-summary.sh`
  - `batch-integration/scripts/run-jumi-ah-dev-live-smoke-eval.sh`
  - `batch-integration/scripts/run-vm-lab-live-smoke-eval.sh`
  - `batch-integration/scripts/publish-shift-left-observability.sh`

### Remote Validated

실행:
- `env PUBLISH_SHIFT_LEFT_OBSERVABILITY=false bash scripts/run-jumi-ah-dev-live-smoke-eval.sh`

결과:
- live run:
  - `runId=jumi-ah-dev-live-smoke-20260512T082844Z`
  - terminal `Succeeded`
- summary:
  - `generated summary: .../jumi-ah-smoke-live-sli-summary.json`
  - `results=16`
- gate:
  - `gate_result=PASS`
  - `overall_message=Policy checks passed.`

즉 owner가 `JUMI`로 이동한 summary/policy 경로 기준으로도
remote live smoke + local summary + local gate 후처리까지 전체 경로가 유지된다.

## 현재 판단

이번 조각으로 `batch-integration`에서 빠진 것:
- app-specific summary tool
- app-specific threshold policy

현재 `batch-integration/tools`에 남은 app-specific 자산은 사실상 아래뿐이다.
- `tools/jumi-smoke`

즉 Sprint 4의 남은 핵심은:
- `jumi-smoke` owner 재검토
- app-specific shim 추가 축소

## 상태

- `Code Ready`: 완료
- `Remote Validated`: 완료

## 다음 스프린트 초점

1. `batch-integration/tools/jumi-smoke` owner 재검토
2. `SF Observability` publish 자산 분리 시작
3. `artifact-handoff` active coding 고려를 계속 유지

