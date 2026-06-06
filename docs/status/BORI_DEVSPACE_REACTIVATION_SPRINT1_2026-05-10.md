# Bori DevSpace Reactivation Sprint 1 2026-05-10

기준일:
- `2026-05-10`

목적:
- `bori + DevSpace` 실행 경로를 다시 본선으로 올리기 위한 첫 스프린트의 현재 상태를 기록한다.
- 지금 당장 막는 blocker와, 다음 스프린트에서 실제로 손대야 할 대상을 분리한다.

## 이번 스프린트 결론

이번 스프린트에서 확인된 핵심은 다음이다.

- `bori`는 실제로 `DevSpace + kube-slint` 연결을 담당하는 중심 adapter layer다.
- `JUMI`와 `artifact-handoff`는 이미 `devspace.yaml`과 `.bori/` self-registration 자산을 갖고 있다.
- 따라서 현재 blocker는 앱 repo 구조 부재가 아니라,
  `DevSpace` 실행 환경 미설치와 `bori` 문서/실행 모델의 불일치다.

즉:

- 방향은 이미 있다.
- 실행 환경과 정렬 작업이 아직 안 올라온 상태다.

## 확인된 사실

### 1. bori 자체 상태

- 로컬 repo 존재:
  `/opt/go/src/github.com/HeaInSeo/bori`
- `go test ./...` 통과
- `Makefile` 기준 빌드 경로 존재:
  `go build -o bin/bori-devspace ./adapters/devspace`

근거:
- [bori/Makefile](/opt/go/src/github.com/HeaInSeo/bori/Makefile:1)
- [bori/adapters/devspace/main.go](/opt/go/src/github.com/HeaInSeo/bori/adapters/devspace/main.go:1)

### 2. 앱 repo 준비 상태

`JUMI`:
- `devspace.yaml` 존재
- `.bori/component.yaml` 존재
- `.bori/policy.devspace.yaml` 존재

`artifact-handoff`:
- `devspace.yaml` 존재
- `.bori/component.yaml` 존재
- `.bori/policy.devspace.yaml` 존재

즉 앱 repo는 이미 `DevSpace + bori` 경로로 들어갈 최소 자산을 갖고 있다.

근거:
- [JUMI/devspace.yaml](/opt/go/src/github.com/HeaInSeo/JUMI/devspace.yaml:1)
- [JUMI/.bori/component.yaml](/opt/go/src/github.com/HeaInSeo/JUMI/.bori/component.yaml:1)
- [JUMI/.bori/policy.devspace.yaml](/opt/go/src/github.com/HeaInSeo/JUMI/.bori/policy.devspace.yaml:1)
- [artifact-handoff/devspace.yaml](/opt/go/src/github.com/HeaInSeo/artifact-handoff/devspace.yaml:1)
- [artifact-handoff/.bori/component.yaml](/opt/go/src/github.com/HeaInSeo/artifact-handoff/.bori/component.yaml:1)
- [artifact-handoff/.bori/policy.devspace.yaml](/opt/go/src/github.com/HeaInSeo/artifact-handoff/.bori/policy.devspace.yaml:1)

### 3. 현재 환경 blocker

현재 이 환경에서 확인된 blocker:

- `devspace` CLI 없음
- `bori-devspace` 바이너리 없음

즉 지금은 설정과 코드가 있어도 실제로 실행할 host toolchain이 올라와 있지 않다.

## 확인된 불일치

이번 스프린트에서 가장 중요한 발견은 이것이다.

### A. bori 문서 모델과 실제 앱 repo 모델이 완전히 같지 않다

`bori` README/architecture는 대체로 다음 이미지를 준다.

- `bori/devspace.yaml`가 중심
- DevSpace compose/import를 `bori` 쪽에서 관리
- 그 위에 `bori-devspace` hook이 붙는다

하지만 실제 앱 repo는 이미 자기 `devspace.yaml` 안에서
`after:deploy -> bori-devspace`를 호출한다.

즉 현재 코드 기준으로는 오히려:

- 앱 repo 중심 DevSpace 실행
- `bori-devspace`는 공통 gate adapter

에 더 가깝다.

이 불일치는 문서와 운영 모델을 헷갈리게 만든다.

### B. bori/devspace.yaml 자체는 현재 앱을 배포하지 않는다

현재 `bori/devspace.yaml`은 hook만 있고,
문서가 암시하는 “앱 import/compose 중심” 구조가 코드로 분명하게 드러나지 않는다.

즉 지금 단계에서 `bori/devspace.yaml`을 곧바로 본선 진입점으로 볼 수는 없다.

## 냉정한 판단

지금 기준에서 가장 현실적인 본선 경로는 이것이다.

1. 앱 repo에서 `devspace dev`
2. 앱 repo `after:deploy` hook이 `bori-devspace` 호출
3. `bori-devspace`가 `.bori/`를 보고 `kube-slint` gate 수행
4. 결과를 `SF Observability`에 publish

즉:

- 단기 본선은 `app repo-centric DevSpace`
- `bori`는 공통 adapter
- `batch-integration`은 전이용 publish/gate 자산 보관소

이 판단이 현재 코드와 가장 잘 맞는다.

## 지금 당장 큰 리스크

1. 실행 환경 미설치
- `devspace`
- `bori-devspace`
- `slint-gate`

2. 문서/운영 모델 불일치
- `bori` 문서가 `bori/devspace.yaml` 중심으로 읽히는 부분
- 실제 repo들은 app-centric `devspace.yaml`을 이미 사용 중

3. 공통 publish 경로가 아직 `batch-integration`에 묶여 있음
- 장기적으로는 `SF Observability` 운영 경로로 분리돼야 한다.

## 다음 스프린트 목표

### Sprint 2 목표

- `DevSpace` 실행 환경을 실제 K8s VM host에 올린다.
- `bori-devspace`와 `slint-gate`를 host에서 실행 가능하게 만든다.
- `JUMI`와 `artifact-handoff` 중 최소 1개 repo에서
  `devspace dev --profile devspace` 경로를 실제로 검증한다.

### Sprint 2 완료 기준

- host에서 `devspace version` 성공
- host에서 `bori-devspace --help` 또는 실행 성공
- host에서 `slint-gate --help` 성공
- 앱 repo 1개 이상에서 `after:deploy -> bori-devspace` 실제 동작 확인

## 이번 스프린트 산출물

- `bori`가 중심 adapter layer라는 구조 재확인
- `JUMI`/`artifact-handoff`의 `.bori/` 자산 존재 확인
- 실행 환경 미설치가 1차 blocker임을 명확히 분리
- `bori` 문서 모델과 app-centric DevSpace 모델의 차이 식별

## 최종 판단

- 큰 설계 리스크는 없다.
- 가장 큰 위험은 아키텍처 방향이 아니라 “실행 환경이 아직 안 올라와 있다”는 점이다.
- 따라서 다음 스프린트는 새 설계보다 `host toolchain + first live DevSpace repo loop`에 집중하는 것이 맞다.
