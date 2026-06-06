# Milestones And Gates

기준일: `2026-04-21`

원칙:
- `AH`, `JUMI`, `kube-slint` 원본 설계 문서의 상위 일정은 가장 중요한 기준으로 유지한다.
- 이 문서는 상위 일정 자체를 재정의하지 않고, 통합 개발 관점의 게이트만 구체화한다.

## M1. AH 최소 계약 고정

목표일: `2026-05-01`

완료 기준:
- `artifact-handoff`에 resolver service 골격 존재
- proto 초안 존재
- `RegisterArtifact`, `ResolveHandoff`, `NotifyNodeTerminal` happy path 존재
- in-memory store 존재

현재 판단:
- 코드 기준으로 대체로 충족됨
- 단, transport 구현은 HTTP가 먼저 존재하고 제품형 gRPC 경계는 후속 milestone에서 닫아야 함

## M2. JUMI integration seam 삽입

목표일: `2026-05-09`

완료 기준:
- `ArtifactBindings` optional 추가
- `SampleRunID` 추가
- executor에 최소 `BuildingBindings`/`ResolvingInputs` phase 반영
- 기존 fixture가 유지되거나 의도적으로 마이그레이션됨

현재 판단:
- 코드 기준으로 대체로 충족됨
- 단, 기본 런타임 경로는 아직 실제 `artifact-handoff` 대신 `NoopClient` fallback 흔적이 있어
  M3 전에 제품형 통합 경로로 승격이 필요함

## M2.5. kube-slint 개발 동반 guardrail 연결

목표일: `2026-05-09`

완료 기준:
- `kube-slint`가 JUMI/AH 핵심 metrics family를 읽을 준비가 됨
- cluster 비의존 최소 수집 경로가 문서화됨
- 최소 derived indicator 후보가 정리됨
- save/commit 시점에 돌릴 최소 summary 출력 경로가 존재함

현재 판단:
- gate/summary 엔진은 기준선에 도달
- 다음 초점은 standalone guardrail이 아니라 실제 `JUMI/AH` 통합 경로와 결합하는 것

## M3. 첫 실제 통합

목표일: `2026-05-16`

완료 기준:
- JUMI가 AH에 실제 `gRPC over Cilium mesh` 호출
- AH가 응답한 contract로 JUMI happy path 실행
- shared VM 내 dedicated namespace 기준 최소 e2e 시나리오 1개 존재
- kube-slint가 JUMI/AH 최소 summary 생성
- `infra-lab` shared VM 기준 integration check 경로가 실제로 동작

현재 리스크:
- code seam 자체는 있으나, 기본 런타임이 아직 `Noop/HTTP` 경로에 기대는 부분이 남아 있음
- 따라서 이 milestone의 핵심 지연 후보는 관찰면 이름이나 접근성이 아니라 `gRPC/Cilium` 제품 경계 전환임

## M3.5. Remote Dev Loop 최소 구축

목표일: `2026-05-23`

완료 기준:
- `infra-lab` shared VM 기반 개발용 Kubernetes 경로가 표준으로 확정됨
- `DevSpace + bori + kube-slint` 원격 개발 루프가 최소 1개 앱 repo에서 동작함
- `shift-left-observability` tailnet 진입점 `http://100.123.80.48:8008/` 이 표준 사용자 접근 경로로 동작함
- `SF Observability`가 summary/gate 결과를 노출함
- JUMI/AH/kube-slint 배포 가능한 dedicated namespace 기본 경로가 존재함

현재 판단:
- 원격 `DevSpace + bori + kube-slint` 검증과 `SF Observability` rename은 완료
- 남은 핵심은 이 경로를 JUMI/AH 외 다른 데이터플레인 앱까지 확장 가능한 공용 운영 모델로 굳히는 일

## M4. 베타 기반

목표일: `2026-06-13`

완료 기준:
- `NotifyNodeTerminal`, `FinalizeSampleRun` 연결
- retention 기본형 존재
- derived indicator 최소판 존재
- multi-component summary 초안 존재
- JUMI/AH 기능 PR과 kube-slint summary 변화가 같이 검증됨
- `infra-lab` shared VM + dedicated namespace 경로가 milestone 검증 경로로 편입됨

## M5. 운영성 강화

목표일: `2026-07-11`

완료 기준:
- cleanup debt 추적
- low-cardinality guard
- sample-run 격리 검증
- same-node preferred 정책
- 기본 GC 안정화

## M6. 문서 목표 마감

목표일: `2026-07-31`

완료 기준:
- provenance-ready hook
- manifest/digest 계약
- DevSpace/bori profile
- SF Observability 운영 모델
- nightly regression 초안
