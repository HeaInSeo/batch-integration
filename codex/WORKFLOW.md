# Codex Workflow

## 목적

3개 저장소 작업을 통합 순서에 맞춰 진행하기 위한 실행 규칙이다.

## 기본 순서

1. 현재 변경 대상이 어느 저장소인지 고정한다.
2. 변경이 저장소 내부인지 cross-repo contract인지 구분한다.
3. contract 변경이면 먼저 이 허브 문서를 갱신한다.
4. 코드 변경은 의존성 순서대로 진행한다.
5. 각 단계마다 최소 검증을 끝내고 다음 저장소로 넘어간다.

## 권장 작업 순서

1. `artifact-handoff` contract와 stub 구현
2. `JUMI` seam 삽입
3. `JUMI + artifact-handoff` happy path 검증
4. `kube-slint` 최소 metrics/summary 연결
5. lifecycle, GC, provenance, regression 확장

## 문서 갱신 규칙

- 일정 변경은 `plans/revised/INTEGRATED_REALIGNED_PLAN_v1.1.md`에 먼저 반영
- cross-repo 결정은 `docs/decisions/`에 기록
- 리스크 변화는 `docs/status/RISKS.md` 갱신

## PR 분할 기준

- PR 하나에 저장소 경계 1개만 넘는 것이 바람직하다.
- 첫 통합 전에는 대규모 리팩터링과 contract 변경을 같은 PR에 넣지 않는다.
- metrics 추가와 schema 개편은 가능하면 분리한다.
