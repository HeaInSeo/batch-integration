# Batch Integration Operating Rules

이 디렉토리에서의 작업은 3개 저장소를 동시에 고려하는 통합 작업으로 취급한다.

규칙:
- 저장소별 canonical 설계는 각 저장소에 둔다.
- 이 디렉토리에서 저장소 내부 구현 문서를 다시 정의하지 않는다.
- 일정 변경은 반드시 통합 리스크와 의존성 기준으로 기록한다.
- `artifact-handoff`는 resolver service로 취급하고 controller 경로로 되돌리지 않는다.
- `JUMI` 변경은 backward compatibility를 우선한다. 특히 `Inputs/Outputs` fallback과 fixture 영향을 먼저 점검한다.
- `kube-slint` 변경은 초기에 schema 대개편보다 JUMI/AH 측정 가능 상태 확보를 우선한다.

작업 우선순위:
1. 저장소 간 contract를 먼저 고정
2. 첫 수직 통합 경로를 확보
3. lifecycle, GC, provenance, nightly 회귀를 순차 확장

금지:
- 상위 허브 문서를 근거로 각 저장소의 실제 코드 상태를 추정만 하고 밀어붙이는 것
- 동일한 설계 내용을 저장소와 허브 양쪽에 별도 원본처럼 유지하는 것
- 첫 통합 이전에 장기 최종형 기능을 병렬로 과도하게 확장하는 것
