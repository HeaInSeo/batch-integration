# Validation Strategy

기준일: `2026-04-21`

## 원칙

- 초기 개발은 빠른 루프를 우선한다.
- 빠른 루프와 현실 검증 루프를 분리한다.
- 모든 기능을 무거운 환경에서 매번 검증하지 않는다.
- 로컬 작업 환경은 코드 준비와 문서화의 기준일 뿐, runtime truth가 아니다.
- 실제 검증 기준은 `100.123.80.48`의 `infra-lab` 장비다.
- `DevSpace + bori + kube-slint` 루프는 원격 기준선으로 취급한다.
- `SF Observability`는 공용 shift-left 관찰면으로 취급한다.

## 1. 빠른 개발 루프

- 환경: unit/integration harness + local process
- 대상: save, local integration, small change
- 목적:
  - JUMI-AH contract 깨짐 확인
  - metrics 노출 확인
  - kube-slint 최소 summary 확인
  - obvious churn regression 조기 탐지

## 2. 원격 개발 루프

- 환경: app repo + `DevSpace` + `bori` + `kube-slint`
- 대상: feature branch, PR 전
- 목적:
  - 원격 inner loop에서 앱별 smoke 실행
  - `slint-gate` 기준 gate 확인
  - summary diff 확인
  - high-cardinality label 누설 조기 탐지

## 3. 현실 검증 루프

- 환경: `100.123.80.48`의 `infra-lab` shared VM + dedicated namespace + `SF Observability`
- 대상: VM 경로 구축 완료 후 milestone, 기능 묶음 완료 후
- 목적:
  - 현실 압력에서의 churn 확인
  - fallback, cleanup debt, retention 경로 확인
  - regression 비교

## 4. 장기 회귀 루프

- 환경: `infra-lab` + `DevSpace` + `bori` + `kube-slint` + `SF Observability`
- 대상: nightly 또는 milestone gate
- 목적:
  - historical drift
  - long-run churn
  - distribution-based regression

## 적용 기준

- `Phase 2.5 ~ Phase 3`: cluster 비의존 빠른 루프가 주 검증 환경
- `Phase 3.5`: `DevSpace + bori + SF Observability` 최소 구축 스프린트
- `Phase 4`: 기능 개발 중심, 원격 DevSpace 루프와 milestone 검증 편입
- `Phase 5 ~ Phase 6`: 빠른 게이트 + 원격 회귀 환경 강화
