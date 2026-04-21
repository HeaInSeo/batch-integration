# Risks

## R1. AH contract 변경으로 JUMI 재작업 발생

완화:
- proto와 in-memory semantics를 먼저 고정
- 첫 통합 이전에 RPC 이름과 핵심 필드를 흔들지 않음

## R2. JUMI spec 확장이 fixture를 깨뜨림

완화:
- optional field 방식 유지
- `Inputs/Outputs` fallback 유지

## R3. kube-slint 범위 과대

완화:
- 초기에는 metrics family 등록과 핵심 derived indicator만 수행
- summary schema 대개편은 첫 통합 이후로 미룸

## R4. 문서와 실제 코드 상태 불일치

완화:
- 매 주 상태 갱신 시 실제 코드 기준으로 다시 점검
- 허브 문서를 코드보다 우선 기준으로 취급하지 않음

## R5. Host RPM DB 이상으로 kind/podman fast-loop 중단

완화:
- kind 이상 징후 시 먼저 `sudo podman info --format json`를 단독 점검
- 필요 시 `sudo rpm -q -f /usr/bin/runc`로 RPM DB health 확인
- Berkeley DB 기반 `/var/lib/rpm/__db.*` stale 이슈는 백업 후 제거 절차로 복구
- 상세 복구 기록:
  [`KIND_PODMAN_RPM_RECOVERY_2026-04-21.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/KIND_PODMAN_RPM_RECOVERY_2026-04-21.md:1)

## R6. Host cgroup delegation에서 `cpu` 누락으로 kind bootstrap 실패

완화:
- `sudo podman info --format json` 정상 여부와 별개로 kubelet bootstrap 로그 확인
- `batch-int-dev-control-plane` 내부 `journalctl -u kubelet`에서 `cpu.weight` 오류 점검
- host의 `user.slice` / `user-<uid>.slice` `cgroup.subtree_control`에서 `cpu` 위임 여부 확인
- 진행 중 incident 기록:
  [`KIND_CGROUP_CPU_DELEGATION_2026-04-21.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/KIND_CGROUP_CPU_DELEGATION_2026-04-21.md:1)
