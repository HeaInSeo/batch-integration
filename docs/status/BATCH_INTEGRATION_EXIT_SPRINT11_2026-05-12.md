# Batch Integration Exit Sprint 11 2026-05-12

기준일:
- `2026-05-12`

목표:
- `vm-lab` legacy apply/build/smoke 경로를 deprecated wrapper 수준으로 더 낮춘다.
- active owner 경로가 `JUMI`, `infra-lab`, `artifact-handoff`, `SF Observability`로 이미 넘어갔다는 사실을 문서와 스크립트에 고정한다.

## 변경 사항

deprecated wrapper 정리:
- [scripts/apply-vm-lab-manifests.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/apply-vm-lab-manifests.sh:1)
  - deprecated 경고 후 active apply 경로인 `scripts/apply-jumi-ah-dev.sh`로 delegate
- [scripts/run-vm-lab-smoke-eval.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/run-vm-lab-smoke-eval.sh:1)
  - deprecated 경고를 명시
- [scripts/build-vm-lab-images.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/build-vm-lab-images.sh:1)
  - owner repo build flow 사용 권고 경고 추가
- [scripts/build-vm-lab-images-ko.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/build-vm-lab-images-ko.sh:1)
  - owner repo build flow 사용 권고 경고 추가

legacy 문맥 축소:
- [deploy/vm-lab/README.md](/opt/go/src/github.com/HeaInSeo/batch-integration/deploy/vm-lab/README.md:1)
  - active 운영 경로가 아님을 명시
  - 남아 있는 이유를 history/compatibility로 제한

## 로컬 검증

`Code Ready`:
- `bash -n scripts/apply-vm-lab-manifests.sh`: `PASS`
- `bash -n scripts/run-vm-lab-smoke-eval.sh`: `PASS`
- `bash -n scripts/build-vm-lab-images.sh`: `PASS`
- `bash -n scripts/build-vm-lab-images-ko.sh`: `PASS`

## 원격 검증

원격 baseline:
- `infra-lab`: `?? profiles/remote-seoy/`
- `JUMI`: `?? executor/`, `?? handoff/`, `?? tools/`
- `artifact-handoff`: `?? ahv1/`, `?? domain/`, `?? resolver/`

실행:
- `bash scripts/apply-vm-lab-manifests.sh`

결과:
- deprecated wrapper 경고 없이도 실제 apply 대상은 active path인 `scripts/apply-jumi-ah-dev.sh`
- `service/jumi unchanged`
- `deployment.apps/artifact-handoff configured`
- `deployment.apps/jumi configured`
- 즉 legacy apply 진입점은 더 이상 독립 manifest owner가 아니다

## 결론

- `Code Ready`: 완료
- `Remote Validated`: 완료

이번 조각으로 `batch-integration`의 `vm-lab` apply 경로는 사실상 alias 수준으로 낮아졌다.

남은 일:
- `generate-kubeslint-vm-lab-summary.sh`, `run-kubeslint-vm-lab-gate.sh` 같은 thin wrapper의 최종 존치 여부 결정
- `deploy/vm-lab/fixtures/*`와 남은 legacy 문서의 archive/delete 후보 확정
- `batch-integration` 삭제 직전 유지할 shim 최종 목록 고정
