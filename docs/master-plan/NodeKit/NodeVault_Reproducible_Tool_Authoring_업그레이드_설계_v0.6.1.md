# NodeKit / NodeVault Reproducible Tool Authoring 업그레이드 설계 v0.6.1

작성 목적: NodeKit과 NodeVault의 실제 코드·문서 구조를 기준으로, Tool authoring, legacy Dockerfile import, declared/observed metadata, OCI/ORAS referrer, dry-run profiling, security scan, NodePalette/DagEdit 연계를 최종 업그레이드 설계로 정리한다.

이 문서는 사람과 Codex가 함께 읽고 바로 Sprint를 실행할 수 있도록 작성한다. 목표는 추상적인 PoC가 아니라, **기존 NodeVault를 깨지 않고 점진적으로 업그레이드할 수 있는 구현 중심 설계와 실제 repo별 적용 경로**를 확정하는 것이다.

문서의 역할:

```text
이 문서 자체
= 설계 결정 기록 / upgrade decision record

실제 적용
= NodeVault, NodeKit, DagEdit, tools/legacy-import 각 repo의 docs와 code에 커밋되는 산출물
```

---

## 0. Version History

### v0.1

초기 설계 문서. 다음 큰 방향을 정리했다.

- NodeKit = ToolAuthoringBundle editor
- NodeVault = ToolAuthoringBundle intake / normalize / pin / metadata attach
- NodePalette = read-only catalog
- DagEdit = casHash 기반 DAG node pinning
- legacy Dockerfile은 production source가 아니라 historical operational evidence
- Base Runtime은 단순 OS 선택이 아니라 generation policy
- ToolRecipe / CompositeRecipe / ToolAuthoringBundle / RegisteredToolCandidate / OCI metadata draft 개념 도입

### v0.2

실행 가능성을 높이기 위해 다음을 보정했다.

- `authoringHash`와 `casHash` 분리
- Reproducibility를 `technicalLevel`과 `evidenceLevel` 2축으로 분리
- `clinical_pipeline_import` 대신 `validated_pipeline_import`로 용어 보정
- `preserve_original` / `rebuild_equivalent` intent 도입
- stableRef 정책 추가
- targetPlatforms / runtimeFormats / runtimeRequirements 추가
- IO Contract / ValidationFixture / Structured Warning 추가
- NodeVault를 Intake / Builder / Registry / Catalog 단계로 분리

### v0.3

실제 의도였던 dry-run 기반 관측 metadata를 반영했다.

- NodeVault에 Validator / Profiler 단계 추가
- `declaredIoContract`와 `observedIoProfile` 분리
- `declaredRuntimeRequirements`와 `observedResourceProfile` 분리
- `executionEnvironment` 필수화
- `validationHash` 추가
- OCI metadata는 image 안에 넣는 것이 아니라 image에 attach하는 artifact로 정의
- `metadataArtifactDigest`와 `casHash` 순환 의존 문제 정리

### v0.3.1

구현자가 헷갈릴 수 있는 세부 사항을 보정했다.

- Sprint 2: mock `validationHash` 기반 `casHash` 계산 구조 검증
- Sprint 3: 실제 dry-run 기반 `validationHash`와 최종 `casHash` 확정
- `observedResourceProfile`은 metadata에는 포함하되 기본 `validationHash`/`casHash`에는 제외
- schema migration 정책 추가
- signing field는 상태 summary이고 실제 signature/attestation은 별도 OCI artifact라고 정리
- build environment reproducibility open question 추가
- IO type canonical enum / alias normalization open question 추가
- reference binding enum 후보 추가

### v0.4

실제 NodeVault 프로젝트의 기존 구조를 기준으로 최종 통합 전략을 보정했다.

- 전체 독립 PoC 프로젝트를 만들지 않는다.
- NodeVault 본체는 직접 업그레이드한다.
- Legacy Dockerfile 분석기는 NodeVault core가 아니라 별도 migration/import 도구로 둔다.
- 기존 NodeVault `casHash` 계산 방식은 변경하지 않는다.
- `authoringHash`, `validationHash`, `observedProfileDigest`는 additive field로 추가한다.
- OCI referrer는 `toolspec`과 `toolprofile`로 분리한다.
- 기존 `PortSpec`은 버리지 않고 확장한다.
- DagEdit 계층 5 RunnerNode를 조기에 문서화한다.

### v0.5

Security Scan Integration의 자리를 추가했다.

- Security Scan은 Validator/Profiler와 섞지 않고 별도 병렬 검증 축으로 분리한다.
- `application/vnd.nodevault.security.v1+json` referrer 후보를 추가한다.
- `securityScanDigest` optional field를 추가할 수 있다.
- 기록과 UI 표시는 기본, Active 전환 gate는 정책 옵션으로 둔다.
- trivy-operator `VulnerabilityReport` CRD watch/read 방식을 우선 검토한다.

### v0.6

Sprint 일정과 검증 가능한 완료 기준을 추가했다.

- Sprint 0~3 예상 기간 추가
- 전체 일정 7~8주
- 각 Sprint에 산출물, 검증 기준, 완료 판정 추가
- 기존 `casHash` 안정성 검증을 모든 NodeVault 코드 변경 Sprint의 공통 gate로 지정
- index backward compatibility 테스트 추가
- toolspec/toolprofile/security referrer 공존 테스트 추가
- DagEdit RunnerNode C# 테스트 기준 추가

### v0.6.1

운영/프로덕션 적용 관점의 엣지 케이스를 보강한 최종 패치다.

- `validationHash`는 successful functional validation에 대해서만 생성한다.
- OOMKilled, timeout, eviction, scheduling failure, image pull failure 등 infra-level failure를 application-level failure와 분리한다.
- Dry-run timeout 기본값과 override 정책을 추가한다.
- `toolprofile` / `security` referrer retention 및 GC 기본 정책을 추가한다.
- NodePalette / DagEdit UI default badge 정책을 추가한다.
- index update rollback/fallback 테스트를 추가한다.
- Codex Prompt에 기존 struct/JSON tag/field type 변경 금지 규칙을 추가한다.
- 문서 번호 체계를 정리한다.
- companion note: post-push validation/security data-plane 분리 방향은
  `NodeSentinel_Validation_Data_Plane_설계_v0.1.md`를 참조한다.
- 공통 gRPC ingress 표준은
  `K8S_SHARED_GRPC_INGRESS_GUIDELINE_v0.1.md`를 참조한다.

---

## 1. Executive Summary

이번 작업의 핵심 목표는 NodeKit과 NodeVault 사이에 존재하는 Tool authoring 공백을 실제 구현 가능한 형태로 메우는 것이다.

초기에는 별도 독립 PoC 프로젝트를 만들어 `BaseRuntimeProfile`, `ToolRecipe`, `ToolAuthoringBundle`, `RegisteredToolCandidate`, `OCI metadata draft` 등을 새로 검증하는 방향을 고려했다. 그러나 실제 NodeVault 구조를 검토한 결과, NodeVault에는 이미 다음 뼈대가 잘 잡혀 있다.

- ToolDefinition / CAS JSON
- `assets/catalog/{casHash}.tooldefinition`
- OCI referrer spec
- PortSpec
- stableRef:casHash = 1:N 구조
- lifecycle_phase + integrity_health 이중 상태 축
- NodePalette로 노출할 catalog/index 구조

따라서 전체를 별도 PoC로 만들면 기존 NodeVault의 개념과 같은 개념을 다른 이름으로 다시 만들게 된다. 이것은 나중에 다시 통합해야 하는 비용을 만든다.

v0.6.1의 최종 전략은 다음이다.

```text
NodeVault core
  → 직접 점진 업그레이드
  → 기존 ToolDefinition / PortSpec / casHash / index / ORAS 구조 유지
  → toolspec 유지
  → toolprofile 추가
  → security referrer 추가
  → Validator/Profiler 추가
  → Security Scan Integration 병렬 추가
  → observedProfileDigest / validationHash / securityScanDigest optional 확장

Legacy Dockerfile import
  → NodeVault core 밖의 별도 tools/legacy-import 또는 별도 repo
  → 기존 ICG Dockerfile에서 BaseRuntimeProfile / ToolRecipe / CompositeRecipe 후보 추출

External reference project scan
  → 문서 트랙
  → BioContainers, Seqera, Galaxy, nf-core, Dockstore 등 비교
```

현재 선호 구현 경계:

```text
NodeVault
  → build + Harbor push + base metadata

NodeSentinel
  → post-push L3/L4/L5 validation + security scan aggregation
```

구체적 data-plane 분리 설계는 companion 문서
`NodeSentinel_Validation_Data_Plane_설계_v0.1.md`를 참조한다.
외부 gRPC 노출의 공통 규약은
`K8S_SHARED_GRPC_INGRESS_GUIDELINE_v0.1.md`를 따른다.

검증 흐름은 다음과 같이 분리한다.

```text
L1  NodeKit DockGuard / OPA-Rego
    → Dockerfile 정적 정책 검증

L2  podbridge5 또는 build backend
    → image build + registry push

L3  K8s dry-run
    → Job manifest 검증

L4  smoke run
    → 컨테이너 기동 확인

L5-a Validator / Profiler
    → sample data로 실제 tool 실행
    → observed I/O, resource profile 수집

L5-b Security Scan
    → Trivy / trivy-operator
    → CVE, misconfiguration, secret exposure 검증
```

이 흐름은 logical capability를 나타낸다.
현재 선호 배치에서는 L3~L5-b 수행 주체를 host-run `NodeVault`에 고정하지 않고,
별도 K8s data-plane app `NodeSentinel`로 분리할 수 있다.
자세한 경계와 ingress/store/worker 모델은
`NodeSentinel_Validation_Data_Plane_설계_v0.1.md`를 따른다.

Functional validation과 security scan은 서로 다른 축이다. Validator/Profiler는 tool이 실제 sample data로 동작하는지 확인하고, Security Scan은 image의 보안 상태를 확인한다.

가장 중요한 호환성 결정은 다음이다.

```text
기존 NodeVault casHash는 변경하지 않는다.

기존 casHash
= ToolDefinition CAS identity
= 기존 SHA256(spec JSON without cas_hash) 의미 유지
= assets/catalog/{casHash}.tooldefinition 경로 유지
= 기존 index.Entry 참조 호환성 유지
```

새로 추가할 값은 기존 `casHash`를 대체하지 않는다.

```text
authoringHash
= NodeKit authoring request 또는 legacy import source lineage 추적용 optional field

validationHash
= dry-run validation/profile summary 추적용 optional field

observedProfileDigest
= application/vnd.nodevault.toolprofile.v1+json referrer digest optional field

securityScanDigest
= application/vnd.nodevault.security.v1+json referrer digest optional field
```

즉, v0.6.1에서는 다음을 원칙으로 한다.

```text
casHash는 기존 의미 유지.
authoringHash / validationHash / observedProfileDigest / securityScanDigest는 추가 필드.
필요하면 runtimeProfileHash 또는 validatedProfileHash를 나중에 별도 도입.
Security scan은 별도 security referrer로 기록하고, Active gate 여부는 정책 옵션으로 둔다.
```

---

## 2. 현재 NodeVault가 이미 잘 잡아둔 것

NodeVault의 현재 설계는 우리가 논의한 v0.3 계열 방향과 상당히 잘 맞는다.

### 2.1 TOOL_NODE_SPEC.md의 5계층 구조

현재 NodeVault 문서에는 다음 계층 구조가 있다.

```text
계층 1: Dockerfile / build recipe
계층 2: 배포 인프라 YAML
계층 3: ToolDefinition / CAS JSON
계층 4: OCI referrer spec
계층 5: DagEdit RunnerNode
```

현재 상태:

```text
계층 3
  - 동작 중
  - {casHash}.tooldefinition으로 저장

계층 4
  - toolspec referrer attach 방향 존재
  - application/vnd.nodevault.toolspec.v1+json

계층 5
  - 미설계
  - RunnerNode에 casHash 참조 구조가 아직 명확하지 않음
```

v0.6.1에서 가장 먼저 보강해야 할 부분은 계층 5다.

### 2.2 TOOL_CONTRACT_V0_2.md의 PortSpec

기존 NodeVault에는 이미 PortSpec이 있다.

기존 PortSpec 주요 필드:

```text
name
role
format
shape
required
class
constraints
```

이것은 v0.3에서 말한 `declaredIoContract`와 대응된다. 따라서 NodeVault core에 별도 `declaredIoContract`를 새로 만들면 안 된다. 기존 PortSpec을 확장하는 것이 맞다.

### 2.3 INDEX_SCHEMA.md의 이중 축 상태 모델

기존 NodeVault에는 다음 구조가 있다.

```text
lifecycle_phase
integrity_health
```

이것은 v0.3/v0.6.1 방향과 맞는다.

- lifecycle_phase: 관리자가 의도한 상태
- integrity_health: 실제 registry/catalog/artifact 상태

또한 stableRef:casHash = 1:N 구조도 v0.3/v0.6.1의 stableRef 정책과 맞는다.

---

## 3. 기존 문서와 v0.6.1 사이의 실제 갭

갭은 크게 다섯 가지다.

### 3.1 toolspec payload와 observed profile의 분리 필요

현재 계층 4의 OCI referrer payload는 정적 spec 중심이다. 즉, ToolDefinition / PortSpec / declared metadata 중심이다.

v0.3에서 추가된 다음 정보는 현재 payload에 없다.

```text
observedIoProfile
observedResourceProfile
contractCheck
validationHash
executionEnvironment
```

이 정보는 authoring 시점에 존재하지 않는다. dry-run 이후에야 생성된다.

따라서 하나의 toolspec artifact에 모두 넣는 것은 좋지 않다.

최종 결정:

```text
toolspec과 toolprofile을 별도 referrer artifact로 분리한다.
```

구조:

```text
image digest
  ├── [referrer] application/vnd.nodevault.toolspec.v1+json
  │      → declared spec / ToolDefinition / PortSpec
  │
  └── [referrer] application/vnd.nodevault.toolprofile.v1+json
         → observedIoProfile / observedResourceProfile / contractCheck / validation summary
```

분리 이유:

```text
- toolspec은 NodeKit authoring 또는 ToolDefinition 등록 시점의 선언 정보다.
- toolprofile은 dry-run 이후에야 생기는 관측 정보다.
- 같은 image에 대해 dry-run을 다시 실행하면 toolprofile만 갱신하면 된다.
- 하나의 artifact에 다 넣으면 observed profile만 바뀌어도 declared spec까지 교체해야 한다.
```

### 3.2 security scan result의 분리 필요

Security scan은 Validator/Profiler와 생명주기가 다르다. dry-run profile은 sample data와 runner behavior에 대한 관측 결과지만, security scan은 취약점 DB와 scanner 상태에 따라 시간이 지나며 결과가 바뀔 수 있다.

최종 결정:

```text
Security scan result는 toolprofile 안에 넣지 않는다.
별도 application/vnd.nodevault.security.v1+json referrer artifact로 분리한다.
```

구조:

```text
image digest
  ├── [referrer] application/vnd.nodevault.toolspec.v1+json
  ├── [referrer] application/vnd.nodevault.toolprofile.v1+json
  └── [referrer] application/vnd.nodevault.security.v1+json
```

기본 정책:

```text
Security scan result 기록 = 기본
NodePalette UI 표시 = 기본
Active 전환 차단 = 정책 옵션
```

### 3.3 DagEdit RunnerNode 포맷 부재

현재 계층 5가 미설계다. 우리가 “DagEdit는 casHash 기반으로 pin한다”고 말해도, 실제 RunnerNode JSON/YAML 구조가 없으면 원칙이 코드로 내려오지 않는다.

v0.6.1에서는 반드시 다음 문서를 추가한다.

```text
NodeVault/docs/RUNNER_NODE_SPEC.md
```

RunnerNode MVP 구조:

```json
{
  "nodeType": "runner",
  "casHash": "sha256:existing-tooldefinition-cas",
  "stableRef": "bwa@0.7.17",
  "displaySnapshot": {
    "label": "BWA 0.7.17",
    "category": "Alignment",
    "icon": null
  },
  "portBindings": {
    "inputs": {
      "reads": {
        "connectedTo": "parent-node:output-port"
      }
    },
    "outputs": {
      "alignment": {}
    }
  },
  "portMetadata": {
    "source": "declared+observed",
    "toolspecReferrerDigest": "sha256:optional-toolspec-digest",
    "observedProfileDigest": "sha256:optional-toolprofile-digest",
    "validationHash": "sha256:optional-validation-hash"
  }
}
```

필수:

```text
casHash
```

선택:

```text
stableRef
displaySnapshot
observedProfileDigest
validationHash
toolspecReferrerDigest
```

중요한 구분:

```text
portBindings
= 실제 DAG edge 연결

portMetadata
= UI 연결 호환성 판단과 표시를 위한 metadata
```

### 3.4 PortSpec과 v0.3 declaredIoContract 용어 충돌

기존 NodeVault PortSpec과 v0.3 declaredIoContract는 같은 개념을 다른 이름으로 부른 부분이 있다.

매핑:

```text
PortSpec.format  ≈ v0.3 type
PortSpec.shape   ≈ v0.3 multiplicity
PortSpec.role    = 유지
PortSpec.class   = 유지
PortSpec.required = 유지
PortSpec.constraints = 유지
v0.3 staging     = PortSpec에 신규 확장 후보
```

최종 결정:

```text
기존 PortSpec을 기준으로 확장한다.
NodeVault core에 별도 declaredIoContract 모델을 만들지 않는다.
```

예시:

```yaml
ports:
  inputs:
    - name: reads
      role: read_input
      format: FASTQ
      shape: pair_or_single
      class: primary
      required: true
      staging: file
      constraints: []
  outputs:
    - name: alignment
      role: alignment_output
      format: SAM
      shape: single
      class: primary
      required: true
      staging: file
      constraints: []
```

### 3.5 casHash 호환성 문제

v0.3.1의 일반 설계에서는 다음 흐름을 제안했다.

```text
casHash = hash(imageDigest + authoringHash + validationHash + final immutable fields)
```

하지만 기존 NodeVault에서는 이미 `casHash`가 다른 의미로 쓰이고 있다.

```text
현재 NodeVault casHash
= SHA256(spec JSON without cas_hash)
= ToolDefinition CAS identity
= assets/catalog/{casHash}.tooldefinition 파일 경로 key
= index.Entry의 핵심 참조값
```

따라서 기존 `casHash`를 재정의하면 다음 문제가 생긴다.

```text
- 기존 tool들의 casHash가 바뀜
- 기존 catalog 파일 경로가 깨짐
- index.Entry primary reference가 깨짐
- NodePalette/DagEdit 연결 기준이 흔들림
```

최종 결정:

```text
NodeVault v0.6.1 업그레이드는 기존 casHash 계산 방식과 catalog 경로 의미를 변경하지 않는다.
```

추가 필드:

```text
authoringHash
validationHash
observedProfileDigest
securityScanDigest
```

향후 필요 시 새 identity:

```text
runtimeProfileHash
validatedProfileHash
```

---

## 4. Hash 정책 최종안

### 4.1 기존 NodeVault casHash

```text
casHash
= 기존 ToolDefinition CAS identity
= 기존 계산 방식 유지
= 기존 catalog path 유지
= 기존 index compatibility 유지
```

절대 하지 않을 것:

```text
기존 casHash를 validationHash나 observedProfileDigest까지 포함하는 새 hash로 재정의하지 않는다.
```

### 4.2 authoringHash

```text
authoringHash
= NodeKit authoring request 또는 legacy import source lineage 추적용 hash
= optional additive field
```

용도:

```text
- NodeKit authoring request 추적
- legacy Dockerfile import source 추적
- 동일 authoring request 반복 제출 감지
- 감사/audit 보조 정보
```

### 4.3 validationHash

```text
validationHash
= dry-run validation/profile summary hash
= optional additive field
= successful functional validation에 대해서만 생성
```

기본 포함:

```text
- validationRun mode
- imageDigest
- runnerScriptDigest
- sampleDataRefs digest
- command summary
- successful application-level exitCode/status
- observed I/O deterministic summary
  - file exists
  - count
  - non-empty 여부
  - comparator result
- contractCheck summary
```

기본 제외:

```text
- peak CPU
- avg CPU
- peak memory
- durationSeconds
- disk read/write bytes
- node name
- cpu model
- total memory
- raw stdout/stderr 전체
- timestamp
```

중요한 운영 규칙:

```text
validationHash는 successful functional validation에 대해서만 생성한다.

infra-level failure인 경우 validationHash를 확정하지 않는다.
대신 validation status를 infra_failed 또는 profile_inconclusive로 기록한다.
```

infra-level failure 예:

```text
- OOMKilled
- timeout
- node eviction
- pod scheduling failure
- image pull failure
- registry pull error
- SIGTERM/SIGKILL 기반 종료
- cluster/network/storage transient failure
```

application-level failure 예:

```text
- tool 자체가 exit code 1/2 등으로 정상적으로 실패를 보고
- runner가 정상적으로 실행되었고
- 인프라 장애가 아닌 것이 확인된 경우
```

application-level failure를 validationHash에 포함할지 여부는 policy로 둔다. 기본 정책은 다음이다.

```text
기본값:
  successful validation만 validationHash 생성

확장 후보:
  expected-failure fixture가 있는 경우에만 failed validationHash 생성 허용
```

이유:

```text
같은 image와 같은 sample이라도 메모리 limit, timeout, node 상태에 따라 OOMKilled 또는 timeout이 발생할 수 있다.
이 경우 exitCode/status가 환경에 종속되므로, validationHash를 생성하면 환경 차이가 hash 차이로 고정된다.
```

향후 strict profiling mode:

```yaml
validationHashPolicy:
  includeObservedResources: false
  hashOnlySuccessfulValidation: true
  includeExpectedFailureCases: false
```

### 4.4 Dry-run timeout 정책

Dry-run은 무한정 기다리지 않는다.

기본값:

```text
default timeout: 30 minutes
```

정책:

```text
- tool별 override 가능
- validationPlan 또는 profilePolicy에서 override 가능
- timeout 발생 시 validationHash 생성하지 않음
- validation status는 infra_failed 또는 timeout으로 기록
- observedResourceProfile에는 timeout event를 기록
- timeout 결과는 toolprofile에 기록 가능하지만, stable successful validation으로 보지 않음
```

예시:

```yaml
profilePolicy:
  timeout: 30m
  onTimeout: infra_failed
  produceValidationHash: false
```

### 4.5 observedProfileDigest

```text
observedProfileDigest
= application/vnd.nodevault.toolprofile.v1+json referrer digest
= optional additive field
= 기존 casHash에 포함하지 않음
```

용도:

```text
- dry-run observed profile artifact 추적
- integrity_health 계산 보조
- NodePalette/DagEdit UI에서 observed metadata 조회
```

### 4.6 securityScanDigest

```text
securityScanDigest
= application/vnd.nodevault.security.v1+json referrer digest
= optional additive field
= 기존 casHash에 포함하지 않음
```

용도:

```text
- security scan artifact 추적
- security status 표시
- integrity_health 계산 보조
- NodePalette에서 security badge 표시
```

### 4.7 runtimeProfileHash / validatedProfileHash 후보

향후 완전히 검증된 runtime profile 전체를 대표하는 identity가 필요할 수 있다.

그 경우 기존 `casHash`를 재정의하지 않고 새 이름을 사용한다.

후보:

```text
runtimeProfileHash
validatedProfileHash
```

포함 후보:

```text
- 기존 casHash
- validationHash
- observedProfileDigest
- targetPlatform
- runtimeFormat
- reference data digest
- resolved environment digest
```

이 결정은 Sprint 2 이후 별도로 다룬다.

---

## 5. OCI/ORAS Referrer 전략

### 5.1 toolspec referrer

기존 declared metadata.

```text
artifact type:
application/vnd.nodevault.toolspec.v1+json
```

역할:

```text
- ToolDefinition
- PortSpec
- declared runtime requirements
- license/provenance
- source evidence
- base runtime metadata
- target platforms
- runtime formats
```

예시:

```json
{
  "artifactType": "application/vnd.nodevault.toolspec.v1+json",
  "subject": {
    "mediaType": "application/vnd.oci.image.manifest.v1+json",
    "digest": "sha256:IMAGE_DIGEST"
  },
  "metadata": {
    "tool": {},
    "hashes": {
      "casHash": "sha256:EXISTING_TOOLDEFINITION_CAS_HASH",
      "authoringHash": "sha256:OPTIONAL_AUTHORING_HASH"
    },
    "ports": {},
    "declaredRuntimeRequirements": {},
    "license": {},
    "sourceEvidence": {},
    "targetPlatforms": [],
    "runtimeFormats": []
  }
}
```

### 5.2 toolprofile referrer

신규 observed metadata.

```text
artifact type:
application/vnd.nodevault.toolprofile.v1+json
```

역할:

```text
- validationRun
- observedIoProfile
- observedResourceProfile
- executionEnvironment
- contractCheck
- validationHash
- resourceRecommendation
```

예시:

```json
{
  "artifactType": "application/vnd.nodevault.toolprofile.v1+json",
  "subject": {
    "mediaType": "application/vnd.oci.image.manifest.v1+json",
    "digest": "sha256:IMAGE_DIGEST"
  },
  "profile": {
    "casHash": "sha256:EXISTING_TOOLDEFINITION_CAS_HASH",
    "validationHash": "sha256:VALIDATION_HASH",
    "validationStatus": "succeeded",
    "validationRun": {},
    "observedIoProfile": {},
    "observedResourceProfile": {},
    "contractCheck": {},
    "resourceRecommendation": {},
    "profileStatus": "observed"
  }
}
```

infra-level failure 예시:

```json
{
  "artifactType": "application/vnd.nodevault.toolprofile.v1+json",
  "subject": {
    "mediaType": "application/vnd.oci.image.manifest.v1+json",
    "digest": "sha256:IMAGE_DIGEST"
  },
  "profile": {
    "casHash": "sha256:EXISTING_TOOLDEFINITION_CAS_HASH",
    "validationHash": null,
    "validationStatus": "infra_failed",
    "failureReason": "timeout",
    "observedResourceProfile": {
      "timeout": true,
      "timeoutSeconds": 1800
    },
    "profileStatus": "inconclusive"
  }
}
```

### 5.3 security referrer

Security scan result는 toolprofile 안에 넣지 않고 별도 security referrer artifact로 분리한다.

```text
artifact type:
application/vnd.nodevault.security.v1+json
```

역할:

```text
- CVE summary
- vulnerability report digest
- misconfiguration summary
- secret exposure summary
- scanner identity
- scan timestamp
- scan freshness
- policy evaluation result
```

예시:

```json
{
  "artifactType": "application/vnd.nodevault.security.v1+json",
  "subject": {
    "mediaType": "application/vnd.oci.image.manifest.v1+json",
    "digest": "sha256:IMAGE_DIGEST"
  },
  "security": {
    "scanner": "trivy",
    "scannerVersion": "unknown",
    "source": "trivy-operator",
    "reportKind": "VulnerabilityReport",
    "reportDigest": "sha256:REPORT_DIGEST",
    "scanTime": "2026-04-28T00:00:00Z",
    "summary": {
      "critical": 0,
      "high": 2,
      "medium": 5,
      "low": 12,
      "unknown": 0
    },
    "policy": {
      "mode": "record_only",
      "result": "warning",
      "activeGate": false
    }
  }
}
```

분리 이유:

```text
- Security scan은 dry-run과 생명주기가 다르다.
- 새 CVE가 공개되면 security scan만 재실행하면 된다.
- toolprofile 안에 security 결과를 넣으면, 보안 재스캔 때 dry-run profile까지 갱신해야 하는 문제가 생긴다.
- security referrer는 scanner 교체나 주기적 재스캔에도 독립적으로 관리할 수 있다.
```

기본 정책:

```text
Security scan result 기록 = 기본
NodePalette UI 표시 = 기본
Active 전환 차단 = 정책 옵션
```

권장 통합 방향:

```text
trivy-operator
  → nodevault-security namespace에서 동작
  → VulnerabilityReport CR 생성

NodeVault reconcile loop
  → VulnerabilityReport 조회
  → security summary 추출
  → application/vnd.nodevault.security.v1+json 생성
  → image에 security referrer attach
  → index.Entry.securityScanDigest 갱신
  → integrity_health / security status 갱신
```

### 5.4 Referrer retention / GC 기본 정책

`toolprofile`과 `security` referrer는 반복 실행/재스캔으로 누적될 수 있다. 특히 security scan은 CVE DB 갱신으로 주기적으로 결과가 바뀔 수 있다.

기본 정책:

```text
Index.Entry에는 latest digest만 캐시한다.

observedProfileDigest
= latest toolprofile referrer digest

securityScanDigest
= latest security referrer digest
```

Retention 기본값:

```text
toolprofile:
  latest 3개 유지

security:
  latest 3개 또는 최근 30일 유지
```

GC 기본 전략:

```text
- 오래된 referrer는 즉시 삭제하지 않고 GC candidate로 표시한다.
- 실제 삭제는 registry capability, Harbor/OCI registry 정책, 감사 요구사항에 따라 별도 수행한다.
- 운영/임상 evidence가 붙은 profile/security artifact는 자동 삭제하지 않고 보존 또는 manual review 대상으로 둔다.
```

Open policy:

```text
referrerRetention:
  toolprofile:
    keepLatest: 3
  security:
    keepLatest: 3
    keepDays: 30
  deletionMode: mark_gc_candidate
```

### 5.5 signing / attestation 정책

metadata payload 안의 `signing` 필드는 실제 서명이 아니라 상태 summary다.

```yaml
signing:
  status: not_signed
  provider: none
```

실제 cosign signature, in-toto attestation, SLSA provenance 등은 별도 OCI artifact로 attach한다.

```text
metadata.signing
= 현재 서명/attestation 상태 표시 summary

actual signature / attestation
= 별도 OCI artifact
```

---

## 6. Functional Validation vs Security Scan

### 6.1 역할 분리

Validator/Profiler와 Security Scan은 서로 대체하지 않는다.

```text
Validator / Profiler
= sample data로 tool을 실제 실행
= functional behavior 검증
= observed I/O와 resource profile 수집

Security Scan
= image 보안 상태 검증
= CVE, misconfiguration, secret exposure 확인
= 보안 posture 기록
```

### 6.2 Security Scan 기본 정책

기록은 기본이다.

```text
- 어떤 image를 언제 scan했는가
- 어떤 scanner/version을 사용했는가
- critical/high/medium/low CVE가 몇 개인가
- 전체 report digest는 무엇인가
- scan 결과가 최신인가
```

Gate는 정책 옵션이다.

```text
기본값:
  record_only

선택 정책:
  critical CVE가 있으면 Active 전환 차단
  high CVE가 있으면 warning
  scan 결과가 오래되면 integrity_health degrade
```

이유:

```text
CVE가 있다고 해서 항상 해당 tool 실행 경로에서 exploit 가능한 것은 아니다.
예를 들어 image 안의 openssl CVE가 tool 실행 경로와 무관할 수 있다.
따라서 처음부터 Active 전환 차단을 hard default로 두면 운영상 과도한 차단이 될 수 있다.
```

### 6.3 trivy-operator 통합 방향

NodeVault가 Trivy CLI를 직접 호출하는 방식보다, trivy-operator의 CRD를 watch/read하는 방식이 더 좋다.

권장 흐름:

```text
trivy-operator
  → nodevault-security namespace에서 동작
  → VulnerabilityReport CR 생성

NodeVault reconcile loop
  → VulnerabilityReport 조회
  → security summary 추출
  → application/vnd.nodevault.security.v1+json 생성
  → image에 security referrer attach
  → index.Entry.securityScanDigest 갱신
  → integrity_health / security status 갱신
```

장점:

```text
- NodeVault가 Trivy CLI에 직접 의존하지 않는다.
- 나중에 다른 scanner로 교체하기 쉽다.
- Kubernetes-native CRD 기반으로 상태를 관찰할 수 있다.
- 주기적 재스캔과 report 갱신 흐름을 분리하기 쉽다.
```

### 6.4 index.Entry 확장 후보

```go
SecurityScanDigest string `json:"security_scan_digest,omitempty"`
```

또는 JSON 관점:

```json
{
  "security_scan_digest": "sha256:optional-security-referrer-digest",
  "security_status": "warning",
  "security_summary": {
    "critical": 0,
    "high": 2,
    "medium": 5
  }
}
```

이 필드는 optional이다. 기존 entry 호환성을 깨지 않는다.

### 6.5 integrity_health 반영 후보

```text
Healthy
  - image 존재
  - toolspec referrer 존재
  - optional: toolprofile referrer 존재
  - optional: security scan result 존재
  - security policy 통과 또는 warning 수준

Partial
  - image는 있으나 toolspec/security/profile 일부 누락

Warning / Risky
  - critical/high CVE 존재
  - 단, Active 차단 여부는 정책에 따라 결정

Blocked
  - 조직 정책상 critical CVE 차단이 켜져 있고 위반됨
```

---

## 7. declared vs observed 모델

### 7.1 declared metadata

declared metadata는 authoring 또는 ToolDefinition 등록 시점에 존재한다.

NodeVault 통합에서는 기존 PortSpec을 기준으로 한다.

```text
declared metadata
= ToolDefinition
= PortSpec
= declared runtime requirements
= license/provenance
= source evidence
= toolspec referrer
```

### 7.2 observed metadata

observed metadata는 dry-run 이후에 생성된다.

```text
observed metadata
= observedIoProfile
= observedResourceProfile
= executionEnvironment
= contractCheck
= validationHash
= toolprofile referrer
```

중요 원칙:

```text
observed metadata는 declared metadata를 대체하지 않는다.
observed metadata는 declared metadata를 검증하고 보강한다.
```

### 7.3 observedIoProfile 초기 범위

초기에는 semantic type 자동 감지를 하지 않는다.

확인하는 것:

```text
- output path에 파일이 생겼는가
- 파일 개수가 맞는가
- 파일 크기가 0보다 큰가
- exit code가 0인가
```

초기에는 하지 않는 것:

```text
- FASTQ/SAM/BAM/VCF 자동 판별
- BAM header 검사
- VCF normalization 비교
- semantic equivalence 검증
```

예시:

```yaml
observedIoProfile:
  validationRunId: dryrun-001
  outputs:
    - port: alignment
      declaredFormat: SAM
      paths:
        - /out/alignment.sam
      exists: true
      count: 1
      totalBytes: 98765
      typeDetection:
        status: not_performed
        detectedType: unknown
        confidence: none
```

### 7.4 observedResourceProfile

resource 관측값은 반드시 실행 환경과 함께 저장한다.

```yaml
observedResourceProfile:
  validationRunId: dryrun-001
  executionEnvironment:
    type: k8s_pod
    platform: linux/amd64
    containerRuntime: containerd
    cpuLimit: "2"
    memoryLimit: "4Gi"
    nodeClass: unknown
    cpuModel: unknown
    totalMemory: unknown
    notes: "sample dry-run environment; not production sizing guarantee"
  durationSeconds: 18.4
  cpu:
    peakCores: 1.3
    avgCores: 0.8
  memory:
    peakBytes: 734003200
  disk:
    readBytes: 120000000
    writeBytes: 98000000
  exitCode: 0
```

UI 표시 문구:

```text
샘플 dry-run에서 관측된 값입니다.
운영 리소스 보장값이 아니라 sizing 참고값입니다.
```

---

## 8. RunnerNode Spec

RunnerNode는 DagEdit 계층 5의 핵심이다.

### 8.1 원칙

```text
RunnerNode는 casHash를 필수로 가진다.
stableRef는 UI 표시/검색용 snapshot이다.
실행 pin은 casHash다.
observedProfileDigest와 validationHash는 optional이다.
```

### 8.2 MVP JSON

```json
{
  "nodeType": "runner",
  "casHash": "sha256:existing-tooldefinition-cas",
  "stableRef": "bwa@0.7.17",
  "displaySnapshot": {
    "label": "BWA 0.7.17",
    "category": "Alignment",
    "icon": null
  },
  "portBindings": {
    "inputs": {
      "reads": {
        "connectedTo": "parent-node:output-port"
      }
    },
    "outputs": {
      "alignment": {}
    }
  },
  "portMetadata": {
    "source": "declared+observed",
    "toolspecReferrerDigest": "sha256:optional-toolspec-digest",
    "observedProfileDigest": "sha256:optional-toolprofile-digest",
    "validationHash": "sha256:optional-validation-hash"
  }
}
```

### 8.3 portBindings vs portMetadata

```text
portBindings
= 실제 DAG edge 연결

portMetadata
= UI compatibility 판단과 표시를 위한 metadata
```

### 8.4 DagEdit 연결 UX

예시:

```text
Parent output:
  FASTQ pair

Child input:
  FASTQ pair

Compatibility:
  matched by declared PortSpec
  observed dry-run evidence available
```

또는:

```text
Parent output:
  BAM

Child input:
  FASTQ

Compatibility:
  mismatch
```

---

## 9. NodePalette / UI Default Behavior

Optional metadata가 추가되면 기존 legacy tool에는 `observedProfileDigest`, `validationHash`, `securityScanDigest`가 없을 수 있다. 이 경우 UI와 query/filter 동작을 명확히 해야 한다.

### 9.1 기본 badge 정책

```text
observedProfileDigest 없음
→ badge: Unverified
→ 연결은 가능하지만 observed dry-run evidence 없음 표시

validationHash 없음
→ badge: No dry-run profile
→ functional validation hash 없음 표시

securityScanDigest 없음
→ badge: Security Not Scanned
→ 기본 목록에서는 숨기지 않음
→ “scanned only” filter 선택 시 제외

securityScanDigest 있음 + policy warning
→ badge: Security Warning

security policy blocked
→ badge: Security Blocked
→ Active gate 정책이 켜진 경우에만 Active 전환 차단
```

### 9.2 Query / Filter 기본 정책

```text
기본 목록:
  legacy tool 포함
  observed profile 없는 tool 포함
  security scan 없는 tool 포함

verified only:
  observedProfileDigest 있음
  validationHash 있음
  validation status succeeded

security scanned only:
  securityScanDigest 있음

security pass only:
  securityScanDigest 있음
  policy result pass 또는 warning 허용 여부는 정책에 따름
```

### 9.3 NodePalette 표시 예시

```text
BWA 0.7.17
- CAS: sha256:...
- Validation: No dry-run profile
- Security: Not Scanned
- Status: Active
```

또는:

```text
BWA 0.7.17
- CAS: sha256:...
- Validation: Observed dry-run passed
- Security: Warning, 2 High CVEs
- Status: Active, security gate is record_only
```

---

## 10. NodeVault v0.6.1 Mapping Table

이 표는 NodeVault docs에 `NODEVAULT_V03_MAPPING.md`로 별도 저장한다.

| v0.3/v0.6.1 개념 | NodeVault 기존/권장 개념 | 처리 |
|---|---|---|
| ToolAuthoringBundle | NodeKit draft / BuildRequest 계열 | NodeKit 쪽 개념으로 유지. NodeVault core 개념으로 남발하지 않음 |
| ToolRecipe | legacy-import 도구 산출물 | NodeVault core에는 넣지 않음 |
| BaseRuntimeProfile | NodeKit/legacy-import input | NodeVault core에는 metadata로만 저장 가능 |
| declaredIoContract | 기존 PortSpec 확장 | 기존 PortSpec 유지, staging 등만 추가 |
| PortSpec.format | v0.3 type | 기존 format 유지, canonical enum/alias normalization 검토 |
| PortSpec.shape | v0.3 multiplicity | 기존 shape 유지 |
| observedIoProfile | 신규 toolprofile referrer | `application/vnd.nodevault.toolprofile.v1+json` |
| observedResourceProfile | 신규 toolprofile referrer | executionEnvironment 포함 |
| security metadata | 신규 security referrer | `application/vnd.nodevault.security.v1+json` |
| RegisteredToolCandidate | 기존 index.Entry draft/extension | 새 이름 남발 금지 |
| toolspec metadata | 기존 `application/vnd.nodevault.toolspec.v1+json` | declared spec 용도로 유지 |
| observed metadata | 신규 `application/vnd.nodevault.toolprofile.v1+json` | dry-run 이후 attach |
| securityScanDigest | 신규 additive field | optional |
| casHash | 기존 ToolDefinition CAS identity | 계산 방식 변경 금지 |
| authoringHash | 신규 additive field | optional |
| validationHash | 신규 additive field | successful validation에만 생성 |
| observedProfileDigest | 신규 additive field | optional |
| metadataArtifactDigest | 일반 설계 용어 | NodeVault에서는 toolspec/toolprofile/security digest로 분리 |
| RunnerNode | DagEdit 모델 신규 정의 | `casHash` 필수 |
| stableRef | UI/search/grouping 용도 | 실행 pin 아님 |
| portBindings | DagEdit RunnerNode edge binding | 실제 DAG 연결 |
| portMetadata | DagEdit UI compatibility metadata | toolspec/toolprofile에서 공급 |

---

## 11. Legacy Dockerfile Import Tool

Legacy Dockerfile 분석기는 NodeVault core에 넣지 않는다.

위치 후보:

```text
tools/legacy-import/
또는 별도 repo
```

역할:

```text
- ICG Dockerfile scanner
- Dockerfile parser
- classifier
- image lineage graph 생성
- BaseRuntimeProfile YAML 생성
- ToolRecipe YAML 생성
- CompositeRecipe YAML 생성
- BWA / Samtools / FastQC migration helper
```

이 도구의 결과물은 다음 중 하나로 사용한다.

```text
- NodeKit이 import
- NodeVault 등록 request의 입력으로 사용
- migration report로만 사용
```

주의:

```text
legacy Dockerfile은 production source of truth가 아니다.
legacy Dockerfile은 historical operational evidence다.
```

따라서 이 도구는 Dockerfile을 조용히 고치면 안 된다.

```text
Do not silently fix legacy Dockerfiles.
Record warnings.
```

---

## 12. External Reference Project Scan

외부 프로젝트 비교는 코드가 아니라 문서 트랙으로 진행한다.

대상:

```text
BioContainers / Bioconda
Seqera Containers / Wave
nf-core modules
Galaxy / Planemo
CWL
Dockstore / GA4GH TRS
Snakemake
WDL / Cromwell / Terra-style runtime model
DNAnexus, 필요 시
```

비교 기준:

```text
1. 시작점
   - package
   - Dockerfile
   - existing image
   - workflow/paper/validated pipeline

2. 산출물
   - image URI/digest
   - Dockerfile
   - Conda environment
   - lock file
   - workflow descriptor
   - tool wrapper
   - registry entry
   - ORAS/OCI metadata

3. 재현성 단위
   - tool version
   - package spec
   - resolved environment
   - image digest
   - workflow commit
   - reference data digest
   - validation sample result

4. NodeKit이 흡수할 점
5. NodeVault가 흡수할 점
6. 배제할 점
```

---

## 13. Delivery Map — 설계에서 실제 적용까지

이 v0.6.1 문서는 설계 결정 기록이다. 실제 적용은 각 repo에서 다음과 같이 진행한다.

### 13.1 Repo별 적용 위치 요약

```text
NodeVault repo
├── docs/TOOL_CONTRACT_V0_3_DRAFT.md      ← Sprint 0에서 커밋
├── docs/OBSERVED_PROFILE_SPEC.md          ← Sprint 0에서 커밋
├── docs/SECURITY_SCAN_SPEC.md             ← Security 병렬 트랙에서 커밋
├── docs/RUNNER_NODE_SPEC.md               ← Sprint 0에서 커밋
├── docs/NODEVAULT_V03_MAPPING.md          ← Sprint 0에서 커밋
├── docs/TOOL_NODE_SPEC.md                 ← Sprint 0에서 계층 5 업데이트
├── pkg/index/schema.go                    ← Sprint 1에서 optional field 추가 후보
├── pkg/oras/ 또는 referrer 관련 package    ← Sprint 1에서 toolprofile artifact type 추가
├── pkg/oras/ 또는 referrer 관련 package    ← Security 병렬 트랙에서 security artifact type 추가
├── pkg/security/ 또는 scanner adapter       ← Security 병렬 트랙 후보
├── pkg/validator/                         ← Sprint 2에서 신규 패키지
└── pkg/build/service.go 또는 대응 flow      ← Sprint 2에서 profiler hook 연결

NodeKit repo
├── NodeVault ToolContract/PortSpec 기반 authoring draft 모델 반영  ← Sprint 3 이후
├── PortSpec staging / format / shape 편집 UX 반영                 ← Sprint 3 이후
└── Submit to NodeVault UX 반영                                    ← Sprint 3 이후

DagEdit repo
├── RunnerNode 모델에 casHash 필수 필드 추가                       ← Sprint 3
├── observedProfileDigest / validationHash optional field 추가      ← Sprint 3
└── portBindings / portMetadata 모델 추가                           ← Sprint 3

tools/legacy-import 또는 별도 repo
├── scanner.go                                                     ← 병렬 트랙
├── parser.go                                                      ← 병렬 트랙
├── classifier.go                                                  ← 병렬 트랙
├── lineage.go                                                     ← 병렬 트랙
└── BaseRuntimeProfile / ToolRecipe / CompositeRecipe generator     ← 병렬 트랙
```

### 13.2 Sprint별 Delivery Table

| Sprint | Repo / 위치 | 실제 산출물 | 성격 | 핵심 원칙 |
|---|---|---|---|---|
| Sprint 0 | NodeVault/docs/TOOL_CONTRACT_V0_3_DRAFT.md | 기존 ToolDefinition/PortSpec/casHash 호환성 문서 | 문서 | 기존 casHash 변경 금지 |
| Sprint 0 | NodeVault/docs/OBSERVED_PROFILE_SPEC.md | toolprofile referrer / observed profile spec | 문서 | toolspec과 toolprofile 분리 |
| Sprint 0 | NodeVault/docs/RUNNER_NODE_SPEC.md | DagEdit RunnerNode casHash pinning spec | 문서 | RunnerNode casHash 필수 |
| Sprint 0 | NodeVault/docs/NODEVAULT_V03_MAPPING.md | v0.3/v0.6.1 개념과 기존 NodeVault 개념 매핑 | 문서 | 새 용어 남발 방지 |
| Sprint 0 | NodeVault/docs/TOOL_NODE_SPEC.md | 계층 5 RunnerNode 업데이트 | 문서 수정 | 계층 1~4 보존 |
| Sprint 1 | NodeVault/pkg/index/schema.go 또는 대응 파일 | `validationHash`, `observedProfileDigest` optional field | 코드 | additive field only |
| Sprint 1 | NodeVault/pkg/oras/ 또는 referrer 관련 package | `application/vnd.nodevault.toolprofile.v1+json` type 추가 | 코드 | 기존 toolspec 유지 |
| 병렬 Security | NodeVault/docs/SECURITY_SCAN_SPEC.md | security referrer / Trivy operator integration spec | 문서 | security는 별도 검증 축 |
| 병렬 Security | NodeVault/pkg/oras/ 또는 referrer 관련 package | `application/vnd.nodevault.security.v1+json` type 추가 | 코드 | toolspec/toolprofile과 분리 |
| 병렬 Security | NodeVault/pkg/index/schema.go 또는 대응 파일 | `securityScanDigest` optional field | 코드 | additive field only |
| 병렬 Security | nodevault-security namespace | trivy-operator 배포/연동 | 인프라 | NodeVault가 CRD watch/read |
| Sprint 2 | NodeVault/pkg/validator/ | Validator/Profiler 패키지 | 코드 | 최소 dry-run부터 시작 |
| Sprint 2 | NodeVault/pkg/build/service.go 또는 대응 flow | dry-run profiler hook 연결 | 코드 | 기존 Build/Register flow 보존 |
| Sprint 3 | DagEdit model | RunnerNode `casHash`, optional `observedProfileDigest` | 코드 | 실행 pin은 casHash |
| Sprint 3 | DagEdit model/UI | `portBindings`, `portMetadata` 반영 | 코드/UI | binding과 metadata 분리 |
| Sprint 3 이후 | NodeKit | NodeVault ToolContract/PortSpec 기반 authoring UX | 코드/UI | NodeVault canonical contract 편집 |
| Sprint 3 이후 | NodeKit | Submit to NodeVault flow | 코드/UI | NodeKit은 authoring, NodeVault는 register |
| 병렬 | tools/legacy-import 또는 별도 repo | scanner/parser/classifier/lineage | 도구 | NodeVault core 밖 유지 |
| 병렬 | tools/legacy-import/docs | legacy Dockerfile findings / migration guide | 문서 | legacy는 operational evidence |
| 병렬 | reference scan docs | BioContainers/Seqera/Galaxy/nf-core 등 비교 | 문서 | 좋은 점 흡수, 종속 회피 |

### 13.3 Repo별 책임 경계

#### NodeVault repo

NodeVault repo는 canonical Tool catalog, CAS identity, OCI referrer, validation/profile, security scan result, catalog exposure 책임을 가진다.

NodeVault에 들어갈 것:

```text
- TOOL_CONTRACT_V0_3_DRAFT.md
- OBSERVED_PROFILE_SPEC.md
- SECURITY_SCAN_SPEC.md
- RUNNER_NODE_SPEC.md
- NODEVAULT_V03_MAPPING.md
- TOOL_NODE_SPEC.md layer 5 업데이트
- toolprofile artifact type
- security artifact type
- observedProfileDigest / validationHash optional fields
- securityScanDigest optional field
- Validator / Profiler package
- Security scan integration adapter, 병렬 트랙
- Build/Register flow profiler hook
```

NodeVault에서 하지 않을 것:

```text
- legacy Dockerfile parser를 core package로 포함
- BaseRuntimeProfile/ToolRecipe 추출기를 core 책임으로 포함
- 기존 casHash 계산 방식 변경
- 기존 catalog path 변경
- 기존 toolspec referrer payload 전면 교체
```

#### NodeKit repo

NodeKit은 authoring UI/adapter다. NodeVault의 ToolContract/PortSpec을 사용자가 편집·제출할 수 있게 한다.

NodeKit에 들어갈 것:

```text
- NodeVault ToolContract/PortSpec 기반 draft model
- Base Runtime / Tool Source / PortSpec 편집 UX
- PortSpec staging / format / shape 편집 UX
- license / sourceEvidence / validationPlan authoring UX
- Submit to NodeVault flow
```

주의:

```text
ToolDefinition의 canonical source of truth가 NodeVault라면,
NodeKit은 ToolDefinition을 독자적으로 재정의하지 않는다.
NodeKit은 NodeVault contract를 편집하고 제출하는 authoring surface다.
```

#### DagEdit repo

DagEdit는 pipeline authoring UI다. RunnerNode는 NodeVault catalog의 ToolDefinition을 `casHash`로 pin한다.

DagEdit에 들어갈 것:

```text
- RunnerNode.casHash 필수 필드
- RunnerNode.stableRef/displaySnapshot UI용 snapshot
- RunnerNode.observedProfileDigest optional field
- RunnerNode.validationHash optional field
- portBindings
- portMetadata
- NodePalette에서 받은 declared/observed metadata 표시
```

#### tools/legacy-import

Legacy Dockerfile 분석은 NodeVault core 밖에서 수행한다.

들어갈 것:

```text
- scanner
- parser
- classifier
- lineage graph
- BaseRuntimeProfile YAML generator
- ToolRecipe YAML generator
- CompositeRecipe YAML generator
- migration report
```

---

## 14. Sprint Plan — 일정과 검증 가능한 완료 기준

이 섹션은 v0.6.1의 핵심이다. 각 Sprint는 “문서 작성”, “패키지 추가”, “필드 추가” 같은 작업 목록만으로 완료하지 않는다. 반드시 테스트, 명령, grep, golden check, serialization test, backward compatibility test 등으로 완료 여부를 확인한다.

전체 기본 일정:

```text
Sprint 0: 1주
Sprint 1: 2주
Sprint 2: 2~3주
Sprint 3: 2주

총 기간: 7~8주

병렬 트랙:
- Legacy import tool: Sprint 0부터 병렬 시작 가능
- External reference scan: 아무 때나 가능, 문서 트랙
- Security Scan Integration: Sprint 2 이후 병렬 진행 권장
```

공통 gate:

```text
- 기존 테스트가 깨지지 않는다.
- 기존 casHash 계산 방식이 변경되지 않는다.
- 기존 assets/catalog/{casHash}.tooldefinition 경로 의미가 유지된다.
- 기존 index entry가 새 optional field 없이도 정상 로드된다.
- 새 필드는 모두 backward-compatible optional field로 추가한다.
- index update 중 오류가 발생해도 기존 index를 손상시키지 않는다.
```

### Sprint 0 — NodeVault 문서/계약 정렬

예상 기간:

```text
1주
```

실제 적용 위치:

```text
NodeVault/docs/
```

목표:

```text
기존 NodeVault v0.2 구조와 v0.3/v0.6.1 확장 개념을 충돌 없이 연결한다.
이 Sprint는 문서/계약 정렬이 중심이며, 코드 변경은 최소화한다.
```

필수 산출물:

```text
NodeVault/docs/TOOL_CONTRACT_V0_3_DRAFT.md
NodeVault/docs/OBSERVED_PROFILE_SPEC.md
NodeVault/docs/RUNNER_NODE_SPEC.md
NodeVault/docs/NODEVAULT_V03_MAPPING.md
NodeVault/docs/TOOL_NODE_SPEC.md 업데이트
```

선택 산출물:

```text
NodeVault/docs/SECURITY_SCAN_SPEC.md 초안
```

Sprint 0에서 반드시 명시할 결정:

```text
- 기존 casHash 계산 방식 유지
- existing assets/catalog/{casHash}.tooldefinition 경로 유지
- authoringHash / validationHash / observedProfileDigest는 additive field
- toolspec / toolprofile referrer 분리
- security referrer는 별도 병렬 검증 축
- 기존 PortSpec 확장
- RunnerNode casHash 필수
- legacy import는 NodeVault core 밖
```

검증 기준:

1. 문서 존재 확인

```bash
test -f docs/TOOL_CONTRACT_V0_3_DRAFT.md
test -f docs/OBSERVED_PROFILE_SPEC.md
test -f docs/RUNNER_NODE_SPEC.md
test -f docs/NODEVAULT_V03_MAPPING.md
grep -n "Layer 5\|RunnerNode\|casHash" docs/TOOL_NODE_SPEC.md
```

2. git commit 확인

```bash
git log --oneline -- docs/
```

3. 기존 개념과 매핑 표 대조

```bash
grep -R "PortSpec\|casHash\|StableRef\|LifecyclePhase\|IntegrityHealth" pkg/ docs/ || true
```

4. 기존 ToolContract와 PortSpec 확장 호환성 체크

체크리스트:

```text
- name 유지
- role 유지
- format 유지
- shape 유지
- required 유지
- class 유지
- constraints 유지
- staging 등 신규 필드는 additive
```

5. 기존 테스트 통과

```bash
go test ./...
```

선택 코드 stub을 추가하는 경우 추가 검증:

```text
TestIndexBackwardCompatibility_V04Fields
```

완료 판정:

```text
- 필수 문서 5개가 NodeVault/docs/에 존재한다.
- TOOL_NODE_SPEC.md에 RunnerNode 계층 5가 업데이트되었다.
- NODEVAULT_V03_MAPPING.md에 기존 개념과 v0.3/v0.6.1 개념의 매핑표가 있다.
- 기존 PortSpec/casHash/stableRef/index 의미를 변경하지 않는다고 명시되어 있다.
- go test ./... 통과.
- 선택 코드 stub이 있다면 backward compatibility 테스트 통과.
```

### Sprint 1 — NodeVault observed profile 기반 추가

예상 기간:

```text
2주
```

실제 적용 위치:

```text
NodeVault/pkg/index/schema.go 또는 대응 index schema 파일
NodeVault/pkg/oras/ 또는 referrer 관련 package
NodeVault/docs/OBSERVED_PROFILE_SPEC.md 보강
```

목표:

```text
기존 toolspec referrer는 유지하고, dry-run observed profile을 위한 toolprofile referrer를 별도 artifact로 추가한다.
```

필수 산출물:

```text
application/vnd.nodevault.toolprofile.v1+json artifact type
observedProfileDigest optional field
validationHash optional field
ToolProfile payload model 또는 schema
```

검증 기준:

1. toolprofile artifact type 상수 존재

```bash
grep -R "application/vnd.nodevault.toolprofile.v1+json\|toolprofile" pkg/
```

2. toolprofile referrer push 테스트

```text
TestPushToolProfileReferrer
```

3. toolspec + toolprofile 공존 테스트

```text
TestDualReferrerCoexistence
```

4. index mixed entry 테스트

```text
TestIndexMixedEntries_V04
```

5. 기존 casHash 안정성 테스트

```text
TestCasHashStability
또는
TestExistingToolDefinitionCasHashGolden
```

6. index fallback 테스트

```text
TestIndex_FallbackOnError
```

확인 내용:

```text
index update 중 오류가 발생하면 기존 index 파일이 손상되지 않는다.
partial write가 발생하지 않는다.
마지막으로 유효했던 index 상태로 fallback할 수 있다.
```

완료 판정:

```text
- toolprofile artifact type이 코드에 존재한다.
- TestPushToolProfileReferrer 통과.
- TestDualReferrerCoexistence 통과.
- TestIndexMixedEntries_V04 통과.
- TestIndex_FallbackOnError 통과.
- 기존 casHash golden/stability 테스트 통과.
- go test ./... 통과.
```

### Sprint 2 — Validator / Profiler 연결

예상 기간:

```text
2~3주
```

실제 적용 위치:

```text
NodeVault/pkg/validator/
NodeVault/pkg/build/service.go 또는 대응 build/register flow
NodeVault/pkg/oras/ 또는 referrer 관련 package
NodeVault/pkg/index/schema.go 또는 대응 index schema 파일
```

목표:

```text
Build/Register 흐름에 Validator/Profiler hook을 연결하고, 최소 dry-run으로 observed I/O profile을 생성한다.
```

필수 산출물:

```text
pkg/validator/ 패키지
ValidationRun model
ObservedIoProfile model
ObservedResourceProfile model
ContractCheck model
ValidationHash 계산 함수
Build/Register flow의 profiler hook
Toolprofile attach flow
Dry-run timeout policy
Infra-level failure classification
```

최소 dry-run 기준:

```text
command:
  echo hello > /out/result.txt

expected:
  /out/result.txt exists=true
  count=1
  totalBytes>0
```

검증 기준:

1. validator 패키지 컴파일

```bash
go build ./pkg/validator/...
```

2. profiler hook 호출 테스트

```text
TestBuildAndRegister_ProfilerHookCalled
```

3. output capture 테스트

```text
TestProfiler_OutputCapture
```

4. validationHash deterministic 테스트

```text
TestValidationHash_Deterministic
```

5. observedResourceProfile 제외 정책 테스트

```text
TestValidationHash_ExcludesObservedResourcesByDefault
```

6. successful validation만 hash 생성 테스트

```text
TestValidationHash_OnlyForSuccessfulFunctionalValidation
```

확인 내용:

```text
successful validation이면 validationHash가 생성된다.
infra_failed 또는 timeout이면 validationHash가 생성되지 않는다.
```

7. infra failure classification 테스트

```text
TestValidator_InfraFailureClassification
```

확인 내용:

```text
OOMKilled, timeout, eviction, image pull failure, scheduling failure가 infra_failed 또는 profile_inconclusive로 분류된다.
```

8. dry-run timeout 테스트

```text
TestProfiler_TimeoutProducesInconclusiveProfile
```

확인 내용:

```text
timeout 발생 시 validationHash는 생성되지 않고,
toolprofile에는 timeout event와 profileStatus=inconclusive가 기록된다.
```

9. Build/Register + profile attach 통합 테스트

```text
TestBuildAndRegister_WithProfile
```

10. 기존 casHash 안정성 테스트

```text
TestCasHashStability
또는
TestExistingToolDefinitionCasHashGolden
```

11. index fallback 테스트

```text
TestIndex_FallbackOnError
```

완료 판정:

```text
- go build ./pkg/validator/... 성공.
- TestBuildAndRegister_ProfilerHookCalled 통과.
- TestProfiler_OutputCapture 통과.
- TestValidationHash_Deterministic 통과.
- TestValidationHash_ExcludesObservedResourcesByDefault 통과.
- TestValidationHash_OnlyForSuccessfulFunctionalValidation 통과.
- TestValidator_InfraFailureClassification 통과.
- TestProfiler_TimeoutProducesInconclusiveProfile 통과.
- TestBuildAndRegister_WithProfile 통과.
- TestIndex_FallbackOnError 통과.
- 기존 casHash golden/stability 테스트 통과.
- go test ./... 통과.
```

### Sprint 3 — DagEdit RunnerNode 연결

예상 기간:

```text
2주
```

실제 적용 위치:

```text
DagEdit repo의 RunnerNode/DagItems 모델
DagEdit repo의 port binding / node serialization 관련 코드
NodePalette integration 지점
필요 시 NodeKit submit UX 병행
```

목표:

```text
NodeVault catalog에서 DagEdit RunnerNode까지 casHash 기반 pinning을 실제 모델로 연결한다.
```

필수 산출물:

```text
RunnerNode.casHash 필수 필드
RunnerNode.stableRef/displaySnapshot UI snapshot
RunnerNode.observedProfileDigest optional field
RunnerNode.validationHash optional field
portBindings
portMetadata
catalog response → RunnerNode 생성 flow
UI default badge policy
```

검증 기준:

1. casHash 필수성 테스트

```text
TestRunnerNode_WithoutCasHash_Fails
```

2. serialization round-trip 테스트

```text
TestRunnerNode_Serialization_RoundTrip
```

3. optional field absence 테스트

```text
TestRunnerNode_OptionalFields_Absent
```

4. port binding compatibility 테스트

```text
TestPortBinding_ParentToChild
```

확인 내용:

```text
parent output format=SAM, child input format=SAM → matched
parent output format=BAM, child input format=FASTQ → mismatch
```

5. catalog response 기반 RunnerNode 생성 테스트

```text
TestRunnerNode_FromCatalogResponse
```

6. UI badge default 테스트

```text
TestNodePaletteBadge_DefaultsForMissingOptionalMetadata
```

확인 내용:

```text
observedProfileDigest 없음 → Unverified 또는 No dry-run profile
securityScanDigest 없음 → Security Not Scanned
legacy tool은 기본 목록에 계속 표시됨
```

완료 판정:

```text
- RunnerNode.casHash가 필수로 검증된다.
- serialization round-trip에서 casHash가 보존된다.
- optional observedProfileDigest/validationHash 없이도 동작한다.
- portBindings compatibility 테스트 통과.
- catalog response 기반 RunnerNode 생성 테스트 통과.
- UI badge default 테스트 통과.
- DagEdit 관련 테스트 전체 통과.
```

### Parallel Track — Security Scan Integration

예상 기간:

```text
1~2주
Sprint 2 이후 병렬 진행 권장
```

실제 적용 위치:

```text
NodeVault/docs/SECURITY_SCAN_SPEC.md
NodeVault/pkg/oras/ 또는 referrer 관련 package
NodeVault/pkg/index/schema.go 또는 대응 index schema 파일
NodeVault/pkg/security/ 또는 scanner adapter 후보
nodevault-security namespace / trivy-operator 배포 manifest 후보
```

목표:

```text
Security scan result를 functional toolprofile과 분리된 별도 security referrer로 관리한다.
```

필수 산출물:

```text
application/vnd.nodevault.security.v1+json artifact type
SecurityScan payload model 또는 schema
securityScanDigest optional field
Trivy VulnerabilityReport fixture parser
record_only policy evaluator
retention/GC policy stub
```

검증 기준:

1. security artifact type 상수 존재

```bash
grep -R "application/vnd.nodevault.security.v1+json\|securityScanDigest" pkg/ docs/
```

2. VulnerabilityReport fixture 변환 테스트

```text
TestSecurityReport_FromTrivyVulnerabilityReport
```

3. security referrer payload 생성 테스트

```text
TestSecurityReferrerPayload_Generate
```

4. index backward compatibility 테스트

```text
TestIndexBackwardCompatibility_SecurityScanDigest
```

5. record_only policy 테스트

```text
TestSecurityPolicy_RecordOnlyDoesNotBlockActive
```

6. triple referrer 공존 테스트, 선택

```text
TestTripleReferrerCoexistence
```

7. retention policy 테스트

```text
TestSecurityRetention_MarksOldReferrersAsGCCandidates
```

확인 내용:

```text
latest security referrer digest는 index.Entry.securityScanDigest에 캐시된다.
오래된 security referrer는 삭제하지 않고 GC candidate로 표시된다.
```

완료 판정:

```text
- SECURITY_SCAN_SPEC.md 작성.
- security artifact type 존재.
- TestSecurityReport_FromTrivyVulnerabilityReport 통과.
- TestSecurityReferrerPayload_Generate 통과.
- TestIndexBackwardCompatibility_SecurityScanDigest 통과.
- TestSecurityPolicy_RecordOnlyDoesNotBlockActive 통과.
- TestSecurityRetention_MarksOldReferrersAsGCCandidates 통과.
- 선택 시 TestTripleReferrerCoexistence 통과.
- 기존 casHash 테스트 영향 없음.
```

### Parallel Track — Legacy Dockerfile Import Tool

예상 기간:

```text
2~3주
Sprint 0부터 병렬 시작 가능
```

실제 적용 위치:

```text
tools/legacy-import/
또는 별도 repo
```

목표:

```text
기존 ICG Dockerfile을 historical operational evidence로 분석하고, NodeKit/NodeVault authoring에 사용할 수 있는 migration artifact를 생성한다.
```

필수 산출물:

```text
scanner
parser
classifier
lineage graph generator
BaseRuntimeProfile YAML generator
ToolRecipe YAML generator
BWA/Samtools/FastQC 대표 migration result
```

검증 기준:

```text
TestLegacyImport_ScanDockerfiles
TestLegacyImport_ClassifyBaseRuntime
TestLegacyImport_ClassifyToolRecipe
TestLegacyImport_ClassifyCompositeRecipe
TestLegacyImport_LineageGraph
TestLegacyImport_GenerateBwaToolRecipe
```

완료 판정:

```text
- 대표 Dockerfile scan 성공.
- icg_base_1.0은 base_runtime으로 분류.
- icg_bwa_0.7.17은 tool_recipe로 분류.
- composite Dockerfile은 composite_recipe로 분류.
- BWA ToolRecipe YAML 생성.
- legacy Dockerfile의 문제는 자동 수정하지 않고 warning으로 기록.
```

### Parallel Track — External Reference Project Scan

예상 기간:

```text
1주
문서 트랙이므로 어느 Sprint와도 병행 가능
```

대상:

```text
BioContainers / Bioconda
Seqera Containers / Wave
nf-core modules
Galaxy / Planemo
CWL
Dockstore / GA4GH TRS
Snakemake
WDL / Cromwell
DNAnexus
```

검증 기준:

```text
REFERENCE_PROJECT_SCAN.md에 각 프로젝트별로 다음 항목이 채워져 있다.

- 시작점
- 산출물
- 재현성 단위
- NodeKit이 흡수할 점
- NodeVault가 흡수할 점
- 배제할 점
```

완료 판정:

```text
- 최소 6개 이상 프로젝트 비교 완료.
- NodeKit/NodeVault에 흡수할 점과 배제할 점이 분리되어 있음.
- 특정 외부 workflow 엔진에 내부 모델이 종속되지 않는다는 결론이 명시되어 있음.
```

---

## 15. Codex Prompt v0.6.1

아래 프롬프트는 Sprint 0에 바로 사용할 수 있다.

```text
You are working on the v0.6.1 NodeVault upgrade for NodeKit/NodeVault.

Context:
- NodeVault already has ToolDefinition, PortSpec, index.Entry, catalog, stableRef:casHash = 1:N, lifecycle_phase + integrity_health, and OCI referrer support.
- Do not create a separate full PoC that redefines the same concepts under new names.
- Upgrade NodeVault directly and add v0.3/v0.6.1 concepts as additive extensions.
- Legacy Dockerfile parsing must remain outside NodeVault core as a separate tools/legacy-import or separate repo.

Primary Sprint 0 goal:
Align existing NodeVault docs/contracts with the v0.6.1 design without breaking existing NodeVault behavior.

Required documents:
1. docs/TOOL_CONTRACT_V0_3_DRAFT.md
2. docs/OBSERVED_PROFILE_SPEC.md
3. docs/RUNNER_NODE_SPEC.md
4. docs/NODEVAULT_V03_MAPPING.md
5. Update docs/TOOL_NODE_SPEC.md layer 5 section

Optional document:
6. docs/SECURITY_SCAN_SPEC.md draft

Critical decisions to preserve:
1. Do not change existing casHash calculation.
   - Existing casHash remains ToolDefinition CAS identity.
   - Existing assets/catalog/{casHash}.tooldefinition path semantics must be preserved.
   - authoringHash, validationHash, observedProfileDigest, and securityScanDigest are additive fields.
   - If a future identity is needed for a fully validated runtime profile, use runtimeProfileHash or validatedProfileHash instead of redefining casHash.

2. Split toolspec, toolprofile, and security OCI referrers.
   - application/vnd.nodevault.toolspec.v1+json = declared ToolDefinition/PortSpec metadata.
   - application/vnd.nodevault.toolprofile.v1+json = observed dry-run profile metadata.
   - application/vnd.nodevault.security.v1+json = security scan metadata.

3. Keep existing PortSpec and extend it.
   - Do not introduce a parallel declaredIoContract model in NodeVault core.
   - Map v0.3 declaredIoContract concepts onto existing PortSpec fields.
   - Add staging or type normalization only as additive fields/policies.

4. RunnerNode spec must require casHash.
   - stableRef/displaySnapshot are UI-facing only.
   - observedProfileDigest and validationHash are optional extension fields.

5. observedResourceProfile is included in metadata, but excluded from default validationHash/casHash because resource observations are environment-dependent.

6. validationHash is only produced for successful functional validation by default.
   - Infra-level failures such as OOMKilled, timeout, eviction, scheduling failure, image pull failure, and SIGTERM/SIGKILL must not produce a stable validationHash.
   - Record them as infra_failed or profile_inconclusive.

7. Security scan is a parallel validation track, not a replacement for Validator/Profiler.
   - Record security scan result by default.
   - Surface security summary in NodePalette by default.
   - Use security scan as Active gate only by policy option.
   - Prefer watching trivy-operator VulnerabilityReport CRDs over directly invoking Trivy CLI.

8. Sprint 0 is documentation/contract-first.
   - Do not implement real dry-run profiling in Sprint 0.
   - Do not move legacy Dockerfile parser into NodeVault core.
   - Keep code changes minimal and backward-compatible.

Strict additive coding rules:
Before generating any new code or modifying existing structs such as index.Entry or PortSpec:
1. READ the existing struct definitions from the codebase.
2. DO NOT rename existing fields.
3. DO NOT change existing JSON tags.
4. DO NOT change existing field types.
5. ONLY add new fields as optional fields with omitempty.
6. For Sprint 0, output Markdown docs only unless explicitly asked to add test stubs.
7. If adding a test stub, preserve existing behavior and include backward compatibility tests.

Acceptance criteria:
- Existing tests pass if any code stub is added.
- Existing casHash calculation and catalog path semantics are not changed.
- TOOL_CONTRACT_V0_3_DRAFT.md clearly preserves TOOL_CONTRACT_V0_2 compatibility.
- OBSERVED_PROFILE_SPEC.md defines toolprofile separately from toolspec.
- RUNNER_NODE_SPEC.md defines casHash as required.
- NODEVAULT_V03_MAPPING.md maps v0.3/v0.6.1 concepts to existing NodeVault concepts and prevents duplicate terminology.
- TOOL_NODE_SPEC.md layer 5 is updated with the RunnerNode draft.
- If SECURITY_SCAN_SPEC.md is included, it defines security referrer separately from toolprofile and states record_only as default policy.
```

---

## 16. Risks and Open Questions

### 16.1 casHash compatibility

결정:

```text
기존 casHash는 변경하지 않는다.
```

Open question:

```text
향후 runtimeProfileHash 또는 validatedProfileHash가 필요한가?
필요하다면 어떤 필드를 포함할 것인가?
```

### 16.2 schema migration

정책:

```text
- 기존 artifact는 즉시 파기하지 않는다.
- schemaVersion별 decoder를 제공한다.
- 가능한 경우 lazy migration한다.
- breaking change가 있으면 새 hash가 생길 수 있다.
- 운영/임상 evidence가 붙은 artifact는 자동 migration보다 manual review를 우선한다.
```

### 16.3 build environment reproducibility

Conda/Bioconda package spec만으로는 solver 결과가 시간이 지나며 달라질 수 있다.

고려해야 할 정보:

```text
- conda/mamba/micromamba version
- solver version
- channel list
- channel priority
- channel snapshot / repodata timestamp
- resolved package list
- package build string
- package digest
- environment lock file
```

### 16.4 IO type canonicalization

PortSpec `format`은 장기적으로 canonical enum/ontology가 필요하다.

문제:

```text
FASTQ / fastq / fq / FastQ
```

방향:

```text
- 내부 canonical format enum
- UI alias 허용
- normalize layer에서 canonical format으로 변환
- DagEdit 연결 판단은 canonical format 기준
```

초기 후보:

```text
FASTQ
FASTA
SAM
BAM
CRAM
VCF
BCF
GFF
GTF
BED
TSV
CSV
JSON
DIRECTORY
UNKNOWN
```

### 16.5 reference binding enum

후보:

```text
runtime_required
build_time_required
optional_runtime
pipeline_profile_bound
```

### 16.6 observed type detection

초기에는 하지 않는다.

향후 검토:

```text
- FASTQ/SAM/BAM/VCF 자동 판별
- magic bytes / header inspection
- confidence score
- semantic validator
```

### 16.7 security scan gate policy

Security scan result를 기록하는 것은 기본이다. 그러나 Active 전환 차단 정책은 별도 정책으로 둔다.

Open question:

```text
- critical CVE가 있으면 Active 전환을 막을 것인가?
- high CVE는 warning인가, block인가?
- CVE allowlist/exception은 어디에 둘 것인가?
- scanner report freshness 기준은 며칠로 둘 것인가?
- security status를 lifecycle_phase와 분리할 것인가, integrity_health에 포함할 것인가?
```

### 16.8 security referrer lifecycle

Security scan은 toolspec/toolprofile과 생명주기가 다르다.

Open question:

```text
- 주기적 재스캔 시 이전 security referrer를 보존할 것인가?
- latest security referrer를 index.Entry에 하나만 보관할 것인가?
- scan history를 별도 artifact/index로 보관할 것인가?
- trivy-operator 외 scanner 결과를 같은 security schema로 normalize할 수 있는가?
```

기본 정책:

```text
latest security digest는 index.Entry.securityScanDigest에 캐시한다.
최근 3개 또는 최근 30일을 유지한다.
이전 것은 삭제하지 않고 GC candidate로 표시한다.
```

### 16.9 validationHash failure semantics

Open question:

```text
- application-level failure를 validationHash로 고정해야 하는 경우가 있는가?
- expected-failure fixture를 지원할 것인가?
- timeout 기본값 30분이 충분한가?
- tool별 timeout override를 어디에 둘 것인가?
```

기본 정책:

```text
successful functional validation에 대해서만 validationHash 생성.
infra-level failure는 validationHash 없음.
```

### 16.10 index rollback / partial write

Open question:

```text
- index update 전 snapshot/backup을 어디에 둘 것인가?
- atomic rename 방식으로 partial write를 방지할 것인가?
- corrupt index 감지 시 previous valid index로 fallback할 것인가?
```

기본 정책:

```text
index update는 atomic write를 기본으로 한다.
write 실패 시 기존 index를 보존한다.
TestIndex_FallbackOnError를 추가한다.
```

---

## 17. 최종 결론

v0.6.1의 최종 결론은 다음이다.

```text
전체 독립 PoC 프로젝트는 만들지 않는다.
NodeVault는 기존 구조를 유지하면서 직접 업그레이드한다.
Legacy Dockerfile import는 NodeVault core 밖의 별도 도구로 둔다.
External reference scan은 문서 트랙으로 둔다.
Security scan은 Validator/Profiler와 별도 병렬 검증 축으로 둔다.
```

NodeVault에 직접 넣을 것:

```text
- TOOL_CONTRACT_V0_3_DRAFT.md
- OBSERVED_PROFILE_SPEC.md
- SECURITY_SCAN_SPEC.md
- RUNNER_NODE_SPEC.md
- NODEVAULT_V03_MAPPING.md
- TOOL_NODE_SPEC.md layer 5 업데이트
- toolprofile referrer artifact type
- security referrer artifact type
- observedProfileDigest / validationHash optional fields
- securityScanDigest optional field
- Validator/Profiler 단계
- Security Scan Integration 병렬 트랙
- PortSpec additive extension
```

NodeVault core에 넣지 않을 것:

```text
- legacy Dockerfile parser
- ToolRecipe 추출기
- BaseRuntimeProfile migration scanner
- external reference project scanner
```

가장 중요한 유지 원칙:

```text
기존 casHash는 변경하지 않는다.
기존 catalog path는 변경하지 않는다.
기존 toolspec은 유지한다.
새 observed profile은 toolprofile referrer로 추가한다.
새 security scan result는 security referrer로 추가한다.
기존 PortSpec은 버리지 않고 확장한다.
RunnerNode는 casHash로 pin한다.
Security scan 기록과 UI 표시는 기본, Active gate는 정책 옵션이다.
validationHash는 successful functional validation에 대해서만 생성한다.
infra-level failure는 validationHash를 생성하지 않고 inconclusive 상태로 기록한다.
오래된 profile/security referrer는 즉시 삭제하지 않고 GC candidate로 표시한다.
```

이 방향이면 기존 NodeVault의 동작 중인 계층 1~4를 깨지 않으면서, dry-run 기반 observed metadata, security scan metadata, NodePalette/DagEdit 연결성, 재현성 중심 authoring 흐름을 점진적으로 흡수할 수 있다.
