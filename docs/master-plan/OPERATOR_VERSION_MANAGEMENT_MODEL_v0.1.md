# Operator Version Management Model v0.1

## 목적

이 문서는 향후 도입할 오퍼레이터가
단순 설치기나 리소스 생성기가 아니라,
버전 전환, rename migration, 승격, 정리까지 관리하는
버전 수명주기 관리자여야 한다는 점을 고정한다.

배경:

- `nodeforge -> nodevault` 같은 rename transition이 이미 발생했다.
- 클러스터에는 아직 `nodeforge-system`, `nodeforge-controlplane` 잔재가 남아 있다.
- 단순 `kubectl apply` 모델만으로는
  새 이름 자산 배포, 기존 참조 유지, 안전한 전환, 구버전 정리를
  일관되게 처리하기 어렵다.
- `kube-slint`가 이미 회귀/승격 판단 엔진 후보로 존재한다.

따라서 향후 오퍼레이터는
"버전이 올라오면 자연스럽게 새 버전으로 흘러가게 하는"
모델을 담당할 수 있어야 한다.

## 핵심 판단

이 모델은 가능하다.

다만 처음부터 Knative Serving 전체 수준의 기능을 목표로 두지 않는다.
현재 환경에서는 다음 다섯 책임을 우선 가진
작은 수명주기 오퍼레이터부터 시작하는 것이 맞다.

1. desired state 선언 해석
2. 새 revision 배포
3. readiness / gate 확인
4. active reference 전환
5. 이전 revision 정리

## 문제 유형

향후 오퍼레이터가 풀어야 하는 실제 문제는 아래와 같다.

### 1. 이름 전환

예:

- `nodeforge-system` -> `nodevault-system`
- `nodeforge-controlplane` -> `nodevault-controlplane`
- `nodeforge.10.113.24.96.nip.io` -> `nodevault.10.113.24.96.nip.io`

이 경우 "구버전 삭제 후 신버전 생성"은 안전하지 않다.

필요한 모델:

- 구버전과 신버전 공존
- 신버전 readiness 확인
- route / reference / consumer 전환
- 구버전 drain 및 cleanup

### 2. 이미지/버전 승격

예:

- `:candidate`가 준비되면 `:stable`로 승격
- 새 image digest가 준비되면 active revision 전환

필요한 모델:

- pinned / stable / candidate 같은 채널 개념
- 자동 추적과 수동 hold 모두 지원

### 3. 회귀 방지

예:

- readiness는 통과했지만
  `fallback`, `backlog`, `churn`, `remote_fetch` 지표가 나빠지는 경우

필요한 모델:

- readiness 외에 policy gate 추가
- `kube-slint` 결과를 승격 판단에 반영

## 오퍼레이터 역할 경계

오퍼레이터는 아래를 담당한다.

- CRD 기반 desired state 해석
- revision 생성과 상태 추적
- 참조 전환 순서 보장
- 구버전 정리 정책
- 상태/condition 보고
- gate 결과를 반영한 promote / hold / rollback 판단

오퍼레이터가 담당하지 않는 것:

- `kube-slint` 자체 계산 엔진 구현
- 애플리케이션 비즈니스 로직 구현
- `infra-lab` 같은 VM lifecycle 관리

즉:

- `infra-lab`은 클러스터 lifecycle owner
- `JUMI`, `artifact-handoff`, `NodeVault` 등은 workload owner
- 오퍼레이터는 workload lifecycle orchestration owner

## 제안 CRD 모델

첫 단계에서는 복잡한 리소스 분해보다
번들 단위 리소스 하나로 시작하는 편이 현실적이다.

예시:

```yaml
apiVersion: platform.heainseo.dev/v1alpha1
kind: ManagedBundle
metadata:
  name: nodevault
spec:
  channel: stable
  version: "1.2.3"
  strategy:
    type: Progressive
    maxUnavailable: 0
    cleanupDelaySeconds: 600
  references:
    serviceName: nodevault-controlplane
    routeHost: nodevault.10.113.24.96.nip.io
  gate:
    mode: KubeSlint
    summaryRef:
      kind: ConfigMap
      name: nodevault-kubeslint-summary
    requiredResult: PASS
```

후속 분리 가능 예:

- `ManagedBundle`
- `ManagedRevision`
- `PromotionPolicy`
- `MigrationPolicy`

하지만 첫 구현은 `ManagedBundle` 하나로도 충분하다.

## 상태 모델

오퍼레이터는 사용자가 현재 전환 단계를 읽을 수 있게
명확한 상태를 노출해야 한다.

예시:

- `Ready`
- `Progressing`
- `Migrating`
- `Degraded`
- `Blocked`
- `CleanupPending`

상태 필드 예:

- `status.activeRevision`
- `status.pendingRevision`
- `status.previousRevision`
- `status.activeVersion`
- `status.observedGeneration`
- `status.lastPromotionResult`
- `status.lastGateResult`
- `status.conditions[]`

## Reconcile 단계

### Phase 1. 현재 상태 읽기

- active revision 확인
- desired version/channel 확인
- migration 대상 legacy resource 존재 여부 확인

### Phase 2. 새 revision 준비

- 새 Deployment / Service / Route / Secret binding 생성
- 필요한 네임스페이스/ReferenceGrant/HTTPRoute/GRPCRoute 구성

### Phase 3. readiness 확인

- Pod readiness
- Service endpoint
- Route programmed
- 최소 smoke endpoint

### Phase 4. gate 확인

- `kube-slint` summary/gate 결과 조회
- `PASS` 아니면 promote 금지
- `WARN` 허용 여부는 policy로 분리

### Phase 5. active reference 전환

- consumer가 바라보는 hostname / Service / Route 기준 전환
- 필요하면 alias 또는 compatibility route 유지

### Phase 6. cleanup

- grace period 이후 구버전 revision 삭제
- rename migration 완료 후 legacy namespace/resource 정리

## Rename migration 모델

이번 `nodeforge -> nodevault` 같은 케이스의 기본 원칙은 아래다.

1. legacy 리소스를 즉시 삭제하지 않는다.
2. 새 이름 리소스를 먼저 준비한다.
3. readiness와 gate를 통과시킨다.
4. 참조를 새 이름으로 전환한다.
5. cleanup delay 이후 legacy 리소스를 제거한다.

즉 rename은 단순 refactor가 아니라
오퍼레이터 관점에서는 `migration workflow`다.

## kube-slint 연계 모델

`kube-slint`는 오퍼레이터의 내장 로직이 아니라
외부 평가 결과를 제공하는 gate engine으로 다루는 편이 좋다.

기본 모델:

1. smoke or live run 실행
2. `sli-summary.json` 생성
3. `slint-gate-summary.json` 생성
4. 오퍼레이터가 이 산출물을 읽어 promote 가능 여부 판단

이 구조의 장점:

- gate 규칙을 오퍼레이터 바이너리와 분리 가능
- threshold / baseline / regression 정책을 독립적으로 조정 가능
- 현재 스프린트의 `dev-space` 관찰면과도 직접 연결 가능

## 도입 단계

### Stage 1. Install / Upgrade Operator

- 특정 bundle의 install / upgrade / cleanup만 수행
- 수동 version 지정
- readiness condition만 사용

### Stage 2. Rename / Migration Awareness

- legacy resource 감지
- dual-run 전환
- cleanup delay 도입

### Stage 3. Gate-aware Promotion

- `kube-slint` 결과 읽기
- PASS 시 promote
- FAIL 시 hold

### Stage 4. Channel Tracking

- `stable`, `candidate`, `pinned` 모델
- 자동 업데이트와 수동 고정 병행

### Stage 5. Progressive Rollout / Rollback

- 일부 전환 후 gate 재확인
- 실패 시 이전 revision 유지 또는 rollback

## 현재 스프린트와의 관계

이번 스프린트의 직접 목표는 오퍼레이터 구현이 아니다.

이번 스프린트의 직접 목표는:

- `dev-space`에서 진행 상태를 본다
- `kube-slint`로 효율/회귀를 읽는다

그러나 이 스프린트는 향후 오퍼레이터에 필요한
두 가지 기반을 먼저 만든다.

1. 사용자 관찰면
2. gate 기반 승격 판단 재료

즉 지금 만드는 `dev-space` 관찰면은
향후 오퍼레이터의 status/promotion UX로 자연스럽게 이어진다.

## 결론

향후 오퍼레이터에서 version/update/migration을 관리하는 모델은
충분히 가능하고, 현재 드러난 rename 잔재 문제를 보면
오히려 꼭 필요한 방향이다.

다만 출발점은 아래여야 한다.

- 작은 CRD
- 명확한 상태
- readiness + gate
- dual-run migration
- 늦은 cleanup

이 다섯 축을 먼저 닫고,
그 위에 channel tracking과 progressive rollout을 얹는 순서가 맞다.
