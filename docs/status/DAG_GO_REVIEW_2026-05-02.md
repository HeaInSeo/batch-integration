# dag-go Review 2026-05-02

기준:
- `JUMI`가 현재 실제로 사용하는 `dag-go` surface만 본다
- 일반 기능 소개가 아니라 현재 스프린트와 일정 리스크 관점에서 본다

결론:
- `dag-go`는 `JUMI`의 DAG 실행 오케스트레이터다
- 하지만 현재 Sprint A에서 정리한 handoff failure semantics는 대부분 `JUMI` executor 책임이다
- `dag-go`가 직접 쥐고 있는 핵심은
  `parent failure fan-in`, `phase 전이`, `per-node execution timeout`, `Wait 종료 조건`이다

## JUMI가 실제로 쓰는 표면

`JUMI`는 아래 표면만 직접 사용한다.
- `InitDag`
- `CreateNode`
- `AddEdge`
- `FinishDag`
- `SetNodeRunners`
- `ConnectRunner`
- `GetReady`
- `Start`
- `Wait`

참조:
- [executor.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/executor/executor.go:188)

## Findings

1. downstream skip/failure fan-in의 1차 결정은 `dag-go`가 한다.
- `preFlight()`는 모든 parent channel을 기다리다가
  하나라도 `Failed`를 받으면 `PreflightFailed`를 돌린다.
  [node.go](/opt/go/src/github.com/HeaInSeo/dag-go/node.go:172)
- `connectRunner()`는 이 경우 child를 `Failed`로 알리고 종료한다.
  [dag.go](/opt/go/src/github.com/HeaInSeo/dag-go/dag.go:1313)
- 의미:
  downstream이 “왜 못 돌았는지”의 1차 신호는 `dag-go`가 만든다.
  `JUMI`는 그 위에 `dependency_failed`, `skipped`, fast-fail 의미를 덧씌운다.

2. `JUMI`의 handoff failure taxonomy는 `dag-go`가 아니라 executor 책임이다.
- `producer_failed`, `input_resolution_missing`, `notify_node_terminal_error`,
  `handoff_finalize_error` 같은 failure reason은 `JUMI`가 만든다.
  [executor.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/executor/executor.go:315)
- `dag-go`는 phase-level 성공/실패만 안다.
- 의미:
  Sprint A에서 한 failure semantics 작업은 라이브러리 문제가 아니라
  `JUMI` 쪽 정리였다는 판단이 맞다.

3. node timeout 책임은 `dag-go`가 갖고 있다.
- `connectRunner()`는 `Node.Timeout > 0` 또는 `Dag.Config.DefaultTimeout > 0`이면
  `RunE`에 별도 timeout context를 건다.
  [dag.go](/opt/go/src/github.com/HeaInSeo/dag-go/dag.go:1359)
- `preFlight`는 이 timeout을 소비하지 않고 caller context만 사용한다.
  [node.go](/opt/go/src/github.com/HeaInSeo/dag-go/node.go:172)
- 의미:
  timeout semantics를 바꾸려면 `JUMI` executor가 아니라 `dag-go`를 같이 봐야 한다.

4. `Wait()` 성공 조건은 end node의 `FlightEnd` 하나다.
- `Wait()`는 `EndNode`가 `FlightEnd`를 내보내면 성공,
  `PreflightFailed/InFlightFailed/PostFlightFailed`면 실패로 본다.
  [dag.go](/opt/go/src/github.com/HeaInSeo/dag-go/dag.go:1166)
- 의미:
  `JUMI`는 node registry를 따로 보며 run failure reason을 정교화해야 한다.
  `dag-go`만으로는 어떤 비즈니스 실패였는지 알 수 없다.

5. error fan-in은 존재하지만 `JUMI`는 거의 직접 쓰지 않는다.
- `dag-go`는 내부 `Errors` 채널과 `reportError/collectErrors`를 갖고 있다.
  [dag.go](/opt/go/src/github.com/HeaInSeo/dag-go/dag.go:542)
- 하지만 현재 `JUMI`는 registry와 event stream을 기준으로 fast-fail을 감지한다.
  [executor.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/executor/executor.go:220)
- 의미:
  현재 장애 분류의 주 기준은 `dag-go` error channel이 아니라 `JUMI` registry 상태다.

## Sprint Impact

Sprint A:
- 이미 한 작업 대부분은 `JUMI` 책임이었다
- `dag-go`에서 즉시 손봐야 할 blocker는 현재 보이지 않는다

Sprint B:
- timeout semantics를 더 세분화하려면 `dag-go` 영향이 있다

Sprint D:
- fast-fail, sibling cancel, downstream skipped semantics를 더 엄격히 다듬을 때
  `dag-go` behavior를 함께 검토해야 한다

## 정확한 판단

- `spawner`는 runtime contract owner라서 우선순위가 높다
- `dag-go`는 execution semantics owner지만,
  현재까지 드러난 스프린트 지연의 주원인은 아니다
- 따라서 다음 개발 우선순위는 여전히
  `artifact-handoff` lifecycle/cleanup 의미론과
  `JUMI -> spawner` runtime contract 정리 쪽이 더 높다
