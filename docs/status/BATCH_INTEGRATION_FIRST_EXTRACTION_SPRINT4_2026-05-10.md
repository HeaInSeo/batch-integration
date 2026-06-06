# Batch Integration First Extraction Sprint 4 2026-05-10

기준일:
- `2026-05-10`

목적:
- `batch-integration` 안 자산을 실제 owner repo로 옮기는 첫 extraction을 수행한다.
- 이번 스프린트에서는 `JUMI`가 owner여야 하는 smoke fixture/remote helper와
  `artifact-handoff`가 owner여야 하는 deployment patch를 먼저 옮긴다.
- 기존 `batch-integration` 루프는 깨지지 않도록 compatibility shim을 남긴다.

## 이번 스프린트에서 옮긴 자산

### JUMI repo

추가:
- [vm-lab-jumi-smoke-remote.sh](/opt/go/src/github.com/HeaInSeo/JUMI/scripts/vm-lab-jumi-smoke-remote.sh:1)
- [jumi-handoff-smoke.json](/opt/go/src/github.com/HeaInSeo/JUMI/deploy/devspace/fixtures/jumi-handoff-smoke.json:1)
- [patch-jumi-deployment.yaml](/opt/go/src/github.com/HeaInSeo/JUMI/deploy/devspace/patch-jumi-deployment.yaml:1)

의미:
- JUMI smoke helper와 fixture의 canonical owner를 `JUMI` repo로 이동
- runtime-helper smoke input도 JUMI repo가 관리

### artifact-handoff repo

추가:
- [patch-artifact-handoff-deployment.yaml](/opt/go/src/github.com/HeaInSeo/artifact-handoff/deploy/devspace/patch-artifact-handoff-deployment.yaml:1)

의미:
- AH deployment patch의 canonical owner를 `artifact-handoff` repo로 이동

## batch-integration 에서 남긴 호환층

변경:
- [vm-lab-jumi-smoke-remote.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/vm-lab-jumi-smoke-remote.sh:1)
  - 이제 직접 구현이 아니라 `JUMI/scripts/vm-lab-jumi-smoke-remote.sh` delegating shim
- [run-jumi-ah-dev-live-smoke-eval.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/run-jumi-ah-dev-live-smoke-eval.sh:1)
  - 기본 fixture 경로를 `JUMI/deploy/devspace/fixtures/jumi-handoff-smoke.json`으로 변경
  - 기본 helper 경로를 `JUMI/scripts/vm-lab-jumi-smoke-remote.sh`로 변경
  - `tools/jumi-smoke`도 원격에 stage해서 local `Code Ready` 상태를 기준으로 빌드하게 변경

추가 보정:
- `tools/jumi-smoke` 모듈의 Kubernetes indirect dependency 해시를 갱신
  - [go.mod](/opt/go/src/github.com/HeaInSeo/batch-integration/tools/jumi-smoke/go.mod:1)
  - [go.sum](/opt/go/src/github.com/HeaInSeo/batch-integration/tools/jumi-smoke/go.sum:1)

## 검증

### Code Ready

완료:
- `bash -n`:
  - `JUMI/scripts/vm-lab-jumi-smoke-remote.sh`
  - `batch-integration/scripts/vm-lab-jumi-smoke-remote.sh`
  - `batch-integration/scripts/run-jumi-ah-dev-live-smoke-eval.sh`
- `go build .`:
  - `batch-integration/tools/jumi-smoke`

### Remote Validation

1차 실행:
- `100.123.80.48` 대상으로
  `env PUBLISH_SHIFT_LEFT_OBSERVABILITY=false bash scripts/run-jumi-ah-dev-live-smoke-eval.sh`
- 결과:
  - 새 owner repo 경로의 fixture/helper가 실제로 사용됨
  - remote `jumi-smoke` build도 local stage 경로로 진행됨
  - run submission까지는 성공
    - `runId=jumi-ah-dev-live-smoke-20260510T110817Z`
    - `status=Accepted`
  - 하지만 producer pod가 `ImagePullBackOff`

1차 직접 원인:
- 당시 deployed JUMI image는 `manifest-20260503-verify3`
- spawned worker pod가 `serviceAccountName: default`로 올라감
- pod event:
  `failed to pull and unpack image ... no basic auth credentials`

대응:
- 로컬 source를 원격 `/tmp` staging으로 복사
- 원격 `100.123.80.48`에서 새 JUMI image build/push
  - `harbor.10.113.24.96.nip.io/batch-int/jumi:extract-20260510-1140`
- `jumi-ah-dev` overlay와 JUMI smoke fixture를 새 태그로 갱신
- overlay 재배포 후 live smoke 재실행

2차 실행 결과:
- `runId=jumi-ah-dev-live-smoke-20260510T114353Z`
- terminal status: `Succeeded`
- summary results: `16`
- gate result: `PASS`

즉 이번 스프린트의 first extraction 자체는 remote end-to-end 기준으로도 통과했다.

## 남은 리스크

worker pod inspection 결과:
- `jumi-ah-dev-live-smoke-20260510t114353z-produce-xl8rq   default   Succeeded`
- `jumi-ah-dev-live-smoke-20260510t114353z-consume-lfhvc   default   Succeeded`

의미:
- smoke는 새 image와 node cache 상태에서 PASS했다.
- 하지만 worker job의 `serviceAccountName`은 여전히 `default`다.
- 따라서 `serviceAccountName` runtime contract는 아직 완전히 닫히지 않았다.
- 이번 PASS는 image cache 또는 노드 상태 때문에 Harbor pull auth 리스크가 다시 드러나지 않은 것일 수 있다.

냉정한 판단:
- first extraction 스프린트 자체는 `Remote Validated`로 올릴 수 있다.
- 다만 `JUMI -> spawner -> worker Job serviceAccountName` 전파는
  별도 runtime contract bug로 계속 추적해야 한다.

## 상태

- `Code Ready`: 완료
- `Remote Validated`: 완료

설명:
- owner repo 경로로의 first extraction과 orchestration 경로는 확인됨
- 다만 `JUMI -> spawner -> Job serviceAccountName` 전파 버그는 별도 후속 항목으로 남음

## 다음 스프린트 초점

1. `serviceAccountName`이 spawned worker job에 실제로 내려가도록
   JUMI runtime contract를 분리 진단
2. node cache에 가려지지 않는 조건에서 같은 smoke를 다시 확인
3. 이후 `artifact-handoff` deployment 자산의 실제 repo-owned apply 경로도 분리
