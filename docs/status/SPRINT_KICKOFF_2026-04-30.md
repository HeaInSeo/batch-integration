# Sprint Kickoff

기준일: `2026-04-30`

## 목적

이번 스프린트의 가장 중요한 목표는
사용자가 `dev-space`에서 현재 개발 진행 상태를 직접 보고,
그 변화가 효율적인지, 회귀되지 않았는지를
`kube-slint` 기준으로 해석할 수 있게 만드는 것이다.

여기서 "본다"의 의미는 단순히 파드가 떠 있는지 확인하는 수준이 아니다.

- `JUMI`
- `artifact-handoff`
- 관련 인프라 경로

이 세 축에서 발생하는 메트릭, summary, gate 결과를 통해
"기능이 올라왔는지", "churn 또는 fallback 경로가 비정상적으로 흔들리지 않았는지",
"이전 기준선보다 나빠지지 않았는지"를 읽을 수 있어야 한다.

## 현재 기준선

이번 스프린트 시작 시점의 확인된 기준선은 다음과 같다.

### 1. JUMI

- `artifact-handoff` seam phase-1 기준선 반영 완료
- `artifactBindings`, `sampleRunId`, resolve/register/finalize/evaluate seam 포함
- handoff 계열 metrics preseed 반영 완료
- `go test ./...` 통과

관련 문서:

- [JUMI_AH_PHASE1_STATUS_2026-04-27.md](/opt/go/src/github.com/HeaInSeo/JUMI/docs/JUMI_AH_PHASE1_STATUS_2026-04-27.md)

### 2. artifact-handoff

- resolver phase-1 기준선 반영 완료
- sample-run lifecycle / evaluate GC 최소형 포함
- resolver metrics preseed 반영 완료
- `go test ./...` 통과

관련 문서:

- [PHASE1_RESOLVER_STATUS.md](/opt/go/src/github.com/HeaInSeo/artifact-handoff/docs/PHASE1_RESOLVER_STATUS.md)

### 3. kube-slint

- JUMI/AH smoke guardrail 기준 반영 완료
- Go CLI gate 경로 정착 완료
- 현재 워킹트리 추가 변경 없음
- `go test ./...` 통과

현재 판단:

- `kube-slint`는 이번 스프린트에서 "새로운 주인공"이 아니라
  JUMI/AH 진행 상태를 관찰하고 회귀를 판정하는 기준 엔진으로 사용한다.

### 4. VM lab / infra-lab

- 표준 랩 운영 저장소는 이제 `infra-lab`
- 표준 원격 호스트는 `seoy@100.123.80.48`
- `HOST_PROFILE=hosts/remote-lab.env` 기반 운영 모델 정착
- `infra-lab/scripts/k8s-tool.sh status`로 원격 상태 확인 성공
- 원격 클러스터의 3노드 `Ready` 확인
- `batch-int-dev`에서 `JUMI`, `artifact-handoff` Running 확인

### 5. 통합 기준선

- VM lab live smoke 성공
- `kube-slint` live gate `PASS` 성공
- `multipass` 사용자 CLI는 wrapper 경로 기준 복구 완료

관련 문서:

- [VM_LAB_LIVE_SMOKE_EVAL_2026-04-27.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/VM_LAB_LIVE_SMOKE_EVAL_2026-04-27.md)
- [MULTIPASS_STANDARD_CLI_RECOVERY_2026-04-27.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/MULTIPASS_STANDARD_CLI_RECOVERY_2026-04-27.md)

## 이번 스프린트의 핵심 질문

이번 스프린트는 기능을 무작정 더 넣는 스프린트가 아니다.
핵심 질문은 아래 한 가지다.

"사용자가 `dev-space`에서 JUMI/AH 진행 상태와 회귀 여부를
`kube-slint` 기준으로 직접 읽을 수 있는가?"

이 질문을 충족하려면 아래 네 축이 필요하다.

1. 원격 `100.123.80.48`에서 재현 가능한 배포/검증 경로
2. `dev-space` 또는 그에 준하는 사용자 관찰 진입점
3. `kube-slint` summary/gate/baseline 산출물
4. 같은 fixture 재실행 시 회귀 여부를 비교하는 절차

## 이번 스프린트 목표

### G1. `infra-lab`을 표준 제어면으로 고정

- `multipass-k8s-lab`이라는 예전 이름을 운영 기준에서 내린다.
- VM lifecycle, 상태 확인, backend 선택은 `infra-lab` 기준으로만 본다.

### G2. `dev-space`를 "사용자 관찰면"으로 정의

- `dev-space`는 단순 개발 편의 도구가 아니라
  사용자가 진행 상태와 회귀 여부를 읽는 자리로 정의한다.
- 여기서 사용자에게 보여야 하는 최소 대상은 아래다.
  - `JUMI` 상태
  - `artifact-handoff` 상태
  - smoke fixture 실행 결과
  - `kube-slint` summary
  - `slint-gate` 결과

### G3. `kube-slint`를 회귀 해석 엔진으로 사용

- 이번 스프린트에서 `kube-slint`는 다음 역할을 맡는다.
  - live metrics 수집
  - summary 생성
  - threshold gate 평가
  - 이후 baseline 기반 regression 비교

즉 이번 스프린트의 "진행률 관찰"은
ad-hoc한 로그 열람보다 `kube-slint` 산출물을 우선 기준으로 본다.

### G4. `dev-space` 검증 경로 착수

- 현재 문서 기준으로 `dev-space`는 아직 미구축이다.
- 이번 스프린트에서는 최소한 아래 중 하나를 닫아야 한다.
  - 실제 `dev-space` 설치/접근 경로 고정
  - 또는 `dev-space` 대체 관찰 워크플로우를 명시적으로 결정

## 이번 스프린트 완료 조건

아래 조건이 맞으면 이번 스프린트 목표를 달성한 것으로 본다.

1. `infra-lab` 기준 원격 랩 운영 경로가 문서와 실제 명령 모두 일치한다.
2. 사용자가 `100.123.80.48` 환경에서 진행 상태를 확인할 표준 진입점이 있다.
3. `JUMI/AH` fixture 실행 결과가 `kube-slint` summary와 gate로 남는다.
4. 같은 fixture를 다시 돌렸을 때 회귀 여부를 baseline 또는 threshold 기준으로 비교할 수 있다.
5. `dev-space`에서 무엇을 봐야 하는지와 왜 그것이 유효한지 설명 가능하다.

## 이번 스프린트에서 하지 않을 것

- `kube-slint`를 대형 observability 플랫폼으로 키우지 않는다.
- `infra-lab`을 프로젝트 workload 저장소로 바꾸지 않는다.
- `dev-space` 없이도 되는 ad-hoc 운영 습관을 표준 경로로 인정하지 않는다.

## 현재 판단

이번 스프린트의 우선순위는 맞다.

이미 JUMI/AH seam, VM lab smoke, `kube-slint` gate까지
최소 통합 기준선은 올라와 있다.

이제 필요한 것은
"기능이 있다"는 사실을 넘어서
"사용자가 진행 상태와 회귀 여부를 읽을 수 있다"는 운영면을 닫는 것이다.
