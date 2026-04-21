# Implementation Progress

기준일: `2026-04-21`

이 문서는 원본 일정 문서를 대체하지 않는다.
현재 스프린트에서 실제로 구현된 최소 기능을 기록해,
다음 커밋/통합/검증 단위의 기준점으로 사용한다.

## 1. artifact-handoff

현재 반영된 최소 구현:
- resolver service 골격 존재
- proto 초안 존재
- in-memory store 존재
- `RegisterArtifact`, `ResolveHandoff`, `NotifyNodeTerminal` 동작
- `FinalizeSampleRun`, `EvaluateGC`, `GetSampleRunLifecycle` 동작
- terminal node 집계 존재
- GC blocked reason 최소 규칙 존재
- 최소 retention window 존재
  - 기본 source: `service_default`
  - 기본 duration: `15m`

현재 의미:
- sample run 종료 직후 바로 GC eligible로 넘어가지 않는다.
- terminal node가 없거나 retained artifact가 없으면 GC가 차단된다.
- retention window가 끝나기 전에는 GC가 차단된다.

남은 핵심 작업:
- gRPC generated path
- lease/pin 모델
- retention policy 외부 주입
- progressive GC / failed sample retention / promotion gate
- 실제 delete executor

## 2. JUMI

현재 반영된 최소 구현:
- handoff client package 존재
- HTTP client / noop client 존재
- executor가 node 성공 시 output artifact를 AH에 등록
- output 등록용 최소 URI 생성
  - `jumi://runs/<runID>/nodes/<nodeID>/outputs/<outputName>`
- artifact 등록 메트릭 존재
  - `jumi_artifacts_registered_total`

현재 의미:
- JUMI가 더 이상 output lifecycle을 완전히 로컬 내부 문제로만 두지 않는다.
- 성공한 node output이 AH inventory에 들어갈 최소 seam이 생겼다.

남은 핵심 작업:
- binding 기반 resolve 호출 확대
- sampleRun 격리 강화
- retention class / GC hook
- provenance-ready hook

## 3. kube-slint

현재 반영된 최소 구현:
- JUMI/AH 최소 guardrail spec 확장
- 아래 metric delta를 읽는 최소 테스트 존재
  - `jumi_jobs_created_delta`
  - `jumi_fast_fail_trigger_delta`
  - `jumi_artifacts_registered_delta`
  - `ah_resolve_requests_delta`
  - `ah_fallback_delta`
  - `ah_artifacts_registered_delta`
- cleanup / GC backlog 계열 end-state 체크 유지

현재 의미:
- JUMI/AH 개발과 kube-slint guardrail 확장이 분리되지 않고 같이 전진한다.
- cluster가 완전히 준비되지 않아도 최소 회귀 지표를 로컬 테스트로 누적할 수 있다.

남은 핵심 작업:
- kind/tilt 또는 대체 환경 연결
- summary 출력 경로 고정
- churn / fallback / retention 회귀 지표 강화

## 4. 스프린트 해석

원본 설계 문서 기준으로 보면:
- `artifact-handoff`는 `M1` 범위가 실질적으로 거의 확보되었다.
- `JUMI`는 `M2`로 가는 seam 삽입이 시작되었다.
- `kube-slint`는 `M2.5`의 최소 guardrail 준비가 시작되었다.

단, 아직 미완인 항목:
- 실제 gRPC contract 고정
- 더 넓은 JUMI resolve 경로
- cluster 기반 통합 검증 경로
- `vm + dev-space` 최소 구축

## 5. 현재 판단

현재 스프린트는 다음 순서가 맞다.
- `artifact-handoff` lifecycle/retention/GC 기본형 계속 고도화
- `JUMI`가 AH hook를 더 많이 실제 호출하도록 확장
- `kube-slint`가 그 seam을 회귀 지표로 감시하도록 확장
- 환경 구축은 병행하되 주 개발 트랙의 블로커로 두지 않음
