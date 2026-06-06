# Infra-Lab Dedicated Namespace Plan

기준일: `2026-05-01`

## 목적

`infra-lab` shared VM Kubernetes를
다른 프로젝트와 함께 쓰는 현재 현실을 전제로,
다음 스프린트의 기본 통합 무대를
`별도 VM`이 아니라 `dedicated namespace` 로 고정한다.

## 결정

기본 선택지:

- shared VM 유지
- dedicated namespace 생성
- `JUMI`, `artifact-handoff`, 관련 Service와 설정을 그 namespace에만 배치

후순위 선택지:

- 별도 VM 신규 분리

별도 VM은 아래 조건이 실제로 확인될 때만 고려한다.

- CRD 또는 cluster-scope 자산 충돌
- mesh/network policy 실험이 다른 프로젝트에 영향을 줌
- 성능 간섭이 summary/gate 결과를 흔듦
- destructive 테스트가 shared cluster에 위험함

## 제안 namespace

- `jumi-ah-dev`

이 namespace는 다음 스프린트 동안
`JUMI <-> artifact-handoff` 제품형 통합 검증의 기준 공간으로 사용한다.

## 배치 대상

- `artifact-handoff` gRPC Service
- `JUMI` workload
- 관련 ConfigMap / Secret / policy
- smoke fixture 실행에 필요한 최소 자산

초기 배치 자산:

- overlay:
  `deploy/jumi-ah-dev/`
- 원격 apply 스크립트:
  `scripts/apply-jumi-ah-dev.sh`
- 스크립트는 `batch-int-dev` 의 `harbor-regcred` 를
  `jumi-ah-dev` 로 복제해 image pull 전제 조건도 함께 맞춘다

주의:

- 이 overlay는 다음 스프린트의 namespace 기준 무대를 먼저 고정하는 목적이다.
- 현재 코드 기준 제품 목표는 `gRPC over Cilium mesh` 이지만,
  실제 gRPC server/client 전환이 닫히기 전까지는 기존 HTTP handoff 경로를 유지한다.
- 즉 이 배치는 `격리와 배포 기준`을 먼저 닫는 단계이고,
  `제품형 gRPC 경계`는 다음 구현 단계에서 이어진다.

`dev-space` 관찰면은 별도 namespace에 남겨도 무방하다.
핵심은 사용자 진입점과 데이터플레인 통합 검증 공간을
운영상 분리하는 것이다.

## 서비스 이름 원칙

다음 스프린트 기준 권장 예시는 아래다.

- namespace: `jumi-ah-dev`
- AH service: `artifact-handoff`
- AH DNS: `artifact-handoff.jumi-ah-dev.svc.cluster.local`

JUMI는 이 service DNS를 통해
`artifact-handoff`에 gRPC로 연결한다.

## 검증 순서

1. namespace 생성
2. `artifact-handoff` 배포 및 Service 노출
3. `JUMI`가 해당 Service DNS를 사용하도록 설정
4. 최소 happy-path fixture 1회 실행
5. `kube-slint` summary/gate 생성
6. 결과를 `dev-space`에 publish

초기 배포는 아래로 시작할 수 있다.

```bash
cd /opt/go/src/github.com/HeaInSeo/batch-integration
./scripts/apply-jumi-ah-dev.sh
```

## 운영 원칙

- namespace 분리는 지금 당장 가장 비용이 낮은 격리 수단이다.
- shared VM이라는 사실 자체를 문제로 보지 않는다.
- 제품 경계 검증을 가로막는 실제 충돌이 나올 때만 별도 VM으로 올린다.
