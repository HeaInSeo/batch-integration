# JUMI AH Dev Sprint Slices 2026-05-02

목적:
- 운영 루프와 별도로 `JUMI`/`artifact-handoff` 개발 회복을
  짧은 스프린트 조각으로 관리한다.

## Slice 1

목표:
- `JUMI` 기본 실행 경로에서 무음 `Noop` fallback 제거

상태:
- 완료

결과:
- `JUMI_AH_GRPC_TARGET` 또는 `JUMI_AH_URL`이 없으면 기본적으로 프로세스가 실패한다.
- `JUMI_ALLOW_NOOP_HANDOFF=true`일 때만 개발용 noop mode를 허용한다.

관련 변경:
- [main.go](/opt/go/src/github.com/HeaInSeo/JUMI/cmd/jumi/main.go:1)
- [main_test.go](/opt/go/src/github.com/HeaInSeo/JUMI/cmd/jumi/main_test.go:1)

## Slice 2

목표:
- `JUMI` handoff lifecycle 오류가 성공처럼 보이지 않게 하기

상태:
- 완료

결과:
- `RegisterArtifact` 실패 시 node/run이 `register_artifact_error`로 실패한다.
- `FinalizeSampleRun` 실패 시 성공 run도 `handoff_finalize_error`로 실패한다.
- `EvaluateGC` 실패 시 성공 run도 `handoff_gc_evaluate_error`로 실패한다.
- 이미 실패/취소된 node의 terminal notify 실패는 원래 실패 원인을 유지하고 이벤트로만 남긴다.

관련 변경:
- [executor.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/executor/executor.go:315)
- [dag_engine_test.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/executor/dag_engine_test.go:35)

## Slice 3

목표:
- `artifact-handoff` resolver가 `PENDING`과 `MISSING`을 더 정확히 나누게 하기

상태:
- 완료

결과:
- producer terminal이 아직 없고 artifact도 없으면 `PENDING/unavailable`
- producer가 이미 terminal인데 artifact가 없으면 `MISSING/unavailable`
- sample run이 이미 `GCEligible`이면 artifact가 있어도 handoff 대상에서 제외

관련 변경:
- [service.go](/opt/go/src/github.com/HeaInSeo/artifact-handoff/pkg/resolver/service.go:85)
- [service_test.go](/opt/go/src/github.com/HeaInSeo/artifact-handoff/pkg/resolver/service_test.go:48)

## Slice 4

목표:
- proto-generated gRPC 경로 전환 준비

상태:
- live 검증 포함 완료

범위:
- `ah_v1.proto` 기준 generated server/client 도입
- `artifact-handoff` server registration을 generated service로 교체
- `JUMI` handoff gRPC client를 generated client로 교체
- `infra-lab`의 `jumi-ah-dev` live smoke로 실제 런타임 재검증

결과:
- generated files:
  [ah_v1.pb.go](/opt/go/src/github.com/HeaInSeo/artifact-handoff/api/proto/ahv1/ah_v1.pb.go:1)
  [ah_v1_grpc.pb.go](/opt/go/src/github.com/HeaInSeo/artifact-handoff/api/proto/ahv1/ah_v1_grpc.pb.go:1)
- server:
  [grpc.go](/opt/go/src/github.com/HeaInSeo/artifact-handoff/pkg/resolver/grpc.go:1)
- client:
  [grpc_client.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/handoff/grpc_client.go:1)
- `JUMI`는 container build 제약 때문에 generated proto copy를 자체 package로 포함:
  [go.mod](/opt/go/src/github.com/HeaInSeo/JUMI/go.mod:1)
- live evidence:
  `runId=jumi-ah-dev-live-smoke-20260502T075335Z`
  `gate_result=PASS`
  `published_dev_space=true`

남은 정리:
- manual JSON codec 경로를 완전히 걷어낼지 호환 레이어로 당분간 남길지 결정
- `JUMI` 자체 API gRPC도 같은 수준으로 proto/generated 경로로 갈지 별도 판단

## Slice 5

목표:
- 실패 케이스 회귀망 확장

상태:
- 1차 완료

범위:
- `digest mismatch`
- `producer failed but artifact missing`
- `notify terminal failure`
- `gc lifecycle blocked/unblocked`
- `handoff unavailable` 재시도 정책 정리

결과:
- `artifact-handoff`
  - `digest mismatch` 오류 테스트 추가
  - `sample_run_not_finalized` GC block 테스트 추가
  - `producer failed but artifact missing`를 `producer_failed` decision으로 분리
- `JUMI`
  - `handoff_gc_evaluate_error` run failure 테스트 추가
  - `resolve_handoff_error` node failure 테스트 추가
  - `input_resolution_missing` node failure 테스트 추가
  - `producer_failed + MISSING`를 `input_resolution_producer_failed`로 분리

관련 변경:
- [service_test.go](/opt/go/src/github.com/HeaInSeo/artifact-handoff/pkg/resolver/service_test.go:1)
- [dag_engine_test.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/executor/dag_engine_test.go:1)

남은 항목:
- `notify terminal failure` 정책 확정 완료
  - `Succeeded` notify 실패는 `notify_node_terminal_error`로 hard-fail
  - `Failed`/`Canceled` notify 실패는 terminal reason을 유지하고
    `node.handoff.notify_failed` 이벤트만 남김
- `handoff unavailable` 재시도 정책과 backoff semantics는 1차 구현 완료

## Slice 6

목표:
- `handoff unavailable`에 대한 bounded retry/backoff 추가

상태:
- 완료

결과:
- `JUMI`는 `ResolveBinding`에서 transient 오류에 대해 최대 3회까지 재시도한다.
- 재시도 사이에는 짧은 backoff를 둔다.
- retry budget 소진 시 기존처럼 `resolve_handoff_error`로 실패한다.
- transient 오류가 budget 안에서 회복되면 run은 계속 진행한다.
- `NotFound`, `InvalidArgument`, `FailedPrecondition` 같은 non-transient 오류는 즉시 실패한다.
- `Unavailable`, `DeadlineExceeded`, `ResourceExhausted`, `Aborted`, `Internal`과
  HTTP `408/425/429/500/502/503/504`는 재시도 대상으로 분류한다.

관련 변경:
- [executor.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/executor/executor.go:390)
- [dag_engine_test.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/executor/dag_engine_test.go:1)

## Slice 7

목표:
- `wrapped-shell` provenance 경로를 `runtime helper` 바이너리로 옮길 바닥을 만들고,
  helper delivery 전략을 현재 스프린트 범위에 맞게 고정

상태:
- 진행 중

결과:
- `jumi-output-helper` helper package와 CLI가 추가됐다.
- helper는 사용자 command 실행, output digest/size 계산, manifest 생성,
  termination-log export를 Go 코드로 수행한다.
- `JUMI` backend adapter에 `runtime-helper` mode가 추가됐다.
- 이번 스프린트에서는 generic `spawner` helper delivery surface를 새로 열지 않고,
  helper가 포함된 workload image를 사용하는 전략을 먼저 택한다.

관련 변경:
- [helper.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/runtimehelper/helper.go:1)
- [main.go](/opt/go/src/github.com/HeaInSeo/JUMI/cmd/jumi-output-helper/main.go:1)
- [spawner_k8s.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/backend/spawner_k8s.go:1)
- [Containerfile](/opt/go/src/github.com/HeaInSeo/JUMI/Containerfile:1)

남은 항목:
- helper 기반 workload image 경로 live 재검증
- shell wrapper를 fallback 경로로 내리는 순서 확정
- generic `spawner` delivery surface가 실제로 필요한 시점 재판단
- 기술 문서:
  [RUNTIME_HELPER_WORKLOAD_IMAGE_STRATEGY_2026-05-03.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/RUNTIME_HELPER_WORKLOAD_IMAGE_STRATEGY_2026-05-03.md:1)
