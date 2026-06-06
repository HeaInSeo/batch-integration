# Active Internal Library Review 2026-05-02

기준:
- `poc`와 과거 실험 repo는 제외
- 현재 활성 제품 경로(`JUMI`, `artifact-handoff`, `batch-integration`, `infra-lab`)에서
  실제로 import 또는 runtime wiring으로 연결되는 내부 라이브러리만 본다

결론:
- 현재 활성 경로에서 직접 봐야 하는 내부 라이브러리는 사실상 `spawner`와 `dag-go`다
- `artifact-handoff`는 현재 공통 내부 라이브러리를 직접 물지 않는다
- `go-grpc-kit`, `utils` 등은 현재 활성 경로의 직접 runtime dependency로 확인되지 않았다

## Active Dependency Map

`JUMI`
- `github.com/seoyhaein/dag-go`
  - executor DAG runtime
  - [executor.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/executor/executor.go:20)
- `github.com/seoyhaein/spawner`
  - backend runtime implementation
  - [spawner_k8s.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/backend/spawner_k8s.go:11)

`artifact-handoff`
- current direct internal library dependency not found

## Findings

1. `JUMI`의 실제 backend는 현재 사실상 `spawner` 하나다.
- `cmd/jumi`는 기본 adapter로 `NewSpawnerK8sAdapterFromKubeconfig()`를 바로 생성한다.
  [main.go](/opt/go/src/github.com/HeaInSeo/JUMI/cmd/jumi/main.go:24)
- `pkg/backend`에도 구현 파일은 `spawner_k8s.go` 하나뿐이다.
  [backend.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/backend/backend.go:7)
- 의미:
  `PrepareNode/StartNode/WaitNode/CancelNode` 의미론은 지금 사실상 `spawner`가 결정한다.

2. `JUMI` spec의 runtime 필드 일부가 `spawner`로 전달되지 않는다.
- `JUMI` node spec에는 `WorkingDir`, `ServiceAccountName`이 있다.
  [types.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/spec/types.go:81)
- 하지만 `toSpawnerRunSpec()`는 이 값을 전혀 넘기지 않는다.
  [spawner_k8s.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/backend/spawner_k8s.go:154)
- `spawner` `RunSpec` 자체에도 해당 필드가 없다.
  [types.go](/opt/go/src/github.com/HeaInSeo/spawner/pkg/api/types.go:92)
- 의미:
  현재 `JUMI` spec에 값을 넣어도 실제 K8s Job runtime에는 반영되지 않는다.

현재 상태 보정:
- `spawner`에는 `WorkingDir`, `ServiceAccountName`을 추가했다.
- `JUMI` adapter도 해당 필드를 채우도록 갱신했다.
- 다만 `JUMI`는 아직 릴리스된 `spawner` 버전을 참조하므로,
  dependency 버전이 올라가기 전까지는 reflection 기반 호환 모드로 유지한다.

3. same-node / placement 확장 포인트는 `spawner`에 있지만 `JUMI`에서 아직 연결하지 않는다.
- `spawner` `RunSpec`은 `Placement.NodeSelector`를 지원한다.
  [types.go](/opt/go/src/github.com/HeaInSeo/spawner/pkg/api/types.go:109)
- `k8s_driver`도 이를 실제 Pod `nodeSelector`로 반영한다.
  [k8s_driver.go](/opt/go/src/github.com/HeaInSeo/spawner/cmd/imp/k8s_driver.go:215)
- 하지만 `JUMI` node spec에는 placement 필드가 없고 adapter도 값을 넘기지 않는다.
  [types.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/spec/types.go:67)
  [spawner_k8s.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/backend/spawner_k8s.go:154)
- 의미:
  Sprint D의 same-node preferred는 `spawner` 문제가 아니라
  `JUMI spec -> adapter -> spawner` 연결 미완성 문제다.

4. cleanup TTL은 현재 policy가 아니라 adapter 상수에 묶여 있다.
- `JUMI` adapter는 모든 Job에 `TTLSecondsAfterFinished: 600`을 고정한다.
  [spawner_k8s.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/backend/spawner_k8s.go:201)
- `spawner`는 이 TTL을 그대로 Job spec에 반영한다.
  [k8s_driver.go](/opt/go/src/github.com/HeaInSeo/spawner/cmd/imp/k8s_driver.go:191)
- 의미:
  Sprint B/D에서 다룰 retention, cleanup debt, lifecycle 안정화는
  `artifact-handoff`만 손봐서는 안 되고 `JUMI -> spawner` cleanup contract도 정리해야 한다.

5. `spawner` K8s wait/cancel은 아직 PoC 성격이 강하다.
- `Wait()`는 watch가 아니라 2초 polling이다.
  [k8s_driver.go](/opt/go/src/github.com/HeaInSeo/spawner/cmd/imp/k8s_driver.go:84)
- `Cancel()`은 background delete만 수행한다.
  [k8s_driver.go](/opt/go/src/github.com/HeaInSeo/spawner/cmd/imp/k8s_driver.go:125)
- 의미:
  fast-fail, cancel latency, cleanup timing은 현재 `spawner` 구현 특성에 직접 영향을 받는다.
  이건 당장 치명적 blocker는 아니지만 Sprint D 운영성 항목과는 직접 연결된다.

## Priority

즉시 봐야 하는 것:
- `spawner`
  - runtime contract owner이기 때문

다음으로 봐야 하는 것:
- `dag-go`
  - fail-fast, sibling cancel, skipped/downstream semantics owner이기 때문

지금은 보류 가능한 것:
- `poc`
- `artifact-handoff-poc`
- 직접 import 되지 않는 workspace repo들

## Sprint Impact

Sprint A:
- `spawner` 자체가 직접 blocker는 아니었음
- 다만 cancellation/runtime semantics 확인에는 이미 영향을 주고 있음

Sprint B:
- cleanup TTL 상수, lifecycle/cleanup 연계가 리스크

Sprint D:
- same-node preferred, cleanup debt, cancel/wait stabilization은
  `spawner` 검토와 변경 없이는 닫기 어렵다
