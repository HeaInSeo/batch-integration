# JUMI ServiceAccount Propagation Sprint — 2026-05-12

## Scope

- `spawner` canonical source를 `github.com/HeaInSeo/spawner` 기준으로 전환
- `JUMI -> spawner -> worker Job` 경로에서 `serviceAccountName` 전파 버그 수정
- `100.123.80.48` 원격 환경에서 live smoke로 실제 동작 확인

## Code Ready

- `spawner` module path를 `github.com/HeaInSeo/spawner`로 변경
- `spawner` 내부 import를 `github.com/HeaInSeo/spawner/...`로 정리
- `JUMI`가 `github.com/HeaInSeo/spawner`를 보도록 import / go.mod 정리
- `JUMI/tools/jumi-smoke`도 동일 경로를 보도록 조정
- `JUMI/pkg/backend/spawner_k8s.go`의 direct K8s fallback 경로는 그대로 유지

## Local Validation

- `go test ./...` in `spawner` PASS
- `go test ./pkg/backend` in `JUMI` PASS
- `go test .` in `JUMI/tools/jumi-smoke` PASS
- `rg github.com/seoyhaein/spawner` on `JUMI` / `spawner` source code returned no source hits

## Remote Validation

### Image build / push

- remote staging path: `/tmp/jumi-spawner-build`
- image tag: `harbor.10.113.24.96.nip.io/batch-int/jumi:serviceaccountfix-20260512-124505`
- build context는 `JUMI + spawner`를 함께 담은 temporary workspace를 사용

### Apply

- `bash scripts/apply-jumi-ah-dev.sh` PASS
- `deployment.apps/jumi configured`

### Live smoke

- first successful runtime run:
  - `runId=jumi-ah-dev-live-smoke-20260512T130942Z`
  - terminal `Succeeded`
- second full summary/gate run:
  - `runId=jumi-ah-dev-live-smoke-20260512T131051Z`
  - terminal `Succeeded`
  - summary `results=16`
  - gate `FAIL`

### ServiceAccount verification

- producer pod:
  - `jumi-ah-dev-live-smoke-20260512t130942z-produce-2jgkl`
  - `spec.serviceAccountName=jumi`
- consumer pod:
  - `jumi-ah-dev-live-smoke-20260512t130942z-consume-ql756`
  - `spec.serviceAccountName=default`

Interpretation:

- explicit `serviceAccountName`이 지정된 node에는 정상 전파됨
- smoke fixture에서 `consume`은 별도 `serviceAccountName`을 주지 않으므로 `default`가 정상
- 기존 blocker였던 producer `ImagePullBackOff`는 해소됨

## Residual Issue

이번 스프린트의 남은 fail은 `serviceAccountName` 전파가 아니라 `JUMI` metric collection / gate 쪽이다.

- gate fail results:
  - `jumi_jobs_created_smoke`
  - `jumi_artifacts_registered_smoke`
  - `jumi_input_resolve_requests_smoke`
  - `jumi_input_remote_fetch_smoke`
  - `jumi_input_materializations_smoke`
  - `jumi_sample_runs_finalized_smoke`
  - `jumi_gc_evaluate_requests_smoke`
  - `ah_retained_artifact_bytes_smoke`
  - `ah_artifact_metadata_complete_smoke`

Current reading:

- run execution 자체는 성공
- producer artifact manifest도 pod termination message에 기록됨
- 그러나 summary input에서 `JUMI` counter delta가 `0`으로 잡혀 gate가 깨짐
- 다음 JUMI 작업은 이 metrics/gate drift를 owner issue로 보고 분리해서 다루는 것이 맞음

## Status

- `Code Ready`: complete
- `Remote Validated`: complete for serviceAccount propagation
- next owner track: `JUMI metrics / gate drift`
