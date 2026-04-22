# kube-slint VM Lab Gate

기준일: `2026-04-22`

## 목적

VM lab smoke로 생성한 `sli-summary.json`을
`slint-gate` 입력으로 바로 넣어
기계 판정 결과 `slint-gate-summary.json`까지 재현 가능하게 만든다.

즉 이번 단계에서 닫는 경로는 아래다.

1. VM lab smoke 결과
2. `kube-slint` smoke summary 생성
3. threshold-only policy 평가
4. `slint-gate-summary.json` 산출

## 추가 자산

- gate policy:
  - `policy/vm-lab/jumi-ah-smoke-thresholds.yaml`
- gate run script:
  - `scripts/run-kubeslint-vm-lab-gate.sh`
- generated gate output:
  - `artifacts/vm-lab/gate/slint-gate-summary.json`

## 실행 방법

먼저 summary를 생성한다.

```bash
cd /opt/go/src/github.com/HeaInSeo/batch-integration
./scripts/generate-kubeslint-vm-lab-summary.sh
```

그 다음 gate를 실행한다.

```bash
cd /opt/go/src/github.com/HeaInSeo/batch-integration
./scripts/run-kubeslint-vm-lab-gate.sh
```

## policy 판단 방식

이번 예시는 baseline 회귀가 아니라
VM lab smoke 최소 성공 조건을 threshold로 고정한 policy다.

즉:

- regression: 비활성화
- reliability: `complete` 요구
- threshold miss만 fail 승격

이 정책을 쓰는 이유:

- 현재 단계에서는 baseline 없이도 PASS/FAIL 의미가 분명하다
- VM lab smoke가 살아 있는지 빠르게 검증할 수 있다
- 이후 `vm + dev-space` 단계에서 regression policy를 별도로 얹기 쉽다

## 기대 결과

현재 저장된 smoke summary 기준 기대 gate result는 `PASS`다.

근거:

- 모든 smoke threshold 충족
- replay summary reliability는 `complete`
- regression은 꺼져 있음

## 다음 단계

- live scrape 갱신 후 summary와 gate를 연속 생성하는 wrapper 추가
- 이후 baseline을 두고 regression-enabled policy 예시 추가
