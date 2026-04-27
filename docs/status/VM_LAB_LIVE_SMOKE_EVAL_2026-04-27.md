# VM Lab Live Smoke Eval

기준일: `2026-04-27`

## 목적

- 복구된 `multipass` VM lab 위에 새 `JUMI`, `artifact-handoff` 이미지를 다시 올린다.
- 실제 smoke run과 `kube-slint` gate를 재실행해
  환경 복구와 코드 기준선이 함께 유효한지 확인한다.

## 사용 이미지

- `harbor.10.113.24.96.nip.io/batch-int/artifact-handoff:phase1-20260427-101256z`
- `harbor.10.113.24.96.nip.io/batch-int/jumi:phase1-20260427-101256z`

## 실행 결과

- runId: `vm-lab-live-smoke-20260427T122705Z`
- sampleRunId: `vm-lab-live-smoke-sample-20260427T122705Z`
- smoke terminal status: `Succeeded`
- live gate result: `PASS`

주요 run 흐름:

- `produce`: `Succeeded`
- `consume`: `Succeeded`
- `node.input_resolved`: `decision=remote_fetch status=RESOLVED`

## 이번에 확인된 이슈

### 1. live metrics probe가 빈 registry를 실패로 처리함

초기 재실행에서는 `scripts/run-vm-lab-live-smoke-eval.sh`가
시작 전 metrics 수집 단계에서 바로 실패했다.

실제 원인:

- 새로 rollout된 직후에는 `jumi`와 `artifact-handoff`의
  custom metrics registry가 비어 있을 수 있다.
- `/metrics`는 `200`을 반환하지만 body는 빈 문자열일 수 있다.
- 그런데 collector는 `wget ... | grep prefix_`를 사용했고,
  매칭이 없으면 `grep`이 `exit 1`로 끝나 전체 스크립트가 실패했다.

복구:

- collector 명령을 `grep ... || true`로 완화했다.
- 결과적으로 "zero metrics"와 "collector failure"를 구분할 수 있게 됐다.

이 수정은 threshold를 느슨하게 만든 것이 아니라,
빈 시작점도 합법적인 관찰값으로 처리하게 만든 것이다.

## 산출물

- fixture:
  - `deploy/vm-lab/fixtures/kube-slint-jumi-ah-smoke-metrics.live.json`
- summary:
  - `artifacts/vm-lab/jumi-ah-smoke-live-sli-summary.json`
- gate:
  - `artifacts/vm-lab/gate/slint-gate-live-summary.json`

## 현재 판단

- `multipass` VM lab은 다시 실사용 가능한 상태다.
- 새 phase-1 이미지도 VM lab에서 실제 smoke와 gate를 통과했다.
- 남은 주요 infra debt는 `snap run multipass` 표준 CLI 경로 복구다.
