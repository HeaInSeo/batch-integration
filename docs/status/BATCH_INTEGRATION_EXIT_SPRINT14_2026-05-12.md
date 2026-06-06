# Batch Integration Exit Sprint 14 2026-05-12

기준일:
- `2026-05-12`

목표:
- deprecated `vm-lab` shim과 legacy manifest/fixture를 실제로 제거한다.
- `batch-integration`에 active compatibility shim만 남긴다.

## 삭제된 자산

삭제된 legacy shim:
- `scripts/apply-vm-lab-manifests.sh`
- `scripts/build-vm-lab-images-ko.sh`
- `scripts/build-vm-lab-images.sh`
- `scripts/generate-kubeslint-vm-lab-summary.sh`
- `scripts/run-kubeslint-vm-lab-gate.sh`
- `scripts/run-vm-lab-live-smoke-eval.sh`
- `scripts/run-vm-lab-smoke-eval.sh`
- `scripts/vm-lab-jumi-smoke-remote.sh`

삭제된 legacy deploy 자산:
- `deploy/vm-lab/README.md`
- `deploy/vm-lab/artifact-handoff.yaml`
- `deploy/vm-lab/fixtures/jumi-handoff-smoke.json`
- `deploy/vm-lab/fixtures/kube-slint-jumi-ah-smoke-metrics.json`
- `deploy/vm-lab/fixtures/kube-slint-jumi-ah-smoke-metrics.live.json`
- `deploy/vm-lab/jumi.yaml`
- `deploy/vm-lab/kustomization.yaml`
- `deploy/vm-lab/namespace.yaml`

남은 active compatibility shim:
- [scripts/apply-jumi-ah-dev.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/apply-jumi-ah-dev.sh:1)
- [scripts/run-jumi-ah-dev-live-smoke-eval.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/run-jumi-ah-dev-live-smoke-eval.sh:1)
- [scripts/publish-shift-left-observability.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/publish-shift-left-observability.sh:1)
- [scripts/install-shift-left-observability-tailnet-proxy.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/install-shift-left-observability-tailnet-proxy.sh:1)

기타 유지 자산:
- `scripts/kind-cluster-init.sh`
- `scripts/podman-cgroupfs.containers.conf`

## 로컬 검증

`Code Ready`:
- `bash -n scripts/apply-jumi-ah-dev.sh`: `PASS`
- `bash -n scripts/run-jumi-ah-dev-live-smoke-eval.sh`: `PASS`
- `bash -n scripts/publish-shift-left-observability.sh`: `PASS`

## 원격 검증

원격 baseline:
- `infra-lab`: `?? profiles/remote-seoy/`
- `JUMI`: `?? executor/`, `?? handoff/`, `?? tools/`
- `artifact-handoff`: `?? ahv1/`, `?? domain/`, `?? resolver/`

실행 1:
- local current script 기준 `bash scripts/apply-jumi-ah-dev.sh`

결과 1:
- `namespace/jumi-ah-dev unchanged`
- `deployment.apps/artifact-handoff unchanged`
- `deployment.apps/jumi unchanged`
- apply shim은 정상 동작

실행 2:
- local current script 기준 `env PUBLISH_SHIFT_LEFT_OBSERVABILITY=false bash scripts/run-jumi-ah-dev-live-smoke-eval.sh`

결과 2:
- 새 run 제출 확인:
  - `runId=jumi-ah-dev-live-smoke-20260512T123547Z`
- 하지만 producer pod는 `ErrImagePull`로 실패
- 원인:
  - pod `serviceAccountName=default`
  - Harbor auth secret 미적용
  - `no basic auth credentials`

판단:
- 이 실패는 cleanup 회귀가 아니라 기존 `JUMI -> spawner -> worker Job serviceAccountName` 전파 버그 재노출이다.
- fixture image와 현재 deployment image는 동일했다.
- 즉 image drift가 아니라 runtime contract 이슈다.

## 결론

- `Code Ready`: 완료
- `Remote Validated`: 부분 완료

정리 작업 자체는 끝났다.

현재 남은 blocker:
- `batch-integration` cleanup이 아니라
- `JUMI` 런타임의 worker job `serviceAccountName` 전파 버그

즉 저장소 exit 관점에서는 거의 종료 상태고,
완전한 원격 green 상태까지 요구하면 다음 owner repo 작업은 `JUMI` 런타임 버그 수정이다.

## 리뷰 포인트

최종 리뷰 시 확인할 목록:
- 삭제된 legacy shim 목록이 의도와 맞는지
- active compatibility shim 4개만 남기는 기준이 맞는지
- `kind-cluster-init.sh`, `podman-cgroupfs.containers.conf`를 별도 보관할지
- `batch-integration` 저장소 제거 전, live smoke green을 꼭 요구할지
- 요구한다면 다음 owner 작업을 `JUMI` runtime bug fix로 열지
