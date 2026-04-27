# Harbor Push Timeout Incident

기준일: `2026-04-27`

## 상황

`artifact-handoff` phase-1, `JUMI` AH seam phase-1 기준선을
원격 VM lab 호스트에서 새 이미지로 다시 올리기 위해
다음 tag로 빌드/푸시를 시작했다.

- tag: `phase1-20260427-101256z`

원격 호스트:

- `seoy@100.123.80.48`

빌드 경로:

- `/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/build-vm-lab-images.sh`

## 먼저 해결된 문제

초기 build 실패 원인은 `artifact-handoff/.gitignore` 패턴이었다.

- 잘못된 ignore:
  - `artifact-handoff-resolver`
- 영향:
  - 루트 binary뿐 아니라 `cmd/artifact-handoff-resolver/` 디렉토리까지 같이 무시
  - 결과적으로 원격 clone에 resolver entrypoint source가 빠졌고 build가 실패

복구:

- ignore를 `/artifact-handoff-resolver`로 수정
- `cmd/artifact-handoff-resolver/main.go`를 추적 대상으로 복구
- 복구 커밋:
  - `artifact-handoff` `1e60fbc` `Track resolver entrypoint source`

## 현재 이슈

entrypoint 문제를 고친 뒤 build 자체는 통과했다.

확인된 상태:

- `artifact-handoff` image build 성공
- `JUMI` image build 성공
- 현재 병목은 Harbor push 단계

관찰된 에러:

```text
trying to reuse blob ... at destination: pinging container registry harbor.10.113.24.96.nip.io:
Get "http://harbor.10.113.24.96.nip.io/v2/": dial tcp 10.113.24.96:80: i/o timeout
```

즉 현재 문제는 애플리케이션 코드가 아니라,
원격 호스트에서 Harbor registry endpoint로 접근하는 경로의 timeout이다.

## 현재 판단

이번 회차 기준 기술부채 성격은 다음과 같다.

1. 코드 debt
   - phase-1 기준선은 테스트와 커밋으로 이미 닫힘
2. 이미지 build debt
   - entrypoint 누락 문제는 복구 완료
3. 환경/운영 debt
   - Harbor reachability 또는 registry responsiveness가 현재 재검증의 실질 blocker

## 다음 확인 포인트

- 원격 호스트에서 Harbor endpoint reachability 재확인
- timeout이 artifact-handoff push에만 걸리는지, 전체 registry 문제인지 확인
- 필요 시 unique tag 재시도 대신 Harbor/네트워크 경로 먼저 점검
