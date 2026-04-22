# VM Lab Smoke Eval Wrapper

기준일: `2026-04-22`

## 목적

VM lab smoke 검증에서 필요한 두 단계를
하나의 진입점으로 묶는다.

기존 분리 단계:

1. `kube-slint` summary 생성
2. `slint-gate` 평가

새 래퍼:

- `scripts/run-vm-lab-smoke-eval.sh`

## 실행 방법

```bash
cd /opt/go/src/github.com/HeaInSeo/batch-integration
./scripts/run-vm-lab-smoke-eval.sh
```

기본 동작:

- `scripts/generate-kubeslint-vm-lab-summary.sh` 실행
- `scripts/run-kubeslint-vm-lab-gate.sh` 실행
- 마지막에 아래 핵심 값 출력
  - summary path
  - gate path
  - result count
  - `gate_result`
  - `evaluation_status`
  - `measurement_status`
  - `overall_message`

## 현재 의미

이 래퍼는 아직 live scrape를 직접 수행하지 않는다.

지금 단계에서는:

- fixture replay 기반 summary 생성
- threshold-only gate 평가

까지를 한 번에 돌리는 운영 진입점이다.

즉 현재 용도는:

- VM lab smoke 회귀 상태를 빠르게 재확인
- summary와 gate 산출물을 항상 같이 갱신
- 이후 `vm + dev-space` 검증 래퍼의 기반 제공

## 다음 단계

이 래퍼 위에 아래 중 하나를 추가하면 된다.

- live metric collection -> fixture 갱신 -> summary -> gate
- direct live summary generation -> gate

현재는 첫 번째 방향이 더 안전하다.

이유:

- live scrape 실패와 gate 실패를 분리해서 해석할 수 있다
- 측정값 snapshot을 fixture로 남겨 문서/리뷰에 첨부하기 쉽다
