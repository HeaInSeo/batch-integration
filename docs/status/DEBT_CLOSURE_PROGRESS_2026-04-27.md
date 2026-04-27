# Debt Closure Progress

기준일: `2026-04-27`

## 목적

4월 말까지 새 기능을 더 넓히지 않고,
현재 진행된 `artifact-handoff` phase-1과 `JUMI` AH seam phase-1을
기술부채 적게 닫기 위한 진행 상태를 기록한다.

## 오늘 확인한 상태

### artifact-handoff

- resolver service 골격 유지
- sample-run lifecycle / GC 최소형 유지
- HTTP shim과 proto contract 정합성 보강
- JSON shape 정리
- 빌드 산출물 ignore 추가
- `go test ./...` 통과

오늘 추가로 정리한 항목:

- `FinalizeSampleRun`, `EvaluateGC`에서 caller context 사용
- `SampleRunLifecycle` JSON tag 추가
- register endpoint가 envelope body와 기존 flat body를 모두 수용하도록 정리
- proto에 `artifact_id`, `GetSampleRunLifecycle` contract 추가
- README / phase status 문서 정합성 보강
- HTTP 테스트에 envelope 등록과 lifecycle JSON key 확인 추가
- startup 시점에 known metrics를 0으로 preseed 하도록 정리

### JUMI

- AH client / executor seam 유지
- artifact binding, sampleRunId, metrics, HTTP integration test 유지
- 빌드 산출물 ignore 추가
- `go test ./...` 통과

오늘 추가로 정리한 항목:

- handoff client request JSON tag 정리
- resolve seam에 `artifactId` 전달 추가
- noop resolve가 빈 source node를 만들지 않도록 정리
- artifact register / finalize / GC metric은 실제 handoff 호출 성공 시에만 증가하도록 정리
- executable run spec 문서에 `sampleRunId`, `artifactBindings` 반영
- executor 테스트에 `artifactId` 전달과 register metric 확인 추가
- startup 시점에 known metrics를 0으로 preseed 하도록 정리

## 현재 판단

기술부채 관점에서 가장 위험했던 것은 기능 미완성보다
wire contract와 문서가 서로 다른 형태를 설명하던 부분이었다.

오늘 기준으로는:

- 코드
- 테스트
- 최소 문서
- HTTP/proto seam

이 네 축의 불일치는 눈에 띄게 줄어든 상태다.

## 오늘 추가 확인

- 원격 `100.123.80.48`의 `multipass` 사용자 명령을 복구했다.
- stale `core22` mount namespace와 user-data 경로 충돌을 분리해서 진단했다.
- `/usr/local/bin/multipass`를
  `root HOME + namespace discard + stale metadata cleanup + retry` 방식으로 교체했다.
- `multipass list`, `version`, `info`, `exec` 실사용 검증을 통과했다.

## 아직 남은 것

- raw `snap run multipass` 경로의 snapd platform debt는 별도 추적
- 4월 말 상태 문서를 월말 기준으로 한 번 더 정리
