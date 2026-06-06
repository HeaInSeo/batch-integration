# JUMI AH Dev Backlog 2026-05-02

목적:
- `dev-space`와 live smoke 운영 루프가 아니라
  `JUMI`와 `artifact-handoff` 자체의 개발 지연 항목을 코드 기준으로 다시 고정한다.

판단:
- 운영 진입점은 확보됐다.
- 하지만 제품 기능 완성도 기준으로는 `JUMI`와 `artifact-handoff` 둘 다 아직 뒤에 남은 항목이 크다.
- 따라서 다음 스프린트의 중심은 운영이 아니라 개발 backlog 소거여야 한다.

## JUMI backlog

1. 기본 실행 경로가 아직 강하게 `Noop` fallback을 허용한다.
   - `NewDagEngine()` 기본값이 `handoff.NewNoopClient()`다.
     [executor.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/executor/executor.go:86)
   - `cmd/jumi`도 `JUMI_AH_GRPC_TARGET` 초기화 실패 시 바로 `NoopClient`로 떨어진다.
     [main.go](/opt/go/src/github.com/HeaInSeo/JUMI/cmd/jumi/main.go:82)
   - 결과적으로 제품형 경계가 죽어도 실행 자체는 계속될 수 있다.

2. handoff lifecycle 오류 의미론은 1차 정리됐지만 summary/gate 연결은 더 남아 있다.
   - `FinalizeSampleRun`, `EvaluateGC`, `RegisterArtifact` 실패는 이제 성공처럼 보이지 않는다.
   - `NotifyNodeTerminal` 정책도 고정됐다.
     - success notify failure => `notify_node_terminal_error` hard-fail
     - failed/canceled notify failure => event-only
   - 남은 일은 이 의미론을 현재 성숙한 `slint-gate` 입력 schema와
     summary/gate 신호에 더 정확히 투영하는 것이다.

3. binding resolution 실패 종류가 아직 거칠다.
   - `producer_failed + MISSING`는 `input_resolution_producer_failed`로 분리됐다.
   - transient/non-transient retry 분류도 1차 고정됐다.
   - 남은 일은 `PENDING`, digest/policy mismatch, summary/gate 반영 같은 세부 의미론 확장이다.

4. generated gRPC happy path는 붙었지만 제품형 계약 정리는 더 남아 있다.
   - `JUMI`와 `artifact-handoff`는 generated proto 경로로 happy path와 live smoke를 통과했다.
   - 남은 일은 package 공유 방식, API surface, 그리고 `manifest -> RegisterArtifact -> AH inventory` ownership 정리를 더 하는 것이다.

5. 통합 테스트가 아직 제품형 service 경계를 충분히 대표하지 못한다.
   - executor의 HTTP handoff 통합 테스트는 실제 `artifact-handoff`가 아니라 `httptest` stub을 사용한다.
     [dag_engine_handoff_http_test.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/executor/dag_engine_handoff_http_test.go:15)
   - live smoke는 생겼지만, 개발용 실패 케이스 회귀망은 아직 얕다.

## artifact-handoff backlog

1. resolver 결정 로직이 아직 최소 happy path 수준이다.
   - `ResolveHandoffCore()`는 사실상 `local_reuse`, `remote_fetch`, `missing/unavailable` 정도만 구분한다.
     [service.go](/opt/go/src/github.com/HeaInSeo/artifact-handoff/pkg/resolver/service.go:85)
   - locality, digest policy, retention state, node health 같은 실제 배치 조건은 아직 비어 있다.
   - 특히 `uri`는 영구 저장 위치가 아니라 run-scope locator라는 의미론을 resolver와 문서에 같이 반영해야 한다.

2. GC/lifecycle은 아직 bookkeeping 단계다.
   - `FinalizeSampleRunCore()`와 `EvaluateGCCore()`는 이제 store 기준 snapshot refresh를 수행한다.
   - `ah_gc_backlog_bytes`는 이제 GC eligible retained artifact의 실제 `sizeBytes` 합 기준으로 계산된다.
   - 다만 delete execution, retention override source, non-memory durability는 아직 남아 있다.

3. generated gRPC live path는 검증됐지만 제품형 정리는 더 남아 있다.
   - `ah_v1.proto` generated server/client happy path와 live smoke는 이미 통과했다.
   - 남은 일은 contract 확대, package 정리, API surface 일치다.

4. storage/inventory가 아직 제품형 durability를 대표하지 않는다.
   - `Service`는 store interface 위에 올라가 있지만 현재 주 사용 경로는 in-memory 개발 경로 중심이다.
   - 그래서 restart, replay, retention carry-over, multi-instance semantics는 아직 검증되지 않았다.
   - 또 producer pod 내부 manifest는 export shim일 뿐이고, `AH inventory`가 source-of-truth라는 기준도 durable backend 설계에 같이 반영돼야 한다.

## 다음 스프린트 우선순위

1. `JUMI` 기본 경로에서 `Noop` fallback을 개발 전용 모드로 격리한다.
2. `JUMI`에서 handoff lifecycle 호출 실패를 어디까지 hard-fail로 볼지 의미론을 정한다.
3. `artifact-handoff` resolve/GC/lifecycle 로직을 placeholder 수준에서 한 단계 올린다.
4. `ah_v1.proto` 기준 generated gRPC 경로 전환 계획을 시작한다.
5. `manifest/export shim`과 `AH inventory source-of-truth` 의미론을 계약/코드/문서에 일치시킨다.
6. happy path가 아니라 `missing`, `digest mismatch`, `handoff unavailable`, `finalize/gc failure` 테스트를 늘린다.
7. `wrapped-shell` provenance 경로를 `runtime helper` 바이너리로 치환한다.
   - helper scaffold는 생겼다.
   - helper scaffold와 `runtime-helper` mode wiring은 생겼다.
   - `workload image 포함 전략`을 먼저 택했다.
     - helper가 포함된 workload image를 실행하고
       `JUMI`는 command wiring만 바꾼다.
     - generic `spawner` helper delivery surface는 후속 스프린트로 미룬다.
   - 남은 일은 live 재검증, shell wrapper 제거 순서, generic delivery 필요 시점 판단이다.
   - 현재 `spawner`는 single-container Job + PVC mount 수준만 지원하고,
     init container / sidecar / projected helper injection surface가 없다.
   - 관련 기술 문서:
     [RUNTIME_HELPER_WORKLOAD_IMAGE_STRATEGY_2026-05-03.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/RUNTIME_HELPER_WORKLOAD_IMAGE_STRATEGY_2026-05-03.md:1)
8. `kube-slint` 본체 개발보다 `JUMI/AH -> summary -> slint-gate` 연결을 먼저 정교화한다.
   - 현재 병목은 gate 엔진 자체보다 입력 신호 품질과 summary schema 결합이다.

정리:
- 지금 닫힌 것은 운영 루프다.
- 지금 밀린 것은 `JUMI`와 `artifact-handoff`의 제품 기능 개발이다.
- 다음 스프린트는 이 backlog를 직접 줄이는 쪽으로 잡아야 한다.
