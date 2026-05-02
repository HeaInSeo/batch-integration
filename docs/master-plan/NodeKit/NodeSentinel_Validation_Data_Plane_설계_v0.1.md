# NodeSentinel Validation Data Plane 설계 v0.1

작성 목적: `NodeVault`가 Harbor에 이미지를 push한 이후의 후속 검증, 실행 확인, 보안 스캔, 결과 집계를 담당하는
Kubernetes data-plane app의 역할과 경계를 고정한다.

이 문서는 `NodeVault_Reproducible_Tool_Authoring_업그레이드_설계_v0.6.1.md`의 companion 문서다.
v0.6.1이 논리적 L1~L5 흐름과 OCI metadata 방향을 정의했다면, 이 문서는 그중 **L3~L5-b를 실제로 누가 수행할지**를
`NodeSentinel` 기준으로 명시한다.

외부 gRPC 노출 방식의 공통 표준은
`K8S_SHARED_GRPC_INGRESS_GUIDELINE_v0.1.md`를 따른다.

---

## 0. Executive Summary

최종 경계는 다음과 같다.

```text
NodeKit
  → ToolDefinition authoring / L1 static validation
  → NodeVault로 build request 전송

NodeVault
  → image build
  → Harbor push
  → toolspec / 기본 catalog metadata 확정
  → NodeSentinel에 validation work enqueue

NodeSentinel
  → K8s data-plane validation orchestration
  → dry-run / smoke-run / functional profiling
  → trivy-operator security result 수집
  → toolprofile / security metadata 생성
  → 결과를 client-facing 상태로 집계
```

즉:

- `NodeVault`는 **build-and-publish control plane**으로 제한한다.
- `NodeSentinel`은 **post-push validation / security data plane**이다.
- `NodeVault`가 kubeconfig로 L3/L4/L5를 직접 수행하는 초기 구조는 transition 모델로 보고,
  장기 방향은 `NodeSentinel` 분리로 둔다.

---

## 1. 문제 정의

현재 host-run `NodeVault` + kubeconfig 모델은 다음 한계가 있다.

- 특정 kubeconfig / 특정 cluster endpoint에 강하게 결합된다.
- API server 주소 변경, stale kubeconfig, 네트워크 단절에 취약하다.
- post-push validation / security scan까지 `NodeVault` 책임으로 두면 역할이 비대해진다.
- `trivy-operator`, validation Job, runtime observation 등 K8s-native data-plane 동작과의 결합이 어색하다.

따라서 post-push 단계는 별도 app으로 분리한다.

---

## 2. NodeSentinel 역할

`NodeSentinel`은 Harbor에 이미 올라간 image artifact를 대상으로 다음을 수행한다.

### 2.1 Validation Plane

- smoke-run Job 실행
- functional validation fixture 실행
- declared command / script 동작 확인
- observed I/O profile 수집
- observed resource profile 수집
- infra failure와 application failure 분리

### 2.2 Security Plane

- `trivy-operator`가 생성한 `VulnerabilityReport` 결과 조회
- 필요 시 misconfiguration / secret exposure summary 수집
- scanner identity / freshness / policy result 집계

### 2.3 Metadata Plane

- `toolprofile` artifact payload 생성
- `security` artifact payload 생성
- client 표시용 status / badge summary 생성

---

## 3. 비목표

`NodeSentinel`은 다음을 하지 않는다.

- Dockerfile authoring
- L1 static validation
- image build
- Harbor push
- stable `casHash` 정의 변경
- `NodeVault` catalog identity 재정의

즉 `NodeSentinel`은 **artifact identity authority가 아니라 post-push runtime/security evidence plane**이다.

---

## 4. NodeVault와의 경계

### 4.1 NodeVault가 끝나는 지점

`NodeVault`는 다음이 끝나면 책임이 종료된다.

- image build 완료
- Harbor push 완료
- `toolspec` 및 기본 catalog/index 확정
- `NodeSentinel`에 validation work enqueue 완료

### 4.2 NodeSentinel이 시작하는 지점

`NodeSentinel`은 다음 입력을 받으면 일을 시작한다.

- image repository
- image digest
- stableRef
- tool name / version
- casHash
- requested validation modes
- requested security modes

---

## 5. 통신 방식

### 5.1 외부 경계: NodeVault → NodeSentinel ingress

`NodeVault`는 `NodeSentinel`에 직접 worker RPC를 호출하지 않는다.
대신 `enqueue` 전용 ingress API를 호출한다.

초기 권장 방식:

```text
NodeVault --gRPC EnqueueValidationWork--> NodeSentinel ingress
```

이 ingress는 작업을 내부 `WorkStore`에 기록하고 즉시 반환한다.
실제 검증은 비동기 worker가 수행한다.

배치 표준:

- `NodeSentinel`은 node별 직접 외부 노출을 기본으로 하지 않는다.
- shared Cilium Gateway 뒤의 app-specific hostname을 사용한다.
- 권장 hostname 규칙은 `<app>.apps.<base-domain>`이다.
- 예: `nodesentinel.apps.example.internal`

즉 외부 경계는 다음처럼 본다.

```text
NodeVault
  → nodesentinel.apps.<base-domain>
  → shared Gateway
  → NodeSentinel GRPCRoute
  → NodeSentinel Service
```

### 5.2 내부 경계: NodeSentinel ingress → WorkStore → worker

```text
ingress
  → CreateJob()
  → SQLite WorkStore

worker
  → LeaseJob()
  → Run validation / security steps
  → CompleteJob() / FailJob()
```

즉 외부에선 gRPC ingress를 노출하되, 내부 처리 모델은 store-backed pull worker다.

---

## 6. WorkStore 설계

### 6.1 왜 SQLite인가

현재는 DB 최종 결정을 하지 않는다.
초기 구현은 다음 이유로 SQLite를 채택한다.

- 단일 바이너리/단일 Pod에서 가장 구현 비용이 낮다.
- 상태 전이, retry, lease, 결과 요약 저장이 쉽다.
- Postgres 등 RDBMS로의 migration 경로가 비교적 단순하다.
- 파일 spool보다 concurrency / retry 모델을 깔끔하게 유지할 수 있다.

중요:

```text
SQLite는 최종 저장소가 아니라 임시 구현이다.
비즈니스 로직은 SQLite를 직접 알면 안 된다.
```

### 6.2 추상 인터페이스

최소 인터페이스:

```text
CreateJob(request)
LeaseJob(worker, ttl)
Heartbeat(job, ttl)
CompleteJob(job, result)
FailJob(job, error, retryable)
GetJob(id)
ListJobs(filter)
```

향후 교체 후보:

- PostgreSQL
- Redis-backed queue
- NATS / RabbitMQ
- Kubernetes CRD/operator-backed store

---

## 7. Job 모델

### 7.1 요청 payload

최소 레코드:

```text
job_id
artifact_kind             = tool
image_repository
image_digest
stable_ref
tool_name
version
cas_hash
requested_actions
  - smoke_run
  - profile
  - security_scan
requested_fixture_set
created_at
```

### 7.2 상태

초기 상태:

```text
queued
leased
running
succeeded
failed
```

보조 필드:

```text
attempt
lease_owner
lease_until
last_error
result_summary
updated_at
```

---

## 8. 실행 흐름

### 8.1 Happy path

```text
1. NodeVault build 완료
2. Harbor push 완료
3. NodeVault → NodeSentinel enqueue
4. NodeSentinel worker lease
5. smoke-run Job 실행
6. functional validation / profiling 수행
7. trivy-operator VulnerabilityReport 수집
8. toolprofile payload 생성
9. security payload 생성
10. result summary / badge state 갱신
11. job complete
```

### 8.2 실패 분류

infra-level failure:

- scheduling failure
- image pull failure
- timeout
- OOMKilled
- eviction
- API unreachability

application-level failure:

- command exit failure
- contract mismatch
- expected output missing

이 분류는 v0.6.1 `validationHash` 정책과 일치해야 한다.

---

## 9. K8s 실행 모델

### 9.1 Namespace

기본 validation namespace:

- `nodevault-smoke`

필요 시 profile/security 전용 namespace를 나중에 추가할 수 있다.

### 9.1.a kubeconfig / cluster authority

transition 단계에서 `NodeSentinel` ingress 또는 bootstrap 유틸리티가 원격 cluster 연결 정보를 다룰 경우,
multi-agent 환경에서는 **remote authoritative kubeconfig**를 기본으로 사용한다.

원칙:

```text
default:
  remote authoritative kubeconfig

exception:
  explicit local kubeconfig injection only
```

즉:

- 다른 에이전트의 로컬 개발 kubeconfig를 기본값으로 가정하지 않는다.
- 원격 호스트/클러스터의 authoritative kubeconfig를 우선한다.
- local kubeconfig 주입은 명시적 override로만 허용한다.

### 9.2 수행 단위

- smoke-run: `Job`
- functional validation: `Job`
- security: 기본은 `trivy-operator` 결과 read

즉 초기 `NodeSentinel`은 scanner를 직접 실행하기보다
**`trivy-operator`가 만든 CRD 결과를 읽는 aggregator**에 가깝다.

### 9.3 K8s 권한

최소 필요 권한:

- Jobs create/get/list/delete/watch
- Pods get/list/watch
- Pods/log get
- `VulnerabilityReport` get/list/watch

---

## 10. 결과 산출물

### 10.1 toolprofile

artifact type:

```text
application/vnd.nodevault.toolprofile.v1+json
```

포함 항목:

- validation summary
- observedIoProfile
- observedResourceProfile
- contract check
- validationHash

### 10.2 security

artifact type:

```text
application/vnd.nodevault.security.v1+json
```

포함 항목:

- scanner = `trivy`
- source = `trivy-operator`
- report kind = `VulnerabilityReport`
- severity summary
- freshness
- policy result
- securityScanDigest

### 10.3 client-facing summary

`NodeSentinel`은 최소한 다음 요약 상태를 제공해야 한다.

- validation status
- security status
- last scan time
- badge summary

이 summary는 나중에 NodePalette / DagEdit / 기타 client가 조회하는 표면으로 연결된다.

---

## 11. NodePalette / client 연결

초기 원칙:

- raw full payload는 OCI referrer artifact에 둔다.
- client는 직접 referrer 원문을 다 읽지 않고, 요약 상태를 먼저 본다.

예시 badge:

- validation: `validated`, `warning`, `failed`, `unknown`
- security: `clean`, `warning`, `critical`, `stale`, `unknown`

---

## 12. 교체 가능성 보장

미래 교체가 쉬우려면 다음을 지킨다.

### 12.1 DB 독립성

- business logic은 `WorkStore`만 본다
- SQLite-specific SQL은 infra layer에만 둔다

### 12.2 transport 독립성

- ingress contract는 `enqueue` 하나로 최소화한다
- 내부 worker는 transport를 모른다

### 12.3 metadata 독립성

- toolprofile/security payload 생성 로직은 store와 분리한다
- referrer writer는 validation/security executor와 분리한다

---

## 13. 단계적 구현 순서

### Phase 1

- `NodeSentinel` 이름 고정
- ingress proto 초안
- SQLite `WorkStore` 인터페이스/구현
- job enqueue / lease / complete

### Phase 2

- smoke-run Job worker
- result summary 저장

### Phase 3

- functional validation / profile 수집
- `toolprofile` referrer write

### Phase 4

- `trivy-operator` `VulnerabilityReport` 수집
- `security` referrer write
- client badge summary

---

## 14. NodeVault v0.6.1과의 관계

이 문서는 v0.6.1을 대체하지 않는다.
역할은 다음과 같다.

- v0.6.1:
  - 전체 logical upgrade 목표
  - additive field / OCI metadata / verification semantics 정의
- NodeSentinel v0.1:
  - post-push validation/security data-plane app의 실제 경계 정의

정리:

```text
v0.6.1 = 무엇을 남겨야 하는가
NodeSentinel v0.1 = 누가 그것을 수행하는가
```
