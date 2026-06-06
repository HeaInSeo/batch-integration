# Batch Integration App Extraction Sprint 7 2026-05-12

기준일:
- `2026-05-12`

목표:
- `batch-integration/tools/jumi-smoke` owner를 `JUMI`로 넘기고,
  live smoke가 새 owner 경로를 실제로 쓰는지 원격에서 다시 닫는다.

범위:
- `JUMI/tools/jumi-smoke` module wiring 수정
- `batch-integration/scripts/run-jumi-ah-dev-live-smoke-eval.sh`의 remote build owner 수정
- `100.123.80.48` 기준 live smoke 재검증

## 변경 사항

`JUMI` owner 자산:
- [tools/jumi-smoke/go.mod](/opt/go/src/github.com/HeaInSeo/JUMI/tools/jumi-smoke/go.mod:1)
- [tools/jumi-smoke/go.sum](/opt/go/src/github.com/HeaInSeo/JUMI/tools/jumi-smoke/go.sum:1)
- [tools/jumi-smoke/main.go](/opt/go/src/github.com/HeaInSeo/JUMI/tools/jumi-smoke/main.go:1)

`batch-integration` shim 변경:
- [scripts/run-jumi-ah-dev-live-smoke-eval.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/run-jumi-ah-dev-live-smoke-eval.sh:1)
  - remote `jumi-smoke` build 위치를 `batch-integration` repo가 아니라
    remote `JUMI` repo로 변경

## 로컬 검증

`Code Ready`:
- `go test -mod=mod .` in `JUMI/tools/jumi-smoke`: `PASS`
- `bash -n scripts/run-jumi-ah-dev-live-smoke-eval.sh` in `batch-integration`: `PASS`

## 원격 검증

원격 baseline:
- `JUMI`: dirty (`?? executor/`, `?? handoff/`)
- `batch-integration`: dirty (`M tools/jumi-smoke/go.mod`, `M tools/jumi-smoke/go.sum`, 기타 untracked)
- 이번 검증은 원격 dirty 상태를 덮지 않고 `/tmp` staging + remote owner repo build 방식으로 수행

실행:
- `env PUBLISH_SHIFT_LEFT_OBSERVABILITY=false bash scripts/run-jumi-ah-dev-live-smoke-eval.sh`

결과:
- `runId=jumi-ah-dev-live-smoke-20260512T084426Z`
- terminal status: `Succeeded`
- summary results: `16`
- gate result: `PASS`
- overall message: `Policy checks passed.`

## 결론

- `Code Ready`: 완료
- `Remote Validated`: 완료

이번 조각으로 `jumi-smoke` owner 이동은 원격까지 닫혔다.

Sprint 4에서 app-specific로 크게 남은 축은:
- `SF Observability` publish/site/proxy 자산
- `batch-integration`에 남아 있는 app-specific shim 정리

