# Sprint Status

기준일: `2026-04-22`

이 문서는 원본 일정 문서의 상위 목표를 유지한 채,
현재 스프린트에서 실제 진행 상황을 보고하기 위한 문서다.

## 스프린트 목표

- `artifact-handoff` lifecycle seam을 실제 서비스 형태로 더 고정
- `JUMI -> artifact-handoff` resolve/register/finalize seam을 확대
- `kube-slint`가 해당 seam의 회귀 지표를 최소 기준으로 감시
- VM lab에서 첫 실제 배포를 성공시켜 이후 회귀 검증의 발판을 만든다

## 완료

### 1. artifact-handoff

- resolver service 최소 구현 정리
- artifact register metric 추가
- sample run finalize / GC evaluate 최소 규칙 확장
- `Containerfile`, `Dockerfile` 준비

### 2. JUMI

- AH client 경로 확장
  - `RegisterArtifact`
  - `ResolveBinding`
  - `NotifyNodeTerminal`
  - `FinalizeSampleRun`
  - `EvaluateGC`
- executor가 node output을 AH에 등록하도록 확장
- resolve 결과를 node env로 주입하도록 확장
- sample run 종료 시 finalize/evaluate hook 연결
- `Containerfile`, `Dockerfile` 준비

### 3. kube-slint

- JUMI/AH minimum guardrail spec 확장
- artifact register / resolve / materialization / finalize / GC 관련 delta 추가

### 4. VM lab

- Harbor project `batch-int` 생성
- 원격 fallback 경로로 첫 이미지 push 완료
- `batch-int-dev` namespace에 첫 배포 완료
- ImagePullBackOff 원인 규명 및 복구 완료
- 현재 `artifact-handoff`, `JUMI` 둘 다 Ready 상태 확보

## 진행 중

- JUMI submit fixture 또는 최소 run path로
  AH resolve/register/finalize가 실제로 왕복되는지 검증하는 작업
- kube-slint가 VM lab 관찰 결과를 어떻게 summary에 반영할지 연결하는 작업

## 막힌 점

- `kind + tilt` 주 경로는 현재 host kernel/cgroup 제약 때문에 막혀 있다
- `multipass` user CLI와 `multipass exec`는 여전히 불안정하다
- 로컬 workspace host에서 Harbor 직접 접근이 안 되어 `ko -> Harbor push`를 바로 쓰기 어렵다

## 현재 판단

원본 설계 일정의 큰 축은 유지 가능하다.
다만 이번 스프린트의 현실적 실행 경로는 아래가 맞다.

- 주 개발: `artifact-handoff`, `JUMI`, `kube-slint` seam 확장
- 환경 검증: VM lab direct SSH 경로 활용
- 이미지 빌드: 설계상 `ko`, 운영상 당분간 remote `podman/buildah` fallback 병행

## 다음 액션

1. JUMI 최소 submit/execute 경로로 AH resolve seam 검증
2. 해당 결과를 kube-slint minimum guardrail과 연결
3. VM lab에서 반복 가능한 smoke/회귀 절차 문서화
4. `dev-space`는 이후 검증 단계에서 별도 착수

## 일정 영향

현재까지는 상위 일정 전체를 늦추는 조정이 아니라,
하위 실행 경로를 현실에 맞게 바꾼 수준이다.

즉:

- 설계 문서의 상위 milestone 해석은 유지
- 세부 실행 순서는 VM lab 검증이 가능하도록 재정렬
- 큰 완료 시점 자체를 다시 미루는 판단은 아직 필요하지 않음
