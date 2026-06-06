# Batch Integration Asset Migration Sprint 3 2026-05-10

기준일:
- `2026-05-10`

목적:
- `batch-integration` 안 자산을 장기 목적지 기준으로 실제 파일 단위로 분해한다.
- 어떤 자산을 앱 repo, `bori`, `kube-slint`, `SF Observability`, `infra-lab` 운영 경로로
  옮길지 구체적으로 고정한다.
- 이 저장소가 영구 허브가 아니라 전이용 staging 저장소라는 점을
  코드와 문서 기준으로 다시 명확히 한다.

## 전제

- 실제 운영/테스트 장비는 `100.123.80.48`
- 실제 개발 루프 기준은 `DevSpace + bori + kube-slint`
- 공용 관찰면 기준은 `shift-left-observability` / `SF Observability`
- `batch-integration`은 장기적으로 비워지거나 제거된다

## 현재 확인한 자산 축

스크립트:
- `scripts/apply-jumi-ah-dev.sh`
- `scripts/apply-vm-lab-manifests.sh`
- `scripts/build-vm-lab-images-ko.sh`
- `scripts/build-vm-lab-images.sh`
- `scripts/generate-kubeslint-vm-lab-summary.sh`
- `scripts/install-shift-left-observability-tailnet-proxy.sh`
- `scripts/kind-cluster-init.sh`
- `scripts/publish-shift-left-observability.sh`
- `scripts/run-jumi-ah-dev-live-smoke-eval.sh`
- `scripts/run-kubeslint-vm-lab-gate.sh`
- `scripts/run-vm-lab-live-smoke-eval.sh`
- `scripts/run-vm-lab-smoke-eval.sh`
- `scripts/vm-lab-jumi-smoke-remote.sh`

배포 자산:
- `deploy/jumi-ah-dev/*`
- `deploy/shift-left-observability/*`
- `deploy/shift-left-observability-tailnet-proxy/*`
- `deploy/vm-lab/*`

앱 repo에 이미 있는 DevSpace/bori 자산:
- `JUMI/devspace.yaml`
- `JUMI/.bori/*`
- `artifact-handoff/devspace.yaml`
- `artifact-handoff/.bori/*`

## 목적지별 이관표

### 1. JUMI repo로 이관할 자산

대상:
- `scripts/vm-lab-jumi-smoke-remote.sh`
- `deploy/jumi-ah-dev/jumi.yaml`
- `deploy/jumi-ah-dev/patch-jumi-deployment.yaml`
- `deploy/vm-lab/jumi.yaml`
- `deploy/vm-lab/fixtures/jumi-handoff-smoke.json`

이유:
- JUMI 실행 방식, smoke input, runtime env, image wiring은 앱 owner가 관리해야 한다.
- DevSpace 기반으로 가더라도 JUMI smoke contract는 JUMI repo가 owning 하는 편이 맞다.

전이 방식:
- JUMI repo에 `deploy/devspace/` 또는 `deploy/infra-lab/` 계층 추가
- smoke fixture와 remote smoke helper를 JUMI repo에서 관리
- `batch-integration`에서는 cross-repo orchestration만 남김

### 2. artifact-handoff repo로 이관할 자산

대상:
- `deploy/jumi-ah-dev/artifact-handoff.yaml`
- `deploy/jumi-ah-dev/patch-artifact-handoff-deployment.yaml`
- `deploy/vm-lab/artifact-handoff.yaml`

이유:
- AH deployment flags, ports, env, image, service behavior는 앱 owner가 관리해야 한다.
- JUMI/AH 통합 배치 중 AH 전용 자산은 AH repo에서 버전과 함께 관리하는 편이 안전하다.

전이 방식:
- AH repo에 `deploy/devspace/` 또는 `deploy/infra-lab/` 계층 추가
- JUMI repo와 shared namespace overlay는 별도 운영 계층에서 합성

### 3. infra-lab 운영 경로로 이관할 자산

대상:
- `deploy/jumi-ah-dev/namespace.yaml`
- `deploy/jumi-ah-dev/kustomization.yaml`
- `deploy/vm-lab/namespace.yaml`
- `deploy/vm-lab/kustomization.yaml`
- `scripts/apply-jumi-ah-dev.sh`
- `scripts/apply-vm-lab-manifests.sh`

이유:
- namespace와 multi-app overlay는 특정 앱 repo보다 실행 기반 운영 계층이 owner가 되는 편이 맞다.
- shared VM, dedicated namespace, 공통 regcred, 공통 overlay는 `infra-lab` 성격이다.

전이 방식:
- 장기적으로 `infra-lab` 쪽 운영 디렉토리 또는 전용 ops repo가 owner
- 앱 repo가 제공하는 base manifest를 운영 overlay에서 합성

### 4. bori 로 이관할 자산

대상:
- `scripts/run-kubeslint-vm-lab-gate.sh`의 app-independent orchestration 부분
- `scripts/generate-kubeslint-vm-lab-summary.sh`의 app-independent summary wrapper
- `scripts/run-jumi-ah-dev-live-smoke-eval.sh`의 DevSpace 이후 gate orchestration 로직 중 공용 부분

이유:
- `bori`는 DevSpace와 `kube-slint`를 잇는 공용 adapter다.
- 앱에 독립적인 smoke 이후 summary/gate orchestration은 `bori`가 owning 해야 한다.

주의:
- JUMI/AH에 종속된 live smoke 시퀀스 전체를 그대로 `bori`로 옮기면 안 된다.
- `bori`로 가는 것은 app-independent orchestration이어야 한다.
- JUMI/AH-specific smoke 실행과 lifecycle 증적 수집은 각 앱 repo 또는 앱 adapter에 남긴다.

### 5. kube-slint 로 이관 또는 공동 정렬할 자산

대상:
- `tools/kubeslint-smoke-summary/*`
- summary schema 설명 문서 중 app-independent 부분

이유:
- summary/gate schema가 앱 공통 계약이면 `kube-slint`와 더 가까운 곳에서 관리하는 편이 맞다.
- 다만 JUMI/AH derived signal은 app adapter 성격이 있으므로 분리 필요하다.

권장 분리:
- 공통 summary schema와 gate contract: `kube-slint`
- JUMI/AH-specific derived signal builder: 앱 repo 또는 app-specific adapter layer

### 6. SF Observability 운영 경로로 이관할 자산

대상:
- `deploy/shift-left-observability/*`
- `deploy/shift-left-observability-tailnet-proxy/*`
- `scripts/publish-shift-left-observability.sh`
- `scripts/install-shift-left-observability-tailnet-proxy.sh`

이유:
- 이 자산은 더 이상 JUMI/AH 전용이 아니다.
- 여러 데이터플레인 앱의 gate/summary 결과를 보여주는 공용 관찰면이므로
  장기적으로 별도 운영 경로가 owner가 되는 것이 자연스럽다.

전이 방식:
- 별도 `SF Observability` 운영 repo 또는 dedicated ops path로 분리
- app-specific publish payload만 각 앱/adapter에서 공급

### 7. 보관 또는 폐기 후보

대상:
- `scripts/kind-cluster-init.sh`
- `scripts/podman-cgroupfs.containers.conf`
- `scripts/run-vm-lab-live-smoke-eval.sh`
- `scripts/run-vm-lab-smoke-eval.sh`
- `deploy/vm-lab/README.md`

이유:
- 이 자산은 현재 기준선인 `DevSpace + bori + kube-slint + SF Observability`보다
  이전 스프린트의 `kind/podman/multipass/vm-lab` 경로에 더 가깝다.
- 당장 삭제할 필요는 없지만, 장기 owner가 불분명한 상태로 남기면 노이즈가 커진다.

권장 처리:
- 역사/비상용이면 `archive/` 성격으로 이동
- 더 이상 기준 경로가 아니면 제거 후보로 명시

## 우선순위

### Sprint 3A. Ownership Freeze

이번 스프린트 완료 기준:
- 각 자산의 장기 owner를 문서로 확정
- `batch-integration` 안에서 영구 보관 자산과 전이 자산을 구분

### Sprint 3B. First Extraction

다음 단계:
- JUMI smoke fixture/remote helper를 JUMI repo로 이동 시작
- AH deployment patch를 AH repo로 이동 시작

### Sprint 3C. Shared Layer Extraction

다음 단계:
- app-independent summary/gate wrapper를 `bori` 또는 `kube-slint` 쪽으로 이관
- `SF Observability` publish 자산의 별도 운영 경로 초안 작성

## 현재 판단

- 큰 구조 리스크는 없다.
- 지금 병목은 “어디로 갈지 모름”이 아니라 “옮길 파일과 owner를 아직 확정하지 않음”이다.
- 따라서 이번 스프린트의 핵심은 기능 추가가 아니라 ownership freeze다.

## 상태

- `Code Ready`: 완료
- `Remote Validated`: 해당 없음

설명:
- 이번 스프린트는 파일 owner와 목적지 정리 문서화 작업이다.
- runtime 변경이나 원격 smoke 재실행이 필요한 변경은 아니다.

## 다음 스프린트 초점

1. `JUMI` smoke fixture와 remote helper의 첫 실제 이관
2. `artifact-handoff` deployment 자산의 첫 실제 이관
3. `bori` 또는 `kube-slint`로 옮길 공용 summary/gate wrapper 경계 확정
