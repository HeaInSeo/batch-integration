# Review Checklist

## 공통

- 저장소 경계가 흐려지지 않았는가
- 문서 변경과 코드 변경이 같은 의미를 가리키는가
- backward compatibility를 의도적으로 깨뜨린 경우 근거가 기록되었는가

## JUMI

- `Inputs/Outputs` fallback이 유지되는가
- fixture와 테스트 영향이 확인되었는가
- lifecycle phase 추가가 executor 복잡도를 과도하게 올리지 않았는가

## artifact-handoff

- resolver service 경로를 유지하는가
- controller-style Kubernetes object 추가를 끌어오지 않았는가
- source priority와 lease 책임이 AH 쪽에 남아 있는가

## kube-slint

- high-cardinality label 누설 위험이 없는가
- derived indicator 계산이 소비자 스크립트로 새지 않는가
- 초기 단계에서 schema 범위를 과하게 키우지 않았는가

## 통합

- 첫 통합 happy path가 계속 유지되는가
- metrics names와 field names가 저장소마다 어긋나지 않는가
- sample-run 경계가 세 저장소에서 같은 의미로 쓰이는가
