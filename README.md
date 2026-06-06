# Batch Integration Hub

이 디렉토리는 `JUMI`, `artifact-handoff`, `kube-slint`, `bori`,
`SF Observability` 전이 작업을 함께 진행하기 위한 상위 통합 staging 저장소다.

목적:
- 저장소 간 의존성과 전이 순서를 한 곳에서 관리
- 통합 설계와 수정된 일정의 기준 문서 제공
- 각 자산을 장기 목적지로 이관하기 전 임시 작업장을 제공

원칙:
- 각 저장소 내부 설계의 canonical 문서는 각 저장소에 유지한다.
- 이 디렉토리는 cross-repo 일정, 계약, 운영 규칙과 전이 계획만 다룬다.
- 원본 계획 문서는 `plans/original/`에 보존하고, 수정안은 `plans/revised/`에 둔다.
- `AH`, `JUMI`, `kube-slint` 원본 설계 문서의 상위 일정은 가장 중요한 기준으로 유지한다.
- 장기적으로 `batch-integration` 자산은 앱 repo, `bori`, `kube-slint`,
  `SF Observability` 운영 경로로 이관되고, 이 저장소는 축소 또는 제거된다.

구성:
- `plans/original/`: 2026-04-21 기준 원본 계획 문서 보관본
- `plans/revised/`: 현실 조정안 기준 수정 계획 문서
- `docs/master-plan/`: 통합 일정, 아키텍처, 게이트 문서
- `docs/decisions/`: cross-repo 의사결정 기록
- `docs/contracts/`: 저장소 간 계약 문서
- `docs/status/`: 위험과 주간 상태 추적
- `scripts/`: 특정 소비자 repo에 종속되지 않는 공용 운영 스크립트
- `codex/`: Codex 운영 문서와 검토 체크리스트

현재 기준:
- 기준일: `2026-05-10`
- 실제 운영/테스트 장비: `100.123.80.48`
- 현재 원격 검증 기준 경로:
  `DevSpace -> bori -> kube-slint -> SF Observability`
- 첫 통합 목표: `2026-05-16` 전후
- 베타 목표: `2026-06-13` ~ `2026-06-20`
- 문서 목표 완료: `2026-07-31` 전후

운영 원칙:
- `kube-slint`는 후행 검증 도구가 아니라 초기 병행 개발 축으로 취급한다.
- 단, 초기에는 `개발 동반용 최소 guardrail` 범위로 제한한다.
- host 환경 이슈는 주 개발 스프린트와 분리한다.
- 실제 runtime truth는 항상 `100.123.80.48` 원격 장비 기준으로 판정한다.
- 로컬 작업 결과는 `Code Ready`, 원격 GitHub 기준 검증은 `Remote Validated`로 분리한다.

현재 스프린트 우선순위:
- 주 개발 트랙:
  - `artifact-handoff`, `JUMI`, `kube-slint` 구현 지속
- 원격 개발 루프 트랙:
  - `DevSpace + bori + kube-slint` 경로 유지 및 강화
- 관찰면/전이 트랙:
  - `SF Observability` 자산 정리
  - `batch-integration` 자산 이관 계획 구체화

주요 참고 문서:
- 스프린트 전략:
  [`docs/master-plan/SPRINT_STRATEGY_v1.0.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/master-plan/SPRINT_STRATEGY_v1.0.md:1)
- 검증 전략:
  [`docs/master-plan/VALIDATION_STRATEGY.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/master-plan/VALIDATION_STRATEGY.md:1)

현재 빠른 VM lab 검증 진입점:
- `jumi-ah-dev` live smoke + summary + gate:
  [`scripts/run-jumi-ah-dev-live-smoke-eval.sh`](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/run-jumi-ah-dev-live-smoke-eval.sh:1)
- `jumi-ah-dev` live smoke + publish:
  `PUBLISH_SHIFT_LEFT_OBSERVABILITY=true bash scripts/run-jumi-ah-dev-live-smoke-eval.sh`
- active apply shim:
  [`scripts/apply-jumi-ah-dev.sh`](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/apply-jumi-ah-dev.sh:1)
- active publish shim:
  [`scripts/publish-shift-left-observability.sh`](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/publish-shift-left-observability.sh:1)

현재 공식 사용자 접근 경로:
- tailnet 표준 진입점:
  `http://100.123.80.48:8008/`
- health check:
  `http://100.123.80.48:8008/healthz`
- lab 내부 원본 호스트:
  `http://shift-left-observability.10.113.24.96.nip.io`

이름 주의:
- 공식 자산명은 `shift-left-observability`다.
- 페이지 표시 이름은 `SF Observability`다.
- 이 이름은 `https://github.com/devspace-sh/devspace` CLI/도구와 구분된다.
- 실제 개발 루프는 `DevSpace`와 `bori`를 통해 원격 `infra-lab` 장비에서 수행한다.
- 예: [JUMI/devspace.yaml](/opt/go/src/github.com/HeaInSeo/JUMI/devspace.yaml:1)
- 예: [artifact-handoff/devspace.yaml](/opt/go/src/github.com/HeaInSeo/artifact-handoff/devspace.yaml:1)

관련 문서:
- publish 상태:
  [`docs/status/DEV_SPACE_OBSERVABILITY_PUBLISH_2026-04-30.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/DEV_SPACE_OBSERVABILITY_PUBLISH_2026-04-30.md:1)
- tailnet reverse proxy:
  [`docs/status/DEV_SPACE_TAILNET_PROXY_2026-05-01.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/DEV_SPACE_TAILNET_PROXY_2026-05-01.md:1)
- `jumi-ah-dev` live loop:
  [`docs/status/JUMI_AH_DEV_LIVE_LOOP_2026-05-02.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/JUMI_AH_DEV_LIVE_LOOP_2026-05-02.md:1)
- runtime helper workload image 전략:
  [`docs/status/RUNTIME_HELPER_WORKLOAD_IMAGE_STRATEGY_2026-05-03.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/RUNTIME_HELPER_WORKLOAD_IMAGE_STRATEGY_2026-05-03.md:1)
- DevSpace 플랫폼 재정렬:
  [`docs/status/DEVSPACE_PLATFORM_REALIGNMENT_2026-05-10.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/DEVSPACE_PLATFORM_REALIGNMENT_2026-05-10.md:1)
- bori/DevSpace 전이 보고:
  [`docs/status/BORI_DEVSPACE_TRANSITION_REPORT_2026-05-10.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BORI_DEVSPACE_TRANSITION_REPORT_2026-05-10.md:1)
- DevSpace/bori 원격 검증:
  [`docs/status/BORI_DEVSPACE_REACTIVATION_SPRINT2_2026-05-10.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BORI_DEVSPACE_REACTIVATION_SPRINT2_2026-05-10.md:1)
- SF Observability rename:
  [`docs/status/SF_OBSERVABILITY_RENAME_SPRINT1_2026-05-10.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/SF_OBSERVABILITY_RENAME_SPRINT1_2026-05-10.md:1)
- SF Observability 문서 정렬:
  [`docs/status/SF_OBSERVABILITY_ALIGNMENT_SPRINT2_2026-05-10.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/SF_OBSERVABILITY_ALIGNMENT_SPRINT2_2026-05-10.md:1)
- batch-integration 자산 이관:
  [`docs/status/BATCH_INTEGRATION_ASSET_MIGRATION_SPRINT3_2026-05-10.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_ASSET_MIGRATION_SPRINT3_2026-05-10.md:1)
- 첫 실제 자산 이관:
  [`docs/status/BATCH_INTEGRATION_FIRST_EXTRACTION_SPRINT4_2026-05-10.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_FIRST_EXTRACTION_SPRINT4_2026-05-10.md:1)
- App extraction Sprint 5:
  [`docs/status/BATCH_INTEGRATION_APP_EXTRACTION_SPRINT5_2026-05-12.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_APP_EXTRACTION_SPRINT5_2026-05-12.md:1)
- App extraction Sprint 6:
  [`docs/status/BATCH_INTEGRATION_APP_EXTRACTION_SPRINT6_2026-05-12.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_APP_EXTRACTION_SPRINT6_2026-05-12.md:1)
- App extraction Sprint 7:
  [`docs/status/BATCH_INTEGRATION_APP_EXTRACTION_SPRINT7_2026-05-12.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_APP_EXTRACTION_SPRINT7_2026-05-12.md:1)
- SF Observability extraction Sprint 8:
  [`docs/status/SF_OBSERVABILITY_EXTRACTION_SPRINT8_2026-05-12.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/SF_OBSERVABILITY_EXTRACTION_SPRINT8_2026-05-12.md:1)
- Batch integration exit Sprint 9:
  [`docs/status/BATCH_INTEGRATION_EXIT_SPRINT9_2026-05-12.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_EXIT_SPRINT9_2026-05-12.md:1)
- Batch integration exit Sprint 10:
  [`docs/status/BATCH_INTEGRATION_EXIT_SPRINT10_2026-05-12.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_EXIT_SPRINT10_2026-05-12.md:1)
- Batch integration exit Sprint 11:
  [`docs/status/BATCH_INTEGRATION_EXIT_SPRINT11_2026-05-12.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_EXIT_SPRINT11_2026-05-12.md:1)
- Batch integration exit Sprint 12:
  [`docs/status/BATCH_INTEGRATION_EXIT_SPRINT12_2026-05-12.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_EXIT_SPRINT12_2026-05-12.md:1)
- Batch integration exit Sprint 13:
  [`docs/status/BATCH_INTEGRATION_EXIT_SPRINT13_2026-05-12.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_EXIT_SPRINT13_2026-05-12.md:1)
- Batch integration exit Sprint 14:
  [`docs/status/BATCH_INTEGRATION_EXIT_SPRINT14_2026-05-12.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_EXIT_SPRINT14_2026-05-12.md:1)
- batch-integration 종료 스프린트 고정 계획:
  [`docs/status/BATCH_INTEGRATION_EXIT_SPRINT_PLAN_2026-05-12.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_EXIT_SPRINT_PLAN_2026-05-12.md:1)
- kube-slint v1.0.1 adoption:
  [`docs/status/KUBESLINT_V101_ADOPTION_2026-05-12.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/KUBESLINT_V101_ADOPTION_2026-05-12.md:1)
