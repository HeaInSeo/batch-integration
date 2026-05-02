# K8s Shared gRPC Ingress Guideline v0.1

작성 목적: Cilium 기반 Kubernetes 환경에서 여러 app이 외부 app과 gRPC로 통신할 때,
외부 노출 방식을 각 app마다 제각각 만들지 않고 일관된 표준으로 고정한다.

이 문서는 특정 app 전용 문서가 아니다.
`NodeSentinel`, `NodeVault`, `NodePalette`, 그리고 이후 추가될 K8s data-plane / control-plane app이
공통으로 따라야 하는 ingress guideline이다.

---

## 0. 결론

기본 표준은 다음과 같다.

```text
공통 Gateway 인프라
  + 앱별 hostname
  + 앱별 Service
  + 앱별 GRPCRoute
```

즉:

- 외부 진입점 인프라는 공유한다.
- hostname은 app별로 분리한다.
- 각 app을 node 단위로 직접 외부 노출하지 않는다.
- gRPC backend는 항상 cluster 내부 `Service` 뒤에 둔다.

권장 예시:

```text
nodesentinel.apps.example.internal
nodevault.apps.example.internal
nodepalette.apps.example.internal
```

---

## 1. 왜 이 방식을 기본값으로 두는가

### 1.1 node-by-node 외부 노출은 운영 비용이 크다

각 app을 각 node에서 직접 외부에 노출하면:

- 포트 관리가 분산된다.
- 방화벽/ACL 관리가 복잡해진다.
- TLS 종료 지점이 분산된다.
- 장애 추적 시 어느 node가 ingress endpoint인지 계속 확인해야 한다.
- app이 늘수록 외부 엔드포인트 수가 급격히 증가한다.

이 방식은 특별한 저지연/고대역폭 요구가 없는 한 기본 패턴으로 삼지 않는다.

### 1.2 단일 hostname 공유보다 app별 hostname이 경계가 명확하다

단일 hostname 예시:

```text
grpc.example.internal
```

이 모델은 endpoint를 단순하게 보일 수는 있지만, 서비스 수가 늘면:

- route 규칙이 커진다.
- 정책 분리가 어렵다.
- 인증서/접근제어/관측을 app 단위로 나누기 어렵다.
- 외부 클라이언트 입장에서 어느 endpoint가 어느 app인지 덜 명확하다.

반면 app별 hostname은:

- DNS 경계가 곧 서비스 경계다.
- 앱별 TLS / authz / rate limit / observability 적용이 쉽다.
- 운영자가 endpoint만 보고도 backend app을 즉시 식별할 수 있다.

---

## 2. 표준 토폴로지

권장 구조:

```text
external app
  → shared Cilium Gateway
  → app-specific GRPCRoute
  → cluster Service
  → target app Pod
```

예시:

```text
NodeVault
  → nodesentinel.apps.example.internal
  → NodeSentinel Service

client / admin tool
  → nodepalette.apps.example.internal
  → NodePalette Service
```

핵심 원칙:

- shared Gateway는 공용 ingress plane이다.
- app별 route는 `Service` 단위로 분리한다.
- app Pod는 외부 네트워크 상세를 몰라야 한다.
- 외부 통신 계약은 hostname + gRPC contract로 고정한다.

---

## 3. Naming Rule

기본 hostname 규칙:

```text
<app>.apps.<base-domain>
```

예:

```text
nodesentinel.apps.example.internal
nodevault.apps.example.internal
nodepalette.apps.example.internal
```

규칙:

- app 이름은 Kubernetes `Service` 이름과 가능한 한 동일하게 맞춘다.
- hostname은 app 역할을 직접 드러내야 한다.
- `grpc.example.internal`처럼 모든 app을 하나의 이름 아래 숨기는 패턴은 기본값으로 쓰지 않는다.

---

## 4. Gateway / Route Ownership

소유권은 다음처럼 분리한다.

### 4.1 shared Gateway

- platform/infra 소유
- 공용 listener, TLS, 공통 policy를 담당

### 4.2 app-specific GRPCRoute

- 각 app 소유
- app 배포 단위와 함께 관리
- backend service와 hostname binding을 명확히 유지

즉:

```text
Gateway는 shared infra asset
GRPCRoute는 app-owned routing asset
```

---

## 5. Security / Policy Guideline

기본 정책:

- TLS는 shared Gateway에서 종료하거나, 필요 시 re-encrypt 정책을 둔다.
- app별 hostname마다 접근 주체를 분리할 수 있어야 한다.
- authn/authz는 shared Gateway 공통 계층 또는 app 계층 중 하나에 명확히 둔다.
- 외부에서 직접 Pod IP / node port를 호출하는 경로를 표준으로 인정하지 않는다.

추가 원칙:

- mTLS 필요 여부는 app 민감도에 따라 결정
- internal-only app은 public DNS 대신 private/internal domain 사용
- admin/control-plane app과 data-plane app을 같은 hostname으로 섞지 않는다

---

## 6. Cilium / Gateway API 기준 구현 단위

공통적으로 필요한 리소스:

- `Gateway`
- app별 `Service`
- app별 `GRPCRoute`
- 필요 시 `ReferenceGrant`
- 필요 시 `Certificate` / secret

구현 시 지켜야 할 점:

- route는 hostname 기준으로 먼저 분리한다.
- gRPC method 단위 분기는 예외적 보조 수단으로만 쓴다.
- app 간 내부 호출은 cluster-local DNS를 우선한다.
- 외부 app은 가능한 hostname만 알면 되게 설계한다.

---

## 7. 예외가 허용되는 경우

다음 경우에만 표준 예외를 검토한다.

- 초저지연 요구로 shared gateway hop 자체가 병목인 경우
- 특정 app이 node-local device / hostNetwork / 고정 node affinity를 강하게 요구하는 경우
- 규제/격리 요구로 별도 external endpoint가 반드시 필요한 경우

예외를 쓰더라도:

- 왜 shared gateway 표준을 따르지 않는지 문서화
- 대체 보안 경계와 운영 책임 명시
- hostname / certificate / monitoring 계획 분리

---

## 8. NodeSentinel에의 적용

현재 결정:

- `NodeSentinel`은 shared Gateway 뒤의 gRPC app으로 설계한다.
- 권장 hostname은 `nodesentinel.apps.<base-domain>` 패턴을 따른다.
- `NodeVault`는 `NodeSentinel`의 node IP나 node-local port가 아니라,
  `NodeSentinel` hostname을 통해 enqueue ingress에 접근한다.

즉:

```text
NodeVault
  → nodesentinel.apps.<base-domain>
  → shared Gateway
  → NodeSentinel Service
```

---

## 9. 다른 app에 대한 개발 가이드

새 app이 외부 gRPC endpoint를 가져야 한다면, 기본 체크리스트는 다음과 같다.

1. 이 app이 정말 외부 노출이 필요한지 먼저 판단한다.
2. 필요하다면 기존 shared Gateway를 재사용한다.
3. app별 hostname을 먼저 정한다.
4. app별 `Service`와 `GRPCRoute`를 만든다.
5. node 직접 노출이나 app별 독립 gateway는 예외 사유가 있을 때만 선택한다.
6. README/운영 문서에 hostname, owner, auth model, backend service를 남긴다.

---

## 10. 문서 연결

이 guideline을 참조해야 하는 문서:

- `NodeVault_Reproducible_Tool_Authoring_업그레이드_설계_v0.6.1.md`
- `NodeSentinel_Validation_Data_Plane_설계_v0.1.md`
- 이후 추가될 app의 deploy / architecture / platform 문서
