# Batch Integration Exit Sprint 12 2026-05-12

기준일:
- `2026-05-12`

목표:
- `generate-kubeslint-vm-lab-summary.sh`, `run-kubeslint-vm-lab-gate.sh`를 deprecated thin wrapper로 고정한다.
- 정적 smoke summary/gate 경로도 owner 자산 중심으로만 동작하는 마지막 호환면으로 축소한다.

## 변경 사항

deprecated 고정:
- [scripts/generate-kubeslint-vm-lab-summary.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/generate-kubeslint-vm-lab-summary.sh:1)
  - deprecated 경고 추가
  - owner script인 `JUMI/scripts/generate-kubeslint-jumi-ah-summary.sh`로만 delegate
- [scripts/run-kubeslint-vm-lab-gate.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/run-kubeslint-vm-lab-gate.sh:1)
  - deprecated 경고 추가
  - policy owner를 `JUMI/policy/devspace/...` 기준으로만 유지

의미:
- `batch-integration`은 더 이상 summary/gate 본체 owner가 아니다.
- 남은 역할은 정적 smoke/gate 호환 진입점 제공뿐이다.

## 로컬 검증

`Code Ready`:
- `bash -n scripts/generate-kubeslint-vm-lab-summary.sh`: `PASS`
- `bash -n scripts/run-kubeslint-vm-lab-gate.sh`: `PASS`
- `bash -n scripts/run-vm-lab-smoke-eval.sh`: `PASS`

## 원격 검증

실행:
- `bash -lc "cd /opt/go/src/github.com/HeaInSeo/batch-integration && bash scripts/run-vm-lab-smoke-eval.sh"`

설명:
- 비대화형 SSH 기본 PATH에는 `go`가 없어서 첫 시도는 실패했다.
- login shell로 재실행해 실제 wrapper 경로만 검증했다.

결과:
- summary 생성 성공
- gate 생성 성공
- `results=11`
- `gate_result=PASS`
- `overall_message=Policy checks passed.`

## 결론

- `Code Ready`: 완료
- `Remote Validated`: 완료

이번 조각으로 `batch-integration`의 정적 smoke summary/gate 경로는 본체가 아니라 deprecated compatibility shim이 됐다.

남은 일:
- `deploy/vm-lab/fixtures/*`의 archive/delete 후보 확정
- 남은 legacy status 문서의 보관 범위 결정
- `batch-integration` 삭제 직전 유지할 shim 최종 목록 고정
