# JUMI Metrics / Gate Drift Sprint — 2026-05-13

## Scope

- `serviceAccountName` 전파 버그 이후 남아 있던 `JUMI` smoke gate `FAIL` 원인 분석
- `JUMI` live smoke metrics collection 경로 보정

## Finding

Run execution 자체는 성공했지만 live smoke fixture의 `startMetrics` / `endMetrics`에서
`JUMI` 카운터가 모두 `0`으로 기록되고 있었다.

원격 `/metrics` 원문 확인 결과 실제 export 값은 정상적으로 올라가고 있었다.

Example:

- `jumi_jobs_created_total{otel_scope_name="github.com/HeaInSeo/JUMI",...} 4`
- `jumi_artifacts_registered_total{...} 2`
- `jumi_input_resolve_requests_total{...} 2`

즉 런타임/metrics export 문제가 아니라 **live smoke parser bug**였다.

## Root Cause

`JUMI/scripts/run-jumi-ah-dev-live-smoke-eval.sh`의 `parse_metrics()`가
Prometheus metric key의 label set을 제거하지 않고
`jumi_jobs_created_total{otel_scope_name=...}` 전체를 key로 저장했다.

그 결과 summary builder가 찾는 순수 metric name:

- `jumi_jobs_created_total`
- `jumi_artifacts_registered_total`
- `jumi_input_resolve_requests_total`
- ...

와 매칭되지 않아 모두 `0` fallback으로 내려갔다.

## Fix

`parse_metrics()`에서 `{...}` label suffix를 제거하도록 수정:

- before: `jumi_jobs_created_total{...}`
- after: `jumi_jobs_created_total`

## Validation

### Code Ready

- `bash -n JUMI/scripts/run-jumi-ah-dev-live-smoke-eval.sh` PASS

### Remote Validated

- run:
  - `jumi-ah-dev-live-smoke-20260513T060605Z`
- terminal:
  - `Succeeded`
- summary:
  - `results=16`
- gate:
  - `PASS`
- overall:
  - `Policy checks passed.`

## Notes

- collection 중 `kubectl run --rm` attach warning 1건이 있었으나
  결과 파일 생성과 gate 판정에는 영향 없었다.
- 이번 스프린트로 `serviceAccountName` 후속으로 남아 있던
  `JUMI metrics / gate drift`도 닫혔다.
