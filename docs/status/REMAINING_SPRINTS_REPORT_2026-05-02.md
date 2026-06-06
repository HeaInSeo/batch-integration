# Remaining Sprints Report 2026-05-02

기준일:
- `2026-05-02`

목적:
- 현재 코드와 문서 기준으로
  무엇이 끝났고 무엇이 남았는지,
  그리고 남은 스프린트를 어떤 순서와 목표로 잡아야 하는지
  정확하게 정리한다.

## 현재 상태 요약

완료 또는 기준선 도달:
- `M1. AH 최소 계약 고정`
- `M2. JUMI integration seam 삽입`
- `M2.5. kube-slint 개발 동반 guardrail 연결`
- `M3`의 핵심 happy path 상당 부분
  - `JUMI -> AH` gRPC happy path 존재
  - `infra-lab` shared VM + `jumi-ah-dev` namespace live smoke 존재
  - `kube-slint` summary/gate 생성 가능
  - `SF Observability` publish 경로 동작
- `M3.5`의 접근성/관찰면 부분
  - tailnet 진입점
  - dedicated namespace
  - live observability

아직 안 닫힌 것:
- `M3`의 제품형 실패 의미론과 기능 폭
- `M4`의 lifecycle/retention/summary 결합 완성도
- `M5`의 same-node preferred, cleanup debt, GC 안정화
- `M6`의 provenance/digest/manifest/nightly regression 문서 마감

## 이미 끝난 개발 조각

완료된 slice:
- Slice 1: `JUMI` 기본 경로의 무음 `Noop` fallback 제거
- Slice 2: `JUMI` handoff lifecycle 오류가 성공처럼 보이지 않게 변경
- Slice 3: `artifact-handoff` resolver의 `PENDING/MISSING` 분기 정교화
- Slice 4: `ah_v1.proto` generated gRPC happy path 전환
- Slice 5: 실패 케이스 회귀망 1차 확장
- Slice 6: `handoff unavailable` bounded retry/backoff 1차 구현

관련 기준 문서:
- [JUMI_AH_DEV_SPRINT_SLICES_2026-05-02.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/JUMI_AH_DEV_SPRINT_SLICES_2026-05-02.md:1)
- [MILESTONES_AND_GATES.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/master-plan/MILESTONES_AND_GATES.md:1)

## 남은 스프린트 구조

### Sprint A. M3 Closeout

목표:
- `M3. 첫 실제 통합`을 형식적 happy path가 아니라
  제품형 최소 통합으로 닫는다.

반드시 닫아야 할 항목:

완료 기준:
- `JUMI/AH` failure semantics가 문서와 코드에서 일치
- `producer_failed`, `missing`, `pending`, `resolve error`의 의미가 정리
- `infra-lab` live smoke와 `SF Observability` publish가 generated proto 경로에서 다시 PASS
- 위 PASS 결과를 기준선으로 삼아 failure semantics 변경이 live 경로를 깨지 않음을 유지

예상 산출물:
- `JUMI` executor 추가 테스트
- `artifact-handoff` resolver decision 문서 보강
- updated live smoke evidence

현재 상태 보정:
- generated proto 경로 live 재검증은 완료
  - `runId=jumi-ah-dev-live-smoke-20260502T075335Z`
  - `gate_result=PASS`
  - `published_shift_left_observability=true`
- `producer_failed + MISSING`는 `JUMI`에서 `input_resolution_producer_failed`로 분리 완료
- `notify terminal failure` 정책은 코드와 테스트로 고정 완료
  - success notify failure => hard-fail
  - failed/canceled notify failure => event-only
- `ResolveBinding` retry 대상도 코드와 테스트로 고정 완료
  - transient: gRPC `Unavailable/DeadlineExceeded/ResourceExhausted/Aborted/Internal`,
    HTTP `408/425/429/500/502/503/504`
  - non-transient: `NotFound/InvalidArgument/FailedPrecondition` 등
- 따라서 Sprint A의 남은 핵심은 live connectivity가 아니라 failure semantics 정리다

### Sprint B. M4 Foundation

목표:
- `NotifyNodeTerminal`, `FinalizeSampleRun`, `retention`, `derived indicator`, `multi-component summary`
  를 베타 기반 수준으로 끌어올린다.

보정:
- `kube-slint` 자체의 gate 엔진/CLI는 이미 많이 성숙했다.
- 따라서 이 스프린트의 본선은 `kube-slint` 기능 개발 자체보다
  `JUMI/AH lifecycle` 신호를 현재 `slint-gate` 입력 schema와 summary에
  얼마나 정확히 연결하느냐에 있다.

반드시 닫아야 할 항목:
- retention/lifecycle 의미론 강화
  - 지금은 `minRetention=15m` 고정
  - policy source/override 구조는 placeholder 성격이 강함
- `ah_gc_backlog_bytes` placeholder 제거 또는 명시적 모델화
  - current model: only GC-eligible retained artifacts contribute backlog,
    and backlog bytes come from registered artifact `sizeBytes`
- `manifest/export shim` vs `AH inventory` source-of-truth 정리
  - producer pod 내부 manifest는 임시 export 매체로만 취급
  - source-of-truth는 `AH inventory`
  - `uri`는 영구 위치가 아니라 run-scope locator로 정의
- `shell wrapper`에서 `runtime helper`로의 전환 시작
  - `jumi-output-helper` 바이너리 scaffold 완료
  - typed manifest 생성, digest/size 계산, termination-log export를 Go 코드로 이동할 바닥은 준비됨
  - `runtime-helper` mode wiring은 추가됐다
  - helper 전달 방식은 이번 스프린트에서 `workload image 포함 전략`을 먼저 택한다
    - helper가 들어 있는 image를 쓰고 command wiring만 바꾼다
    - generic `spawner` helper delivery surface는 후속 스프린트로 미룬다
  - 관련 기술 문서:
    [RUNTIME_HELPER_WORKLOAD_IMAGE_STRATEGY_2026-05-03.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/RUNTIME_HELPER_WORKLOAD_IMAGE_STRATEGY_2026-05-03.md:1)
- `kube-slint` summary에 lifecycle 관련 derived indicator 추가
  - 현재 smoke는 resolve/register/finalize/gc 계열 count 중심
  - 필요한 일은 `kube-slint` gate 엔진을 새로 만드는 것이 아니라
    `JUMI/AH` 쪽 상태를 현재 summary 결과에 더 잘 실어 넣는 것이다
- `JUMI` 성공/실패와 `AH` lifecycle snapshot을 같은 summary로 읽을 수 있게 결합

완료 기준:
- lifecycle/GC 관련 summary가 단순 count가 아니라 의미 있는 상태를 보여줌
- 기능 PR 검증에서 `kube-slint` summary 변화가 실제 review 신호로 쓰일 수 있음

예상 산출물:
- `artifact-handoff` lifecycle/GC 로직 보강
- `batch-integration` summary schema 보강
- `JUMI/AH` lifecycle 신호를 반영한 derived indicator 연결
- `SF Observability` 카드/테이블 항목 확장

### Sprint C. M4 Completion

목표:
- `multi-component summary`와 기능 PR 검증 결합을 실제 운영 기준으로 닫는다.

보정:
- `slint-gate` CLI와 gate 모델은 현재 기준으로 충분히 usable 하다.
- 따라서 Sprint C의 핵심은 `kube-slint` 본체를 더 만드는 것이 아니라,
  `run -> summary -> gate -> SF Observability` 경로를 우리 제품형 검증 루프로
  표준화하는 일이다.

반드시 닫아야 할 항목:
- `JUMI/AH/kube-slint`를 한 묶음으로 보는 summary schema 정리
- PR 또는 feature validation 시
  `run -> metrics -> summary -> gate -> SF Observability` 경로를 표준화
- shared VM `jumi-ah-dev`를 milestone 검증 경로로 공식 편입

완료 기준:
- `M4` 문서의 완료 기준이 실제 스크립트/증적과 연결
- live loop가 운영 루프일 뿐 아니라 기능 검증 루프로도 인정됨

### Sprint D. M5 Operability

목표:
- 운영성 강화 항목을 실제 코드와 정책으로 구현한다.

반드시 닫아야 할 항목:
- same-node preferred 정책
  - 현재는 `local_reuse`, `remote_fetch`, `producer_failed`, `unavailable` 정도
  - same-node preference를 더 명시적 정책으로 끌어올려야 함
- cleanup debt 추적
  - 현재 `jumi_cleanup_backlog_objects`는 거의 placeholder
- sample-run 격리 검증
  - shared VM/multi-run 상황에서 sample boundary가 안 섞이는지 확인 필요
- GC 안정화
  - retry, retention, lifecycle와 실제 삭제 정책의 연결이 아직 없다
- low-cardinality guard
  - metrics/event shape가 운영 관점에서 과도하게 늘어나지 않게 제어 필요

완료 기준:
- `M5` 항목이 단순 문서가 아니라 코드/metrics/test로 증명됨

### Sprint E. M6 Docs And Regression

목표:
- 문서 목표와 nightly regression 초안을 마감한다.

반드시 닫아야 할 항목:
- provenance-ready hook 정리
- manifest/digest 계약을 proto/runtime/doc에 일치시킴
  - 사용자 workload가 직접 쓰는 파일 계약으로 고정하지 않고,
    runtime export shim + AH inventory ledger 모델로 정리
- `infra-lab`/`DevSpace`/`SF Observability` 운영 프로필 문서 고정
- nightly regression 초안
  - 최소한 live smoke + gate + publish의 배치 실행안

완료 기준:
- 문서 기준과 코드 기준이 같은 말을 함
- 야간 회귀 초안이 실제 스크립트 수준에서 실행 가능

## 가장 급한 우선순위

1. Sprint A
   `M3` closeout
   이유:
   지금 가장 위험한 건 happy path만 있고 failure semantics가 덜 닫힌 상태라는 점이다.

2. Sprint B
   `M4` foundation
   이유:
   lifecycle/retention/summary가 placeholder를 벗어나야 베타 기반이 의미를 가진다.

3. Sprint C
   `M4` completion
   이유:
   기능 PR 검증과 live loop를 연결해야 `kube-slint`가 진짜 게이트가 된다.

4. Sprint D
   `M5` operability
   이유:
   same-node, cleanup debt, GC 안정화는 운영성 강화를 위한 중기 항목이다.

5. Sprint E
   `M6` docs and regression
   이유:
   문서와 nightly는 마지막에 정리해야 하지만, 너무 늦게 몰아도 안 되므로
   Sprint B부터 초안은 병행해도 된다.

## 정확한 판단 한 줄 요약

- 운영 경로는 이미 usable 하다.
- 개발 경로는 `M3` happy path를 넘긴 상태지만 아직 `M3 closeout`이 끝난 것은 아니다.
- 남은 스프린트의 핵심은 `failure semantics -> lifecycle semantics -> validation semantics -> operability -> docs/regression` 순서다.
