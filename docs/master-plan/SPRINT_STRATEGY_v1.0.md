# Sprint Strategy v1.0

기준일: `2026-05-01`

## 목적

현재 스프린트 전략은
`shift-left-observability` / `SF Observability` cutover와
`DevSpace + bori + kube-slint` 원격 루프 검증이 끝난 이후의 우선순위를 다시 고정한다.

이제 host의 `kind + podman` 반복 디버깅은 기준 경로가 아니다.
표준 검증 무대는 `infra-lab`이 관리하는
`100.123.80.48` 상의 libvirt 기반 VM Kubernetes다.

가장 중요한 전제:
- `AH`, `JUMI`, `kube-slint` 초기 설계 문서에 적힌 상위 일정은 유지한다.
- 이 스프린트 전략은 그 일정을 깨는 문서가 아니라, 그 일정을 지키기 위한 실행 우선순위 문서다.

## 운영 우선순위

### 1. 주 개발 트랙

- 대상:
  - `artifact-handoff`
  - `JUMI`
  - `kube-slint`
- 목표:
  - `JUMI <-> artifact-handoff` 제품 경계를 `gRPC over Cilium mesh` 기준으로 고정
  - metrics/summary 축적
  - repo-local test/harness와 shared VM 검증 경로 확장
- 원칙:
  - cluster 준비 여부 때문에 개발이 멈추면 안 되지만,
    제품에서 이미 확정된 통신 경계는 스프린트 목표에서 미루지 않는다.
  - 구현, 계약, 문서, 테스트를 계속 전진시키되,
    `Noop` 또는 임시 HTTP 경로는 개발 fallback으로만 남긴다.

### 2. 원격 개발 루프 트랙

- 대상:
  - `infra-lab`
  - `DevSpace`
  - `bori`
- 목표:
  - `100.123.80.48`에서 앱 repo 기준 DevSpace inner loop를 안정화
  - `bori`가 `DevSpace`와 `kube-slint`를 붙이는 공용 adapter로 동작하게 유지
  - 앱별 `.bori/` self-registration 구조를 기준 경로로 정리
- 원칙:
  - 실제 runtime truth는 항상 `100.123.80.48` 원격 장비에서 판정한다.
  - 로컬에서 끝난 변경은 `Code Ready`, 원격 GitHub 기준 검증은 `Remote Validated`로 구분한다.
  - 새로운 개발 루프는 `batch-integration`이 아니라 각 앱 repo와 `bori` 중심으로 옮긴다.

### 3. 관찰면/전이 트랙

- 대상:
  - `SF Observability`
  - `batch-integration` 자산 이관
- 목표:
  - 공용 shift-left 관찰면을 여러 데이터플레인 앱이 재사용 가능한 형태로 유지
  - 관찰면, gate, publish 자산을 장기 목적지로 이관할 수 있게 정리
- 원칙:
  - 관찰면은 `shift-left-observability` 자산명과 `SF Observability` 표시명을 표준으로 사용한다.
  - `batch-integration`은 영구 허브가 아니라 전이용 staging 저장소로 취급한다.

## 이번 스프린트 기준

### 반드시 진행

- `artifact-handoff` gRPC server 구현 경로 고정
- `JUMI` gRPC client 구현 및 기본 통합 경로 연결
- `JUMI -> artifact-handoff` failure/lifecycle semantics 정리
- `DevSpace -> bori -> kube-slint` 원격 검증 루프 유지
- `SF Observability`와 summary/gate 연결 자산 정리

### 병행 진행

- `SF Observability`에서 새 통합 경로 결과를 읽도록 publish 절차 유지
- gRPC service naming, timeout, mesh 경계 문서화
- `batch-integration` 자산의 목적지별 이관 계획 정리

### 지금 미루는 것

- host `kind + podman` 경로 반복 디버깅
- 별도 VM 신규 분리
- 무거운 현실 검증을 모든 기능 변경마다 수행

## 성공 기준

- `SF Observability`가 표준 사용자 진입점으로 동작한다
- `infra-lab` shared VM 위 dedicated namespace 경로가 문서와 실제 배포 기준으로 일치한다
- `JUMI`가 `artifact-handoff`를 실제 gRPC 경계로 호출한다
- `DevSpace + bori + kube-slint` 경로가 원격 장비에서 재현된다
- `kube-slint`가 그 결과를 summary/gate로 남기고 `SF Observability`가 이를 읽는다
