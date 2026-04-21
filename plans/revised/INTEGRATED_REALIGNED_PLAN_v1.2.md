# 통합 수정 개발 계획 v1.3 — 현실 조정안 + 환경 제약 반영

기준일: `2026-04-21`

## 1. 수정 원칙

- `AH`, `JUMI`, `kube-slint` 원본 설계 문서의 상위 일정은 가장 중요한 기준으로 유지한다.
- 현재 수정안은 상위 일정 자체를 뒤집는 문서가 아니라, 세부 순서와 운영 방식을 현실에 맞게 조정하는 문서다.
- 최종 목표는 유지한다.
- 초기 스프린트의 순서와 범위를 수정한다.
- 첫 수직 통합을 최우선 마일스톤으로 둔다.
- 저장소별 최종형 확장보다 cross-repo seam 고정을 먼저 한다.
- `kube-slint`는 후행 검증 도구가 아니라 초기 병행 개발 축으로 취급한다.
- 단, 초기 범위는 `개발 동반용 최소 guardrail`로 제한한다.
- host kernel/cgroup 제약으로 막힌 환경 이슈는 `주 개발 스프린트`와 분리한다.
- `vm + dev-space`는 즉시 대체 운영 경로가 아니라 `별도 구축 스프린트`로 취급한다.

## 2. 일정 요약

### Phase 1. AH 최소 계약

기간: `2026-04-21 ~ 2026-05-01`

산출물:
- resolver service 골격
- proto 초안
- in-memory inventory/store
- `RegisterArtifact`, `ResolveHandoff`, `NotifyNodeTerminal` happy path

### Phase 2. JUMI seam 삽입

기간: `2026-04-28 ~ 2026-05-09`

산출물:
- `ArtifactBindings` optional 추가
- `SampleRunID` 추가
- `BuildingBindings` / `ResolvingInputs` 최소 phase
- fallback 유지

### Phase 2.5. kube-slint 개발 동반 guardrail

기간: `2026-04-28 ~ 2026-05-09`

산출물:
- JUMI/AH 핵심 metrics family 등록 초안
- 로컬/단위/하네스 기준 최소 수집 경로
- 최소 derived indicator 후보 정리
- save/commit 시점 최소 summary 출력 경로
- cluster 환경과 독립적인 최소 summary 확인 루프

### Phase 3. 첫 실제 통합

기간: `2026-05-05 ~ 2026-05-16`

산출물:
- JUMI -> AH 실제 호출
- 최소 placement/acquisition contract 응답
- happy path e2e 1개
- kube-slint 최소 summary
- cluster 환경 의존도가 낮은 integration check 경로

### Phase 3.5. VM + dev-space 구축 스프린트

기간: `2026-05-12 ~ 2026-05-23`

산출물:
- `multipass` VM 내부 개발용 k8s 경로 선택
- `dev-space` 진입 전 최소 운영 문서
- JUMI/AH/kube-slint 배포 가능한 기본 경로 1개
- 메트릭 확인 및 kube-slint 1회 실행 가능한 상태

### Phase 4. 베타 기반

기간: `2026-05-19 ~ 2026-06-13`

산출물:
- `NotifyNodeTerminal`, `FinalizeSampleRun`
- retention 기본형
- derived indicator 최소판
- multi-component summary 초안
- JUMI/AH 기능 PR과 kube-slint 검증 경로 결합
- `vm + dev-space`를 milestone 검증 경로로 편입

### Phase 5. 운영성 강화

기간: `2026-06-16 ~ 2026-07-11`

산출물:
- cleanup debt
- low-cardinality guard
- sample-run 격리 검증
- same-node preferred
- 기본 GC 안정화
- `vm + dev-space` 기반 현실 검증 루프 안정화

### Phase 6. 문서 목표 마감

기간: `2026-07-14 ~ 2026-08-01`

산출물:
- provenance-ready hook
- manifest/digest 계약
- `multipass/dev-space` profile
- nightly regression 초안

## 3. 검증 전략

### 빠른 개발 루프

- 환경: unit/integration harness + local process
- 시점: save, local integration, small feature step
- 목적: contract 깨짐, metric 노출, 최소 summary, obvious regression 확인

### 중간 검증 루프

- 환경: repo-local integration + 가능한 cluster 경로
- 시점: feature branch, PR 전
- 목적: JUMI-AH happy path, summary diff, cardinality 위험 조기 확인

### 현실 검증 루프

- 환경: `multipass-k8s-vm + dev-space`
- 시점: VM 경로 구축 완료 후 milestone 단위, 기능 묶음 완료 후
- 목적: 현실 압력에서의 churn, fallback, cleanup debt, regression 확인

### 장기 회귀 루프

- 환경: `multipass-k8s-vm + dev-space`
- 시점: nightly 또는 milestone gate
- 목적: historical drift, long-run churn, distribution-based regression

## 4. 핵심 마일스톤

- 첫 통합 완료: `2026-05-16` 전후
- 베타: `2026-06-13` ~ `2026-06-20`
- 문서 목표 완료: `2026-07-31` 전후

## 5. 수정 이유

- `artifact-handoff`는 현재 greenfield에 가깝다.
- `JUMI`는 이미 실행 골격이 있어 대규모 리팩터링 비용이 높다.
- `kube-slint`는 JUMI/AH 개발 초반부터 같이 가야 churn과 regression을 보면서 개발할 수 있다.
- 다만 `kube-slint`도 최종형을 한 번에 밀기보다 개발 동반용 최소 guardrail로 먼저 서야 한다.
- 현재 host의 `kind + podman` 경로는 kernel/cgroup 제약으로 막혀 있으므로, 이를 주 개발 스프린트와 분리해야 한다.

따라서 초기에는 AH contract를 작게 고정하고, JUMI seam을 삽입하고, 동시에 kube-slint를 cluster 비의존 최소 감시 경로로 병행 개발하는 순서가 가장 현실적이다. `vm + dev-space`는 별도 구축 스프린트로 올리고, 구축이 끝난 뒤에만 현실 검증 경로로 승격한다.

## 6. 일정 해석 규칙

- 원본 설계 문서의 상위 일정은 유지한다.
- 통합 허브 문서에서 바꾸는 것은 다음 항목에 한정한다.
  - 세부 작업 순서
  - 병행 개발 방식
  - 검증 경로
  - 스프린트 내 우선순위
- 따라서 허브 문서의 현실 조정안은 `원본 일정 대체`가 아니라 `원본 일정 준수를 위한 실행 조정안`으로 해석한다.
