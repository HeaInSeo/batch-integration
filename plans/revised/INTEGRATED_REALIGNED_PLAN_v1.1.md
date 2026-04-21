# 통합 수정 개발 계획 v1.1 — 현실 조정안

기준일: `2026-04-21`

## 1. 수정 원칙

- 최종 목표는 유지한다.
- 초기 스프린트의 순서와 범위를 수정한다.
- 첫 수직 통합을 최우선 마일스톤으로 둔다.
- 저장소별 최종형 확장보다 cross-repo seam 고정을 먼저 한다.
- `kube-slint`는 초기부터 병행 개발하되, 개발 동반용 최소 guardrail 범위로 제한한다.

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
- `kind + ko + tilt` 기준 최소 수집 경로
- 최소 derived indicator 후보 정리
- save/commit 시점 최소 summary 출력 경로

### Phase 3. 첫 실제 통합

기간: `2026-05-05 ~ 2026-05-16`

산출물:
- JUMI -> AH 실제 호출
- 최소 placement/acquisition contract 응답
- happy path e2e 1개
- kube-slint 핵심 metrics family와 최소 summary
- kind 환경 churn/regression 확인 경로

### Phase 4. 베타 기반

기간: `2026-05-19 ~ 2026-06-13`

산출물:
- `NotifyNodeTerminal`, `FinalizeSampleRun`
- retention 기본형
- derived indicator 최소판
- multi-component summary 초안
- JUMI/AH 기능 PR과 kube-slint 검증 경로 결합

### Phase 5. 운영성 강화

기간: `2026-06-16 ~ 2026-07-11`

산출물:
- cleanup debt
- low-cardinality guard
- sample-run 격리 검증
- same-node preferred
- 기본 GC 안정화

### Phase 6. 문서 목표 마감

기간: `2026-07-14 ~ 2026-08-01`

산출물:
- provenance-ready hook
- manifest/digest 계약
- multipass/devspace profile
- nightly regression 초안

## 3. 핵심 마일스톤

- 첫 통합 완료: `2026-05-16` 전후
- 베타: `2026-06-13` ~ `2026-06-20`
- 문서 목표 완료: `2026-07-31` 전후

## 4. 수정 이유

- `artifact-handoff`는 현재 greenfield에 가깝다.
- `JUMI`는 이미 실행 골격이 있어 대규모 리팩터링 비용이 높다.
- `kube-slint`는 초기부터 함께 가야 하지만 최종형 schema까지 바로 밀 필요는 없다.

따라서 초기에는 AH contract를 먼저 작게 고정하고, JUMI seam을 삽입하고, 동시에 kube-slint를 개발 동반용 최소 감시 경로로 붙이는 순서가 가장 현실적이다.
