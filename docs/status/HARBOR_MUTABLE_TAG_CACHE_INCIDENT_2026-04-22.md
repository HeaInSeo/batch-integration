# Harbor Mutable Tag Cache Incident

기준일: `2026-04-22`

## 증상

`artifact-handoff`, `JUMI` 코드를 수정하고
같은 태그 `:dev`로 Harbor에 다시 push한 뒤
deployment를 restart 했지만,
VM lab의 동작은 이전과 동일해 보였다.

실제 관찰:

- smoke 재실행 시 여전히 이전 증상이 남아 있었음
- 이후 unique tag로 바꾸자 동작이 즉시 달라짐

## 원인

배포 설정이 아래 조합이었다.

- `imagePullPolicy: IfNotPresent`
- mutable tag `:dev`

이 경우 rollout restart가 일어나도
노드가 로컬 캐시 이미지로 pod를 다시 올릴 수 있다.

즉:

- Harbor에는 새 이미지가 올라가도
- cluster는 예전 캐시 이미지를 계속 사용할 수 있다

## 복구

이번 복구는 두 단계로 진행했다.

1. unique tag 생성
   - `vmfix-20260422-1015`
2. deployment image 명시 갱신
   - `artifact-handoff=...:vmfix-20260422-1015`
   - `jumi=...:vmfix-20260422-1015`

그 후 smoke 재검증에서
수정된 동작이 실제로 반영된 것을 확인했다.

## 운영 기준

개발 단계에서도 아래 둘 중 하나는 지켜야 한다.

- immutable/unique tag 사용
- 또는 mutable tag를 쓸 거면 `imagePullPolicy: Always`

현재 VM lab 경로에서는
고유 태그 사용이 더 안전하다.

이유:

- Harbor push 결과와 실제 cluster 동작을 일치시켜 준다
- 회귀 검증 시 어떤 빌드가 올라갔는지 추적이 가능하다
- smoke 결과를 문서/이슈와 연결하기 쉽다

## 후속 권장

- `deploy/vm-lab/README.md`에 mutable tag 주의사항 추가
- smoke/배포 스크립트에서 기본 tag를 timestamp 또는 git SHA 기반으로 생성하는 방향 검토
