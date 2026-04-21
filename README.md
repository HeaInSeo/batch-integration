# Batch Integration Hub

이 디렉토리는 `JUMI`, `artifact-handoff`, `kube-slint` 3개 저장소를 함께 진행하기 위한 상위 통합 허브다.

목적:
- 저장소 간 의존성과 개발 순서를 한 곳에서 관리
- 통합 설계와 수정된 일정의 기준 문서 제공
- Codex 작업 규칙과 검토 기준 고정

원칙:
- 각 저장소 내부 설계의 canonical 문서는 각 저장소에 유지한다.
- 이 디렉토리는 cross-repo 일정, 계약, 운영 규칙만 다룬다.
- 원본 계획 문서는 `plans/original/`에 보존하고, 수정안은 `plans/revised/`에 둔다.

구성:
- `plans/original/`: 2026-04-21 기준 원본 계획 문서 보관본
- `plans/revised/`: 현실 조정안 기준 수정 계획 문서
- `docs/master-plan/`: 통합 일정, 아키텍처, 게이트 문서
- `docs/decisions/`: cross-repo 의사결정 기록
- `docs/contracts/`: 저장소 간 계약 문서
- `docs/status/`: 위험과 주간 상태 추적
- `scripts/`: 특정 소비자 repo에 종속되지 않는 공용 운영 스크립트
- `codex/`: Codex 운영 문서와 검토 체크리스트

현재 기준:
- 기준일: `2026-04-21`
- 추천 일정안: `현실 조정안`
- 첫 통합 목표: `2026-05-16` 전후
- 베타 목표: `2026-06-13` ~ `2026-06-20`
- 문서 목표 완료: `2026-07-31` 전후

운영 원칙:
- `kube-slint`는 후행 검증 도구가 아니라 초기 병행 개발 축으로 취급한다.
- 단, 초기에는 `개발 동반용 최소 guardrail` 범위로 제한한다.
- `kind + ko + tilt` 경로에서 JUMI/AH 변경을 바로 관찰할 수 있어야 한다.
- `multipass/dev-space`는 첫 통합 이후 고도화 단계에서 확장한다.
