# Batch Integration Exit Sprint 13 2026-05-12

기준일:
- `2026-05-12`

목표:
- `batch-integration` 삭제 직전까지 남길 shim 목록을 고정한다.
- `deploy/vm-lab/fixtures/*`와 legacy manifest/script를 archive/delete 후보로 분류한다.

## 최종 shim 후보

삭제 직전까지 남길 수 있는 shim:
- [scripts/apply-jumi-ah-dev.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/apply-jumi-ah-dev.sh:1)
- [scripts/run-jumi-ah-dev-live-smoke-eval.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/run-jumi-ah-dev-live-smoke-eval.sh:1)
- [scripts/publish-shift-left-observability.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/publish-shift-left-observability.sh:1)
- [scripts/install-shift-left-observability-tailnet-proxy.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/install-shift-left-observability-tailnet-proxy.sh:1)

설명:
- 위 네 개는 현재 owner repo 경로로 delegate하는 active compatibility shim이다.
- 최종 cutover 전까지는 사용자 습관과 원격 운영 경로를 끊지 않기 위해 유지 가능하다.

deprecated legacy shim:
- [scripts/apply-vm-lab-manifests.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/apply-vm-lab-manifests.sh:1)
- [scripts/run-vm-lab-live-smoke-eval.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/run-vm-lab-live-smoke-eval.sh:1)
- [scripts/run-vm-lab-smoke-eval.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/run-vm-lab-smoke-eval.sh:1)
- [scripts/generate-kubeslint-vm-lab-summary.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/generate-kubeslint-vm-lab-summary.sh:1)
- [scripts/run-kubeslint-vm-lab-gate.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/run-kubeslint-vm-lab-gate.sh:1)
- [scripts/build-vm-lab-images.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/build-vm-lab-images.sh:1)
- [scripts/build-vm-lab-images-ko.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/build-vm-lab-images-ko.sh:1)

판단:
- 더 이상 owner 경로가 아니다.
- 다음 cleanup window에서는 우선 삭제 후보로 본다.

## Legacy Fixture / Manifest 분류

archive/delete 후보:
- [deploy/vm-lab/fixtures/jumi-handoff-smoke.json](/opt/go/src/github.com/HeaInSeo/batch-integration/deploy/vm-lab/fixtures/jumi-handoff-smoke.json:1)
- [deploy/vm-lab/fixtures/kube-slint-jumi-ah-smoke-metrics.json](/opt/go/src/github.com/HeaInSeo/batch-integration/deploy/vm-lab/fixtures/kube-slint-jumi-ah-smoke-metrics.json:1)
- [deploy/vm-lab/fixtures/kube-slint-jumi-ah-smoke-metrics.live.json](/opt/go/src/github.com/HeaInSeo/batch-integration/deploy/vm-lab/fixtures/kube-slint-jumi-ah-smoke-metrics.live.json:1)
- [deploy/vm-lab/artifact-handoff.yaml](/opt/go/src/github.com/HeaInSeo/batch-integration/deploy/vm-lab/artifact-handoff.yaml:1)
- [deploy/vm-lab/jumi.yaml](/opt/go/src/github.com/HeaInSeo/batch-integration/deploy/vm-lab/jumi.yaml:1)
- [deploy/vm-lab/kustomization.yaml](/opt/go/src/github.com/HeaInSeo/batch-integration/deploy/vm-lab/kustomization.yaml:1)
- [deploy/vm-lab/namespace.yaml](/opt/go/src/github.com/HeaInSeo/batch-integration/deploy/vm-lab/namespace.yaml:1)

설명:
- owner 자산은 이미 `JUMI`, `artifact-handoff`, `infra-lab`로 넘어갔다.
- 이 경로는 runtime source-of-truth가 아니라 historical compatibility copy다.
- 실제 삭제는 관련 status 문서 링크 정리와 동시에 수행하는 편이 안전하다.

history-only 문맥:
- [deploy/vm-lab/README.md](/opt/go/src/github.com/HeaInSeo/batch-integration/deploy/vm-lab/README.md:1)
- 2026-04-22 ~ 2026-04-30 계열 `docs/status/VM_LAB_*`, `KUBESLINT_VM_LAB_*` 문서

## README 정렬

README 기준:
- active 진입점은 `run-jumi-ah-dev-live-smoke-eval.sh`만 남긴다.
- `generate-kubeslint-vm-lab-summary.sh`, `run-kubeslint-vm-lab-gate.sh`는 deprecated로 표기한다.
- `run-vm-lab-live-smoke-eval.sh`는 legacy wrapper로만 표기한다.

## 결론

- `Code Ready`: 완료
- `Remote Validated`: 해당 없음

이번 조각은 실제 runtime 변경이 아니라 final cleanup 기준 고정이다.

남은 일:
- 마지막 cleanup window에서 deprecated shim과 `deploy/vm-lab/*` 삭제 여부 실행
- 삭제 직전 README와 sprint plan에서 최종 유지 경로만 남기기
