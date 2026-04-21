# Milestones And Gates

기준일: `2026-04-21`

## M1. AH 최소 계약 고정

목표일: `2026-05-01`

완료 기준:
- `artifact-handoff`에 resolver service 골격 존재
- proto 초안 존재
- `RegisterArtifact`, `ResolveHandoff`, `NotifyNodeTerminal` happy path 존재
- in-memory store 존재

## M2. JUMI integration seam 삽입

목표일: `2026-05-09`

완료 기준:
- `ArtifactBindings` optional 추가
- `SampleRunID` 추가
- executor에 최소 `BuildingBindings`/`ResolvingInputs` phase 반영
- 기존 fixture가 유지되거나 의도적으로 마이그레이션됨

## M2.5. kube-slint 개발 동반 guardrail 연결

목표일: `2026-05-09`

완료 기준:
- `kube-slint`가 JUMI/AH 핵심 metrics family를 읽을 준비가 됨
- cluster 비의존 최소 수집 경로가 문서화됨
- 최소 derived indicator 후보가 정리됨
- save/commit 시점에 돌릴 최소 summary 출력 경로가 존재함

## M3. 첫 실제 통합

목표일: `2026-05-16`

완료 기준:
- JUMI가 AH에 실제 호출
- AH가 응답한 contract로 JUMI happy path 실행
- 최소 e2e 시나리오 1개 존재
- kube-slint가 JUMI/AH 최소 summary 생성
- cluster 환경 의존도가 낮은 integration check 경로가 실제로 동작

## M3.5. VM + dev-space 최소 구축

목표일: `2026-05-23`

완료 기준:
- `multipass` VM 내부에서 개발용 Kubernetes 경로 1개가 선택됨
- JUMI/AH/kube-slint 배포 가능한 기본 경로가 존재함
- 메트릭 확인 가능
- kube-slint 1회 실행 가능

## M4. 베타 기반

목표일: `2026-06-13`

완료 기준:
- `NotifyNodeTerminal`, `FinalizeSampleRun` 연결
- retention 기본형 존재
- derived indicator 최소판 존재
- multi-component summary 초안 존재
- JUMI/AH 기능 PR과 kube-slint summary 변화가 같이 검증됨
- `vm + dev-space`가 milestone 검증 경로로 편입됨

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
- multipass/devspace profile
- nightly regression 초안
