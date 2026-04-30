# Dev-Space Observability Plan

기준일: `2026-04-30`

## 목적

`dev-space`를 단순 개발 편의 공간이 아니라
사용자가 현재 진행 상태와 회귀 여부를 직접 읽는 관찰면으로 만든다.

이번 단계에서는
별도 복잡한 개발 플랫폼을 먼저 도입하는 대신,
원격 VM lab에서 이미 생성되는 `kube-slint` 산출물을
정적 관찰 페이지로 노출하는 최소 경로를 만든다.

## 현재 확인 상태

- 원격 호스트: `100.123.80.48`
- 표준 제어면: `infra-lab`
- 원격 클러스터: 3노드 `Ready`
- `batch-int-dev`에 `JUMI`, `artifact-handoff` Running
- Harbor Gateway 경로 동작 중
  - host: `harbor.10.113.24.96.nip.io`
- `dev-space` 네임스페이스는 아직 없음

즉:

- 클러스터 관찰 진입점을 만들 네트워크 기반은 이미 있다.
- 아직 없는 것은 `dev-space`라는 사용자 관찰면 자체다.

## 왜 정적 관찰면부터 가는가

이번 스프린트의 목적은
"사용자가 무엇을 봐야 하는지"를 먼저 고정하는 것이다.

따라서 초기에 꼭 필요한 것은:

- 최신 smoke/live run ID
- gate 결과
- 핵심 metric delta
- threshold 기대값
- summary JSON 원문 링크

이 다섯 가지다.

이를 위해서는
복잡한 dashboard stack보다
정적 페이지 + JSON 산출물 노출이 더 작고 빠르다.

## 현재 사용 산출물

입력 산출물:

- `artifacts/vm-lab/jumi-ah-smoke-live-sli-summary.json`
- `artifacts/vm-lab/gate/slint-gate-live-summary.json`
- `policy/vm-lab/jumi-ah-live-thresholds.yaml`

이 산출물은 이미 아래 내용을 포함한다.

- runId
- sampleRunId
- per-metric smoke result
- gate PASS/FAIL
- threshold 기대값
- reliability 상태

즉 관찰면의 첫 버전은
새 데이터를 계산하지 않고도 만들 수 있다.

## 추가한 자산

이번 스프린트에서 아래 자산을 추가했다.

배포 자산:

- `deploy/dev-space/namespace.yaml`
- `deploy/dev-space/deployment.yaml`
- `deploy/dev-space/service.yaml`
- `deploy/dev-space/httproute.yaml`
- `deploy/dev-space/kustomization.yaml`

사이트 자산:

- `deploy/dev-space/site/index.html`

배포 스크립트:

- `scripts/publish-dev-space-observability.sh`

## 의도한 동작

1. 로컬 `batch-integration` 저장소에서 최신 summary/gate JSON을 읽는다.
2. 정적 사이트 bundle을 만든다.
3. 원격 `100.123.80.48`로 전송한다.
4. `dev-space` 네임스페이스에 nginx 기반 정적 페이지를 배포한다.
5. Harbor Gateway(`lab-gateway`)에 `HTTPRoute`를 붙인다.
6. 사용자는 아래 host로 관찰면에 접근한다.

- `dev-space.10.113.24.96.nip.io`

## 이 관찰면에서 보는 것

사용자는 여기서 아래를 읽는다.

1. 현재 gate 결과가 `PASS/FAIL/WARN/NO_GRADE` 중 무엇인지
2. 어떤 smoke metric이 기대값을 만족했는지
3. fallback / backlog / remote_fetch 같은 회귀 민감 지표가 흔들렸는지
4. 어떤 runId / sampleRunId 기준 판단인지
5. raw JSON 원문이 어디 있는지

즉 "개발이 잘 되고 있는지"를
파드 개수나 수동 로그 대신
`kube-slint` 기준으로 읽게 된다.

## 아직 남은 것

- 원격 배포 실제 실행
- `dev-space` host 접근 확인
- 필요 시 Gateway/ReferenceGrant 세부 조정
- baseline 비교 UI를 추가할지 판단
- 향후 자동 publish 시점 정의

## 현재 판단

이번 스프린트에서 `dev-space`를 바로 풀 개발 플랫폼으로 도입하는 것보다,
먼저 `kube-slint` 관찰면으로 고정하는 편이 맞다.

이유:

- 이미 있는 live smoke 산출물을 바로 활용 가능
- 사용자 목표와 정확히 맞음
- 향후 오퍼레이터 승격/hold 판단 UX와도 자연스럽게 연결됨
