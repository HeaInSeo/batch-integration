# artifact-handoff Delta v1.1

원본 대비 조정 사항:

- greenfield 특성을 반영해 최소 resolver contract를 최우선으로 한다.
- 5개 RPC 전체 완성보다 우선 3개 happy path를 만든다.
- controller naming과 사고방식은 early phase에서 정리한다.
- backend adapter와 in-memory store를 먼저 두고, Dragonfly는 뒤로 미룬다.
- lifecycle/GC는 타입과 빈 경로를 먼저 두고 점진 확장한다.

현재 우선순위:
1. resolver service 골격
2. proto 초안
3. in-memory inventory/store
4. `RegisterArtifact`, `ResolveHandoff`, `NotifyNodeTerminal`
5. `FinalizeSampleRun`, `EvaluateGC`
