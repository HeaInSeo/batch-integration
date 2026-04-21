# Sprint Strategy v1.0

기준일: `2026-04-21`

## 목적

현재 스프린트는 `코드 개발 지속`과 `환경 문제 대응`을 분리해서 운영한다.
host의 `kind + podman` 경로는 kernel/cgroup 제약으로 막혀 있으므로,
환경 문제를 주 개발 스프린트와 섞지 않는다.

## 운영 우선순위

### 1. 주 개발 트랙

- 대상:
  - `artifact-handoff`
  - `JUMI`
  - `kube-slint`
- 목표:
  - cross-repo seam 고정
  - metrics/summary 축적
  - repo-local test/harness 확장
- 원칙:
  - cluster 준비 여부에 막혀 개발이 멈추면 안 됨
  - 구현, 계약, 문서, 테스트를 계속 전진시킴

### 2. 환경 구축 트랙

- 대상:
  - `vm + dev-space`
- 목표:
  - 개발용 Kubernetes 경로 1개 확보
  - 메트릭/배포/검증이 가능한 최소 운영 환경 확보
- 원칙:
  - 신규 서브프로젝트로 취급
  - 주 개발 트랙의 블로커로 승격하지 않음

### 3. 현실 검증 트랙

- 대상:
  - milestone 단위 통합 검증
- 목표:
  - churn
  - fallback
  - retention
  - regression
- 원칙:
  - `vm + dev-space` 구축 완료 후에만 사용

## 이번 스프린트 기준

### 반드시 진행

- AH resolver/service 축 개발
- JUMI seam 및 handoff client 축 개발
- kube-slint minimum guardrail 확장
- repo-local test/harness 강화
- 환경 이슈 문서화 및 허브 반영

### 병행 진행

- `vm + dev-space` 최소 구축 조사
- VM 내부 k8s 경로 선택
- 이후 milestone 검증 경로 후보 정리

### 지금 미루는 것

- host `kind + podman` 경로 반복 디버깅
- `vm + dev-space`를 즉시 주 개발 경로로 승격
- 무거운 현실 검증을 모든 기능 변경마다 수행

## 성공 기준

- 코드 개발이 환경 이슈 때문에 정지하지 않음
- 문서/계약/테스트가 스프린트 종료 시점까지 누적됨
- `vm + dev-space`는 최소 구축 계획이 확정됨
- 다음 milestone에서 현실 검증 경로로 편입할 준비가 됨
