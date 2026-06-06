# SF Observability Alignment Sprint 2 2026-05-10

기준일:
- `2026-05-10`

목적:
- `shift-left-observability` / `SF Observability` rename 이후
  현재 운영 기준 문서가 실제 구조와 같은 말을 하도록 정렬한다.
- `DevSpace + bori + kube-slint + SF Observability`를
  공용 shift-left 플랫폼 경로로 고정한다.
- `batch-integration`을 영구 허브가 아니라
  전이용 staging 저장소로 다시 명시한다.

## 이번 스프린트에서 정렬한 문서

- `README.md`
- `docs/master-plan/SPRINT_STRATEGY_v1.0.md`
- `docs/master-plan/VALIDATION_STRATEGY.md`
- `docs/master-plan/MILESTONES_AND_GATES.md`
- `docs/status/JUMI_AH_DEV_LIVE_LOOP_2026-05-02.md`

## 핵심 변경

1. 관찰면 명칭 정렬
- 공식 자산명은 `shift-left-observability`
- 사용자 표시 이름은 `SF Observability`
- 현재 운영 기준 문서에서 `dev-space`를 현재형 표현으로 쓰지 않게 정리

2. 원격 검증 기준 정렬
- 실제 runtime truth는 `100.123.80.48`
- 로컬 작업은 `Code Ready`
- 원격 GitHub 기준 검증은 `Remote Validated`

3. 플랫폼 구조 정렬
- `DevSpace`는 앱별 원격 개발 루프
- `bori`는 `DevSpace`와 `kube-slint`를 붙이는 공용 adapter
- `kube-slint`는 공용 shift-left gate
- `SF Observability`는 공용 shift-left 관찰면

4. 저장소 역할 정렬
- `batch-integration`은 장기 허브가 아니라 전이용 staging 저장소
- 장기적으로 자산은 앱 repo, `bori`, `kube-slint`, `SF Observability` 운영 경로로 이관

## 현재 판단

- `SF Observability` rename 자체는 이미 원격까지 검증 완료
- 이번 스프린트는 기능 변경이 아니라 활성 문서 정렬 스프린트다
- 따라서 이 스프린트의 핵심 산출물은 코드가 아니라
  운영 기준과 계획 문서의 불일치 제거다

## 상태

- `Code Ready`: 완료
- `Remote Validated`: 해당 없음

설명:
- 이번 스프린트는 runtime 경로를 바꾸지 않고
  현행 기준 문서만 정렬했다.
- 따라서 별도 원격 smoke/gate 재실행은 요구되지 않는다.

## 다음 스프린트 초점

1. `batch-integration` 자산 이관표를 더 구체화
2. `bori` 중심 DevSpace 자산을 앱 repo 기준으로 정리
3. `SF Observability` publish/gate 경로의 장기 목적지 확정
