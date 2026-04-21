# JUMI Delta v1.1

원본 대비 조정 사항:

- full lifecycle 완성보다 integration seam을 먼저 구현한다.
- `ArtifactBindings`와 `SampleRunID`를 P0로 둔다.
- executor의 전체 phase 완성보다 `BuildingBindings`, `ResolvingInputs` 최소 삽입을 먼저 한다.
- `Inputs/Outputs` fallback과 기존 fixture 호환을 유지한다.
- AH real client 연결은 AH 최소 계약 이후에 시작한다.

현재 우선순위:
1. spec 확장
2. executor seam 삽입
3. AH 호출 happy path
4. terminal/finalize 연결
5. provenance, retention, GC 고도화
