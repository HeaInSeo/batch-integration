# Bori DevSpace Reactivation Sprint 2 2026-05-10

기준일:
- `2026-05-10`

목적:
- `100.123.80.48`에서 `bori + DevSpace + kube-slint` 경로를 실제로 올린 결과를 기록한다.
- Sprint 1에서 식별한 blocker가 실제로 해소됐는지 확인한다.

## 최종 상태

- `Code Ready`: 완료
- `Remote Validated`: 완료

이번 스프린트는 문서 점검 수준이 아니라,
실제 운영 및 테스트 장비인 `100.123.80.48`에서
`bori-devspace` 루프를 실행해 PASS까지 확인했다.

## 원격에서 실제 수행한 일

대상 장비:
- `100.123.80.48`

실행 내용:

1. `JUMI` 원격 checkout을 GitHub 최신 `main`으로 fast-forward
2. `artifact-handoff` 원격 checkout을 GitHub 최신 `main`으로 fast-forward
3. `bori` repo를 원격 장비에 clone
4. `kube-slint` repo를 원격 장비에 clone
5. host toolchain 정리
   - `devspace` 설치
   - `bori-devspace` build
   - `slint-gate` build
6. `bori-devspace --apps-dir /opt/go/src/github.com/HeaInSeo --profile devspace --v` 실행

## 원격 확인 결과

### 1. Repo 업데이트

원격 업데이트 결과:

- `JUMI`
  - 이전: `66503d7...`
  - 이후: `ae581045d4e94b1c2f5c8310abe02bd431d2f3bb`
- `artifact-handoff`
  - 이전: `62b4efa...`
  - 이후: `9f74bad20030d7078391bbe030fb22d04589013d`
- `bori`
  - clone 후 HEAD:
    `29ea6389942797c7fbca83e9447ec30e21ab375b`

중요한 점:

- 원격 `JUMI`와 `artifact-handoff`에는
  `.bori/`와 `devspace.yaml`이 이제 실제로 올라와 있다.

### 2. Toolchain 상태

원격 host에서 확인:

- `devspace version`
  - `6.3.21`
- `bori-devspace --help`
  - 정상 출력
- `slint-gate --help`
  - 정상 출력

즉 Sprint 1에서 blocker로 잡았던
`host toolchain 미설치` 문제는 이번 스프린트에서 닫혔다.

### 3. bori 실제 실행 결과

원격에서 실행:

```bash
/home/seoy/bin/bori-devspace --apps-dir /opt/go/src/github.com/HeaInSeo --profile devspace --v
```

실제 결과:

- `bori`가 앱 2개를 발견
  - `jumi`
  - `artifact-handoff`
- `jumi`
  - pre-smoke scrape 성공
  - post-smoke scrape 성공
  - gate result: `PASS`
- `artifact-handoff`
  - pre-smoke scrape 성공
  - post-smoke scrape 성공
  - gate result: `PASS`
- overall:
  - `PASS`

즉:

- `bori` discovery
- `kubectl port-forward` 기반 metric scrape
- `slint-gate` 평가
- multi-app DevSpace profile loop

가 실제 운영 및 테스트 장비에서 한 번 끝까지 돌았다.

## 이번 스프린트에서 닫힌 것

1. `bori`가 단순 계획 문서가 아니라 실제 실행 가능한 경로임을 검증
2. `JUMI`와 `artifact-handoff`의 `.bori/` self-registration 자산이 원격에서도 유효함을 검증
3. `devspace + bori-devspace + slint-gate` host toolchain 경로를 원격에서 실증
4. `DevSpace` profile 기준 공통 shift-left gate 루프가 최소 2개 앱에 대해 PASS 되는 것을 확인

## 아직 남은 것

1. `SF Observability` rename 완결
- 현재는 observability rename 작업이 로컬에서 진행 중이며,
  원격 publish 경로까지 일관되게 마감되지는 않았다.

2. `bori` 문서 모델과 실제 app-centric DevSpace 모델 정렬
- 현재 실제로는 각 앱 repo의 `devspace.yaml`이 중심이고,
  `bori-devspace`는 공통 adapter로 쓰인다.
- 문서도 그 현실에 더 맞게 조정돼야 한다.

3. `batch-integration` 자산 이관
- 현재 원격 검증은 성공했지만,
  publish/observability 자산은 아직 `batch-integration`에 남아 있다.

4. 실제 smoke command 통합 고도화
- 현재 `bori-devspace`는 wait 기반 smoke도 가능하다.
- 이후에는 앱별 더 강한 smoke command와 `SF Observability` publish를 연결해야 한다.

## 다음 스프린트 목표

### Sprint 3

목표:
- `bori + DevSpace` 루프 결과를 `SF Observability`까지 자연스럽게 연결

해야 할 일:
- observability rename 마감
- `shift-left-observability` 공식 자산명 정리
- `bori` loop 산출물과 publish 계약 정리
- `batch-integration` 자산 이관 계획 구체화

완료 기준:
- `DevSpace -> bori -> kube-slint -> SF Observability` 경로가
  같은 용어와 자산명으로 설명 가능

## 판단

- 이번 스프린트는 실질적으로 달성됐다.
- 큰 구조 리스크는 없다.
- 이제 본선 리스크는 “DevSpace가 되느냐”가 아니라
  “이 경로를 장기 구조로 어떻게 정리하고 이관하느냐” 쪽으로 옮겨갔다.
