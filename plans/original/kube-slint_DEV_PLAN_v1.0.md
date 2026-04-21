# kube-slint 개발 문서 v1.0 — JUMI/AH-Aware Guardrail Framework

> 작성일: 2026-04-21
> 기준 입력:
> - `JUMI_AH_Integration_Design_ko v0.7` (2026-04-20)
> - `JUMI_AH_kube_slint_metrics_churn_dev_plan_ko v2` (2026-04-20)
> - `kube-slint-main` 저장소 현황 (Phase 6-c RC Approved 상태)
> - `hello-operator-main` canonical consumer fixture
> 목적: kube-slint를 hello-operator(controller-runtime) 중심 검증에서 **JUMI/AH(batch data-plane) 소비자도 1급으로 다루는 guardrail framework**로 확장하기 위한 개발 기준선과 스프린트 일정을 고정한다.

---

## 0. 한 줄 요약

kube-slint는 더 이상 controller-runtime 가정 위에서만 동작하면 안 된다. JUMI/AH가 만들어내는 **batch churn(API/watch/scheduler/etcd/data-plane)** 을 1급 입력으로 받아, `kind → multipass → dev space` 3단 루프에서 회귀를 자동 감시하는 가드레일 프레임워크가 되어야 한다.

---

## 1. 현재 상태 진단

### 1.1 잘 잡혀 있는 것

- **정체성 고정 완료**: `D-001`로 "shift-left operational quality guardrail" 정체성이 결정 로그에 명시되어 있다.
- **계측 분리 철학**: `D-002` (measurement failure ≠ test failure), `D-006` (guardrail evaluation ≠ correctness testing)가 합의되어 있다.
- **Library/harness 골격**: `pkg/slo/{spec,engine,fetch,summary,tags}` 구조가 안정화되어 있고, `pkg/slo/spec/registry.go`로 SLI 등록 모델이 잡혀 있다.
- **Canonical consumer fixture**: `hello-operator`로 소비자 DX 검증 경로 (`Tiltfile`, `hack/run-slint-gate.sh`, `.slint/policy.yaml`, `docs/baselines/hello-operator-sli-summary.json`) 가 실제 `PASS` 결과로 입증되어 있다.
- **CI 가시성**: `slint-gate.yml`, `roadmap-status.yml`, `bench.yml`, `test-e2e.yml` 워크플로우가 존재하고, `docs/project-status.yaml`이 자동화 단일 입력 (D-007)으로 고정되어 있다.
- **P4/P5 경계 규율**: `pkg/slo`는 P5(K8s 타입 누수 금지), `internal/`/`test/e2e/`는 P4로 격리되어 있어 의존성 변경에 강한 구조다.
- **Regression baseline lifecycle**: 생성/사용/부재/손상/갱신 경로가 모두 문서화되어 있고, `make baseline-update-prepare` helper도 존재한다.

### 1.2 부족한 부분

#### F1. controller-runtime 중심 가정에서 못 벗어남

현재 `pkg/slo/spec/spec.go`와 `docs/baselines/hello-operator-sli-summary.json` 기반으로 잡혀 있는 RC metric set은 `reconcile_total_delta`, `workqueue_depth_end` 두 개뿐이다 (`progress.md` 라인 70). 이는 controller-runtime 메트릭 계열에 종속된 모델이다.

JUMI/AH 통합 설계 문서 v0.7과 kube-slint 메트릭 계획 v2가 요구하는 다음 메트릭 계열은 **현재 spec registry에 일급으로 등록될 자리가 없다**:

- `jumi_jobs_created_total`, `jumi_fast_fail_trigger_total`, `jumi_cleanup_backlog_objects`
- `ah_resolve_requests_total`, `ah_fallback_total`, `ah_gc_backlog_bytes`, `ah_materialize_duration_seconds`
- 파생 지표: `fallback_ratio`, `same_node_hit_ratio`, `cleanup_debt`, `delete_storm_rate`

#### F2. derived indicator 계산 계층 부재

메트릭 계획 v2 §12.1의 공통 요약 항목 (`fallback_ratio`, `cleanup_backlog_objects`, `same_node_hit_ratio`, `delete_storm_rate` 등)을 **raw counter들로부터 계산하는 1급 엔진**이 `pkg/slo/engine/engine.go`에 없다. 현재 engine은 단일 SLI 값 평가에 가깝다.

#### F3. 환경 프로파일 분리 부재

메트릭 계획 v2 §11이 요구하는 `kind / multipass / devspace` 3개 프로파일 (`policy.kind.yaml`, `policy.multipass.yaml`, `policy.devspace.yaml`)에 대한 1급 지원이 없다. 현재는 `.slint/policy.yaml` 단일 진입점만 존재하고, 환경별 차이는 소비자 bridge script가 알아서 골라야 한다.

#### F4. low-cardinality lint/guard 부재

메트릭 계획 v2 §6.1, §13.5가 요구하는 "metric label cardinality 자동 점검" 기능이 없다. 현재는 문서·리뷰·소비자 자율에 의존한다. JUMI/AH는 `runId`, `sampleRunId`, `artifactDigest`, `podName` 같은 high-cardinality 값을 metric label로 누설할 위험이 매우 크다.

#### F5. multi-source/multi-fetcher 조합 부재

현재 `pkg/slo/fetch`는 `curlpod`, `inside`, `promtext` 정도다. JUMI/AH 환경에서는 한 번의 summary 계산에 다음을 동시에 읽어야 한다:
- JUMI `/metrics` 엔드포인트
- AH `/metrics` 엔드포인트
- Kubernetes apiserver `/metrics` (apiserver, scheduler, controller-manager, kube-state-metrics)
- (선택) etcd metrics

이를 한 fetcher session에서 묶어 처리하는 "multi-target observability profile"이 없다.

#### F6. summary schema가 단일 consumer 전제

현재 `pkg/slo/summary/schema.go`와 `docs/baselines/hello-operator-sli-summary.json`은 단일 operator 가정에 가깝다. JUMI와 AH는 같은 클러스터에서 함께 도는 두 컴포넌트라서 summary가 **multi-component** 구조를 자연스럽게 표현할 수 있어야 한다.

#### F7. Phase 6-c 회귀 비교가 numeric scalar에 머묾

현재 regression 비교는 `reconcile_total_delta`, `workqueue_depth_end` 같은 단일 숫자 비교에 가깝다. JUMI/AH는 `delete storm rate`, `cleanup debt 누적 추이`처럼 **time-window aggregated**, **distribution-based** (p95) 비교가 필요하다.

#### F8. nightly long-run loop 부재

메트릭 계획 v2 §15.4의 save/commit/nightly 매트릭스 중 **nightly 루프**에 해당하는 historical baseline 비교 자동화가 없다. 현재는 `slint-gate.yml`이 단일 실행 결과만 평가한다.

### 1.3 위험성

#### R1. JUMI/AH가 kube-slint를 안 쓰는 외길로 갈 수 있음 (Critical)

현재 kube-slint가 hello-operator만 검증한 채로 JUMI/AH 개발이 빨리 진행되면, JUMI/AH 팀이 자체 ad-hoc dashboard/스크립트를 만들어 운영 가드레일이 분기될 수 있다. 통합 설계 문서 v0.7 §18(Observability/Metrics/Churn)이 요구하는 단일 가드레일이 깨진다.

**완화**: Sprint K-1, K-2가 끝나기 전에 JUMI Sprint 6, AH Sprint 1을 시작하지 않는다 (의존성 명시).

#### R2. low-cardinality 규율 위반이 소리 없이 누적

JUMI/AH 개발자가 `runId`를 metric label에 넣어도 현재 kube-slint가 자동으로 못 잡는다. 운영 단계에서 Prometheus TSDB cardinality explosion으로 발견될 가능성이 높다.

**완화**: Sprint K-3에서 cardinality lint를 1급으로 추가.

#### R3. controller-runtime 패턴 잔류로 batch consumer가 어색함

`reconcile_total_delta`처럼 controller가 한 번 돌 때마다 1씩 증가하는 메트릭 사고방식은 batch Job/Pod를 수만 번 만드는 JUMI에 안 맞는다. baseline schema 자체가 batch-aware로 확장되지 않으면, JUMI/AH 소비자가 baseline json 형식을 자기 식으로 해석해버리는 fork가 발생할 수 있다.

**완화**: Sprint K-2에서 summary schema를 multi-component, batch-aware로 확장.

#### R4. derived indicator 계산이 소비자 bridge script로 흩어짐

현재처럼 `fallback_ratio`, `cleanup_debt` 같은 파생 지표 계산을 소비자 bridge script가 담당하면, JUMI repo와 AH repo, 그리고 통합 개발 저장소가 각자 다른 공식을 쓸 위험이 있다.

**완화**: Sprint K-2에서 derived indicator 계산을 `pkg/slo/engine`에 1급으로 흡수.

#### R5. policy 평가 결과의 binary화 (PASS/FAIL only)

`PASS | WARN | FAIL | NO_GRADE` enum (D-008)이 정의되어 있지만, JUMI/AH의 churn 지표는 단일 임계값으로 이진 판정하기 어렵다 (예: `same_node_hit_ratio`는 fixture에 따라 변동 폭이 크다). WARN/NO_GRADE 활용을 적극 문서화하지 않으면 false-positive로 게이트가 막힌다.

**완화**: Sprint K-3에서 batch consumer용 WARN/NO_GRADE 운영 가이드를 baseline policy에 직접 반영.

#### R6. multipass-k8s-vm와 dev space 환경의 표준화 부재

메트릭 계획 v2가 multipass와 dev space를 1급 환경으로 명시하지만, kube-slint 저장소에는 이를 자동 검증하는 워크플로우가 없다. CI에서는 kind만 돌고, multipass/dev space는 "있다고 가정"한다.

**완화**: Sprint K-4에서 multipass profile workflow와 dev space history workflow를 추가.

#### R7. summary path friction이 영구화될 위험

현재 hello-operator는 dynamic summary 파일명과 fixed gate input 사이를 bridge script가 잇는다 (notes/`baseline-update-flow-2026-03-20.md` 참고). 이걸 JUMI/AH가 그대로 받으면 영구 wart가 되고, 메트릭 계획 v2 §13.2에서도 "장기적으로 줄여야 한다"고 명시되어 있다.

**완화**: Sprint K-5에서 fetcher가 만든 summary path를 evaluator가 직접 받을 수 있도록 contract 정렬.

### 1.4 보완해야 할 것 — 우선순위 요약

| 우선순위 | 항목 | 관련 부족·위험 | 다루는 스프린트 |
|---|---|---|---|
| P0 | JUMI/AH 메트릭을 spec registry 1급으로 등록 | F1, R1 | K-1 |
| P0 | summary schema multi-component 확장 | F6, R3 | K-2 |
| P0 | derived indicator 계산을 engine에 흡수 | F2, R4 | K-2 |
| P1 | 환경 프로파일 (kind/multipass/devspace) 1급 | F3, R6 | K-3 |
| P1 | low-cardinality lint/guard | F4, R2 | K-3 |
| P1 | batch consumer용 WARN/NO_GRADE 가이드 | R5 | K-3 |
| P2 | multi-source fetcher session | F5 | K-4 |
| P2 | nightly long-run loop 자동화 | F8 | K-4 |
| P2 | distribution-based regression (p95 비교) | F7 | K-5 |
| P3 | summary path friction 제거 | R7 | K-5 |

---

## 2. 개발 목표 및 비목표

### 2.1 목표

1. JUMI/AH의 batch app metrics를 1급으로 받아 derived indicator를 계산하는 engine을 만든다.
2. `kind → multipass → dev space` 3단 환경에서 동일한 정책 평가가 동작하도록 환경 프로파일을 1급으로 둔다.
3. Low-cardinality 규율을 자동으로 점검한다.
4. JUMI/AH가 nightly long-run에서 churn drift를 감지할 수 있게 historical baseline 비교를 자동화한다.
5. hello-operator에서 검증한 consumer DX 패턴(`.slint/policy.yaml`, bridge script, Tilt local_resource)을 JUMI/AH가 그대로 채택할 수 있게 문서화한다.

### 2.2 비목표

- production 임계값 최종 확정 (각 소비자 책임)
- Dragonfly adapter 자체 검증 (AH 책임)
- 장기 보존/BI 대시보드 제품화
- full provenance 시스템

---

## 3. 아키텍처 변경 요점

### 3.1 spec registry 확장

`pkg/slo/spec/registry.go`에 다음 메트릭 family를 1급으로 등록한다:

- **JUMI family** (prefix: `jumi_`)
  - 제출/실행/종료, Job/Pod, fast-fail/cancel, 실행 지연, cleanup/GC debt, lifecycle gap
- **AH family** (prefix: `ah_`)
  - artifact 등록, resolve, locality/fallback, materialization, lifecycle/GC, provenance-ready
- **Kubernetes family** (prefix: `apiserver_`, `scheduler_`, `workqueue_`, `etcd_`)
  - 기존 controller-runtime family와 별도로 batch-aware 관점에서 재정렬

### 3.2 derived indicator 계산 계층

`pkg/slo/engine/derived/` 패키지를 새로 추가하고 다음을 1급으로 계산:

- `fallback_ratio` = `ah_fallback_total` / `ah_resolve_completed_total`
- `same_node_hit_ratio` = `ah_locality_decision_total{decision="local_reuse"}` / sum
- `delete_storm_rate` = `rate(apiserver_request_total{verb="DELETE"}[5m])`
- `cleanup_debt` = `jumi_cleanup_backlog_objects + jumi_cleanup_backlog_seconds + jumi_cleanup_debt_samples` 합성 지표
- `gc_backlog_bytes` = `ah_gc_backlog_bytes`
- `etcd_pressure_ratio` = `(etcd_db_total_size - etcd_db_in_use) / etcd_db_total_size`

### 3.3 multi-component summary schema

`pkg/slo/summary/schema.go`를 다음 구조로 확장:

```text
SLISummary
├── meta (runId, sampleRunId optional, environment, capturedAt)
├── components[]
│   ├── name (ex: "jumi", "ah", "kubernetes")
│   ├── kind ("batch_executor" | "resolver_service" | "platform" | "controller")
│   ├── raw_metrics{...}
│   ├── derived_indicators{...}
│   └── lifecycle_gap_signals{...}
└── policy_evaluation
    ├── checks[]
    ├── overall_result (PASS|WARN|FAIL|NO_GRADE)
    └── regression_baseline_ref
```

기존 hello-operator baseline json은 `components[0].kind = "controller"` 한 개로 자동 마이그레이션 가능하게 한다 (backward compatibility).

### 3.4 환경 프로파일 1급

`.slint/` 디렉토리 구조를 다음으로 정렬:

```text
.slint/
├── policy.yaml             # 기본 진입점 (호환 유지)
├── policy.kind.yaml        # 빠른 깨짐 탐지 임계값
├── policy.multipass.yaml   # 현실 압력 검증 임계값
├── policy.devspace.yaml    # 장기 회귀 임계값
└── profiles/               # 환경별 fetcher/spec 조합
    ├── kind.yaml
    ├── multipass.yaml
    └── devspace.yaml
```

`slint-gate`가 `--profile <kind|multipass|devspace>` flag를 받아 자동 선택.

### 3.5 cardinality lint

`pkg/slo/lint/cardinality.go` 추가. 다음을 자동 점검:

- 등록된 spec의 label set이 forbidden list (`runId`, `sampleRunId`, `artifactDigest`, `podName`, `jobName`, `patientId`, `filePath`)와 교집합 있는지
- summary fetcher가 가져온 메트릭이 forbidden label을 포함하는지
- 결과는 별도 `cardinality_warnings[]`로 summary에 추가, 정책 위반 시 WARN

---

## 4. 스프린트 일정

전체 스프린트는 **K-1 ~ K-5의 5개 스프린트**로 진행한다. 각 스프린트는 2주를 기준선으로 잡되, K-1과 K-2는 JUMI/AH 개발의 전제 조건이므로 우선 진행한다.

### 스프린트 K-1 — JUMI/AH 메트릭 spec 1급 등록 (2주)

#### 목표

JUMI/AH가 노출할 메트릭을 kube-slint가 1급으로 받을 수 있는 spec registry 확장 완료.

#### 작업 항목

1. `pkg/slo/spec/spec.go`에 `MetricFamily` 개념 추가 (`controller_runtime` | `batch_executor` | `resolver_service` | `platform`)
2. `pkg/slo/spec/registry.go`에 JUMI family 등록 (메트릭 계획 v2 §7 전체)
3. `pkg/slo/spec/registry.go`에 AH family 등록 (메트릭 계획 v2 §8 전체)
4. `pkg/slo/spec/registry.go`에 batch-aware Kubernetes family 등록 (메트릭 계획 v2 §9)
5. spec validation: family별 필수 메트릭과 선택 메트릭 분리
6. unit test: 각 family에 대한 fixture metric 입력 → spec match 확인

#### 완료 기준 (DoD)

- `go test ./pkg/slo/spec/...`이 새로운 family 등록 모두 통과
- 메트릭 계획 v2 부록 A의 "JUMI 최소 세트", "AH 최소 세트", "Raw K8s 최소 세트"가 spec registry에서 조회 가능
- 새 family 등록이 hello-operator의 기존 baseline json 평가를 깨지 않음 (backward compat 테스트 통과)

#### 산출물

- `pkg/slo/spec/registry.go` 갱신
- `pkg/slo/spec/families/{controller_runtime,batch_executor,resolver_service,platform}.go` 분할
- `docs/notes/metric-family-registry-202604XX.md`

#### 의존성

- 메트릭 계획 v2 §7, §8 메트릭 이름이 확정 상태여야 함 (현재 확정됨)

#### 위험

- JUMI/AH 팀이 메트릭 이름을 살짝 바꿀 가능성 → Sprint K-1 시작 전에 JUMI/AH 팀과 메트릭 이름 lock-in 회의 필요

---

### 스프린트 K-2 — Summary schema 확장 + derived indicator engine (2주)

#### 목표

multi-component summary schema와 derived indicator 계산을 engine 1급으로 흡수.

#### 작업 항목

1. `pkg/slo/summary/schema.go`를 multi-component 구조로 확장
2. backward compatibility: 기존 hello-operator baseline json을 자동으로 `components[0]` 형태로 lift하는 reader
3. `pkg/slo/engine/derived/` 패키지 신설
4. 다음 derived indicator 구현 (각각 별도 파일):
   - `fallback_ratio.go`
   - `same_node_hit_ratio.go`
   - `delete_storm_rate.go`
   - `cleanup_debt.go`
   - `gc_backlog_bytes.go`
   - `etcd_pressure_ratio.go`
   - `apiserver_write_rate.go`
5. 각 derived indicator의 입력 메트릭이 부재할 때 `NO_GRADE` 반환 규칙 통일
6. 통합 테스트: JUMI/AH/K8s family fixture에서 derived indicator 계산 정확성 검증

#### 완료 기준 (DoD)

- 신규 schema가 hello-operator의 RC PASS를 그대로 재현
- JUMI fixture와 AH fixture를 합친 multi-component summary가 evaluator를 통과
- derived indicator 6개 이상 unit test 통과
- 입력 메트릭 부재 시 `NO_GRADE`가 정확히 표시

#### 산출물

- `pkg/slo/summary/schema.go` v2 (multi-component)
- `pkg/slo/engine/derived/*.go`
- `docs/SUMMARY_SCHEMA_V2.md`
- backward compatibility 가이드

#### 의존성

- K-1 완료 (메트릭 spec이 등록되어 있어야 derived 계산 가능)

#### 위험

- backward compatibility를 깰 가능성 → hello-operator의 기존 RC baseline을 회귀 테스트 fixture로 고정

---

### 스프린트 K-3 — 환경 프로파일 + cardinality lint + WARN 가이드 (2주)

#### 목표

`kind / multipass / devspace` 3개 프로파일을 1급으로, low-cardinality 규율을 자동 점검, batch consumer용 WARN/NO_GRADE 가이드 확정.

#### 작업 항목

1. `.slint/profiles/` 디렉토리 도입과 schema 정의
2. `slint-gate` CLI에 `--profile` flag 추가
3. `policy.kind.yaml`, `policy.multipass.yaml`, `policy.devspace.yaml` 기준선 작성 (각 환경에서 다른 임계값)
4. `pkg/slo/lint/cardinality.go` 신설
5. forbidden label list를 `pkg/slo/spec/cardinality_rules.go`에 분리
6. summary fetcher가 fetch한 메트릭에 대해 자동 cardinality 체크
7. WARN/NO_GRADE 적용 시나리오 가이드: 어떤 derived indicator는 어떤 조건에서 WARN인지 매트릭스
8. JUMI/AH 양쪽에 적용 가능한 batch consumer reference policy 작성

#### 완료 기준 (DoD)

- `slint-gate --profile kind` / `--profile multipass` / `--profile devspace` 모두 동작
- 동일한 summary 입력에 대해 환경별로 다른 결과가 나옴 (예: multipass는 PASS, devspace는 WARN)
- forbidden label이 들어간 fake 메트릭 입력 시 cardinality lint가 WARN/FAIL 반환
- batch consumer용 WARN 가이드 문서 (`docs/BATCH_CONSUMER_GUIDE.md`)

#### 산출물

- `.slint/profiles/*.yaml`
- `pkg/slo/lint/cardinality.go`
- `pkg/slo/spec/cardinality_rules.go`
- `docs/BATCH_CONSUMER_GUIDE.md`

#### 의존성

- K-2 완료 (multi-component summary가 있어야 환경별 다른 derived 평가 가능)

#### 위험

- 환경별 임계값이 너무 보수적이면 false positive로 개발 마찰 증가, 너무 느슨하면 회귀 못 잡음 → K-4의 nightly 결과 기반으로 K-5에서 재조정

---

### 스프린트 K-4 — Multi-source fetcher session + nightly workflow (2주)

#### 목표

한 번의 summary 계산에 JUMI `/metrics`, AH `/metrics`, Kubernetes apiserver/scheduler 메트릭을 동시 수집. nightly long-run 루프 자동화.

#### 작업 항목

1. `pkg/slo/fetch/session.go` 신설: 여러 target endpoint를 묶어 한 번에 fetch
2. fetcher target descriptor: `{name, kind, endpoint, auth, scrape_interval}` 구조
3. multi-target session 결과를 multi-component summary에 자동 매핑
4. `.github/workflows/slint-nightly.yml` 추가:
   - cron schedule (UTC 매일 02:00)
   - heavy fixture 실행 (별도 마련)
   - historical summary 비교 (`docs/baselines/history/`)
   - regression report 생성
5. `hack/run-slint-nightly.sh` (multipass/dev space 환경에서 수동 실행도 가능하게)
6. historical baseline 디렉토리 구조 (`docs/baselines/history/<date>/<env>/sli-summary.json`)
7. nightly 결과의 progress log 자동 갱신 (`docs/PROGRESS_LOG.md`에 nightly 결과 footer 추가)

#### 완료 기준 (DoD)

- 단일 명령으로 JUMI + AH + K8s 메트릭이 한 번에 수집되고 multi-component summary가 생성됨
- nightly workflow가 dry-run 모드로 GitHub Actions에서 동작
- historical baseline 7일치 누적 후 regression detection이 동작 (fixture 기반)

#### 산출물

- `pkg/slo/fetch/session.go`
- `.github/workflows/slint-nightly.yml`
- `hack/run-slint-nightly.sh`
- `docs/baselines/history/.gitkeep` + 운영 가이드

#### 의존성

- K-3 완료 (환경 프로파일이 있어야 nightly가 어느 환경에서 도는지 명확)

#### 위험

- multipass/dev space가 GitHub Actions runner에 없음 → nightly는 self-hosted runner 또는 외부 dev space cluster에서 도는 것으로 명시. CI는 kind only.

---

### 스프린트 K-5 — Distribution regression + summary path friction 제거 (2주)

#### 목표

p95 등 distribution-based regression 평가, summary path friction 영구 제거.

#### 작업 항목

1. `pkg/slo/engine/regression/` 패키지 신설
2. distribution regression 알고리즘:
   - quantile 기반 비교 (p50, p95, p99)
   - sliding window 기반 추세 비교 (7일 이동평균 대비 오늘)
   - statistical significance 가벼운 체크 (Mann-Whitney U 등 단순 비모수)
3. `slint-gate-summary.json`에 `regression_evaluation` 섹션 추가
4. fetcher가 생성한 summary path를 evaluator가 직접 받도록 contract 정리:
   - `--summary-path` flag로 dynamic path 직접 지정
   - `--summary-glob`으로 가장 최근 파일 자동 선택
   - bridge script 의존성 제거를 hello-operator/JUMI/AH 모두에서 검증
5. K-3에서 만든 환경별 임계값을 nightly 결과 기반으로 재조정

#### 완료 기준 (DoD)

- p95 기반 regression 비교가 fixture 통과
- bridge script 없이 `slint-gate --summary-glob "artifacts/sli-summary.*.json"` 직접 실행 가능
- hello-operator/JUMI/AH 모두 bridge script 없는 단일 명령으로 gate 평가 가능
- 7일 누적 fixture에서 nightly drift detection 동작

#### 산출물

- `pkg/slo/engine/regression/distribution.go`
- `pkg/slo/engine/regression/sliding_window.go`
- `pkg/slo/cli/slint-gate.go` flag 확장
- `docs/REGRESSION_MODEL_V2.md`

#### 의존성

- K-4 완료 (nightly 결과가 누적되어야 sliding window 회귀가 의미 있음)

#### 위험

- statistical significance 판정이 너무 엄격하면 회귀 못 잡고, 너무 느슨하면 false positive → K-5에 hello-operator/JUMI/AH 각 fixture에서 manual tuning 필요

---

## 5. 스프린트 외 병행 작업

### 5.1 hello-operator 회귀 안정성 유지

K-1 ~ K-5 어느 스프린트도 hello-operator의 RC baseline PASS를 깨면 안 된다. PR 단위로 hello-operator e2e 회귀 테스트를 GitHub Actions가 자동 실행한다 (이미 `slint-gate.yml`에 있음).

### 5.2 JUMI/AH consumer fixture 신설

K-3 시점에 hello-operator에 더해 다음 두 consumer fixture를 추가:

- `test/consumer-onboarding/jumi-batch-consumer/` — JUMI fixture
- `test/consumer-onboarding/ah-resolver-consumer/` — AH fixture

각 fixture는 작은 mock metric exporter로 구성. 실제 JUMI/AH 저장소와 결합하지 않음 (independent).

### 5.3 문서 정렬

- `README.md`와 `README(Kor).md`에 batch consumer 지원 명시
- `sli-design-principles.md`에 batch-aware 원칙 추가
- `docs/CODEX_OPERATING_RULES.md`에 batch consumer 작업 규칙 추가

---

## 6. 스프린트별 메트릭 (자기 자신의 진척도)

스프린트 진행도를 다음 메트릭으로 자체 추적:

- 스프린트별 PR 머지 수
- 회귀 테스트 PASS rate (hello-operator baseline)
- 신규 spec registry 커버리지 (메트릭 계획 v2 §7, §8 대비)
- derived indicator 구현 수
- consumer fixture 수

---

## 7. 의존성 그래프 (다른 프로젝트와의)

```text
kube-slint K-1 (메트릭 spec 등록)
    ├── 사전: JUMI/AH 메트릭 이름 lock-in 회의
    └── 후속: JUMI Sprint 6, AH Sprint 1 (메트릭 노출)이 K-1 완료 후 시작 가능

kube-slint K-2 (multi-component schema + derived)
    └── 후속: JUMI Sprint 7, AH Sprint 2 (gate 통과)가 K-2 완료 후 가능

kube-slint K-3 (환경 프로파일 + cardinality)
    └── 후속: JUMI/AH가 nightly fixture 작성 가능

kube-slint K-4 (multi-source + nightly)
    └── 후속: JUMI/AH가 dev space 누적 회귀 관찰 가능

kube-slint K-5 (distribution regression)
    └── 후속: JUMI/AH가 churn drift 자동 감지 가능
```

**가장 중요한 의존성**: kube-slint K-1, K-2가 끝나기 전에 JUMI Sprint 6, AH Sprint 1을 시작하면 안 된다. 이걸 어기면 JUMI/AH 팀이 자체 ad-hoc 가드레일을 만들기 시작해서 통합 설계 문서 v0.7의 단일 가드레일 원칙이 깨진다.

---

## 8. 운영 체크리스트 (각 스프린트 마지막에 확인)

- [ ] hello-operator RC baseline이 여전히 PASS인가
- [ ] 신규 family에 forbidden label이 누설되지 않았는가
- [ ] 신규 derived indicator가 입력 부재 시 `NO_GRADE`로 명확히 떨어지는가
- [ ] backward compatibility: 기존 hello-operator baseline json이 자동으로 v2 schema로 lift되는가
- [ ] PROGRESS_LOG.md가 갱신되었는가
- [ ] DECISIONS.md에 본 스프린트의 결정이 추가되었는가
- [ ] consumer fixture가 깨지지 않았는가

---

## 9. 결론

kube-slint는 hello-operator를 통해 controller-runtime 영역에서 정체성과 RC를 이미 확보했다. 다음 스텝은 **batch data-plane consumer (JUMI/AH)도 1급으로 다루는 가드레일 프레임워크로 확장**하는 것이고, 이 문서는 그 확장을 5개 스프린트로 나눴다.

핵심은 **K-1과 K-2를 먼저 끝내야 JUMI/AH 팀이 따라올 수 있다**는 것이다. 그리고 K-1 시작 전에 JUMI/AH 팀과 메트릭 이름을 lock-in하는 짧은 회의가 반드시 필요하다.

---

## 부록 A. 신규 spec registry 등록 메트릭 전체 목록

### JUMI family

```text
jumi_pipeline_submissions_total
jumi_sample_runs_started_total
jumi_sample_runs_active
jumi_sample_runs_terminal_total{result}
jumi_nodes_ready_total
jumi_nodes_submitted_total
jumi_nodes_terminal_total{result,reason_class}
jumi_jobs_create_requests_total
jumi_jobs_created_total
jumi_job_create_failures_total{reason_class}
jumi_pods_observed_total{phase}
jumi_pods_terminal_total{phase}
jumi_fast_fail_trigger_total{reason_class}
jumi_cancel_requests_total{scope,reason_class}
jumi_cancelled_nodes_total{reason_class}
jumi_fail_fast_cascade_size
jumi_node_ready_to_submit_seconds
jumi_submit_to_pod_running_seconds
jumi_running_to_terminal_seconds
jumi_sample_run_wall_clock_seconds
jumi_cleanup_started_total{trigger}
jumi_cleanup_completed_total{result}
jumi_cleanup_backlog_objects
jumi_cleanup_backlog_seconds
jumi_delete_requests_total{resource_kind}
jumi_delete_lag_seconds{resource_kind}
jumi_binding_build_started_total
jumi_binding_build_failures_total
jumi_resolving_inputs_started_total
jumi_resolving_inputs_failures_total
jumi_finalizing_outputs_started_total
jumi_finalizing_outputs_failures_total
```

### AH family

```text
ah_artifact_register_requests_total
ah_artifact_registered_total{artifact_class}
ah_artifact_register_failures_total{reason_class}
ah_resolve_requests_total{policy}
ah_resolve_completed_total{mode,result}
ah_resolve_duration_seconds{policy}
ah_binding_count_per_resolve
ah_locality_decision_total{decision}
ah_fallback_total{from,to,reason_class}
ah_source_selection_total{source_kind}
ah_materialize_requests_total{source_kind}
ah_materialize_duration_seconds{source_kind}
ah_materialize_bytes_total{source_kind}
ah_materialize_failures_total{reason_class}
ah_expected_digest_mismatch_total
ah_gc_evaluations_total{artifact_class}
ah_gc_actions_total{action,result}
ah_gc_deferred_total{reason}
ah_gc_backlog_artifacts
ah_gc_backlog_bytes
ah_gc_bytes_reclaimed_total
ah_retained_artifacts_total{reason}
ah_unavailable_artifacts_total
ah_digest_commit_total
ah_manifest_missing_total
ah_manifest_parse_failures_total
ah_availability_state_total{state}
```

### Forbidden labels (cardinality lint 대상)

```text
runId, sampleRunId, artifactDigest, podName, jobName, patientId, filePath
```

---

## 부록 B. backward compatibility 매트릭스

| 현재 (v1) | 신규 (v2) | 변환 규칙 |
|---|---|---|
| `sli-summary.json` 단일 root | `components[0]` 자동 wrap | reader가 자동 |
| `reconcile_total_delta` | `components[0].raw_metrics.reconcile_total_delta` | path 자동 매핑 |
| `workqueue_depth_end` | `components[0].raw_metrics.workqueue_depth_end` | path 자동 매핑 |
| 기존 baseline json 평가 | 신규 reader가 v1로 인식 | flag 없이 자동 |

---

## 부록 C. 관련 문서

- `docs/DECISIONS.md` (현 RC 결정)
- `docs/PROGRESS_LOG.md` (Phase 6-c RC 상태)
- `docs/notes/slint-gate-spec-2026-03-07.md`
- `docs/notes/slint-gate-io-contract-2026-03-07.md`
- `docs/notes/baseline-update-flow-2026-03-20.md`
- `JUMI_AH_Integration_Design_ko v0.7`
- `JUMI_AH_kube_slint_metrics_churn_dev_plan_ko v2`
