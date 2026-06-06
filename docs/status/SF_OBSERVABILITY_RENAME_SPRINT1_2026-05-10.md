# SF Observability Rename Sprint 1 2026-05-10

기준일:
- `2026-05-10`

목적:
- `dev-space observability` 자산을 `shift-left-observability` / `SF Observability` 기준으로 실제 원격까지 전환한 결과를 기록한다.

## 최종 상태

- `Code Ready`: 완료
- `Remote Validated`: 완료

## 이번 스프린트에서 한 일

공식 자산명 변경:
- deploy path:
  `deploy/shift-left-observability`
- namespace:
  `shift-left-observability`
- service/deployment/httproute/configmap 이름 변경
- publish script:
  `scripts/publish-shift-left-observability.sh`
- tailnet proxy install script:
  `scripts/install-shift-left-observability-tailnet-proxy.sh`
- page title / visible label:
  `SF Observability`

페이지 쪽 변경:
- HTML title을 `SF Observability`로 변경
- 페이지 헤더를 `SF Observability`로 변경
- localStorage key를
  `shift-left-observability-sli-description-language`
  로 변경

proxy 쪽 변경:
- upstream host header를
  `shift-left-observability.10.113.24.96.nip.io`
  로 변경
- systemd/service/runtime/log 식별자도
  `shift-left-observability-tailnet-proxy`
  기준으로 정리

## 원격 수행 결과

대상 장비:
- `100.123.80.48`

실제 수행:

1. `publish-shift-left-observability.sh` 실행
2. `install-shift-left-observability-tailnet-proxy.sh` 실행
3. old `dev-space-tailnet-proxy`를 내리고
   new `shift-left-observability-tailnet-proxy`로 cutover

### 원격 배포 결과

생성/갱신:
- `namespace/shift-left-observability`
- `service/shift-left-observability`
- `deployment/shift-left-observability`
- `httproute/shift-left-observability`
- `configmap/shift-left-observability-site`

rollout:
- 성공

### 원격 검증 결과

tailnet entrypoint:
- `http://100.123.80.48:8008/`

metadata:
- `site_hostname = shift-left-observability.10.113.24.96.nip.io`
- `published_at = 2026-05-10T09:00:04Z`

page content:
- `<title>SF Observability</title>`
- `<h1>SF Observability</h1>`

proxy cutover:
- `shift-left-observability-tailnet-proxy.service`: `active`
- `dev-space-tailnet-proxy.service`: `inactive`

즉:
- 새 hostname
- 새 title
- 새 tailnet proxy
가 실제 운영 및 테스트 장비에서 살아 있음을 확인했다.

## 지금 닫힌 것

1. `DevSpace`와 `dev-space observability` 이름 충돌의 핵심 경로 제거
2. 공식 자산명을 `shift-left-observability`로 고정
3. 사용자 표시명을 `SF Observability`로 고정
4. 원격 tailnet 진입점이 실제로 새 이름 기준으로 응답함을 검증

## 아직 남은 것

1. 문서 전반의 옛 표현 정리
- 여러 상태 문서와 계획 문서에 아직 `dev-space` 표현이 남아 있다.

2. 일부 스크립트/문서의 backward compatibility 정리
- `PUBLISH_DEV_SPACE` alias 등은 현재 호환용으로 남아 있다.

3. 장기 자산 이관
- 현재 rename은 `batch-integration` 내부 자산 기준이다.
- 이후 `SF Observability` 운영 경로로의 장기 이관은 별도 스프린트 항목이다.

## 다음 스프린트 목표

- `DevSpace -> bori -> kube-slint -> SF Observability` 용어와 자산명을
  문서 전반에서 일관되게 맞춤
- `batch-integration` 자산 중 observability 관련 부분의 장기 목적지 정리

## 판단

- 큰 리스크 없이 이번 스프린트 목표는 달성됐다.
- 이제 rename 자체는 blocker가 아니다.
- 다음 본선은 이름 충돌 제거 이후,
  `batch-integration` 자산을 어떻게 장기 구조로 이관할지 정리하는 일이다.
