# Shared Scripts

이 디렉토리의 스크립트는 특정 소비자 fixture 저장소에 종속되지 않는 공용 운영 스크립트다.

현재 공용 스크립트:

- [`scripts/kind-cluster-init.sh`](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/kind-cluster-init.sh:1)
  - 목적: `kind-batch-int-dev` fast-loop 클러스터 재생성
  - 배치 이유: `hello-operator` 삭제 후에도 kind+tilt 검증 경로를 유지하기 위해
  - 운영 참고:
    - rootful `podman info --format json`가 멈추면 kind도 함께 정지할 수 있음
    - 2026-04-21 장애/복구 기록:
      [`docs/status/KIND_PODMAN_RPM_RECOVERY_2026-04-21.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/KIND_PODMAN_RPM_RECOVERY_2026-04-21.md:1)

운영 원칙:

- consumer fixture repo에만 존재하면 안 되는 스크립트는 `batch-integration/scripts/`로 이동한다.
- consumer repo 스크립트는 fixture-local behavior만 가져야 한다.
