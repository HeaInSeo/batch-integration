# kube-slint Delta v1.1

원본 대비 조정 사항:

- 초기에는 batch-aware 최종형 schema보다 개발 동반 측정 가능 상태를 우선한다.
- JUMI/AH metrics family 등록과 핵심 derived indicator 최소판을 먼저 한다.
- 첫 통합 이전에는 `kind + ko + tilt` 경로에서 최소 summary를 보는 것을 먼저 완료한다.
- `multipass/dev-space`는 첫 통합 이후 확장한다.
- JUMI/AH 기능 PR과 짝지어 회귀 확인에 쓰이도록 early gate 역할을 맡긴다.
- 첫 통합 이전에는 multi-component summary를 초안 수준으로 제한한다.
- nightly long-run과 distribution regression은 후행 단계로 둔다.
- low-cardinality guard는 운영성 강화 단계에 넣는다.

현재 우선순위:
1. JUMI/AH metrics family 등록
2. `kind + ko + tilt` 최소 수집/summary 경로
3. 핵심 derived indicator 최소판
4. 첫 통합 summary 출력과 회귀 확인
5. multi-component summary 초안
6. `multipass/dev-space`, nightly, p95 regression
