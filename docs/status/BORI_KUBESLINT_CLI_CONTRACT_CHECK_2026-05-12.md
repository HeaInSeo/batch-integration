# bori kube-slint CLI Contract Check 2026-05-12

## Goal

`bori`가 `kube-slint`를 Go import가 아니라 `slint-gate` CLI shell-out 방식으로 사용하더라도,
최신 `kube-slint` 업데이트 이후 CLI/입출력 계약이 유지되는지 확인한다.

## Checked Contract

`bori`가 실제로 기대하는 계약은 아래로 좁혀진다.

1. 바이너리 이름
   - `slint-gate`
2. CLI flags
   - `--measurement-summary`
   - `--policy`
   - `--output`
3. 입력 summary schema
   - `slint.summary.v4`
4. 출력 gate summary 최소 필드
   - `gate_result`
   - `overall_message`
5. 종료 코드 의미
   - non-zero여도 output file이 있으면 `bori`는 JSON을 읽고 결과를 해석할 수 있어야 함

## Static Findings

### bori side

- `bori/pkg/adapter/gate_runner.go`
  - `exec.CommandContext(... "slint-gate", "--measurement-summary", "--policy", "--output")`
  - output JSON 에서 `gate_result`, `overall_message`만 읽음
- `bori/pkg/adapter/summary.go`
  - `sli-summary.json` 을 `slint.summary.v4` 호환 구조로 생성

### kube-slint side

- `cmd/slint-gate/main.go`
  - `--measurement-summary`, `--policy`, `--output` 유지
  - 추가로 `--baseline`, `--fail-on`, `--github-step-summary` 존재
- `internal/gate/gate.go`
  - output JSON 에 `gate_result`, `overall_message` 유지
- `pkg/slo/summary/schema.go`
  - summary schema 는 여전히 `schemaVersion`, `config`, `results` 기반이며
    `bori`가 생성하는 `slint.summary.v4` 형태와 충돌 없음

## Local Validation

- `go test ./pkg/adapter ./adapters/devspace` in `bori` PASS

이 결과는 `bori` 자체 코드가 최신 `kube-slint` CLI 기대치와 충돌하지 않는다는 1차 신호다.

## Remote Validation

실제 기준 장비: `100.123.80.48`

### Remote baseline

- remote `kube-slint` checkout: `c4143a4`
- local updated `kube-slint` checkout: `da4aa87`

즉 원격 기본 바이너리는 최신 로컬 업데이트를 아직 반영하지 않은 상태였다.

### Validation method

원격 repo는 건드리지 않고,
로컬 최신 `kube-slint` 소스를 `/tmp/kube-slint-validate-20260512` 로 stage 후
원격에서 아래 바이너리를 빌드했다.

- `/tmp/slint-gate-validate-20260512`

그 다음 `bori-devspace`를 이 바이너리로 직접 실행했다.

```bash
/home/seoy/bin/bori-devspace \
  --apps-dir /opt/go/src/github.com/HeaInSeo \
  --profile devspace \
  --slint-gate /tmp/slint-gate-validate-20260512 \
  --v
```

### Remote result

- `jumi`: PASS
- `artifact-handoff`: PASS
- overall: PASS

즉 최신 로컬 `kube-slint` 코드로 빌드한 `slint-gate` 기준에서도
`bori -> slint-gate` CLI shell-out 경로는 깨지지 않았다.

## Conclusion

- `bori`는 최신 `kube-slint` 업데이트 이후에도 즉시 코드 수정이 필요하지 않다.
- `bori`가 의존하는 것은 내부 Go API가 아니라 CLI/JSON 계약인데,
  이번 점검 범위에서는 그 계약이 유지되었다.
- 현재 수정이 필요했던 소비자는 `batch-integration`뿐이었고,
  그 경로는 2026-05-11에 이미 정리했다.

## Residual Risk

- 향후 `slint-gate`가 아래를 변경하면 `bori`는 다시 영향받는다.
  - 필수 flag 이름
  - output JSON의 `gate_result`, `overall_message`
  - `sli-summary.json` 최소 schema
- 따라서 `bori`는 계속 “Go API dependency 없음” 상태이지만,
  “CLI contract dependency 없음” 상태는 아니다.

