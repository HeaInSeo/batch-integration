# kube-slint Consumer Impact 2026-05-11

## Summary

`kube-slint` 대규모 업데이트 이후 실제 수정이 필요했던 소비자는 현재 기준으로 `batch-integration`이다.

`bori`는 계속 `slint-gate` CLI shell-out 모델을 쓰고 있어 즉시 수정이 필요하지 않았다.
`JUMI`, `artifact-handoff`는 `kube-slint`를 코드로 직접 import 하지 않고 `.bori/` policy를 통해 간접 사용하므로
현재 확인된 범위에서는 코드 수정이 필요하지 않았다.

## Findings

### 1. batch-integration

- `scripts/run-kubeslint-vm-lab-gate.sh` 가 삭제된 경로
  `kube-slint/hack/slint_gate.py`
  를 호출하고 있었다.
- `tools/kubeslint-smoke-summary` 가
  `github.com/HeaInSeo/kube-slint/pkg/slo/spec`
  의 `JUMIAHSmokeGuardrailSpecs`, `JUMIAHMinimumSpecs`
  에 직접 의존하고 있었는데,
  최신 `kube-slint`에서는 이 preset source 파일이 `//go:build ignore`
  처리되어 build 대상에서 제외되었다.

조치:

- `run-kubeslint-vm-lab-gate.sh` 를 현재 `slint-gate` CLI 호출로 교체
- `kubeslint-smoke-summary` 에 JUMI/AH preset 을 로컬 복제
  - 이유: `batch-integration` 은 전이용 staging 저장소이고,
    최신 `kube-slint` 는 해당 preset 을 consumer example 로 취급하기 시작했기 때문

검증:

- `go test .` in `batch-integration/tools/kubeslint-smoke-summary` PASS
- `bash -n batch-integration/scripts/run-kubeslint-vm-lab-gate.sh` PASS

### 2. bori

- `bori` 는 `kube-slint` Go library 를 import 하지 않고
  `slint-gate` 바이너리를 shell-out 한다.
- 현재 `slint-gate` CLI flag
  `--measurement-summary`, `--policy`, `--output`
  가 그대로 살아 있어서 즉시 수정은 필요하지 않았다.

검증:

- `go test ./pkg/adapter ./adapters/devspace` in `bori` PASS

### 3. JUMI / artifact-handoff

- 코드 차원의 `kube-slint` direct import 없음
- `.bori/policy.devspace.yaml` 로 간접 연동
- 현재 확인된 범위에서는 코드 수정 필요 없음

주의:

- 정책 schema 나 metric naming 이 바뀌는 수준의 의미적 변경이 추가되면
  `.bori/policy.devspace.yaml` 재검토는 필요할 수 있다.

## Current Status

- `batch-integration`: 업데이트 필요했고 반영 완료
- `bori`: 코드 업데이트 불필요
- `JUMI`: 코드 업데이트 불필요
- `artifact-handoff`: 코드 업데이트 불필요

