# VM Lab JUMI to AH Smoke Result

기준일: `2026-04-22`

## 목적

VM lab에서 `JUMI -> artifact-handoff` seam이
실제 run 제출 경로로 동작하는지 검증한 결과를 기록한다.

## 최종 결과

최종 검증 run:

- `runId`: `vm-lab-smoke-20260422T101800Z`
- `sampleRunId`: `vm-lab-smoke-sample-20260422T101800Z`
- 결과: `Succeeded`

node 결과:

- `produce`: `Succeeded`
- `consume`: `Succeeded`

핵심 이벤트:

- `node.input_resolved`
  - `binding=dataset`
  - `decision=remote_fetch`
  - `status=RESOLVED`
- `run.completed`
  - `Succeeded`

## 확인한 내용

### 1. run 제출 경로

`JUMI` gRPC `SubmitRun`으로 fixture를 제출했고
run이 terminal `Succeeded`까지 도달했다.

### 2. producer -> register

`produce` node가 성공했고,
`report` output이 AH inventory에 등록되었다.

### 3. consumer -> resolve

`consume` node 시작 전 artifact binding이 resolve되었다.

실제 pod 로그:

```text
status=RESOLVED decision=remote_fetch uri=jumi://runs/vm-lab-smoke-20260422T101800Z/nodes/produce/outputs/report source= materialize=true
```

해석:

- `status=RESOLVED` 확인
- `decision=remote_fetch` 확인
- `uri=jumi://...` logical artifact URI 확인
- `materialize=true` 확인
- `source`는 현재 비어 있음
  - 현재 register 경로에서 producer `NodeName`을 채우지 않기 때문

### 4. finalize / evaluateGC

run 종료 시 `FinalizeSampleRun`, `EvaluateGC` 호출이 반영된 것을
JUMI/AH metrics에서 확인했다.

## metrics 확인

### JUMI

```text
jumi_artifacts_registered_total 1
jumi_input_materializations_total 1
jumi_input_remote_fetch_total 1
jumi_input_resolve_requests_total 1
jumi_jobs_created_total 2
jumi_sample_runs_finalized_total 2
jumi_gc_evaluate_requests_total 2
```

메모:

- `jobs_created_total 2`는 producer/consume 2개 node 실행과 일치
- finalize / evaluateGC count는 재배포 후 누적 기준으로 2까지 증가한 상태

### artifact-handoff

```text
ah_artifacts_registered_total 1
ah_fallback_total 1
ah_resolve_requests_total 1
ah_gc_backlog_bytes 0
```

해석:

- artifact register 1회 확인
- remote fetch fallback 1회 확인
- resolve request 1회 확인

## 이번 검증에서 수정한 결함

### 1. JUMI/AH JSON contract 매핑 누락

증상:

- `consume` log에 `status=`가 비어 있었음
- event에도 `status=`가 비어 있었음

원인:

- `artifact-handoff`의 resolve HTTP 응답과
  `JUMI`의 decode struct 사이에 JSON tag가 명시돼 있지 않아
  `resolutionStatus` 매핑이 누락됨

조치:

- `artifact-handoff/pkg/domain/types.go`
- `JUMI/pkg/handoff/client.go`

에 JSON tag를 추가하고 테스트를 보강했다.

### 2. same tag 재사용으로 인한 캐시 재사용

증상:

- 수정 이미지를 `:dev`로 다시 push하고 rollout restart를 해도
  cluster 동작이 바뀌지 않는 것처럼 보였음

원인:

- 배포가 `imagePullPolicy: IfNotPresent`
- tag가 mutable `:dev`

즉 노드가 기존 캐시 이미지를 그대로 재사용할 수 있었다.

조치:

- unique tag `vmfix-20260422-1015` 생성
- deployment image를 그 태그로 명시 갱신
- 이후 smoke 재실행에서 `status=RESOLVED` 확인

## 현재 판단

이번 스프린트 기준으로
`JUMI -> artifact-handoff` seam은
로컬 테스트 수준이 아니라 VM lab 실제 실행 경로에서도 최소 동작이 확인되었다.

즉 다음 단계는:

- kube-slint 회귀 기준에 이 smoke 결과를 연결
- 이후 VM + dev-space 단계에서 churn 회귀 검증으로 승격
