# DevSpace Platform Realignment 2026-05-10

기준일:
- `2026-05-10`

목적:
- 현재 코드와 문서, 스크립트, 운영 경로를 다시 묶어
  `DevSpace + infra-lab + kube-slint + SF Observability` 기준의
  다음 진행 방향을 확정한다.
- `batch-integration`의 역할과 각 앱 repo의 역할을 분리한다.
- `dev-space`라는 이름 충돌 문제와 rename 순서를 정리한다.

## 결론 요약

1. `DevSpace`는 폐기 대상이 아니다.
- 앞으로 `infra-lab` 위에서 실제 원격 통합 개발 루프를 담당해야 한다.

2. 현재 `dev-space observability`는 `DevSpace`와 이름이 충돌한다.
- 공식 인프라/배포 이름은 `shift-left-observability`
- 사용자 표시 이름은 `SF Observability`
  로 분리하는 것이 맞다.

3. `kube-slint`도 `JUMI/AH` 전용 도구가 아니라 공용 shift-left gate 계층으로 봐야 한다.

4. `batch-integration`은 장기 유지 대상이 아니다.
- `DevSpace` 기반 경로가 올라오면 전이용 통합 저장소 역할을 마치고
  단계적으로 비워지거나 제거되는 방향이 맞다.

## 현재 사실관계

### 1. DevSpace 현재 상태

현재 확인된 사실:

- `JUMI/devspace.yaml` 존재
  - [JUMI/devspace.yaml](/opt/go/src/github.com/HeaInSeo/JUMI/devspace.yaml:1)
- `artifact-handoff/devspace.yaml` 존재
  - [artifact-handoff/devspace.yaml](/opt/go/src/github.com/HeaInSeo/artifact-handoff/devspace.yaml:1)
- 두 파일 모두 `after:deploy` hook에서 `bori-devspace`를 호출하려는 흔적이 있다.

하지만 현재 환경에서 확인된 상태:

- `devspace` CLI 없음
- `bori-devspace` 없음

즉 지금 상태는:

- DevSpace 설정 파일은 남아 있다.
- 그러나 현재 활성 개발 루프의 본선 경로는 아니다.
- 지금 본선 경로는 `infra-lab + kubectl + run-jumi-ah-dev-live-smoke-eval.sh + publish`다.

### 2. 현재 활성 통합 경로

현재 실제로 동작하는 경로:

- `infra-lab` shared VM
- `jumi-ah-dev` namespace
- live smoke:
  [run-jumi-ah-dev-live-smoke-eval.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/run-jumi-ah-dev-live-smoke-eval.sh:1)
- publish:
  현재 스크립트 rename 중이지만 실질 역할은 observability publish 경로다
- gate:
  `kube-slint` summary/gate
- observability page:
  현재 이름은 `dev-space observability`

즉:

- DevSpace는 예정된 개발 루프
- 현재 돌아가는 것은 smoke/gate/publish 중심의 통합 검증 루프

### 3. dev-space 이름 충돌

현재 `dev-space`는 아래 의미로 쓰이고 있다.

- namespace 이름
- hostname 일부
- publish script 이름
- tailnet proxy 이름
- observability page 제목
- 여러 문서의 공용 검증 환경 이름

문제:

- `DevSpace`를 앞으로 실제 개발 루프로 사용할 계획이면
  `dev-space` observability 이름은 계속 설명 비용을 만든다.
- 문서, 대화, 운영 스크립트에서 두 개를 계속 구분해야 한다.

따라서 rename은 필요하다.

## 플랫폼 역할 재정의

### infra-lab

역할:
- 공용 원격 실행 기반
- VM/Kubernetes/네트워크 표준 실행 무대

의미:
- 각 데이터플레인 앱이 공통으로 의존하는 실행 substrate

### DevSpace

역할:
- 앱별 remote inner loop
- sync, build, deploy, iterative development

의미:
- 개발자가 실제로 코드를 바꾸고 빠르게 원격 반복 개발을 수행하는 경로

### kube-slint

역할:
- 공용 shift-left gate/summary 계층

의미:
- `JUMI/AH` 전용이 아니라
  이후 다른 데이터플레인 앱도 동일한 summary/gate 패턴으로 붙어야 한다.

### SF Observability

역할:
- 공용 shift-left evidence surface

의미:
- 앱 공통 관찰면
- 현재 첫 onboarded app은 `JUMI/AH`
- 이후 다른 데이터플레인 앱도 같은 page/model에 붙을 수 있어야 한다.

### batch-integration

현재 역할:
- cross-repo 통합 기준 임시 저장소
- 공통 계약 정리
- 공통 smoke/gate/publish 루프 실험
- 공통 문서 초안

장기 의미:
- 최종 목적지는 아니다.
- `DevSpace + infra-lab + kube-slint + SF Observability` 경로가 앱 repo 중심으로 정리되면
  `batch-integration`에 있던 자산은 각 목적지로 이관돼야 한다.
- 즉 이 저장소는 `permanent control-plane`이 아니라 `migration staging area`에 가깝다.

## batch-integration 에서 이관할 것

장기적으로 각 목적지로 옮겨야 할 것:

- 앱 repo 또는 공용 DevSpace layer로 이관:
  - 앱별 inner dev loop
  - source sync
  - app image build/push
  - 앱별 deploy 반복
  - 앱별 smoke trigger 시점
  - 앱별 developer workflow
  - `devspace.yaml`와 hook 기준

- `kube-slint` 또는 공용 gate layer로 이관:
  - 앱 독립적인 summary/gate adapter
  - 공통 threshold/gate profile 모델

- `SF Observability` 전용 운영 경로로 이관:
  - observability static site
  - publish script
  - tailnet proxy 자산

- 장기 기준 문서 목적지로 이관:
  - 살아남아야 할 계약 문서
  - 플랫폼 운영 문서
  - 앱 독립적인 통합 규약

즉 정확히 말하면:

- `batch-integration`에서 했던 실제 개발 실행 방식은 `DevSpace`로 넘어가야 한다.
- `batch-integration`에서 만든 공통 자산도 장기적으로는 제자리에 다시 배치돼야 한다.
- 최종 상태에서 `batch-integration` 자체가 필수 허브로 남는 구조는 목표가 아니다.

## 이름 전략

공식 이름:
- `shift-left-observability`

표시 이름:
- `SF Observability`

이름 전략 이유:

- `DevSpace`와 명확히 분리된다.
- `JUMI/AH` 전용으로 잠기지 않는다.
- 다른 데이터플레인 앱이 붙어도 이름이 안 깨진다.

이름 사용 규칙:

- K8s namespace, hostname, script, deploy path, proxy unit, 문서의 공식 자산명:
  `shift-left-observability`
- 페이지 title, 사용자 표시 이름, 약칭:
  `SF Observability`

## 현재 코드 기준 리스크

1. DevSpace 경로는 설정 파일은 있으나 현재 활성 루프가 아니다.
- 설정은 있지만 CLI/helper가 현재 환경에 없다.
- 따라서 “계획된 경로”와 “현재 활성 경로”가 다르다.

2. observability rename 영향 범위가 넓다.
- deploy path
- namespace
- hostname
- publish script
- proxy asset
- 문서
- page title/localStorage key

3. DevSpace를 살릴 때도 공통 summary/gate/publish 계약 자체는 버리면 안 된다.
- 각 앱 repo가 제각각 summary/gate/publish를 만들면 다시 파편화된다.
- 다만 그 공통 계약의 보관 장소가 반드시 `batch-integration`일 필요는 없다.

4. `kube-slint`는 앱 전용 표현에 묶이면 안 된다.
- 공통 gate 모델 유지가 중요하다.

## 권장 진행 순서

### Phase 1. Naming Realignment

목표:
- observability 이름 충돌 제거

해야 할 일:
- `dev-space` observability 자산을 `shift-left-observability`로 rename
- 표시 제목은 `SF Observability`로 변경
- 문서 표현 보정

완료 기준:
- 공식 자산명에서 `dev-space observability`가 사라짐
- `DevSpace`와 혼동 없이 대화/문서가 가능

### Phase 2. Platform Document Realignment

목표:
- 네 구성요소의 역할을 고정

해야 할 일:
- `infra-lab`, `DevSpace`, `kube-slint`, `SF Observability`의 역할 문서화
- `JUMI/AH`를 “첫 onboarded app”으로 재서술
- `batch-integration`을 장기 허브가 아니라 전이용 저장소로 재정의

완료 기준:
- 문서가 현재 실제 의도와 같은 말을 함

### Phase 3. DevSpace Reactivation

목표:
- `JUMI`와 `artifact-handoff` repo의 DevSpace 경로를 다시 실제로 사용 가능하게 만듦

해야 할 일:
- `devspace.yaml` 재검토
- `bori-devspace` 의존 여부 정리
- 실제 원격 `infra-lab` loop에 맞게 sync/build/deploy hook 정리
- smoke 실행 타이밍과 `kube-slint` 연계 지점 고정

완료 기준:
- 개발자가 repo에서 DevSpace로 원격 루프를 실제 수행 가능

### Phase 4. Asset Migration Out Of batch-integration

목표:
- `batch-integration`에 쌓인 자산을 장기 목적지로 옮김

해야 할 일:
- 어떤 자산이 어느 저장소/레이어로 가야 하는지 분류
- DevSpace 관련 자산은 앱 repo 또는 공용 DevSpace layer로 이동
- observability 자산은 `SF Observability` 운영 경로로 이동
- 공통 gate 모델은 `kube-slint` 쪽 기준과 맞춤
- 최종적으로 `batch-integration`에 남겨야 할 것이 있는지 다시 판단

완료 기준:
- `batch-integration` 없이도 개발/검증/관찰 루프가 설명 가능

## 일정 제안

### Sprint 1

범위:
- observability rename
- 플랫폼 역할 문서 정리

산출물:
- `shift-left-observability` 자산명 정리
- `SF Observability` 표시 반영
- DevSpace/infra-lab/kube-slint/SF Observability 역할 문서

### Sprint 2

범위:
- `JUMI` DevSpace 루프 복구
- `artifact-handoff` DevSpace 루프 복구

산출물:
- repo별 DevSpace 실행 경로
- 원격 `infra-lab` 개발 루프 실증

### Sprint 3

범위:
- DevSpace loop와 `kube-slint` shift-left gate 결합
- 결과를 `SF Observability`에 publish

산출물:
- 개발 중 gate 확인 경로
- 공통 summary/publish adapter

### Sprint 4

범위:
- 자산 이관과 `batch-integration` 축소

산출물:
- 목적지별 자산 이관 계획
- `batch-integration` 제거 전 체크리스트

## 최종 판단

- 현재 코드와 문서는 `DevSpace`를 버리는 방향보다
  `DevSpace`를 다시 본선 개발 루프로 올리는 방향이 맞다.
- 다만 `batch-integration`은 장기 공통 허브로 남기기보다,
  필요한 자산을 각 목적지로 이관한 뒤 비워지거나 제거되는 방향이 맞다.
- `dev-space observability`는 지금 단계에서 이름을 바꾸는 것이 맞다.
- `kube-slint`와 `SF Observability`는 둘 다 공용 플랫폼 층으로 봐야 한다.
- `JUMI/AH`는 그 위에 올라간 첫 번째 데이터플레인 앱으로 재정의하는 것이 가장 일관된다.
