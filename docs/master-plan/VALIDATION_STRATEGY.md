# Validation Strategy

기준일: `2026-04-21`

## 원칙

- 초기 개발은 빠른 루프를 우선한다.
- 빠른 루프와 현실 검증 루프를 분리한다.
- 모든 기능을 무거운 환경에서 매번 검증하지 않는다.
- `vm + dev-space`는 구축 완료 전까지 주 개발 경로로 취급하지 않는다.
- 그러나 `vm + dev-space` 현실 검증은 구축 완료 후 milestone 단위로 반드시 수행한다.

## 1. 빠른 개발 루프

- 환경: unit/integration harness + local process
- 대상: save, local integration, small change
- 목적:
  - JUMI-AH contract 깨짐 확인
  - metrics 노출 확인
  - kube-slint 최소 summary 확인
  - obvious churn regression 조기 탐지

## 2. 중간 검증 루프

- 환경: repo-local integration + 가능한 cluster 경로
- 대상: feature branch, PR 전
- 목적:
  - happy path e2e
  - summary diff 확인
  - high-cardinality label 누설 조기 탐지

## 3. 현실 검증 루프

- 환경: `multipass-k8s-vm + dev-space`
- 대상: VM 경로 구축 완료 후 milestone, 기능 묶음 완료 후
- 목적:
  - 현실 압력에서의 churn 확인
  - fallback, cleanup debt, retention 경로 확인
  - regression 비교

## 4. 장기 회귀 루프

- 환경: `multipass-k8s-vm + dev-space`
- 대상: nightly 또는 milestone gate
- 목적:
  - historical drift
  - long-run churn
  - distribution-based regression

## 적용 기준

- `Phase 2.5 ~ Phase 3`: cluster 비의존 빠른 루프가 주 검증 환경
- `Phase 3.5`: `vm + dev-space` 최소 구축 스프린트
- `Phase 4`: 기능 개발 중심, `vm + dev-space` milestone 검증 편입
- `Phase 5 ~ Phase 6`: 빠른 게이트 + `vm + dev-space` 주 회귀 환경
