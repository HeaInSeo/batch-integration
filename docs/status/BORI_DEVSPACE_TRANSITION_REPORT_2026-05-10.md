# Bori DevSpace Transition Report 2026-05-10

기준일:
- `2026-05-10`

목적:
- `bori`를 중심으로 한 최종 목표 구조를 다시 정리한다.
- 현재 `batch-integration`에 있는 자산이 어디로 이관되어야 하는지 분류한다.
- `DevSpace + infra-lab + kube-slint + SF Observability` 경로를 실제 전이 계획으로 고정한다.

## 결론

- `bori`는 주변 프로젝트가 아니라, `DevSpace`와 `kube-slint`를 연결하는 핵심 adapter layer다.
- 각 데이터플레인 앱은 장기적으로 `repo + devspace.yaml + .bori/` 구조로 개발 루프에 참여해야 한다.
- `batch-integration`은 지금까지 통합 실험과 검증 루프를 올리는 staging 저장소 역할을 했고, 장기적으로는 자산 이관 뒤 비워지거나 제거되는 것이 맞다.
- `SF Observability`는 특정 앱 전용이 아니라 여러 데이터플레인 앱이 공통으로 쓰는 shift-left evidence surface로 가야 한다.

## 현재 확인된 사실

### 1. bori의 역할

`bori`는 README와 코드 기준으로 아래 역할을 갖는다.

- `DevSpace` inner-loop와 `kube-slint` gate를 연결
- 각 앱 repo의 `.bori/component.yaml`과 `policy.<profile>.yaml`를 자동 발견
- `slint-gate`를 Go library import가 아니라 CLI shell-out으로 호출
- profile 기반으로 `devspace`, `kind`, `multipass`를 구분

근거:
- [bori/README.ko.md](/opt/go/src/github.com/HeaInSeo/bori/README.ko.md:1)
- [bori/docs/architecture.md](/opt/go/src/github.com/HeaInSeo/bori/docs/architecture.md:1)
- [bori/adapters/devspace/main.go](/opt/go/src/github.com/HeaInSeo/bori/adapters/devspace/main.go:1)

### 2. 앱 repo와의 연결 흔적

현재 확인된 연결:

- `JUMI/devspace.yaml`의 `after:deploy` hook은 `bori-devspace`를 호출한다.
- `artifact-handoff/devspace.yaml`도 같은 패턴을 따른다.

즉 설계 의도는 이미 잡혀 있다.

- 앱 repo는 DevSpace로 배포/동기화
- `bori-devspace`가 smoke/gate를 수행
- `kube-slint`가 PASS/FAIL/WARN/NO_GRADE를 판정

근거:
- [JUMI/devspace.yaml](/opt/go/src/github.com/HeaInSeo/JUMI/devspace.yaml:1)
- [artifact-handoff/devspace.yaml](/opt/go/src/github.com/HeaInSeo/artifact-handoff/devspace.yaml:1)

### 3. 현재 실행 상태

현재 이 환경에서 확인된 상태:

- `devspace` CLI 없음
- `bori-devspace` 없음

즉:

- 설계는 `bori + DevSpace` 중심으로 잡혀 있다.
- 하지만 실제 실행 환경은 아직 그 설계를 따라가지 못하고 있다.
- 그래서 지금은 `batch-integration`의 smoke/gate/publish 루프가 임시 본선 역할을 하고 있다.

## 목표 구조

장기 목표 구조는 이렇게 보는 것이 맞다.

```text
개별 앱 repo (JUMI, artifact-handoff, 이후 다른 dataplane apps)
  ├─ devspace.yaml
  ├─ .bori/component.yaml
  ├─ .bori/policy.devspace.yaml
  └─ 앱 코드 / smoke / deploy 자산
        ↓
bori
  ├─ DevSpace adapter
  ├─ 앱 self-registration discovery
  └─ slint-gate 실행 orchestration
        ↓
kube-slint
  ├─ summary
  └─ gate
        ↓
SF Observability
  ├─ 공용 shift-left evidence page
  └─ app-specific signal sections
        ↓
infra-lab
  └─ 공용 원격 실행 기반
```

이 구조에서 `batch-integration`은 최종 필수 구성요소가 아니다.

## 역할 재정의

### infra-lab

- 공용 원격 실행 기반
- K8s/VM/네트워크 표준 무대

### DevSpace

- 앱별 remote inner loop
- sync/build/deploy/debug

### bori

- DevSpace와 `kube-slint`를 연결하는 공통 adapter/orchestrator
- 여러 앱을 self-registration 방식으로 묶는 공통 계층

### kube-slint

- 공용 shift-left gate 엔진
- 특정 앱 전용이 아니라, 앱별 정책과 metric adapter 위에 올라가는 공통 판정기

### SF Observability

- 공용 shift-left evidence surface
- 현재 첫 onboarded app은 `JUMI/AH`
- 이후 다른 데이터플레인 앱도 같은 구조로 붙어야 함

### batch-integration

- 전이용 통합 저장소
- 실험 중인 공통 smoke/gate/publish 자산 임시 보관소
- 최종 목적지 아님

## 자산 이관표

### A. 각 앱 repo로 이관

대상:
- 앱별 inner dev loop
- 앱별 `devspace.yaml`
- 앱별 smoke command
- 앱별 build/push/deploy 세부
- 앱별 `.bori/component.yaml`
- 앱별 `.bori/policy.<profile>.yaml`

현재 관련 흔적:
- `JUMI/devspace.yaml`
- `artifact-handoff/devspace.yaml`

판단:
- 이 계층은 `batch-integration`에 남으면 안 된다.
- 앱 repo가 ownership을 가져야 한다.

### B. bori 로 이관

대상:
- DevSpace hook 이후 공통 gate orchestration
- 앱 discovery 로직
- app-independent smoke/gate wrapper
- profile 선택 모델

판단:
- `DevSpace + kube-slint`를 연결하는 공통 논리는 `bori`가 owner가 되는 것이 가장 자연스럽다.
- `batch-integration`의 일부 smoke/gate wrapper는 장기적으로 `bori`로 흡수되거나, `bori` 기준에 맞춰 재작성돼야 한다.

### C. kube-slint 로 유지/이관

대상:
- 공통 gate 모델
- threshold/reliability/regression semantics
- summary/gate schema 중 앱 독립적인 부분

판단:
- `kube-slint`는 플랫폼 공통 gate 계층으로 남아야 한다.
- 앱별 metric naming과 derived signal은 adapter가 맞추고, gate 엔진 자체는 가능한 공통으로 유지해야 한다.

### D. SF Observability 운영 경로로 이관

대상:
- observability static site
- publish script
- tailnet proxy 자산
- 공통 metadata bundle format

현재 `batch-integration` 자산:
- `deploy/dev-space` 계열 observability 자산
- publish script
- tailnet proxy 설치 자산

판단:
- 이 자산은 장기적으로 `batch-integration`에 임시로 남아 있을 이유가 약하다.
- 이름을 `shift-left-observability`로 정리한 뒤, 별도 운영 경로나 전용 저장소로 분리하는 것이 맞다.

### E. 장기 문서 목적지로 이관

대상:
- 살아남아야 할 계약 문서
- 플랫폼 운영 문서
- 여러 앱이 공통으로 따라야 할 onboarding 규약

판단:
- 모든 문서가 `batch-integration`에 남을 필요는 없다.
- 앱별 문서는 각 앱 repo로
- `bori` 관련 문서는 `bori`로
- `SF Observability` 운영 문서는 그 운영 경로로
- 공통 아키텍처 문서는 장기 기준 저장소로 옮겨야 한다.

## 단계별 진행 계획

### Step 1. Naming Realignment

목표:
- `dev-space`와 `DevSpace` 충돌 제거

해야 할 일:
- 공식 자산명 `shift-left-observability`
- 표시명 `SF Observability`
- deploy/script/hostname/namespace/doc 용어 정리

완료 기준:
- 공식 자산에서 `dev-space observability` 표현 제거

### Step 2. DevSpace Reactivation

목표:
- `bori + DevSpace` 경로를 실제로 다시 살린다

해야 할 일:
- K8s VM host에 `devspace` 설치
- `bori-devspace` 빌드/배치
- `slint-gate` 설치
- `JUMI`, `artifact-handoff` repo의 `devspace.yaml` 경로 재검증

완료 기준:
- `devspace dev --profile devspace`가 실제로 원격 개발 루프를 돌린다

### Step 3. App Self-Registration

목표:
- 앱별 `.bori/` 구조 정리

해야 할 일:
- `component.yaml`
- `policy.devspace.yaml`
- 필요 시 `kind/multipass` profile도 맞춤

완료 기준:
- `bori`가 앱을 central registry 없이 발견

### Step 4. Shared Gate Contract

목표:
- 앱별 신호와 공통 gate 모델 분리

해야 할 일:
- 앱별 metric naming adapter
- summary bundle contract
- 공통 gate 입력 schema

완료 기준:
- `JUMI/AH` 외 앱도 같은 방식으로 붙을 수 있음

### Step 5. Asset Migration Out Of batch-integration

목표:
- `batch-integration` 축소 및 제거 준비

해야 할 일:
- 어떤 자산이 어디로 가는지 확정
- 실제로 각 목적지로 복사/이관
- `batch-integration` 의존 제거

완료 기준:
- `batch-integration` 없이도 개발/검증/관찰 루프를 설명 가능

## 우선순위

1. `shift-left-observability` rename
- 이름 충돌 제거가 가장 시급하다.

2. `bori + DevSpace` 실행 경로 복구
- 설계는 이미 있으므로, 실제 동작 경로를 올리는 것이 다음 본선이다.

3. 앱별 `.bori/` self-registration 정리
- multi-app 구조로 가려면 필수다.

4. `SF Observability` 공통 모델 정리
- 현재 `JUMI/AH` 전용 표현을 줄이고 공용 관찰면으로 재서술해야 한다.

5. `batch-integration` 자산 이관
- 전이용 저장소를 장기 허브로 굳히면 안 된다.

## 최종 판단

- 지금 방향의 중심은 `batch-integration`이 아니라 `bori`여야 한다.
- `DevSpace`는 앞으로 살릴 예정이 아니라, 이미 목표 경로로 설계돼 있다.
- 부족한 것은 방향이 아니라 실행 환경과 자산 배치다.
- 따라서 다음 단계는 `bori + DevSpace`를 실제로 다시 살아나게 하고, `batch-integration`은 전이용 저장소로서 점진적으로 해체하는 쪽이 맞다.
