# April End Debt Closure Plan

기준일: `2026-04-27`
대상 기간: `2026-04-27` ~ `2026-04-30`

## 목적

4월 말까지는 범위를 더 넓히지 않는다.
기술부채를 늘리지 않는 것을 최우선으로 두고,
이미 진행한 `artifact-handoff`, `JUMI`, `kube-slint`, VM lab 통합 경로를
정리 가능한 단위로 닫는다.

## 현재 기준점

- `batch-integration`
  - VM lab live smoke/gate 경로 공개 반영 완료
  - 마지막 공개 커밋: `e431a9d`
- `kube-slint`
  - JUMI/AH smoke guardrail 반영 완료
  - 워킹트리 clean
- `artifact-handoff`
  - resolver service 골격, lifecycle/GC 최소 규칙, HTTP shim, 테스트 존재
  - 현재 `go test ./...` 통과
  - 문서 정리와 로컬 워킹트리 확정이 남음
- `JUMI`
  - AH client, executor seam, metrics, HTTP integration test 존재
  - 현재 `go test ./...` 통과
  - 문서/빌드 자산/워킹트리 확정이 남음

## 4월 말까지의 최대 완료 목표

### P0. 반드시 닫을 것

1. `artifact-handoff` 워킹트리 안정화
2. `JUMI` 워킹트리 안정화
3. 두 저장소의 빌드 산출물 혼입 방지 (`.gitignore` 등)
4. 현재 seam 기준 테스트 재확인
5. VM lab smoke 재검증 가능 상태 유지

### P1. 가능하면 같이 닫을 것

1. `artifact-handoff` 로컬 변경을 커밋 가능한 묶음으로 고정
2. `JUMI` 로컬 변경을 커밋 가능한 묶음으로 고정
3. `batch-integration`에 4월 말 상태 문서 추가

### 4월 안에 하지 않을 것

1. 새로운 Dragonfly adapter 범위 확대
2. durable state store 도입
3. `kind + tilt` 주 경로 복구 시도
4. `dev-space` 신규 착수
5. fan-in/source-priority 같은 다음 단계 기능 확대

## 일자별 현실 일정

### `2026-04-27`

- `artifact-handoff` 구조와 테스트 기준 재확인
- `JUMI` 구조와 테스트 기준 재확인
- 빌드 산출물 ignore 정리 시작

완료 기준:

- 두 저장소 모두 현재 로컬 코드 기준 테스트 통과 여부 재확인
- 워킹트리 오염 요인 목록 정리

### `2026-04-28`

- `artifact-handoff` 변경 범위를 resolver phase-1 기준으로 고정
- deprecated 문서 이동, README/architecture 연결, 빌드 자산 포함 범위 점검
- 필요 시 phase-1 상태 문서 보강

완료 기준:

- `artifact-handoff`는 "resolver phase-1"로 설명 가능한 상태가 됨
- 테스트, 문서, 엔트리포인트, 빌드 자산 범위가 서로 맞음

### `2026-04-29`

- `JUMI` 변경 범위를 AH seam phase-1 기준으로 고정
- spec 확장, executor hook, handoff client, metrics, 테스트 범위 정리
- backward compatibility와 현재 smoke fixture 사용 가능성 점검

완료 기준:

- `JUMI`는 "AH seam phase-1"로 설명 가능한 상태가 됨
- 테스트, 문서, 빌드 자산 범위가 서로 맞음

### `2026-04-30`

- VM lab smoke 재검증 또는 재검증 준비 상태 최종 확인
- `batch-integration`에 월말 상태 보고 추가
- 5월 첫 스프린트의 시작 조건과 비목표 고정

완료 기준:

- 월말 기준 "무엇이 끝났고, 무엇이 아직 안 끝났는지"가 문서로 닫힘
- 5월에 들어가자마자 새 기능을 늘리지 않고 다음 단계를 시작할 수 있음

## 기술부채 최소화 원칙

1. 테스트가 통과하는 변경만 다음 단계 기준선으로 인정한다.
2. untracked 실행 파일 같은 산출물은 저장소 기준선에서 제거하거나 ignore 한다.
3. resolver/JUMI seam phase-1을 넘는 새 범위는 4월 안에 추가하지 않는다.
4. 문서와 코드가 서로 다른 구조를 설명하면 문서를 먼저 맞춘다.
5. VM lab에서 이미 입증된 smoke 경로를 깨는 변경은 4월 안에 받지 않는다.

## 일정 판단

원본 개발 문서의 상위 milestone은 유지한다.
다만 `2026-04-30`까지의 현실 최대치는
"기능 추가"가 아니라 "현재 진행된 통합 seam을 기술부채 적게 닫는 것"이다.

즉 4월 말까지 기대할 수 있는 최선의 결과는 다음이다:

- `artifact-handoff` phase-1 정리 완료
- `JUMI` AH seam phase-1 정리 완료
- `kube-slint` 기준선 유지
- VM lab smoke 재검증 가능 상태 유지
- 5월 초에 바로 다음 스프린트를 시작할 수 있는 문서/테스트 기준선 확보
