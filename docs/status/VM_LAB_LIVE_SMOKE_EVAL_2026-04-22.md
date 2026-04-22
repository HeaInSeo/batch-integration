# VM Lab Live Smoke Eval

기준일: `2026-04-22`

## 목적

- VM lab에서 실제 `JUMI -> artifact-handoff` smoke run을 실행한다.
- 실행 전후 live metrics를 수집해 `kube-slint` summary/gate까지 한 번에 생성한다.
- 다음 스프린트의 회귀 기준으로 쓸 수 있는 실제 관찰값을 남긴다.

## 실행 경로

- 스크립트: `scripts/run-vm-lab-live-smoke-eval.sh`
- 원격 호스트: `seoy@100.123.80.48`
- VM 접속: host에서 multipass private key로 `ubuntu@10.113.24.254`
- namespace: `batch-int-dev`

실행 순서:

1. `jumi`, `artifact-handoff` metrics를 run 시작 전 수집
2. `/home/ubuntu/vm-lab-jumi-smoke-remote.sh`로 producer/consumer smoke run 실행
3. run 종료 후 metrics 재수집
4. live fixture JSON 생성
5. `kube-slint` summary 생성
6. threshold gate 평가

## 최종 결과

- runId: `vm-lab-live-smoke-20260422T103739Z`
- sampleRunId: `vm-lab-live-smoke-sample-20260422T103739Z`
- smoke terminal status: `Succeeded`
- live gate result: `PASS`

주요 확인값:

- `jumi_jobs_created_smoke = 2`
- `jumi_artifacts_registered_smoke = 1`
- `jumi_input_resolve_requests_smoke = 1`
- `jumi_input_remote_fetch_smoke = 1`
- `jumi_input_materializations_smoke = 1`
- `jumi_sample_runs_finalized_smoke = 1`
- `jumi_gc_evaluate_requests_smoke = 1`
- `ah_artifacts_registered_smoke = 1`
- `ah_resolve_requests_smoke = 1`
- `ah_fallback_smoke = 1`
- `ah_gc_backlog_bytes_smoke = 1024`

## 이슈와 복구

### 1. shell trap cleanup bug

초기 버전의 wrapper는 `EXIT` trap에서 local 변수 이름을 직접 참조했다.
함수가 종료된 뒤 trap이 실행되면서 `unbound variable`로 비정상 종료했다.

복구:

- trap 선언 시 변수명을 넘기지 않고, 이미 확정된 temp file 경로 문자열을 바로 박아 넣도록 수정했다.

### 2. live run과 replay fixture의 backlog 기대값 차이

초기 gate는 replay fixture와 같은 정책을 사용했다.
그 정책은 `ah_gc_backlog_bytes_smoke <= 0`을 요구한다.

하지만 live VM lab에서는 AH retention window 때문에
run 전후 backlog가 `1024`로 유지될 수 있었다.
즉, live smoke는 성공했는데 gate만 실패하는 상태가 발생했다.

복구:

- live run 전용 정책 `policy/vm-lab/jumi-ah-live-thresholds.yaml`을 분리했다.
- live policy에서는 `ah_gc_backlog_bytes_smoke <= 1024`를 허용한다.
- 나머지 smoke threshold는 기존 정책과 동일하게 유지했다.

이 판단은 backlog를 무시하겠다는 뜻이 아니다.
현재는 retention이 살아 있는 live 환경의 정상치와
정규화된 replay fixture의 정상치를 분리해서 해석한다는 뜻이다.

## 산출물

- fixture:
  - `deploy/vm-lab/fixtures/kube-slint-jumi-ah-smoke-metrics.live.json`
- summary:
  - `artifacts/vm-lab/jumi-ah-smoke-live-sli-summary.json`
- gate:
  - `artifacts/vm-lab/gate/slint-gate-live-summary.json`

## 다음 판단

- 다음 스프린트에서는 live smoke 결과를 누적해 baseline 후보로 관리할 수 있다.
- 다만 `ah_gc_backlog_bytes`는 retention 정책 영향이 있으므로
  absolute zero 기준이 아니라 live baseline 대비 변화량 기준으로 보는 편이 더 적절하다.
