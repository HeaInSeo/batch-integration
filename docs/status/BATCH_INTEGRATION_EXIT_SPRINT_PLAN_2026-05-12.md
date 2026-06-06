# Batch Integration Exit Sprint Plan 2026-05-12

기준일:
- `2026-05-12`

목적:
- `batch-integration` 제거까지 가는 짧은 스프린트 일정을 고정한다.
- 작업이 중단되더라도 다음 세션에서 바로 재개할 수 있게 현재 상태와 다음 액션을 기록한다.
- 모든 스프린트는 `Code Ready`와 `Remote Validated`를 분리해서 판정한다.

## 최종 목표

최종 목표는 아래 한 줄로 고정한다.

- `batch-integration`에 남아 있는 전이 자산을 `bori`, 각 앱 repo, `SF Observability` 운영 경로로 이관하고, 이 저장소를 제거 가능한 상태로 만든다.

장기 구조:

- 앱 repo:
  - `JUMI`
  - `artifact-handoff`
  - 이후 다른 데이터플레인 앱
- 공용 개발 루프:
  - `DevSpace`
  - `bori`
- 공용 gate:
  - `kube-slint`
- 공용 관찰면:
  - `shift-left-observability`
  - 표시 이름 `SF Observability`
- 실행 기반:
  - `infra-lab`

## 기본 운영 원칙

1. 로컬은 코드/문서/스크립트 준비 환경이다.
2. 실제 truth는 항상 `100.123.80.48` 원격 장비 기준이다.
3. 원격 repo는 dirty 상태일 수 있으므로, 검증 전 `git status`를 먼저 확인한다.
4. 가능한 한 원격 repo를 직접 수정하지 않고 `/tmp` staging을 우선 사용한다.
5. `bori`는 얇은 glue layer를 유지한다.

`bori`에 남겨도 되는 것:
- 앱 발견
- pre/post metrics scrape
- smoke trigger
- `slint-gate` 호출
- 결과 요약

`bori`에 넣으면 안 되는 것:
- 앱별 배포 로직
- 앱별 fixture 본체
- observability publish 본체
- infra provisioning
- app-specific artifact/handoff 본체 로직

## 현재 상태 요약

이미 닫힌 것:

- `DevSpace + bori + kube-slint` 원격 검증 경로 실증 완료
- `shift-left-observability` / `SF Observability` rename 완료
- `batch-integration` 자산 owner map freeze 완료
- 첫 실제 자산 이관 완료
  - JUMI smoke fixture/helper 일부 → `JUMI`
  - AH deployment patch 일부 → `artifact-handoff`
- 최신 `kube-slint` 기준 `bori -> slint-gate` CLI 계약 원격 검증 완료

아직 남은 것:

- `batch-integration` 잔여 자산의 실제 이관
- `SF Observability` publish 자산 owner 정리
- 남은 shim 제거
- 최종적으로 `batch-integration`이 없어도 운영 경로가 유지되는지 원격 검증

## 스프린트 고정 일정

### Sprint 1. Bori Boundary Freeze

상태:
- 완료

목표:
- `bori`의 역할과 비역할을 고정한다.

완료 기준:
- `bori` scope 문서화 완료
- `batch-integration` 자산 owner map freeze 완료

대표 문서:
- [BORI_DEVSPACE_TRANSITION_REPORT_2026-05-10.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BORI_DEVSPACE_TRANSITION_REPORT_2026-05-10.md:1)
- [BATCH_INTEGRATION_ASSET_MIGRATION_SPRINT3_2026-05-10.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_ASSET_MIGRATION_SPRINT3_2026-05-10.md:1)

### Sprint 2. First Extraction

상태:
- 완료

목표:
- 첫 실제 자산 이관을 끝낸다.

완료 기준:
- JUMI owner 자산 일부가 `JUMI` repo로 이동
- AH owner 자산 일부가 `artifact-handoff` repo로 이동
- 새 owner 경로 기준 live smoke가 원격에서 성공

대표 문서:
- [BATCH_INTEGRATION_FIRST_EXTRACTION_SPRINT4_2026-05-10.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_FIRST_EXTRACTION_SPRINT4_2026-05-10.md:1)

### Sprint 3. Platform Contract Stabilization

상태:
- 완료

목표:
- 공용 플랫폼 계약이 최신 기준으로 유지되는지 확인한다.

세부 범위:
- 최신 `kube-slint` 기준 consumer 영향 점검
- `bori -> slint-gate` CLI/IO 계약 원격 검증
- `batch-integration` 내 오래된 `kube-slint` 의존 제거

완료 기준:
- `batch-integration`의 오래된 `kube-slint` 호출 경로 제거
- 최신 `kube-slint` 기준 `bori` 원격 PASS 확인

대표 문서:
- [KUBESLINT_CONSUMER_IMPACT_2026-05-11.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/KUBESLINT_CONSUMER_IMPACT_2026-05-11.md:1)
- [BORI_KUBESLINT_CLI_CONTRACT_CHECK_2026-05-12.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BORI_KUBESLINT_CLI_CONTRACT_CHECK_2026-05-12.md:1)

결론:
- 완료.
- 다음 액션은 contract 확인이 아니라 남은 자산 이관으로 넘어가는 것이다.

### Sprint 4. App Asset Extraction

상태:
- 진행 중

목표:
- `batch-integration`에 남은 앱 전용 자산을 각 owner repo로 더 밀어낸다.

대상:
- JUMI 전용 smoke/helper/fixture 잔여물
- AH 전용 deploy/patch 잔여물
- app-specific summary/adapter 잔여 경로

완료 기준:
- 앱 실행/검증에 필요한 핵심 자산이 각 앱 repo 기준으로 돌아간다.
- `batch-integration`에는 app-specific shim이 최소만 남는다.

판정:
- `Code Ready` 필수
- `Remote Validated` 필수

예상 리스크:
- 중간
- owner repo와 remote host의 dirty worktree 충돌 가능성
- `artifact-handoff` active coding과 충돌 가능성

현재 메모:
- 이번 스프린트는 `artifact-handoff` active coding을 고려해
  `JUMI` 중심 extraction으로 재조정했다.
- 상세 상태는
  [BATCH_INTEGRATION_APP_EXTRACTION_SPRINT5_2026-05-12.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_APP_EXTRACTION_SPRINT5_2026-05-12.md:1)
  를 기준으로 본다.
- summary/policy owner 이동은
  [BATCH_INTEGRATION_APP_EXTRACTION_SPRINT6_2026-05-12.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_APP_EXTRACTION_SPRINT6_2026-05-12.md:1)
  를 기준으로 본다.
- `jumi-smoke` owner 이동과 remote build owner 수정은
  [BATCH_INTEGRATION_APP_EXTRACTION_SPRINT7_2026-05-12.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_APP_EXTRACTION_SPRINT7_2026-05-12.md:1)
  를 기준으로 본다.

### Sprint 5. SF Observability Extraction

상태:
- 완료

목표:
- publish/site/proxy 자산을 `batch-integration` 의존에서 끊는다.

대상:
- `deploy/shift-left-observability/*`
- `deploy/shift-left-observability-tailnet-proxy/*`
- publish/install script

완료 기준:
- `SF Observability` 운영 자산의 장기 owner 경로가 분명해진다.
- `batch-integration`이 publish 본체를 더 이상 소유하지 않는다.

판정:
- `Code Ready` 필수
- `Remote Validated` 필수

예상 리스크:
- 중간
- 실제 사용자 진입점 `http://100.123.80.48:8008/` 영향 가능성

상세 상태:
- [SF_OBSERVABILITY_EXTRACTION_SPRINT8_2026-05-12.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/SF_OBSERVABILITY_EXTRACTION_SPRINT8_2026-05-12.md:1)

### Sprint 6. Batch-Integration Exit

상태:
- 진행 중

목표:
- `batch-integration` 제거 가능 상태를 만든다.

대상:
- 남은 shim 삭제
- README/문서에서 staging 역할만 남기고 실제 운영 경로 제거
- 삭제 직전 최종 owner 점검

완료 기준:
- 원격 실사용 경로가 `batch-integration` 없이 유지된다.
- 이 저장소는 archive/delete 결정만 남는다.

판정:
- `Code Ready` 필수
- `Remote Validated` 필수

예상 리스크:
- 가장 큼
- 빠진 경로가 있으면 마지막에 크게 되돌아갈 수 있음

상세 상태:
- [BATCH_INTEGRATION_EXIT_SPRINT9_2026-05-12.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_EXIT_SPRINT9_2026-05-12.md:1)
- [BATCH_INTEGRATION_EXIT_SPRINT10_2026-05-12.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_EXIT_SPRINT10_2026-05-12.md:1)
- [BATCH_INTEGRATION_EXIT_SPRINT11_2026-05-12.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_EXIT_SPRINT11_2026-05-12.md:1)
- [BATCH_INTEGRATION_EXIT_SPRINT12_2026-05-12.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_EXIT_SPRINT12_2026-05-12.md:1)
- [BATCH_INTEGRATION_EXIT_SPRINT13_2026-05-12.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_EXIT_SPRINT13_2026-05-12.md:1)
- [BATCH_INTEGRATION_EXIT_SPRINT14_2026-05-12.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_EXIT_SPRINT14_2026-05-12.md:1)

## 재개 체크리스트

작업이 중단된 뒤 다시 시작할 때는 아래 순서로 확인한다.

1. 현재 기준 문서 확인
- 이 문서
- [BATCH_INTEGRATION_ASSET_MIGRATION_SPRINT3_2026-05-10.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_ASSET_MIGRATION_SPRINT3_2026-05-10.md:1)
- [BATCH_INTEGRATION_FIRST_EXTRACTION_SPRINT4_2026-05-10.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_FIRST_EXTRACTION_SPRINT4_2026-05-10.md:1)

2. 원격 baseline 확인
- `100.123.80.48`에서 아래 repo 상태 확인
  - `infra-lab`
  - `JUMI`
  - `artifact-handoff`
  - `bori`
  - `kube-slint`
- 최소 확인 항목:
  - `git status --short`
  - `git rev-parse --short HEAD`

3. 현재 공식 검증 기준 재확인
- DevSpace/bori 기준:
  - `/home/seoy/bin/bori-devspace`
  - `/home/seoy/bin/slint-gate`
- 관찰면 기준:
  - `http://100.123.80.48:8008/`

4. 현재 스프린트 위치 판단
- Sprint 3가 끝났는지
- Sprint 4로 바로 들어갈지
- 이미 일부 이관된 자산이 추가로 남아 있는지

## 현재 다음 액션

현재 기준 다음 액션은 아래로 고정한다.

1. `generate-kubeslint-vm-lab-summary.sh`, `run-kubeslint-vm-lab-gate.sh`의 최종 owner/존치 여부 결정
2. `deploy/vm-lab/fixtures/*`와 legacy status 문서의 archive/delete 후보 정리
3. `batch-integration` 삭제 직전 남길 shim 목록을 한 번 더 줄이기

현재 메모:
- 1번은 완료.
- 2번과 3번도 기준 문서화는 완료.
- 마지막 cleanup window 집행은 완료.
- 남은 것은 `batch-integration` exit을 여기서 종료할지,
  아니면 `JUMI` worker job `serviceAccountName` 버그까지 owner repo에서 닫을지 결정하는 것이다.

## 다음 세션 시작점

다음 세션 시작점은 아래로 고정한다.

- Sprint 4 `App Asset Extraction`을 계속 진행한다.
- 특히 `batch-integration`에 남아 있는 app-specific shim과 app-specific summary/helper 경로를 다시 줄인다.
- 현재 다음 우선순위는 `vm-lab` legacy 축 정리와 마지막 thin wrapper 정리다.
- `vm-lab` legacy wrapper 경량화는
  [BATCH_INTEGRATION_EXIT_SPRINT10_2026-05-12.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/BATCH_INTEGRATION_EXIT_SPRINT10_2026-05-12.md:1)
  를 기준으로 본다.
- `artifact-handoff`는 active coding 종료 전까지 추가 변경 최소화 원칙을 유지한다.
- 시작 전 반드시 `100.123.80.48` 원격 repo dirty 상태를 먼저 확인한다.

## 현재 판정

- `Code Ready`: 완료된 스프린트는 문서로 고정됨
- `Remote Validated`: Sprint 1~4 현재 진행분까지 기준 확인됨
- 가장 중요한 다음 액션:
  - Sprint 4 계속 진행
  - 특히 `tools/jumi-smoke`와 `SF Observability` 자산 owner 정리를 다음 우선순위로 본다.
