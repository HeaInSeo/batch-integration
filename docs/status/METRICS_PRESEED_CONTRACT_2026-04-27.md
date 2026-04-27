# Metrics Preseed Contract

기준일: `2026-04-27`

## 목적

- `JUMI`, `artifact-handoff`가 startup 직후에도
  stable한 `/metrics` contract를 제공하도록 기준을 고정한다.

## 문제

이전 phase-1 이미지에서는 새 rollout 직후
`/metrics`가 `200 OK`를 주더라도 body가 비어 있을 수 있었다.

실제 원인:

- 두 서비스의 custom metrics registry가 lazy-populated 구조였다.
- 즉 metric이 한 번도 증가/설정되지 않으면 해당 key 자체가 렌더되지 않았다.

연쇄 영향:

1. live collector가 `wget ... | grep prefix_`를 사용
2. body가 비면 `grep`이 `exit 1`
3. smoke run 전 수집 단계가 실패처럼 보임

collector 쪽에서는 이미 `grep ... || true`로 완화했지만,
그것만으로는 producer contract가 충분히 안정적이라고 보기 어렵다.

## 복구

애플리케이션 쪽에서 known metric key를 startup 시점에 0으로 선등록했다.

### JUMI

startup 시점에 아래 key를 미리 노출한다.

- `jumi_jobs_created_total`
- `jumi_fast_fail_trigger_total`
- `jumi_artifacts_registered_total`
- `jumi_input_resolve_requests_total`
- `jumi_input_remote_fetch_total`
- `jumi_input_materializations_total`
- `jumi_sample_runs_finalized_total`
- `jumi_gc_evaluate_requests_total`
- `jumi_cleanup_backlog_objects`

### artifact-handoff

startup 시점에 아래 key를 미리 노출한다.

- `ah_artifacts_registered_total`
- `ah_resolve_requests_total`
- `ah_fallback_total`
- `ah_gc_backlog_bytes`

## 검증

새 이미지:

- `harbor.10.113.24.96.nip.io/batch-int/artifact-handoff:phase1-20260427-2137z`
- `harbor.10.113.24.96.nip.io/batch-int/jumi:phase1-20260427-2137z`

rollout 직후 실제 probe 결과:

- `JUMI /metrics`: zero-valued counters/gauge가 모두 노출됨
- `artifact-handoff /metrics`: zero-valued counters/gauge가 모두 노출됨

이 상태에서 live smoke 재실행 결과:

- runId: `vm-lab-live-smoke-20260427T123617Z`
- terminal status: `Succeeded`
- gate: `PASS`

## 현재 판단

이 변경으로 collector는 더 단단해졌고,
서비스 자체도 "metric key가 아직 증가하지 않았다"와
"metrics endpoint가 깨졌다"를 구분 가능한 contract로 바뀌었다.

즉 앞으로는:

- zero metrics = 정상적인 초기 상태 가능
- empty body = 비정상

으로 해석하는 것이 맞다.
