# AH (artifact-handoff) 최종 개발 문서 v1.0 — Resolver Service from Scratch

> 작성일: 2026-04-21
> 기준 입력:
> - `JUMI_AH_Integration_Design_ko v0.7` (2026-04-20)
> - `JUMI_AH_kube_slint_metrics_churn_dev_plan_ko v2` (2026-04-20)
> - `kube-slint 개발 문서 v1.0` (2026-04-21)
> - `JUMI 최종 개발 문서 v1.0` (2026-04-21)
> - `artifact-handoff-main` 저장소 현황 (문서 9종 + 코드 0줄에 가까움)
> 목적: AH를 통합 설계 v0.7이 명시한 **long-lived resolver service** 형태로 처음부터 구현하기 위한 개발 기준선과 스프린트 일정을 고정한다. CRD-heavy controller 경로는 의도적으로 회피한다.

---

## 0. 한 줄 요약

AH는 controller가 아니라 **resolver service**다. JUMI가 호출하는 5개 RPC (`RegisterArtifact`, `ResolveHandoff`, `NotifyNodeTerminal`, `FinalizeSampleRun`, `EvaluateGC`)를 long-lived gRPC 서비스로 제공하고, artifact inventory + lease + retention/GC executor 역할을 수행한다. Dragonfly는 마지막 스프린트에서 얇은 backend adapter로만 붙는다.

---

## 1. 현재 상태 진단

### 1.1 잘 잡혀 있는 것

- **포괄적 설계 문서**: 9개 문서가 한국어/영어 쌍으로 모두 작성되어 있다 (`PRODUCT_IMPLEMENTATION_DESIGN`, `ARCHITECTURE`, `DOMAIN_MODEL`, `API_OBJECT_MODEL`, `STATE_AND_STATUS_MODEL`, `PLACEMENT_AND_FALLBACK_POLICY`, `RETRY_AND_RECOVERY_POLICY`, `OBSERVABILITY_MODEL`, `CRD_INTRODUCTION_STRATEGY`, `DRAGONFLY_ADAPTER_SPEC`).
- **Domain 의미 분리 의식**: `DOMAIN_MODEL.ko.md`가 `Artifact`, `ArtifactBinding`, `ConsumePolicy`, `PlacementIntent`, `ResolvedPlacement`, `Replica`, `BackendRef`, `FailureRecord`로 핵심 엔터티를 8개로 명확히 정의했다.
- **PoC truth 문서화**: `PRODUCT_IMPLEMENTATION_DESIGN.ko.md` §2에 PoC가 검증한 9개 사실이 명시되어 있고 어디까지가 fixed input인지 분명하다.
- **Dragonfly 종속 회피 의식**: `DRAGONFLY_ADAPTER_SPEC.ko.md`가 Dragonfly를 "replaceable backend adapter"로 명시.
- **Placement vs Acquisition 분리 의식**: `PLACEMENT_AND_FALLBACK_POLICY.ko.md`에서 둘을 명시적으로 분리.

### 1.2 부족한 부분 (Critical: 코드가 거의 없음)

#### F1. 코드 자체가 비어 있음 (Most Critical)

```text
cmd/artifact-handoff-controller/main.go : 7줄 (println 한 줄)
go.mod                                  : 4줄
```

전체 코드량 **0줄에 가까움**. 도메인 모델은 문서로만 존재하고 Go 타입으로 표현되지 않았다. 통합 설계 v0.7 §13의 5개 RPC도 proto 정의조차 없다.

#### F2. 프로젝트 이름과 설계 방향 불일치 (High)

`cmd/artifact-handoff-**controller**/main.go` — 이름이 controller인데 통합 설계 v0.7은 명시적으로 "controller가 아니라 resolver service"로 가야 한다고 했다 (§5.4, §6.2). 이 이름 자체가 잘못된 신호를 줄 수 있다.

**수정 필요**: `cmd/artifact-handoff-resolver/main.go`로 디렉토리 이름 변경.

#### F3. 통합 설계 v0.7 반영 부재

기존 9개 문서는 v0.7 통합 설계 이전에 작성되었다. v0.7이 새로 도입한 다음 개념이 기존 AH 문서에 반영되지 않았다:

- **lifecycle / retention / GC** (v0.7 §15)
- **provenance-ready 최소 hook** (v0.7 §19)
- **sample run 단위 격리** (v0.7 §15.2)
- **manifest와 digest commit 분리** (v0.7 §19.2.6)
- **churn taxonomy 7축** (v0.7 §7.1)

기존 문서는 handoff resolution까지만 다루고 lifecycle/GC는 다루지 않는다. 통합 설계 v0.7은 lifecycle을 제품 의미론에 포함시켰다.

#### F4. Resolver service vs CRD controller 결론 모호

`CRD_INTRODUCTION_STRATEGY.ko.md`가 존재한다. 통합 설계 v0.7 §5.4는 명시적으로 "per-artifact / per-binding / per-handoff CRD 경로는 기준선에서 제외"라고 했다. 기존 CRD strategy 문서를 v0.7 기준으로 다시 정리해야 한다.

#### F5. State 모델이 lifecycle/GC 까지 안 다룸

`STATE_AND_STATUS_MODEL.ko.md`는 artifact 상태 모델은 정의하지만, `PromotionPending`, `PromotionConfirmed`, `GCEligible`, `Retained`, `Deleted` 같은 v0.7 §16.1의 lifecycle 상태가 빠져 있다.

#### F6. Backend abstraction 인터페이스 미정의

문서로만 "backend adapter"가 있고, Go 인터페이스 정의가 없다. 통합 설계 v0.7 §20.2가 제시한 다음 surface가 코드로 표현되지 않음:

```text
BackendAdapter
- PutArtifact(...)
- StatArtifact(...)
- EnsureOnNode(...)
- WarmArtifact(...)
- EvictArtifact(...)
```

#### F7. Lease/Pin 모델 설계 부재

v0.7 §4.20의 `Lease / Pin` 개념이 기존 AH 문서에 거의 없다. lease 발급/해제, lease 만료, lease가 GC를 막는 메커니즘을 새로 설계해야 한다.

#### F8. Metrics 노출 인터페이스 부재

`OBSERVABILITY_MODEL.ko.md`는 있지만 메트릭 계획 v2 §8의 27개 메트릭이 모두 매핑되어 있지 않다. AH 자체 코드가 없으니 `/metrics` endpoint도 없다.

#### F9. JUMI ↔ AH gRPC contract 미정

통합 설계 v0.7 §13의 5개 Request/Response가 proto 정의로 안 되어 있다. JUMI Sprint 7과의 integration이 막힌다.

### 1.3 위험성

#### R1. Greenfield인 만큼 잘못된 첫 결정의 비용이 큼 (Critical)

코드가 없으니 자유롭지만, 동시에 잘못된 첫 결정 (예: per-artifact CRD를 만들기 시작)이 매우 빠르게 굳을 수 있다.

**완화**: Sprint A-1에서 통합 설계 v0.7의 "AH 권장 형태" (resolver service)를 명시적으로 코드 구조로 박는다. CRD 디렉토리는 만들지 않는다.

#### R2. JUMI Sprint 7이 AH Sprint 1, 2를 기다림 (Critical 의존성)

JUMI가 hook을 삽입하려면 AH의 5개 RPC가 동작해야 한다. AH가 늦으면 JUMI는 stub으로만 진행해야 하고, real integration 검증은 AH 완료까지 미뤄진다.

**완화**: AH Sprint 1, 2를 kube-slint K-2와 동시에 시작한다. AH Sprint 1에서는 in-memory 구현으로 5개 RPC를 모두 응답 가능하게 만든다 (placement 결정은 단순 hard-coded라도 OK).

#### R3. Dragonfly가 product semantics를 끌고 가는 위험 (High)

문서가 의식하고는 있지만, 코드로 backend adapter 경계가 없는 상태에서 Dragonfly 통합이 시작되면 의미론이 backend로 흘러갈 위험이 매우 높다.

**완화**: Sprint A-6에서야 Dragonfly adapter 도입. 그 전 모든 스프린트는 simple non-Dragonfly backend (HTTP fetch + local FS) 만으로 진행.

#### R4. Lifecycle 모델 누락이 v0.7 통합 어려움을 만듬 (High)

기존 AH 문서가 handoff까지만 다루고 lifecycle/GC가 없으니, 코드를 짜기 시작하면 또 다른 문서 (LIFECYCLE_AND_GC.ko.md)를 추가해야 한다. 빠뜨리면 JUMI Hook D, E (NotifyNodeTerminal, FinalizeSampleRun)을 받을 자리가 없어진다.

**완화**: Sprint A-1에서 v0.7 §15, §19를 반영한 lifecycle 모델을 문서와 Go 타입으로 동시에 박는다.

#### R5. Resolver service의 high availability와 state durability 미정

resolver service가 단일 Pod로 죽으면 in-flight ResolveHandoff가 모두 사라진다. JUMI가 timeout으로 fail하고 cleanup debt가 쌓인다.

**완화**: Sprint A-3까지는 in-memory state로 진행하되, Sprint A-7에서 durable state store (etcd kv 또는 외부 metadata store) 도입을 별도 스프린트로.

#### R6. fan-in 다중 parent에서 source priority 결정 권한 충돌

JUMI Sprint 11도 fan-in을 다루고, AH도 source priority를 결정한다. 이 권한 분리가 명확하지 않으면 양쪽이 다른 결정을 내릴 수 있다.

**완화**: 통합 설계 v0.7 §9의 책임 분리를 코드로 정확히 반영. **JUMI는 binding 단위 우선순위 hint만 제공**, **AH가 최종 source priority 결정**. 이걸 Sprint A-2의 ResolveHandoffRequest/Response에서 명확히.

#### R7. Lease가 메모리에서만 관리되면 restart 후 GC 사고

resolver restart 후 lease 정보가 사라지면, 진행 중인 acquisition을 active consumer가 없다고 오판해서 artifact를 삭제할 위험.

**완화**: Sprint A-4에서 lease 만료 grace period를 길게 (예: 30분), 그리고 restart 시 모든 lease를 일정 시간 retain.

#### R8. acquisition runtime (init-container)의 책임 누설

JUMI가 init-container를 띄우는데, init-container 코드는 AH가 책임지는지 JUMI가 책임지는지 모호. 둘이 같이 만들면 발산.

**완화**: AH가 표준 acquisition runtime 이미지 (`ah-acquisition-runtime:v1`)를 빌드/배포하는 owner. JUMI는 그 이미지를 init-container로 spec에 추가만. Sprint A-3에서 표준 이미지 정의.

#### R9. churn taxonomy의 7축 모두를 AH가 만들어낼 수 있음

AH가 reconcile-style로 가면 API/watch/etcd churn이 폭증. 통합 설계 v0.7 §7이 가장 강조하는 안티패턴.

**완화**: 모든 스프린트에서 "Kubernetes object를 추가로 만들지 않는가"를 PR 체크리스트로. Sprint A-5에서 metric으로 자체 churn 모니터링.

### 1.4 보완해야 할 것 — 우선순위 요약

| 우선순위 | 항목 | 관련 부족·위험 | 다루는 스프린트 |
|---|---|---|---|
| P0 | 코드 골격 + 문서 v0.7 정렬 | F1, F3, F4, F5, R1 | A-1 |
| P0 | gRPC proto + 5개 RPC in-memory 구현 | F9, R2 | A-2 |
| P0 | Backend abstraction 인터페이스 | F6 | A-2 |
| P1 | Resolve 알고리즘 + lifecycle/GC | F5, R4, R6 | A-3 |
| P1 | Lease 관리 + acquisition runtime | F7, R7, R8 | A-4 |
| P2 | Metrics 노출 + churn 자체 모니터링 | F8, R9 | A-5 |
| P2 | Dragonfly adapter | R3 | A-6 |
| P3 | Durable state store | R5 | A-7 |

---

## 2. 개발 목표 및 비목표

### 2.1 목표

1. AH를 long-lived gRPC resolver service로 구현 (Deployment + Service)
2. 통합 설계 v0.7 §13의 5개 RPC를 모두 지원
3. Placement/Acquisition 분리 + product-owned source priority
4. Lifecycle / Retention / GC를 sample run 단위로 안전하게 수행
5. Backend adapter 인터페이스 + simple HTTP backend 구현
6. Dragonfly adapter는 마지막에 얇은 wrapper로
7. 메트릭 계획 v2 §8의 27개 메트릭을 모두 노출
8. JUMI Sprint 7과 cross-test 통과

### 2.2 비목표

- per-artifact / per-binding / per-handoff CRD 도입
- DAG 자체 해석 (JUMI 권한)
- child submit 타이밍 결정 (JUMI 권한)
- multi-cluster handoff
- 비용 최적화 알고리즘 전체

---

## 3. 아키텍처 변경 요점

### 3.1 디렉토리 구조 (greenfield)

```text
artifact-handoff/
├── cmd/
│   └── artifact-handoff-resolver/    # controller가 아닌 resolver
│       └── main.go
├── api/
│   └── proto/                        # gRPC proto 정의
│       └── ah_v1.proto
├── pkg/
│   ├── domain/                       # 도메인 타입 (DOMAIN_MODEL 코드화)
│   │   ├── artifact.go
│   │   ├── binding.go
│   │   ├── policy.go
│   │   ├── placement.go
│   │   ├── lease.go                  # 신규 (v0.7 §4.20)
│   │   └── retention.go              # 신규 (v0.7 §15.3)
│   ├── resolver/                     # 5개 RPC 구현
│   │   ├── server.go                 # gRPC server
│   │   ├── register.go               # RegisterArtifact
│   │   ├── resolve.go                # ResolveHandoff
│   │   ├── notify.go                 # NotifyNodeTerminal
│   │   ├── finalize.go               # FinalizeSampleRun
│   │   └── gc.go                     # EvaluateGC
│   ├── inventory/                    # artifact inventory + lease
│   │   ├── store.go                  # interface
│   │   ├── memory.go                 # in-memory 구현
│   │   └── lease.go                  # lease 관리
│   ├── strategy/                     # placement/acquisition 결정 알고리즘
│   │   ├── placement.go
│   │   ├── acquisition.go
│   │   └── source_priority.go
│   ├── lifecycle/                    # GC 판정/실행
│   │   ├── evaluator.go              # GC eligibility 계산
│   │   └── executor.go               # 실제 delete/evict
│   ├── backend/                      # backend adapter
│   │   ├── adapter.go                # interface
│   │   ├── http.go                   # simple HTTP backend
│   │   └── dragonfly.go              # 마지막 스프린트
│   ├── runtime/                      # acquisition runtime 이미지
│   │   └── (Dockerfile + entrypoint)
│   ├── metrics/                      # /metrics endpoint
│   │   ├── metrics.go
│   │   └── labels.go
│   └── churn/                        # 자체 churn 모니터링
│       └── tracker.go
├── docs/                             # 기존 9개 문서 + v0.7 정렬 추가
│   ├── (기존 9개)
│   ├── LIFECYCLE_AND_GC.ko.md       # 신규
│   ├── PROVENANCE_READY_HOOKS.ko.md # 신규
│   └── PROGRESS_LOG.md              # 신규
└── test/
    ├── e2e/
    └── consumer-onboarding/
        └── jumi-fixture/
```

### 3.2 핵심 설계 원칙

다음 원칙을 코드 PR 체크리스트로 박는다:

1. **모든 새 파일은 controller-runtime을 import하지 않는다.** AH는 controller가 아니다.
2. **Kubernetes API object를 새로 만들지 않는다.** lease, retention, GC 모두 in-memory 또는 외부 metadata store로.
3. **Backend adapter는 product semantics를 import하지 않는다.** 한 방향 의존 (`pkg/strategy` → `pkg/backend`만 허용).
4. **Public API에 backend-specific 타입 (Dragonfly task ID 등)이 누설되지 않는다.**
5. **모든 metric label은 `pkg/metrics/labels.go`의 allowed list만 사용 가능 (compile-time 강제).**
6. **모든 gRPC RPC는 idempotent.** retry 가능해야 함.
7. **resolver는 stateless하게 시작.** state store는 후속 스프린트.

---

## 4. 스프린트 일정

### 스프린트 A-1 — 코드 골격 + v0.7 문서 정렬 (2주)

#### 목표

빈 저장소를 v0.7 정합 코드 골격으로 채우고, 기존 9개 문서를 v0.7 기준으로 정렬한다.

#### 작업 항목

1. `cmd/artifact-handoff-controller/` → `cmd/artifact-handoff-resolver/`로 디렉토리 이름 변경
2. `pkg/domain/` 타입 정의: `Artifact`, `ArtifactBinding`, `ConsumePolicy`, `PlacementIntent`, `ResolvedPlacement`, `Replica`, `BackendRef`, `FailureRecord` (DOMAIN_MODEL.ko.md 코드화)
3. `pkg/domain/lease.go`: `Lease`, `LeaseToken` 타입 (v0.7 §4.20 신규)
4. `pkg/domain/retention.go`: `RetentionClass` 4종 enum (v0.7 §15.3)
5. `pkg/domain/availability.go`: `AvailabilityState` 5종 (v0.7 §19.2.5)
6. `docs/LIFECYCLE_AND_GC.ko.md` 신규 작성: v0.7 §15 전체 반영
7. `docs/PROVENANCE_READY_HOOKS.ko.md` 신규 작성: v0.7 §19 전체 반영
8. 기존 `STATE_AND_STATUS_MODEL.ko.md` 갱신: lifecycle 상태 (`PromotionPending`, `PromotionConfirmed`, `GCEligible`, `Retained`, `Deleted`) 추가
9. 기존 `CRD_INTRODUCTION_STRATEGY.ko.md` 갱신: "기준선에서는 CRD를 만들지 않는다"로 명시
10. 기존 `OBSERVABILITY_MODEL.ko.md` 갱신: 메트릭 계획 v2 §8의 27개 메트릭 매핑
11. `go.mod` 정상 초기화 (`google.golang.org/grpc`, `github.com/prometheus/client_golang` 등 의존성)
12. `docs/PROGRESS_LOG.md` 신규 작성 (kube-slint 패턴)

#### 완료 기준 (DoD)

- 8개 도메인 타입이 Go 코드로 존재
- 신규 문서 2개 작성 완료
- 기존 문서 3개가 v0.7 기준으로 정렬
- `go build ./...` 통과 (구현 0이어도 컴파일 통과)
- CRD 디렉토리 부재 확인

#### 산출물

- `pkg/domain/*.go`
- `docs/LIFECYCLE_AND_GC.ko.md`
- `docs/PROVENANCE_READY_HOOKS.ko.md`
- 갱신된 기존 문서 3종
- `docs/PROGRESS_LOG.md`

#### 의존성

- 통합 설계 v0.7 (확정 상태)

#### 위험

- 기존 9개 문서 갱신이 시간 잡아먹기 → 핵심 3개만 우선 갱신, 나머지는 A-2에서

---

### 스프린트 A-2 — gRPC proto + 5개 RPC in-memory 구현 + Backend interface (3주)

#### 목표

JUMI가 호출할 5개 RPC를 in-memory로 모두 구현. Backend abstraction 인터페이스 정의. JUMI Sprint 7과 cross-test 가능 상태.

#### 작업 항목

1. `api/proto/ah_v1.proto` 작성: 통합 설계 v0.7 §13의 5개 Request/Response
2. proto 컴파일과 Go 코드 생성 (`buf` 또는 `protoc-gen-go`)
3. `pkg/inventory/store.go` interface, `pkg/inventory/memory.go` 구현
4. `pkg/backend/adapter.go`: `BackendAdapter` interface (v0.7 §20.2)
5. `pkg/backend/http.go`: simple HTTP backend 구현 (peer fetch 한정)
6. `pkg/resolver/server.go`: gRPC server 골격
7. `pkg/resolver/register.go`: `RegisterArtifact` 구현 (in-memory inventory에 저장)
8. `pkg/resolver/resolve.go`: `ResolveHandoff` 구현 (단순 알고리즘: same-node 가능하면 LocalReuse, 아니면 FetchProducer)
9. `pkg/resolver/notify.go`: `NotifyNodeTerminal` 구현 (lifecycle 상태만 갱신)
10. `pkg/resolver/finalize.go`: `FinalizeSampleRun` 구현 (sample run 종료 마킹)
11. `pkg/resolver/gc.go`: `EvaluateGC` 구현 (단순 candidate 목록 반환, 실제 delete는 A-3에서)
12. `cmd/artifact-handoff-resolver/main.go`: gRPC server 시작
13. JUMI 측 ahclient.GRPCClient와 cross-test (JUMI J-7과 동시 진행)

#### 완료 기준 (DoD)

- 5개 RPC 모두 grpcurl로 호출 가능
- in-memory inventory에 artifact registration 가능
- ResolveHandoff가 producerNode == childNode인 경우 LocalReuse 반환
- ResolveHandoff가 다른 경우 FetchProducer 반환
- JUMI ahclient.Stub 대신 real AH 호출이 동작
- proto 정의가 통합 설계 v0.7 §13의 모든 필드 포함

#### 산출물

- `api/proto/ah_v1.proto`
- `pkg/resolver/*.go` (5개 RPC)
- `pkg/inventory/memory.go`
- `pkg/backend/adapter.go`, `http.go`
- `cmd/artifact-handoff-resolver/main.go`
- `test/e2e/handoff_basic_test.go`

#### 의존성

- A-1 완료 (도메인 타입)
- **JUMI Sprint 6 동시 진행** (메트릭 이름 lock-in과 spec 정합)
- **kube-slint K-2 동시 진행** (multi-component summary)

#### 위험

- proto 정의가 JUMI와 안 맞을 위험 → A-1 끝나고 A-2 시작 전에 JUMI 팀과 proto 검토 회의 필수
- in-memory inventory가 restart 시 사라짐 → 의식적 한계로 두고 A-7에서 해결

---

### 스프린트 A-3 — Resolve 알고리즘 강화 + lifecycle/GC executor + acquisition runtime (3주)

#### 목표

Placement/Acquisition을 분리한 본격 알고리즘. GC executor가 실제 delete 수행. JUMI가 init-container로 받을 표준 acquisition runtime 이미지 빌드.

#### 작업 항목

1. `pkg/strategy/placement.go`: `consumePolicy` (`SameNodeOnly` | `SameNodeThenRemote` | `RemoteOK`) 별 placement intent 계산
2. `pkg/strategy/acquisition.go`: placement에 맞는 acquisition mode 계산 (LocalReuse | FetchProducer | FetchReplica | EnsureBackend)
3. `pkg/strategy/source_priority.go`: producer / replica / backend 우선순위 계산
4. `pkg/lifecycle/evaluator.go`: GC eligibility 계산 (v0.7 §15.5의 6개 조건 모두)
5. `pkg/lifecycle/executor.go`: 실제 delete (HTTP backend 호출 또는 직접 file delete)
6. progressive GC: NotifyNodeTerminal 시 graph 관점 consumer 종료 신호 처리
7. failed sample retention: FinalizeSampleRun이 `terminalState=Failed`일 때 EphemeralIntermediate만 정리
8. promotion gate: FinalOutputToPromote는 `promotionConfirmed=true`까지 GCEligible 안 됨
9. `pkg/runtime/`에 acquisition runtime Dockerfile + entrypoint script 작성
10. 표준 이미지 `ah-acquisition-runtime:v1` 빌드 및 registry push (또는 local image)
11. JUMI Sprint 8과 cross-test (init-container fetch + verify + stage)

#### 완료 기준 (DoD)

- v0.7 §22.2의 Case A (Same-node), B (Same-node preferred + remote fallback), C (Replica), D (Integrity mismatch), E (Resolve failure) 통합 테스트 통과
- v0.7 §22.2의 Case F (Progressive GC), G (Failed sample retention), H (Promotion gate) 통합 테스트 통과
- acquisition runtime이 fetch + verify (digest 비교) + stage (마운트 경로에 파일 배치) 동작
- JUMI init-container가 ah-acquisition-runtime:v1을 사용해서 child Pod에 input 준비

#### 산출물

- `pkg/strategy/*.go`
- `pkg/lifecycle/*.go`
- `pkg/runtime/Dockerfile`, `entrypoint.sh`
- `test/e2e/lifecycle_test.go`
- `docs/AH_RESOLVE_ALGORITHM.ko.md`

#### 의존성

- A-2 완료
- JUMI J-8 진행 중 또는 완료

#### 위험

- digest 검증 알고리즘 선택 (sha256 vs merkle root) → v0.7 §24.1의 열린 질문 5번. 본 스프린트는 sha256 단일 파일만 지원, 디렉토리/manifest는 후속.
- acquisition runtime 이미지가 외부 registry 의존 → 처음에는 local kind/multipass 환경에서만 동작

---

### 스프린트 A-4 — Lease 관리 + retry + recovery (2주)

#### 목표

Lease 발급/해제/만료. acquisition 재시도와 fallback. resolver restart 시 lease 보존 정책.

#### 작업 항목

1. `pkg/inventory/lease.go`: lease 발급/해제/만료 관리
2. ResolveHandoffResponse에 `leaseToken` 포함
3. acquisition runtime이 종료 시 lease release RPC 호출 (또는 timeout)
4. lease가 있는 동안은 GC 차단 (v0.7 §15.5 조건 1)
5. `pkg/strategy/source_priority.go`에 retry 로직: producer fail → replica → backend
6. `RETRY_AND_RECOVERY_POLICY.ko.md` 갱신: v0.7 §17의 12개 failure taxonomy 반영
7. resolver restart 시 lease 정보 grace period (30분) 유지
8. integrity mismatch 시 quarantine state로 보냄 (delete 안 함, retained-for-investigation)
9. v0.7 §17.1의 12개 failure 모두 메트릭으로 카운트

#### 완료 기준 (DoD)

- lease 발급 후 GC 시도가 차단되는 테스트 통과
- producer fail 시 replica로 자동 fallback 통과
- resolver restart 후 lease 30분 동안 유지 통과
- 12개 failure category 메트릭이 노출

#### 산출물

- `pkg/inventory/lease.go`
- `pkg/strategy/source_priority.go` 갱신
- `docs/RETRY_AND_RECOVERY_POLICY.ko.md` 갱신

#### 의존성

- A-3 완료

#### 위험

- lease가 메모리에서만 관리되면 정합성 약함 → 30분 grace period로 mitigate, 진짜 해결은 A-7에서 durable store 도입 후

---

### 스프린트 A-5 — Metrics + 자체 churn 모니터링 (2주)

#### 목표

메트릭 계획 v2 §8의 27개 메트릭 모두 노출. AH가 만들어내는 churn을 자체 추적. kube-slint와 정합.

#### 작업 항목

1. `pkg/metrics/metrics.go`: 27개 collector 정의 (메트릭 계획 v2 §8 부록 A)
2. `pkg/metrics/labels.go`: forbidden label 차단 helper (kube-slint K-3 cardinality lint와 정합)
3. `/metrics` endpoint를 gRPC server에 noah-side로 추가
4. `pkg/churn/tracker.go`: AH 자체가 만들어내는 K8s API call, watch event, etcd write 추적 (v0.7 §7.1의 7축)
5. derived indicator 계산이 kube-slint 쪽으로 갈 수 있도록 raw metric 모두 노출 (AH는 raw만, derived는 kube-slint engine이)
6. `.slint/policy.yaml` AH 버전 작성
7. `Tiltfile` 작성 (kind + ko + Tilt)
8. `hack/run-slint-gate.sh` 작성
9. CI에서 slint-gate PR 단위 실행
10. cardinality lint를 CI에 통합

#### 완료 기준 (DoD)

- `/metrics` endpoint가 27개 메트릭 모두 노출 (값은 0이어도)
- forbidden label (`runId`, `sampleRunId` 등) 누설 시 컴파일 또는 런타임 차단
- kube-slint가 AH family를 인식하고 derived indicator 계산
- AH PR에서 slint-gate가 PASS 반환

#### 산출물

- `pkg/metrics/*.go`
- `pkg/churn/tracker.go`
- `.slint/policy.yaml`
- `Tiltfile`, `hack/run-slint-gate.sh`
- `.github/workflows/slint-gate.yml`

#### 의존성

- A-4 완료
- kube-slint K-3 완료 (cardinality lint)

#### 위험

- 자체 churn 추적이 또 다른 메트릭 폭증을 유발 → low-cardinality 원칙을 자체에도 적용 (자기 인식 churn은 종합 카운터 1개만)

---

### 스프린트 A-6 — Dragonfly adapter (2주)

#### 목표

Dragonfly를 backend adapter로 추가. Product semantics는 그대로 유지.

#### 작업 항목

1. `pkg/backend/dragonfly.go`: `BackendAdapter` 인터페이스 구현
2. Dragonfly task 생성, 조회, ensure-on-node, warm, evict 호출 wrapper
3. backend-specific identifier (Dragonfly task ID)는 `BackendRef` 안에만 보관, top-level domain에 누설 금지
4. `DRAGONFLY_ADAPTER_SPEC.ko.md` 갱신: v0.7 §20의 허용/금지 surface 명시
5. fallback semantics가 product layer (`pkg/strategy/source_priority.go`)에 그대로 남아 있는지 검증
6. lifecycle/GC 판단이 backend로 끌려가지 않는지 검증 (PR 체크리스트)
7. Dragonfly + HTTP backend 둘 중 골라서 사용 가능한 통합 테스트
8. v0.7 §22.2 Case B의 same-node preferred + Dragonfly remote fallback 테스트

#### 완료 기준 (DoD)

- Dragonfly adapter로 same fixture를 돌렸을 때 결과 (PASS 카운트, GC 동작)가 HTTP backend와 동일
- Public API에 Dragonfly task ID가 누설되지 않음
- placement decision은 항상 `pkg/strategy`에서 결정 (Dragonfly가 결정 안 함)

#### 산출물

- `pkg/backend/dragonfly.go`
- `docs/DRAGONFLY_ADAPTER_SPEC.ko.md` 갱신
- Dragonfly fixture e2e 테스트

#### 의존성

- A-5 완료
- Dragonfly cluster 또는 mock 가용

#### 위험

- Dragonfly가 placement까지 하고 싶어할 수 있음 → adapter 인터페이스가 placement 결과만 받고 placement 결정 권한은 노출 안 함으로 코드 강제

---

### 스프린트 A-7 — Durable state store + HA + nightly fixture (3주)

#### 목표

resolver state를 외부 store로 옮겨 restart-safe하게. HA 배포 가능. nightly long-run 회귀.

#### 작업 항목

1. `pkg/inventory/store.go` interface 다중 backend: in-memory, etcd-kv, postgres
2. `pkg/inventory/etcd.go` 구현
3. `pkg/inventory/postgres.go` 구현 (선택, 운영 환경에 따라)
4. resolver가 active-passive HA 가능 (leader election via lease)
5. `pkg/lifecycle/evaluator.go`가 store 변경 후에도 동일 결과
6. nightly fixture: 100 sample 동시 실행, fast-fail 섞기, delete burst, 7일 누적
7. kube-slint K-4 nightly workflow에 AH fixture 등록
8. multipass-k8s-vm e2e 테스트 추가
9. dev space history baseline 7일치 누적 후 회귀 비교

#### 완료 기준 (DoD)

- resolver Pod kill 후 다른 Pod이 leader로 인계, lease/inventory 보존
- nightly fixture가 multipass-k8s-vm에서 동작
- kube-slint distribution regression이 AH 7일치 데이터로 동작

#### 산출물

- `pkg/inventory/etcd.go`, `postgres.go`
- nightly fixture
- `test/e2e/multipass/`

#### 의존성

- A-6 완료
- kube-slint K-4, K-5 완료

#### 위험

- etcd/postgres 의존성이 운영 부담 증가 → 초기 production은 in-memory + 짧은 retention 으로 시작, store는 옵션화

---

## 5. 의존성 그래프 (kube-slint, JUMI와의)

```text
[A-1] 코드 골격 + v0.7 문서 정렬
        │
        ▼
[A-2] gRPC 5 RPC + Backend interface  ← JUMI J-6 동시, kube-slint K-2 동시
        │
        ▼
[A-3] Resolve + Lifecycle/GC + runtime ← JUMI J-7, J-8 진행 중
        │
        ▼
[A-4] Lease + retry/recovery
        │
        ▼
[A-5] Metrics + churn               ← kube-slint K-3 필요
        │
        ▼
[A-6] Dragonfly adapter
        │
        ▼
[A-7] Durable store + HA + nightly  ← kube-slint K-4, K-5 필요
```

**가장 위험한 경로**: A-1, A-2가 JUMI Sprint 6, 7과 동시 시작이라 두 팀이 같이 움직여야 한다. 한 쪽이 늦으면 cross-test가 막힌다.

---

## 6. PR 체크리스트 (모든 스프린트 공통)

- [ ] controller-runtime을 import하지 않는가
- [ ] Kubernetes API object를 새로 만들지 않는가
- [ ] Public API에 backend-specific 타입이 누설되지 않는가
- [ ] metric label에 forbidden 값이 없는가
- [ ] 모든 RPC가 idempotent한가
- [ ] placement 결정 권한이 product layer에 있는가 (backend 아님)
- [ ] lifecycle/GC 결정 권한이 product layer에 있는가
- [ ] PROGRESS_LOG.md가 갱신되었는가
- [ ] kube-slint gate가 PASS인가

---

## 7. 결론

AH는 코드가 사실상 비어 있고, 기존 9개 문서는 통합 설계 v0.7 이전이라 lifecycle/GC/provenance 부분이 빠져 있다. 본 문서의 A-1 ~ A-7은 이 빈 저장소를 v0.7 정합 resolver service로 만든다.

가장 중요한 두 가지:

1. **CRD 경로로 가지 않는다.** 모든 스프린트의 PR 체크리스트로 강제.
2. **JUMI Sprint 6, 7과 동시에 A-1, A-2를 진행한다.** AH가 늦으면 JUMI가 stub만으로 진행해야 하고 real integration이 막힌다.

이 두 원칙을 지키면 AH는 7~8개월 안에 simple HTTP backend + Dragonfly adapter + durable state store까지 갖춘 production-ready resolver service가 된다.

---

## 부록 A. 5개 RPC proto 초안

```protobuf
syntax = "proto3";

package ah.v1;

service ArtifactHandoff {
  rpc RegisterArtifact (RegisterArtifactRequest) returns (RegisterArtifactResponse);
  rpc ResolveHandoff (ResolveHandoffRequest) returns (ResolveHandoffResponse);
  rpc NotifyNodeTerminal (NotifyNodeTerminalRequest) returns (NotifyNodeTerminalResponse);
  rpc FinalizeSampleRun (FinalizeSampleRunRequest) returns (FinalizeSampleRunResponse);
  rpc EvaluateGC (EvaluateGCRequest) returns (EvaluateGCResponse);
}

message RegisterArtifactRequest {
  string run_id = 1;
  string sample_run_id = 2;
  string pipeline_id = 3;
  string parent_node_id = 4;
  string artifact_id = 5;
  string digest = 6;
  int64 size = 7;
  string producer_pod_ref = 8;
  string producer_task_ref = 9;
  string producer_node = 10;
  string producer_address = 11;
  string backend_ref = 12;
  string output_path = 13;
  string retention_class = 14;
  bool promotion_required = 15;
  map<string, string> metadata = 16;
}

message ResolveHandoffRequest {
  string run_id = 1;
  string sample_run_id = 2;
  string child_node_id = 3;
  repeated ArtifactBindingRequest artifact_bindings = 4;
  SchedulingHints scheduling_hints = 5;
  ClusterHints current_cluster_hints = 6;
  ChildRuntimeHints child_runtime_hints = 7;
}

message ArtifactBindingRequest {
  string binding_name = 1;
  string child_input_name = 2;
  bool required = 3;
  string producer_node_id = 4;
  string producer_output_name = 5;
  string artifact_id = 6;
  string consume_policy = 7;  // SameNodeOnly | SameNodeThenRemote | RemoteOK
  string expected_digest = 8;
  int64 size_hint = 9;
}

message ResolveHandoffResponse {
  PlacementDecision placement_decision = 1;
  repeated AcquisitionPlan acquisition_plans = 2;
  string handoff_summary = 3;
  string failure_if_unsatisfied = 4;
}

message PlacementDecision {
  string mode = 1;  // RequiredSameNode | PreferredSameNode | Unconstrained | SpecificNodeRequired
  string target_node = 2;
  repeated string node_affinity_hints = 3;
}

message AcquisitionPlan {
  string binding_name = 1;
  string mode = 2;  // LocalReuse | FetchProducer | FetchReplica | EnsureBackend
  string source_kind = 3;  // Producer | Replica | Backend
  string source_ref = 4;
  string verify_digest = 5;
  string mount_path = 6;
  string stage_path = 7;
  map<string, string> runtime_injection_hints = 8;
  string lease_token = 9;
}

message NotifyNodeTerminalRequest {
  string run_id = 1;
  string sample_run_id = 2;
  string node_id = 3;
  string terminal_state = 4;  // Succeeded | Failed | Cancelled
  bool retry_planned = 5;
  repeated string fail_fast_pruned_descendants = 6;
  bool diagnostic_retention_requested = 7;
  repeated string promotion_candidates = 8;
}

message NotifyNodeTerminalResponse {}

message FinalizeSampleRunRequest {
  string run_id = 1;
  string sample_run_id = 2;
  string terminal_state = 3;
  bool retry_remaining = 4;
  bool promotion_confirmed = 5;
  int64 debug_retention_until_unix = 6;
  bool release_all_run_scoped_leases = 7;
}

message FinalizeSampleRunResponse {}

message EvaluateGCRequest {
  string run_id = 1;
  string sample_run_id = 2;
}

message EvaluateGCResponse {
  repeated GCCandidate gc_candidates = 1;
  repeated RetainedArtifact retained = 2;
}

message GCCandidate {
  string artifact_id = 1;
  string reason = 2;  // NoMoreConsumers | RunFinalized | PromotionConfirmed | RetentionExpired
  string delete_action = 3;  // DeleteLocal | EvictBackend | KeepUntilTTL
}

message RetainedArtifact {
  string artifact_id = 1;
  string reason = 2;  // ActiveLease | RetryPending | DebugRetention | PromotionPending
}
```

## 부록 B. 관련 문서

- `JUMI_AH_Integration_Design_ko v0.7`
- `JUMI_AH_kube_slint_metrics_churn_dev_plan_ko v2`
- `kube-slint 개발 문서 v1.0`
- `JUMI 최종 개발 문서 v1.0`
- `artifact-handoff-main/docs/PRODUCT_IMPLEMENTATION_DESIGN.ko.md`
- `artifact-handoff-main/docs/ARCHITECTURE.ko.md`
- `artifact-handoff-main/docs/DOMAIN_MODEL.ko.md`
- `artifact-handoff-main/docs/PLACEMENT_AND_FALLBACK_POLICY.ko.md`
- `artifact-handoff-main/docs/RETRY_AND_RECOVERY_POLICY.ko.md`
- `artifact-handoff-main/docs/STATE_AND_STATUS_MODEL.ko.md`
- `artifact-handoff-main/docs/OBSERVABILITY_MODEL.ko.md`
- `artifact-handoff-main/docs/CRD_INTRODUCTION_STRATEGY.ko.md`
- `artifact-handoff-main/docs/DRAGONFLY_ADAPTER_SPEC.ko.md`
- `artifact-handoff-main/docs/API_OBJECT_MODEL.ko.md`
- `artifact-handoff-main/docs/DYNAMIC_PARENT_TO_CHILD_HANDOFF_GUIDE.ko.md`
