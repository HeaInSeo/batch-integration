# Architecture Overview v1.0

## 목적

세 저장소의 역할 경계를 고정하고, 첫 통합 경로를 최소 단위로 정의한다.

## 저장소 경계

### JUMI

- DAG 실행과 node lifecycle의 owner
- binding 관계와 sample run 문맥의 owner
- AH 호출 시점과 child submit timing의 owner
- kube-slint가 읽는 batch executor metrics producer

### artifact-handoff

- long-lived resolver service
- artifact inventory, placement resolution, acquisition contract, lease, retention/GC evaluator의 owner
- backend adapter 경계의 owner

### kube-slint

- JUMI/AH/Kubernetes metrics 수집 및 평가 엔진
- raw metrics를 derived indicator로 바꾸는 guardrail owner
- 환경별 gate와 drift 감시 owner

## 첫 통합 경로

첫 통합은 아래 한 경로가 끝까지 연결되면 달성으로 본다.

1. JUMI가 `ArtifactBindings`를 해석한다.
2. JUMI가 AH의 `ResolveHandoff`를 호출한다.
3. AH가 in-memory inventory 기반으로 최소 placement/acquisition 응답을 준다.
4. JUMI가 해당 응답으로 node 실행을 계속한다.
5. JUMI와 AH가 핵심 metrics를 노출한다.
6. kube-slint가 이 metrics를 수집해 최소 요약을 만든다.

## 후속 확장 순서

1. first happy-path integration
2. terminal notification and sample finalization
3. retention and basic GC
4. cleanup debt and cardinality guard
5. provenance-ready hook
6. multi-environment and nightly regression
