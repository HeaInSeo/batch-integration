# Dev-Space Observability Publish

기준일: `2026-04-30`

## 목적

이번 문서는 원격 VM lab 클러스터에
`dev-space` 관찰면을 실제로 배포한 결과를 기록한다.

목표는 사용자가 `kube-slint` 기준으로
현재 개발 진행 상태와 회귀 여부를 직접 읽을
첫 번째 고정 URL을 제공하는 것이다.

## 배포 대상

- 원격 호스트: `100.123.80.48`
- 표준 제어면: `infra-lab`
- 클러스터 게이트웨이: `harbor/lab-gateway`
- 배포 네임스페이스: `dev-space`

## 사용 자산

- 정적 사이트:
  - `deploy/dev-space/site/index.html`
- 배포 매니페스트:
  - `deploy/dev-space/`
- 배포 스크립트:
  - `scripts/publish-dev-space-observability.sh`

입력 산출물:

- `artifacts/vm-lab/jumi-ah-smoke-live-sli-summary.json`
- `artifacts/vm-lab/gate/slint-gate-live-summary.json`

## 실제 수행 결과

배포 결과:

- `namespace/dev-space` 생성
- `service/dev-space-observability` 생성
- `deployment.apps/dev-space-observability` 생성
- `httproute.gateway.networking.k8s.io/dev-space-observability` 생성
- `configmap/dev-space-observability-site` 생성
- rollout 성공

실제 접근 주소:

- `http://dev-space.10.113.24.96.nip.io`

실제 확인 결과:

- HTTP status: `200 OK`
- 응답 server: `envoy`
- 정적 HTML 페이지 정상 반환 확인

## 사용자가 여기서 보는 것

이 페이지는 아래를 직접 노출한다.

1. 최신 `kube-slint` gate 결과
2. 최신 runId / sampleRunId
3. smoke metric별 threshold 판정
4. `sli-summary.json` 원문 링크
5. `slint-gate-summary.json` 원문 링크

즉:

- JUMI/AH가 실제로 최소 smoke를 통과했는지
- fallback / backlog / remote fetch 경로가 기준선 안에 있는지
- 현재 회귀 여부를 어떤 run 기준으로 해석하는지

를 사용자가 한 페이지에서 읽을 수 있다.

## 현재 판단

이번 배포로 `dev-space`는 아직 풀 개발 플랫폼은 아니지만,
이번 스프린트 목표였던 "사용자 관찰면" 역할은 시작할 수 있는 상태가 됐다.

즉 현재 단계에서 `dev-space`의 의미는:

- 코드 편집 공간이 아니라
- `kube-slint` 기준 진행 상태/회귀 관찰 공간

이다.

## 아직 남은 것

- summary/gate publish 시점을 더 자동화할지 결정
- baseline 비교 UI를 붙일지 결정
- `nodeforge -> nodevault` 전환 이후
  해당 워크로드도 같은 관찰면에 편입할지 결정
