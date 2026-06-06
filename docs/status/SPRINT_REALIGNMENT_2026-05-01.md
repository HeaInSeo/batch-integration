# Sprint Realignment

기준일: `2026-05-01`

## 목적

이번 문서는
`dev-space` 사용자 관찰면 구축 이후의
다음 스프린트 우선순위를 현재 코드와 운영 현실에 맞게 다시 고정한다.

핵심은 단순하다.

- `dev-space` 접근 경로는 닫혔다.
- `infra-lab`은 이미 실제 shared VM Kubernetes 운영 무대다.
- 제품 기준 `JUMI <-> artifact-handoff` 경계는
  `Cilium mesh` 위 `gRPC` 통신으로 확정돼 있다.

따라서 다음 스프린트의 지연 후보는
관찰면이 아니라
제품형 통신 경계 전환이다.

## 방금 닫힌 항목

### 1. 사용자 관찰면

- `dev-space` observability 페이지는 실제로 배포되어 있다.
- lab 내부 원본 주소:
  `http://dev-space.10.113.24.96.nip.io`
- tailnet 표준 사용자 진입점:
  `http://100.123.80.48:8008/`

관련 문서:

- [`DEV_SPACE_OBSERVABILITY_PUBLISH_2026-04-30.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/DEV_SPACE_OBSERVABILITY_PUBLISH_2026-04-30.md:1)
- [`DEV_SPACE_TAILNET_PROXY_2026-05-01.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/DEV_SPACE_TAILNET_PROXY_2026-05-01.md:1)

### 2. 표준 VM 검증 무대

- `infra-lab`은 `100.123.80.48` 상의 libvirt 기반 VM K8s 운영 무대다.
- 이 무대는 현재 다른 프로젝트와 shared 상태다.
- 따라서 다음 기본 선택지는 `별도 VM`이 아니라 `dedicated namespace`다.

## 코드 기준 현재 판단

### 1. artifact-handoff

- resolver service 골격 존재
- in-memory store 존재
- proto 계약 초안 존재
- HTTP surface와 binary entrypoint 존재

즉 `M1` 수준은 대체로 닫혀 있다.

### 2. JUMI

- `ArtifactBindings`, `SampleRunID`,
  `BuildingBindings`, `ResolvingInputs` seam은 코드에 반영돼 있다.
- `NotifyNodeTerminal`, `FinalizeSampleRun`,
  `RegisterArtifact`, `ResolveBinding` hook도 executor에 연결돼 있다.

하지만 현재 리스크도 분명하다.

- 기본 런타임 constructor는 아직 `NoopClient` 를 사용한다.
- HTTP client 경로는 존재하지만,
  제품 기준 경계인 `gRPC over Cilium mesh` 는 아직 닫히지 않았다.

### 3. kube-slint

- summary/gate 엔진은 기준선에 도달했다.
- 다음 초점은 엔진 자체 확장이 아니라
  실제 `JUMI/AH` 제품형 통합 경로와 결합하는 것이다.

## 지금 "밀린 것"의 재정의

이제 스프린트에서 밀린 것으로 봐야 할 것은 아래다.

- `dev-space` 구축 지연: 아님
- `infra-lab` 운영 무대 부재: 아님
- `JUMI <-> AH` 제품 통신 경계 미전환: 맞음
- shared VM 내 전용 namespace 기준 통합 경로 미고정: 맞음

즉 현재 overdue 성격의 항목은
`관찰면`이 아니라
`gRPC/Cilium 제품 경계 전환`이다.

## 다음 스프린트 목표

### G1. 제품 통신 경계 전환

- `artifact-handoff` gRPC server 경로를 구현한다.
- `JUMI` gRPC client 경로를 구현한다.
- 기본 실행 경로에서 `Noop` 사용을 개발 fallback로만 격리한다.

### G2. shared VM 위 dedicated namespace 고정

- `infra-lab` shared VM 내에
  `jumi-ah-dev` 수준의 dedicated namespace를 만든다.
- `JUMI`, `artifact-handoff`, 관련 Service를 그 namespace에 배치한다.
- 별도 VM은 실제 충돌이 확인되기 전까지 만들지 않는다.

### G3. 실제 통합 검증 1회 확보

- `JUMI -> artifact-handoff` 실제 gRPC 호출이 포함된
  최소 happy-path e2e 1개를 shared VM 경로에서 실행한다.
- 그 결과를 `kube-slint` summary/gate와 연결한다.
- 사용자는 계속 `dev-space`에서 그 결과를 읽는다.

## 지금 하지 않을 것

- host `kind + podman` 경로 재시도
- 별도 VM 신규 분리
- `kube-slint`를 대형 observability 플랫폼으로 확장

## 운영 원칙

- 관찰면 표준 주소는 `http://100.123.80.48:8008/` 이다.
- `infra-lab` shared VM은 현재 기본 무대다.
- 충돌 회피의 기본 수단은 별도 VM이 아니라 dedicated namespace다.
- 제품 의미를 갖는 통합 완료는
  `JUMI <-> artifact-handoff` 가 `gRPC over Cilium mesh` 로 연결될 때만 인정한다.
