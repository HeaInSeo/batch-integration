# JUMI 최종 개발 문서 v1.0 — Integration-Aware DAG Executor

> 작성일: 2026-04-21
> 기준 입력:
> - `JUMI_AH_Integration_Design_ko v0.7` (2026-04-20)
> - `JUMI_AH_kube_slint_metrics_churn_dev_plan_ko v2` (2026-04-20)
> - `kube-slint 개발 문서 v1.0` (2026-04-21)
> - `JUMI-main` 저장소 현황 (Sprint 1~5 부분 진행)
> 목적: JUMI를 단순 DAG executor가 아니라, **AH와의 integration seam, kube-slint 계측, lifecycle/GC, provenance-ready hook**을 처음부터 가지는 batch data-plane app으로 완성하기 위한 개발 기준선과 스프린트 일정을 고정한다.

---

## 0. 한 줄 요약

JUMI는 더 이상 "ExecutableRunSpec을 받아 DAG를 도는 앱"이 아니다. JUMI는 **(1) DAG의 binding 관계를 알고 AH에 넘기는 owner**, **(2) lifecycle/GC 권한을 graph 관점에서 선언하는 owner**, **(3) kube-slint가 읽을 batch app metrics를 1급으로 노출하는 producer**, **(4) provenance-ready 최소 hook을 남기는 runtime**이다.

---

## 1. 현재 상태 진단

### 1.1 잘 잡혀 있는 것

- **Run/Node/Attempt 3계층 상태 모델**: `pkg/spec/types.go`에 `RunStatus`, `NodeStatus`, `AttemptStatus`가 분리되어 있고, `pkg/observe/status.go`에 `currentBottleneckLocation`, `terminalStopCause`, `terminalFailureReason` 분리도 되어 있다.
- **DagEngine 골격**: `pkg/executor/executor.go`(602 줄)에 dag-go 기반 실행 엔진이 동작하고 있고, fast-fail/cancel 기본 경로는 있다.
- **gRPC 표면**: `pkg/api/grpc.go`, `pkg/api/service.go`에 `SubmitRun`, `GetRun`, `ListRunNodes`, `CancelRun`이 잡혀 있다.
- **Backend 추상화**: `pkg/backend/backend.go`(`Adapter` 인터페이스), `pkg/backend/spawner_k8s.go`(K8s 구현)로 spawner가 분리되어 있다.
- **Kueue 옵셔널**: `pkg/spec/types.go`의 `KueueHints`와 `NodeObservation`으로 Kueue가 있어도 없어도 core가 깨지지 않는 구조.
- **테스트 커버리지**: `dag_engine_*_test.go`로 fastfail / kueue / observe / scheduler / 일반 dag 시나리오가 분리 테스트.
- **Sprint 1~5 정의**: `docs/JUMI_SPRINT_PLAN.ko.md`로 PoC → 제품 경로가 문서화되어 있다.

### 1.2 부족한 부분

#### F1. Artifact-aware binding 모델 부재 (Critical)

현재 `pkg/spec/types.go` Node의 input/output 모델이 다음 수준이다:

```go
Inputs   []string          `json:"inputs,omitempty"`
Outputs  []string          `json:"outputs,omitempty"`
Metadata map[string]string `json:"metadata,omitempty"`
```

이 구조로는 통합 설계 v0.7 §12.2가 요구하는 다음을 표현할 수 없다:

- `bindingName` (parent output → child input의 logical 이름)
- `producerNodeId` / `producerOutputName`
- `consumePolicy` (`SameNodeOnly` | `SameNodeThenRemote` | `RemoteOK`)
- `expectedDigest`
- `required` / `optional` 구분
- `retentionClass` / `promotionRequired`

#### F2. Lifecycle 단계 부재 (Critical)

현재 `pkg/executor/executor.go`의 단계는 conceptually:

```text
Pending → Ready → Releasing → Starting → Running → Succeeded/Failed/Canceled
```

통합 설계 v0.7 §11이 요구하는 다음 단계가 main path에 없다:

- `BuildingBindings` — JUMI가 binding 목록을 만드는 단계
- `ResolvingInputs` — AH에 넘기고 handoff strategy를 받는 단계
- `PlacementResolved` — 결과 확정
- `FinalizingOutputs` — 출력 등록과 retention class 결정
- `PromotionConfirmed` — 외부 promotion 확인
- `GCEligible` / `Retained` — 회수 가능 상태

executor.go 396번 라인 근처에서 backend prepare → start로 바로 넘어가는데, 그 사이에 `ResolveHandoff` hook이 들어갈 자리가 없다.

#### F3. AH 호출 클라이언트 부재 (Critical)

JUMI가 AH로 `RegisterArtifact`, `ResolveHandoff`, `NotifyNodeTerminal`, `FinalizeSampleRun`을 보낼 클라이언트가 없다. 통합 설계 v0.7 §13의 5개 RPC를 완전히 구현해야 한다.

#### F4. SampleRun 개념 부재

현재 `RunMetadata`는 `RunID`만 가진다. 통합 설계 v0.7 §15.2가 요구하는 "GC 경계는 sample run"을 지원하려면 `sampleRunId`가 1급이 되어야 한다. 같은 pipeline definition을 100명에 대해 돌리는 시나리오에서 artifact namespace를 분리하는 핵심 키다.

#### F5. Provenance-ready 최소 hook 부재

통합 설계 v0.7 §19가 요구하는 다음이 모두 미구현:

- parent output `artifactDigest` 생성 hook
- `/out/_meta/artifacts.manifest.json` 생성 계약
- binding snapshot (parent → child)
- `availabilityState` 모델 (`LOCAL_ONLY`, `CAS_SEALED`, `BOTH`, `DELETED`, `UNAVAILABLE`)

#### F6. Metrics 노출 부재

`pkg/executor/executor.go`에 `prometheus.Counter`, `prometheus.Histogram` 등의 메트릭 정의가 전혀 없다. 메트릭 계획 v2 §7의 32개 메트릭을 모두 새로 추가해야 한다.

#### F7. Cleanup debt 추적 부재

현재 cancel/delete가 best-effort 수준이고, "지웠어야 하는데 아직 못 지운 Job/Pod 수"를 추적하는 mechanism이 없다. 메트릭 계획 v2 §7.5의 `jumi_cleanup_backlog_objects`, `jumi_delete_lag_seconds`를 위한 internal state가 필요.

#### F8. Retention class 표현 부재

통합 설계 v0.7 §15.3의 `EphemeralIntermediate`, `FinalOutputToPromote`, `DiagnosticRetained`, `SharedReusableExplicit` 4개 클래스를 표현할 곳이 spec에도 record에도 없다.

#### F9. fan-in 다중 parent의 source priority 미정

통합 설계 v0.7 §24.1의 열린 질문 4번. 현재 dag-go는 edge 단위로 dependency를 풀지만, 한 child가 여러 parent로부터 같은 artifact를 받을 때 source priority를 표현하는 방법이 없다.

### 1.3 위험성

#### R1. Spec 변경이 PoC fixture를 깰 위험 (High)

`pkg/spec/types.go`의 Node 구조에 `ArtifactBinding` 필드를 추가하면 기존 fixture가 깨질 수 있다. PoC와 e2e 테스트 fixture 모두 새 spec으로 마이그레이션해야 한다.

**완화**: Sprint J-6에서 spec v2를 추가하되, Node에 `ArtifactBindings []ArtifactBinding` 필드를 옵셔널로 추가하고, 비어 있으면 기존 `Inputs`/`Outputs`로 fallback하는 backward compatibility 레이어를 둔다.

#### R2. AH가 Sprint K-2 전에는 호출할 수 없는 상태 (Critical 의존성)

JUMI Sprint 6 (artifact binding 추가) → Sprint 7 (AH 호출 hook 삽입)이 진행되려면, AH 자체가 resolver service로 동작해야 한다. 현재 AH는 main.go가 7줄밖에 안 되는 빈 상태.

**완화**: Sprint J-7은 **AH Sprint 1, 2 완료 후**에만 시작. 그 전까지는 mock AH client (in-process stub)로 개발한다.

#### R3. Lifecycle 단계 추가가 executor.go 대규모 리팩토링 유발 (High)

`BuildingBindings`, `ResolvingInputs`, `FinalizingOutputs` 등을 main path에 넣으려면 `pkg/executor/executor.go`의 nodeRunner를 phase-aware state machine으로 재구성해야 한다.

**완화**: Sprint J-6에서 phase enum과 transition map을 먼저 정의하고, Sprint J-7에서 hook을 점진적으로 삽입. 한 번에 하지 않는다.

#### R4. Same-node placement가 K8s scheduler와 충돌

통합 설계 v0.7이 요구하는 `RequiredSameNode` placement는 현재 backend `spawner_k8s.go`의 Pod spec 생성 시 nodeAffinity나 nodeName으로 반영해야 하는데, K8s scheduler 정책과 충돌할 수 있다.

**완화**: Sprint J-8에서 `PreferredSameNode`만 먼저 구현하고, `RequiredSameNode`는 scheduler 동작 검증 후 도입.

#### R5. fan-in 다중 parent에서 race condition

여러 parent가 동시에 `RegisterArtifact`를 보내고 child가 `ResolveHandoff`를 받을 때, AH의 state 업데이트와 JUMI의 child submission 사이에 race가 발생할 수 있다.

**완화**: Sprint J-7에서 `ResolveHandoff`는 모든 parent의 `RegisterArtifact`가 완료된 후에만 호출되도록 JUMI side에서 명시적 ordering 보장.

#### R6. Sample run 격리가 깨질 위험

`sampleRunId`가 도입되어도, `pkg/registry/memory.go`가 단일 namespace로 run을 보관하면 multi-sample 격리가 약하다. retention/GC 판정 시 다른 sample 데이터를 참조할 위험.

**완화**: Sprint J-9에서 registry에 sample-scoped index 추가.

#### R7. Cleanup debt 무한 증가

fast-fail cascade로 delete 요청이 burst하면 K8s API가 throttle되고, 그 동안 JUMI 내부에 cleanup queue가 쌓인다. 메트릭으로만 노출하면 운영자가 볼 뿐 자동 회복은 안 된다.

**완화**: Sprint J-10에서 cleanup workqueue에 rate limiter와 retry backoff를 명시적으로 도입.

#### R8. metric label cardinality 누설 위험

JUMI 개발자가 무심코 `runId`를 label에 넣을 가능성이 매우 높다 (디버깅 편의 때문에).

**완화**: Sprint J-9에서 metric helper 함수를 통해서만 label set을 받도록 강제하고, kube-slint K-3의 cardinality lint를 CI에서 실행.

### 1.4 보완해야 할 것 — 우선순위 요약

| 우선순위 | 항목 | 관련 부족·위험 | 다루는 스프린트 |
|---|---|---|---|
| P0 | Artifact binding 모델 spec에 추가 | F1, R1 | J-6 |
| P0 | Lifecycle phase enum과 transition map | F2, R3 | J-6 |
| P0 | sampleRunId 도입과 격리 | F4, R6 | J-6 |
| P0 | Metrics 노출 (kube-slint K-1과 정합) | F6, R8 | J-6 |
| P1 | AH 클라이언트와 5개 RPC hook 삽입 | F3, R2 | J-7 |
| P1 | Same-node placement (PreferredSameNode) | R4 | J-8 |
| P1 | Provenance-ready hook (digest, manifest) | F5 | J-8 |
| P2 | Retention class와 GC 판정 hook | F8 | J-9 |
| P2 | Cleanup debt 추적과 backpressure | F7, R7 | J-10 |
| P3 | fan-in source priority | F9 | J-11 |

---

## 2. 개발 목표 및 비목표

### 2.1 목표

1. JUMI가 통합 설계 v0.7의 5개 hook (`RegisterArtifact`, `ResolveHandoff`, `Inject Acquisition Contract`, `FinalizeArtifactLifecycle`, `EvaluateGC/ReleaseRunScope`)을 모두 호출한다.
2. JUMI가 `BuildingBindings`, `ResolvingInputs`, `FinalizingOutputs` 단계를 main path에 명시적으로 가진다.
3. JUMI가 `sampleRunId` 단위로 artifact namespace를 격리한다.
4. JUMI가 메트릭 계획 v2 §7의 batch executor metrics를 모두 노출한다.
5. JUMI가 `/out/_meta/artifacts.manifest.json` 계약과 `artifactDigest` 생성 hook을 갖는다.
6. JUMI가 progressive GC와 end-of-run GC를 sample run 단위로 안전하게 수행한다.

### 2.2 비목표

- AH의 backend (Dragonfly 등) 자체 구현
- authored pipeline compiler / lowering
- global policy scheduler
- multi-cluster handoff
- full provenance DB 자체 구현

---

## 3. 아키텍처 변경 요점

### 3.1 spec 확장 (`pkg/spec/types.go`)

```text
Node에 추가될 필드:
- ArtifactBindings []ArtifactBinding   // 신규, optional (backward compat)
- RetentionClass   string              // 신규, optional
- PromotionRequired bool               // 신규, optional

ArtifactBinding 신규 타입:
- BindingName          string
- ChildInputName       string
- ProducerNodeID       string
- ProducerOutputName   string
- ArtifactID           string  (optional)
- Required             bool
- ConsumePolicy        ConsumePolicy enum
- ExpectedDigest       string  (optional)
- SizeHint             int64   (optional)

RunMetadata에 추가:
- SampleRunID  string  // 신규, optional
- PipelineID   string  // 신규, optional
- BatchGroupID string  // 신규, optional
```

기존 `Inputs []string`, `Outputs []string`는 **유지**하되, `ArtifactBindings`가 비어 있을 때만 사용하는 fallback path로 둔다.

### 3.2 phase 모델 (`pkg/spec/types.go`, `pkg/executor/executor.go`)

```text
NodeStatus에 추가될 enum:
- NodeStatusBuildingBindings    "BuildingBindings"
- NodeStatusResolvingInputs     "ResolvingInputs"
- NodeStatusPlacementResolved   "PlacementResolved"
- NodeStatusFinalizingOutputs   "FinalizingOutputs"
- NodeStatusPromotionPending    "PromotionPending"
- NodeStatusGCEligible          "GCEligible"
- NodeStatusRetained            "Retained"

Transition map (executor 내부):
Ready → BuildingBindings → ResolvingInputs → PlacementResolved 
     → Releasing(기존) → Starting(기존) → Running(기존)
     → Succeeded/Failed/Canceled(기존)
     → FinalizingOutputs → PromotionPending? → GCEligible/Retained
```

### 3.3 AH 클라이언트 (`pkg/ahclient/`)

신규 패키지. 통합 설계 v0.7 §13의 5개 RPC를 클라이언트로 구현:

```text
pkg/ahclient/
├── client.go              # Client interface
├── grpc.go                # gRPC 구현 (real AH)
├── stub.go                # in-process stub (개발/테스트)
├── register.go            # RegisterArtifact wrapper
├── resolve.go             # ResolveHandoff wrapper
├── notify.go              # NotifyNodeTerminal wrapper
├── finalize.go            # FinalizeSampleRun wrapper
└── types.go               # Request/Response 도메인 타입
```

`ahclient.Client` 인터페이스를 통해 mock/stub/real을 교체 가능하게 한다.

### 3.4 Metrics 노출 (`pkg/metrics/`)

신규 패키지. 메트릭 계획 v2 §7의 32개 메트릭을 모두 정의:

```text
pkg/metrics/
├── metrics.go             # 모든 collector 정의
├── labels.go              # 허용 label set helper (forbidden 자동 차단)
├── timing.go              # Histogram timer helper
└── lifecycle.go           # phase별 duration 자동 측정
```

- `runId`, `sampleRunId` 등 forbidden label은 컴파일 타임 helper로 차단 (struct tag 검사)
- `/metrics` endpoint를 `pkg/api/service.go`에 추가

### 3.5 Provenance-ready hooks (`pkg/provenance/`)

신규 패키지. 통합 설계 v0.7 §19의 최소 hook:

```text
pkg/provenance/
├── digest.go              # parent output → artifactDigest 생성
├── manifest.go            # /out/_meta/artifacts.manifest.json 작성
├── binding_snapshot.go    # parent → child binding snapshot
└── correlation.go         # runId/sampleRunId/nodeId/attemptId/digest 표준 키
```

### 3.6 Cleanup tracker (`pkg/cleanup/`)

신규 패키지. cleanup debt와 delete lag 추적:

```text
pkg/cleanup/
├── tracker.go             # cleanup queue, backlog 추적
├── ratelimit.go           # delete burst rate limiter
└── backpressure.go        # cleanup_backlog_objects 임계값 시 신규 submit 일시 차단
```

### 3.7 Registry 확장 (`pkg/registry/memory.go`)

```text
- Sample-scoped index 추가: byRunID, bySampleRunID, byBatchGroupID
- ArtifactRecord 신규 entity (run-scoped artifact inventory)
- 기존 RunRecord/NodeRecord/AttemptRecord 유지
```

---

## 4. 스프린트 일정

기존 Sprint 1~5는 PoC 기반 core skeleton 단계로, 이미 진행 중이다. 본 문서는 통합 설계 v0.7과 메트릭 계획 v2를 반영한 **Sprint 6 ~ Sprint 11**을 새로 정의한다.

### 스프린트 J-6 — Spec 확장 + Phase 모델 + 메트릭 골격 (3주)

#### 목표

artifact-aware spec, phase 모델, kube-slint와 정합하는 메트릭 골격을 한 번에 잡는다.

#### 작업 항목

1. `pkg/spec/types.go`에 `ArtifactBinding`, `ConsumePolicy`, `RetentionClass` 타입 추가
2. `Node`에 `ArtifactBindings`, `RetentionClass`, `PromotionRequired` 필드 추가 (모두 optional)
3. `RunMetadata`에 `SampleRunID`, `PipelineID`, `BatchGroupID` 추가
4. `NodeStatus`에 7개 신규 phase 추가
5. `pkg/executor/executor.go`의 `nodeRunner`를 phase-aware state machine으로 재구성 (transition map만 먼저)
6. `pkg/metrics/` 패키지 신설, kube-slint K-1과 정합하는 32개 collector 정의
7. forbidden label 차단 helper 구현
8. `/metrics` endpoint를 gRPC 서버에 추가
9. `pkg/spec/validate.go`에 새 필드 validation 추가
10. backward compatibility 테스트: 기존 fixture가 새 spec으로도 동작

#### 완료 기준 (DoD)

- 기존 모든 dag_engine_*_test.go가 통과 (backward compat)
- `pkg/spec/types.go`에 `ArtifactBinding` 타입 정의 존재
- `NodeStatus` 7개 신규 phase 정의 존재
- `/metrics` endpoint가 32개 메트릭 모두 노출 (값은 0이어도 OK)
- forbidden label을 인자로 넘기면 panic/error (compile or runtime)
- kube-slint registry가 JUMI family를 인식 가능 (K-1 결과물과 cross-test)

#### 산출물

- `pkg/spec/types.go` v2
- `pkg/spec/validate.go` 갱신
- `pkg/metrics/*.go` 신설
- `pkg/executor/executor.go` 리팩토링 (phase machine만)
- `docs/JUMI_SPEC_V2_MIGRATION.ko.md`

#### 의존성

- **kube-slint K-1 완료** (메트릭 spec registry가 있어야 metric 이름 lock-in 가능)

#### 위험 (이 스프린트 내 관리)

- spec 변경이 외부 fixture를 깰 수 있음 → backward compat 테스트 필수
- phase 확장이 executor 리팩토링을 유발 → 이번 스프린트는 transition map만, 실제 hook은 J-7에서

---

### 스프린트 J-7 — AH 클라이언트 + 5개 hook 삽입 (3주)

#### 목표

통합 설계 v0.7 §12의 5개 hook (A~E)을 모두 main path에 삽입한다.

#### 작업 항목

1. `pkg/ahclient/` 패키지 신설
2. `Client` 인터페이스 정의: `RegisterArtifact`, `ResolveHandoff`, `NotifyNodeTerminal`, `FinalizeSampleRun`, `EvaluateGC`
3. `ahclient.Stub` 구현 (in-process, 개발 단계용)
4. `ahclient.GRPCClient` 구현 (real AH 호출용; AH Sprint 1, 2 완료 전에는 stub만 사용)
5. **Hook A** 삽입: parent node 성공 시 `RegisterArtifact` 호출 (executor.go의 nodeRunner.Run 끝부분)
6. **Hook B** 삽입: child submit 직전 `BuildingBindings → ResolvingInputs` 단계에서 `ResolveHandoff` 호출
7. **Hook C** 삽입: backend prepare 시 acquisition contract를 Pod spec에 반영 (init container envvar로 전달)
8. **Hook D** 삽입: node terminal 시 `NotifyNodeTerminal` 호출
9. **Hook E** 삽입: sample run finalize 시 `FinalizeSampleRun` 호출
10. resolve 실패 시 child가 backend prepare로 안 넘어가는 보장
11. 5개 hook 호출 메트릭 추가 (`jumi_resolving_inputs_*`, `jumi_finalizing_outputs_*`)
12. fan-in: 모든 parent의 RegisterArtifact 완료 후에만 ResolveHandoff 호출하도록 ordering 보장

#### 완료 기준 (DoD)

- ahclient.Stub 사용해서 단일 sample run의 5개 hook이 모두 호출됨
- Hook B 실패 시 backend prepare가 호출되지 않음 (fail-fast 보장)
- fan-in 시나리오 테스트: A,B → C에서 A,B 완료 후에만 C가 ResolveHandoff 받음
- 메트릭에 `jumi_resolving_inputs_started_total`이 sample run 수만큼 증가
- `jumi_finalizing_outputs_started_total`이 sample run 종료 수만큼 증가

#### 산출물

- `pkg/ahclient/` 신설
- `pkg/executor/executor.go` Hook 5개 삽입
- 통합 테스트: `pkg/executor/dag_engine_handoff_test.go` 신설
- `docs/JUMI_AH_HOOKS.ko.md`

#### 의존성

- **J-6 완료** (spec과 phase 모델)
- **AH Sprint 1, 2 완료** — real AH 호출 부분만. stub만 사용하면 J-7 자체는 AH 없이 진행 가능.

#### 위험 (이 스프린트 내 관리)

- AH가 늦으면 stub만으로 끝남 → real AH integration 검증은 AH Sprint 2 완료 후 별도 task
- fan-in race → J-7 안에서 명시적 ordering 보장 안 되면 J-11로 미룸

---

### 스프린트 J-8 — Placement + Acquisition Contract + Provenance hook (3주)

#### 목표

PreferredSameNode placement, init-container 기반 acquisition runtime, provenance-ready 최소 hook 삽입.

#### 작업 항목

1. `ResolveHandoffResponse.placementDecision`을 `pkg/backend/spawner_k8s.go`의 Pod spec 생성 시 nodeAffinity로 반영 (PreferredSameNode만)
2. `acquisitionPlans[]`를 init-container 환경변수로 직렬화 (envvar `AH_ACQUISITION_PLAN` JSON)
3. init-container 표준 이미지 정의 (`ah-acquisition-runtime:v1`) — fetch + verify + stage
4. acquisition 실패와 main computation 실패를 분리 (init-container 실패는 `AcquisitionFailed*` reason class로 기록)
5. `pkg/provenance/digest.go` 신설: parent output 종료 시 `artifactDigest` 자동 계산
6. `pkg/provenance/manifest.go` 신설: `/out/_meta/artifacts.manifest.json` 작성
7. `pkg/provenance/binding_snapshot.go`: parent→child binding snapshot 기록
8. `availabilityState` 필드를 ArtifactRecord에 추가 (`LOCAL_ONLY`, `CAS_SEALED`, `BOTH`, `DELETED`, `UNAVAILABLE`)
9. correlation key 표준화: 모든 log/event에 `runId/sampleRunId/nodeId/attemptId/artifactDigest` 포함
10. ResolveHandoffResponse에 `expectedDigest` 포함 보장

#### 완료 기준 (DoD)

- PreferredSameNode 시 child Pod이 parent와 동일 노드에 스케줄링되는 e2e 테스트 통과
- init-container가 fetch 실패 시 main container가 시작되지 않음
- parent output 종료 후 `artifactDigest`가 자동으로 ArtifactRecord에 저장됨
- `/out/_meta/artifacts.manifest.json`이 parent Pod의 emptyDir에 작성됨
- 모든 EventRecord에 correlation key 5개가 포함됨

#### 산출물

- `pkg/backend/spawner_k8s.go` 갱신 (nodeAffinity, init-container)
- `pkg/provenance/` 신설
- `pkg/registry/memory.go`에 `ArtifactRecord` 추가
- `docs/JUMI_PLACEMENT_AND_PROVENANCE.ko.md`

#### 의존성

- J-7 완료 (Hook A,B,C가 있어야 placement/acquisition 결과가 반영됨)
- AH Sprint 3 완료 (AH가 ResolveHandoffResponse에 placementDecision/acquisitionPlans/expectedDigest를 채워야 함)

#### 위험 (이 스프린트 내 관리)

- RequiredSameNode는 K8s scheduler 동작과 충돌 가능 → 본 스프린트는 PreferredSameNode만, RequiredSameNode는 J-11로 미룸
- init-container 이미지가 별도 빌드 필요 → 초기에는 ah-acquisition-runtime 대신 busybox + curl로 prototype

---

### 스프린트 J-9 — Retention class + GC hook + sampleRun 격리 (3주)

#### 목표

Retention class 4종 도입, GC 판정 권한 분리 (JUMI=graph 관점, AH=실제 실행), sample run 격리 강화.

#### 작업 항목

1. `RetentionClass` 4종 enum (`EphemeralIntermediate`, `FinalOutputToPromote`, `DiagnosticRetained`, `SharedReusableExplicit`)을 spec과 ArtifactRecord에 반영
2. `pkg/executor/executor.go` Hook D 강화: NotifyNodeTerminal에 `failFastPrunedDescendants`, `diagnosticRetentionRequested`, `promotionCandidates` 정확히 채움
3. `pkg/executor/executor.go` Hook E 강화: FinalizeSampleRun에 `retryRemaining`, `promotionConfirmed`, `debugRetentionUntil`, `releaseAllRunScopedLeases` 정확히 채움
4. JUMI가 graph 관점에서 "더 이상 consumer가 없다"를 정확히 계산하는 알고리즘 (downstream traversal + fail-fast pruned 고려)
5. `pkg/registry/memory.go` 확장: `bySampleRunID` 인덱스, sample run 종료 시 cross-sample 데이터 격리 보장
6. progressive GC 시나리오 테스트: A→B,C에서 B,C 완료 후 A intermediate가 GCEligible로 표시
7. failed sample retention 시나리오 테스트: 중간 실패 + retry 없음 → diagnostic만 남고 나머지 정리
8. promotion gate 시나리오 테스트: FinalOutputToPromote는 promotion 확인 전 GCEligible 안 됨
9. multi-sample 격리 테스트: 100 sample 시뮬레이션에서 sample A의 정리가 sample B에 영향 없음

#### 완료 기준 (DoD)

- 4종 retention class가 spec/registry/AH 호출 모두에서 일관되게 사용됨
- 통합 설계 v0.7 §22.2의 Case F (Progressive GC), G (Failed sample retention), H (Promotion gate), I (Multi-sample isolation) 통합 테스트 모두 통과
- `bySampleRunID` 인덱스 동작
- 메트릭 `jumi_gc_evaluations_total`, `jumi_gc_delete_requests_total`, `jumi_gc_delete_lag_seconds`가 정확한 값을 가짐

#### 산출물

- `pkg/spec/types.go` 갱신 (RetentionClass)
- `pkg/executor/executor.go` Hook D,E 강화
- `pkg/registry/memory.go` 갱신
- `pkg/executor/dag_engine_gc_test.go` 신설
- `docs/JUMI_RETENTION_AND_GC.ko.md`

#### 의존성

- J-8 완료
- AH Sprint 4 완료 (AH가 EvaluateGCResponse를 정상 반환해야 함)

#### 위험 (이 스프린트 내 관리)

- "graph 관점에서 consumer 없음" 계산이 잘못되면 unsafe delete 발생 → 본 스프린트의 통합 테스트가 가장 중요
- multi-sample 격리가 약하면 production에서 사고 → namespace 격리를 코드로 강제 (test fixture)

---

### 스프린트 J-10 — Cleanup debt 추적 + backpressure + observability 강화 (2주)

#### 목표

cleanup debt 추적, delete burst 발생 시 신규 submit 일시 차단, kube-slint K-3 cardinality lint 통합.

#### 작업 항목

1. `pkg/cleanup/` 패키지 신설
2. `tracker.go`: cleanup queue, backlog 카운트, age 추적
3. `ratelimit.go`: delete request rate limiter (token bucket)
4. `backpressure.go`: `cleanup_backlog_objects` > threshold 시 신규 SubmitRun을 503으로 거절
5. 메트릭 추가: `jumi_cleanup_backlog_objects`, `jumi_cleanup_backlog_seconds`, `jumi_delete_lag_seconds{resource_kind}`
6. 메트릭 추가: `jumi_fast_fail_cascade_size` (cascade 한 번에 몇 개가 cancel되는지)
7. cleanup debt 시나리오 테스트: fast-fail cascade 시뮬레이션에서 backlog가 정확히 카운트되고 회복됨
8. kube-slint K-3 cardinality lint를 CI에서 실행: forbidden label 누설 시 PR 차단
9. `slint-gate` integration: JUMI repo의 `.slint/policy.yaml`로 PR 단위 gate 평가
10. `docs/PROGRESS_LOG.md` 신설 (kube-slint 패턴 차용)

#### 완료 기준 (DoD)

- fast-fail cascade 1000개 시뮬레이션에서 cleanup backlog가 정확히 1000으로 표시되고 0으로 회복
- backpressure 임계값 도달 시 SubmitRun이 503 반환
- CI에서 cardinality lint 동작
- `slint-gate`가 JUMI 메트릭으로 PASS 결과 반환

#### 산출물

- `pkg/cleanup/` 신설
- `.slint/policy.yaml` JUMI 버전 작성
- `hack/run-slint-gate.sh` 신설 (kube-slint 패턴)
- `Tiltfile` 신설 (kind + ko + Tilt)
- `docs/PROGRESS_LOG.md` 신설
- `.github/workflows/slint-gate.yml` 추가

#### 의존성

- J-9 완료
- kube-slint K-3 완료 (cardinality lint, environment profile)

#### 위험 (이 스프린트 내 관리)

- backpressure가 너무 엄격하면 정상 운영 차단 → threshold를 환경별 (kind 낮음, multipass 보통, dev space 높음)로 분리

---

### 스프린트 J-11 — fan-in source priority + RequiredSameNode + nightly fixture (2주)

#### 목표

남은 열린 질문 처리, nightly 회귀 검증 fixture 작성.

#### 작업 항목

1. fan-in 다중 parent에서 source priority 계산 (binding 단위 우선순위)
2. `RequiredSameNode` placement 도입 (J-8에서 미룬 것)
3. wrapper entrypoint vs init-container 비교 fixture
4. nightly fixture 작성: 100 sample 동시 실행, fast-fail 섞기, delete storm 유도
5. kube-slint K-4 nightly workflow에 JUMI fixture 등록
6. multipass-k8s-vm e2e 테스트 추가
7. dev space history baseline 7일치 누적 후 회귀 비교 테스트

#### 완료 기준 (DoD)

- fan-in 시나리오 e2e 테스트 통과
- RequiredSameNode 시 child가 다른 노드에 있으면 fail-fast 동작
- nightly fixture가 multipass-k8s-vm에서 동작
- kube-slint K-5의 distribution regression이 JUMI 7일치 데이터로 동작

#### 산출물

- nightly fixture 코드와 시나리오 문서
- `test/e2e/multipass/` 신설
- `docs/JUMI_NIGHTLY_FIXTURES.ko.md`

#### 의존성

- J-10 완료
- kube-slint K-4, K-5 완료 (nightly + distribution regression)

---

## 5. 의존성 그래프 (kube-slint, AH와의)

```text
[기존 Sprint 1~5]  PoC 기반 core skeleton — 진행 중
        │
        ▼
[J-6] Spec + Phase + Metrics    ← kube-slint K-1 필요
        │
        ▼
[J-7] AH client + 5 hooks       ← AH Sprint 1, 2 필요
        │
        ▼
[J-8] Placement + Provenance    ← AH Sprint 3 필요
        │
        ▼
[J-9] Retention + GC            ← AH Sprint 4 필요
        │
        ▼
[J-10] Cleanup debt + lint      ← kube-slint K-3 필요
        │
        ▼
[J-11] fan-in + nightly         ← kube-slint K-4, K-5 필요
```

**가장 위험한 경로**: J-7이 AH Sprint 1, 2를 기다리는 부분. AH가 늦으면 stub만으로는 검증 못 하는 게 많다 (실제 placement 결정, real fallback 등). 따라서 AH Sprint 1, 2는 **kube-slint K-2와 동시에**, JUMI J-6과도 일부 겹쳐 시작해야 한다.

---

## 6. 운영 체크리스트 (각 스프린트 마지막에 확인)

- [ ] 기존 dag_engine_*_test.go가 모두 PASS
- [ ] backward compatibility: 기존 fixture가 새 spec으로도 동작
- [ ] 신규 메트릭이 forbidden label 누설 없이 정확히 노출
- [ ] AH stub과 real AH 모두에서 hook이 동작
- [ ] sample run 격리: cross-sample 누설 없음
- [ ] cleanup debt가 fast-fail cascade 후 정상 회복
- [ ] PROGRESS_LOG.md 갱신
- [ ] kube-slint gate가 PR 단위로 PASS

---

## 7. 결론

JUMI는 PoC 기반 Sprint 1~5로 core skeleton을 어느 정도 잡았지만, **artifact-aware binding, lifecycle phase, AH integration, metrics, GC, provenance hook**이 모두 비어 있다. 본 문서의 J-6 ~ J-11을 통해 통합 설계 v0.7과 메트릭 계획 v2가 요구하는 모든 요건을 만족한다.

가장 중요한 원칙 두 가지:

1. **kube-slint K-1, K-2 완료 전에는 JUMI Sprint 6을 시작하지 않는다** (메트릭 이름 lock-in 필요).
2. **AH Sprint 1, 2 완료 전에는 JUMI Sprint 7의 real AH integration을 진행하지 않는다** (stub로만 진행).

이 두 의존성을 지키면 JUMI는 통합 설계 v0.7의 모든 hook, lifecycle, GC, provenance 요건을 7~8개월 안에 완성할 수 있다.

---

## 부록 A. 신규 spec 타입 정의 초안

```go
// pkg/spec/types.go에 추가될 타입

type ConsumePolicy string

const (
    ConsumePolicySameNodeOnly       ConsumePolicy = "SameNodeOnly"
    ConsumePolicySameNodeThenRemote ConsumePolicy = "SameNodeThenRemote"
    ConsumePolicyRemoteOK           ConsumePolicy = "RemoteOK"
)

type RetentionClass string

const (
    RetentionEphemeralIntermediate   RetentionClass = "EphemeralIntermediate"
    RetentionFinalOutputToPromote    RetentionClass = "FinalOutputToPromote"
    RetentionDiagnosticRetained      RetentionClass = "DiagnosticRetained"
    RetentionSharedReusableExplicit  RetentionClass = "SharedReusableExplicit"
)

type ArtifactBinding struct {
    BindingName        string         `json:"bindingName"`
    ChildInputName     string         `json:"childInputName"`
    ProducerNodeID     string         `json:"producerNodeId"`
    ProducerOutputName string         `json:"producerOutputName"`
    ArtifactID         string         `json:"artifactId,omitempty"`
    Required           bool           `json:"required"`
    ConsumePolicy      ConsumePolicy  `json:"consumePolicy"`
    ExpectedDigest     string         `json:"expectedDigest,omitempty"`
    SizeHint           int64          `json:"sizeHint,omitempty"`
}

type AvailabilityState string

const (
    AvailabilityLocalOnly  AvailabilityState = "LOCAL_ONLY"
    AvailabilityCASSealed  AvailabilityState = "CAS_SEALED"
    AvailabilityBoth       AvailabilityState = "BOTH"
    AvailabilityDeleted    AvailabilityState = "DELETED"
    AvailabilityUnavailable AvailabilityState = "UNAVAILABLE"
)

type ArtifactRecord struct {
    ArtifactID         string             `json:"artifactId"`
    Digest             string             `json:"digest"`
    RunID              string             `json:"runId"`
    SampleRunID        string             `json:"sampleRunId,omitempty"`
    ParentNodeID       string             `json:"parentNodeId"`
    ProducerPodRef     string             `json:"producerPodRef,omitempty"`
    ProducerNode       string             `json:"producerNode,omitempty"`
    ProducerAddress    string             `json:"producerAddress,omitempty"`
    BackendRef         string             `json:"backendRef,omitempty"`
    Size               int64              `json:"size,omitempty"`
    AvailabilityState  AvailabilityState  `json:"availabilityState"`
    RetentionClass     RetentionClass     `json:"retentionClass,omitempty"`
    PromotionRequired  bool               `json:"promotionRequired,omitempty"`
    PromotionConfirmed bool               `json:"promotionConfirmed,omitempty"`
    LeaseTokens        []string           `json:"leaseTokens,omitempty"`
    CreatedAt          time.Time          `json:"createdAt"`
}
```

## 부록 B. AH 호출 시퀀스 다이어그램 (텍스트)

```text
JUMI                                     AH
  │                                       │
  │ Parent Node 성공                      │
  ├── RegisterArtifact ─────────────────▶ │  (Hook A)
  │                                       │
  │ Child dependency 만족                 │
  │ BuildingBindings 완료                 │
  ├── ResolveHandoff ───────────────────▶ │  (Hook B)
  │ ◀──── ResolveHandoffResponse ──────── │
  │                                       │
  │ Pod spec에 acquisition contract 반영  │  (Hook C, JUMI 내부)
  │                                       │
  │ Child Node 실행 (init-container fetch)│
  │ Child Node 종료                       │
  ├── NotifyNodeTerminal ───────────────▶ │  (Hook D)
  │                                       │
  │ Sample Run 종료                       │
  ├── FinalizeSampleRun ────────────────▶ │  (Hook E)
  │ ◀── EvaluateGCResponse ────────────── │
  │                                       │
  │ AH가 GC 실행                          │
```

## 부록 C. 관련 문서

- `JUMI_AH_Integration_Design_ko v0.7`
- `JUMI_AH_kube_slint_metrics_churn_dev_plan_ko v2`
- `kube-slint 개발 문서 v1.0`
- `JUMI-main/docs/JUMI_DESIGN.ko.md`
- `JUMI-main/docs/JUMI_FINAL_DEVELOPMENT_GOAL.ko.md`
- `JUMI-main/docs/JUMI_SPRINT_PLAN.ko.md` (Sprint 1~5)
- `JUMI-main/docs/JUMI_STATE_TRANSITION_SPEC.ko.md`
- `JUMI-main/docs/JUMI_GRPC_CONTRACT_DRAFT.ko.md`
- `JUMI-main/docs/JUMI_EXECUTABLE_RUN_SPEC_DRAFT.ko.md`
- `JUMI-main/docs/JUMI_CANCEL_FAILURE_RETRY_SEMANTICS.ko.md`
