# Batch Integration App Extraction Sprint 5 2026-05-12

기준일:
- `2026-05-12`

목적:
- `batch-integration`에 남아 있는 앱 전용 자산을 더 owner repo 기준으로 밀어낸다.
- 단, `artifact-handoff`는 현재 코딩 작업 중이므로 추가 수정은 최소화하고
  이번 스프린트는 `JUMI` 중심 extraction으로 재조정한다.

## 조정 기준

사용자 기준:
- `artifact-handoff`는 현재 active coding 중이다.
- 따라서 이번 스프린트에서 AH repo는 더 이상 넓게 건드리지 않는다.

운영 원칙:
- `artifact-handoff`는 이번 스프린트에서 deploy asset 소비자로만 취급
- 새 로직/구조 변경은 하지 않음
- 원격 검증은 `/tmp` staging을 사용하고 remote repo working tree는 건드리지 않음

## 이번 스프린트 변경

### 1. JUMI owner deploy asset 추가

추가:
- [JUMI/deploy/devspace/jumi-ah-dev/jumi.yaml](/opt/go/src/github.com/HeaInSeo/JUMI/deploy/devspace/jumi-ah-dev/jumi.yaml:1)

의미:
- `jumi-ah-dev` namespace에서 쓰는 JUMI deployment base를
  `batch-integration`이 아니라 `JUMI` repo가 소유하게 함

### 2. artifact-handoff deploy asset 최소 추가

추가:
- [artifact-handoff/deploy/devspace/jumi-ah-dev/artifact-handoff.yaml](/opt/go/src/github.com/HeaInSeo/artifact-handoff/deploy/devspace/jumi-ah-dev/artifact-handoff.yaml:1)

의미:
- AH repo는 이 스프린트에서 이 manifest 추가만 반영
- 이후 AH active coding 기간에는 추가 확장을 멈춤

### 3. batch-integration apply 경로 변경

변경:
- [apply-jumi-ah-dev.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/apply-jumi-ah-dev.sh:1)

변경 내용:
- 더 이상 `batch-integration/deploy/jumi-ah-dev` 내부의
  `jumi.yaml`, `artifact-handoff.yaml`, patch 파일을 canonical source로 쓰지 않음
- 대신 아래 owner repo 파일을 `/tmp` staging으로 모아 원격 apply
  - `JUMI/deploy/devspace/jumi-ah-dev/jumi.yaml`
  - `JUMI/deploy/devspace/patch-jumi-deployment.yaml`
  - `artifact-handoff/deploy/devspace/jumi-ah-dev/artifact-handoff.yaml`
  - `artifact-handoff/deploy/devspace/patch-artifact-handoff-deployment.yaml`

### 4. batch-integration 중복 deploy 자산 제거

삭제:
- `deploy/jumi-ah-dev/jumi.yaml`
- `deploy/jumi-ah-dev/artifact-handoff.yaml`
- `deploy/jumi-ah-dev/patch-jumi-deployment.yaml`
- `deploy/jumi-ah-dev/patch-artifact-handoff-deployment.yaml`

의미:
- `batch-integration`이 JUMI/AH deployment base를 중복 보관하지 않게 함

### 5. gate script fallback 보강

변경:
- [run-kubeslint-vm-lab-gate.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/run-kubeslint-vm-lab-gate.sh:1)

내용:
- PATH에 `slint-gate`가 없으면
  sibling repo의 `../kube-slint/slint-gate` 바이너리를 fallback으로 사용

이유:
- 실제 remote smoke는 성공했지만 로컬 후처리 gate 단계가
  PATH 가정 때문에 중단되었기 때문

## 검증

### Code Ready

완료:
- `bash -n`:
  - `batch-integration/scripts/apply-jumi-ah-dev.sh`
  - `batch-integration/scripts/run-jumi-ah-dev-live-smoke-eval.sh`
  - `batch-integration/scripts/run-kubeslint-vm-lab-gate.sh`

### Remote Baseline

확인:
- `infra-lab`: untracked `profiles/remote-seoy/`
- `JUMI`: untracked `executor/`, `handoff/`
- `artifact-handoff`: untracked `ahv1/`, `domain/`, `resolver/`
- `bori`: clean
- `kube-slint`: clean

판단:
- 이번 스프린트 경로와 직접 충돌하는 수준은 아님

### Remote Validated

실행:
- `./scripts/apply-jumi-ah-dev.sh`
- `env PUBLISH_SHIFT_LEFT_OBSERVABILITY=false bash scripts/run-jumi-ah-dev-live-smoke-eval.sh`

결과:
- apply 성공
- live smoke run:
  - `runId=jumi-ah-dev-live-smoke-20260512T081025Z`
  - terminal `Succeeded`
  - producer/consumer 모두 `Succeeded`
- summary 생성 성공
  - `results=16`
- gate 후처리 성공
  - `gate_result=PASS`
  - `overall_message=Policy checks passed.`

주의:
- live smoke 본체는 원격에서 성공
- local gate 후처리만 PATH 가정 때문에 한 번 실패했고,
  fallback 보강 후 같은 summary로 gate를 다시 생성해 PASS를 확인

## 현재 판단

- 이번 스프린트로 `batch-integration` 안의 JUMI/AH deployment base 중복은 더 줄었다.
- apply 경로는 owner repo 기준으로 바뀌었고, remote validation도 통과했다.
- 다만 `artifact-handoff`는 active coding 중이므로,
  이후 스프린트에서는 AH 쪽 추가 변경을 최대한 피하고
  `JUMI`와 `SF Observability` 측 extraction을 우선하는 것이 맞다.

## 상태

- `Code Ready`: 완료
- `Remote Validated`: 완료

## 다음 스프린트 초점

1. `batch-integration`에 남은 app-specific summary/helper/shim 추가 축소
2. `SF Observability` publish 자산 owner 분리 시작
3. `artifact-handoff`는 active coding 종료 전까지 추가 변경 최소화

