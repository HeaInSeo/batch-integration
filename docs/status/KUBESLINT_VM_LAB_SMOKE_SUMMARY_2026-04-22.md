# kube-slint VM Lab Smoke Summary

기준일: `2026-04-22`

## 목적

VM lab에서 확인한 `JUMI -> artifact-handoff` smoke 결과를
`kube-slint`의 `sli-summary.json` 형식으로도 재현 가능하게 고정한다.

즉 이 문서는:

- 실제 VM lab smoke 결과를 입력 fixture로 보존하고
- `kube-slint` engine을 통해 summary JSON을 생성하며
- 이후 baseline/gate 입력으로 재사용할 수 있게 만드는 단계다.

## 추가 자산

- metrics fixture:
  - `deploy/vm-lab/fixtures/kube-slint-jumi-ah-smoke-metrics.json`
- summary generator:
  - `tools/kubeslint-smoke-summary/`
- generation script:
  - `scripts/generate-kubeslint-vm-lab-summary.sh`
- generated summary:
  - `artifacts/vm-lab/jumi-ah-smoke-sli-summary.json`

## 실행 방법

```bash
cd /opt/go/src/github.com/HeaInSeo/batch-integration
./scripts/generate-kubeslint-vm-lab-summary.sh
```

기본값:

- profile: `smoke`
- input fixture:
  - `deploy/vm-lab/fixtures/kube-slint-jumi-ah-smoke-metrics.json`
- output:
  - `artifacts/vm-lab/jumi-ah-smoke-sli-summary.json`

필요하면 아래처럼 profile을 바꿀 수 있다.

```bash
PROFILE=minimum ./scripts/generate-kubeslint-vm-lab-summary.sh
```

## 현재 의미

이번 summary는 live scrape 결과가 아니라
`2026-04-22` VM lab smoke에서 확인한 관측값을
fixture로 고정해 재생성한 결과다.

generator는 fixture replay 특성 때문에 생기는
`startSkewMs`, `endSkewMs` 감점을 기본적으로 정규화한다.

즉 replay summary에서는 reliability를 아래처럼 해석한다.

- `collectionStatus=Complete`
- `evaluationStatus=Complete`
- `configSourceType=injected`
- `configSourcePath=fixture_replay`

따라서 역할은 다음과 같다.

- `kube-slint` smoke guardrail의 expected shape 제공
- 이후 baseline 비교 입력의 초안 제공
- `vm + dev-space` 단계 전까지 회귀 기준 문서화

## 다음 단계

- live scrape 기반 fixture 수집 경로를 표준화
- 필요하면 이 summary를 gate 입력 예시까지 확장
- `vm + dev-space` 단계에서 churn 회귀 기준과 병합
