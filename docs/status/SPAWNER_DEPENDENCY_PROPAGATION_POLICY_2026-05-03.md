# Spawner Dependency Propagation Policy 2026-05-03

목적:
- `JUMI -> spawner` runtime contract를 발전시키되
  workspace 구조 의존을 만들지 않는 원칙을 고정한다

판단:
- `JUMI`는 현재 runtime backend로 `spawner`에 기능 의존한다
- 하지만 `JUMI`의 기본 빌드/배포가 `../spawner` 같은 sibling repo 존재를 전제로 굳어지면
  결합이 과해진다
- 따라서 기능 의존과 workspace 구조 의존은 분리해야 한다

## 원칙

1. 기본 `go.mod`는 published `spawner` module을 기준으로 유지한다.
- 기본 경로에 `replace github.com/seoyhaein/spawner => ../spawner`를 넣지 않는다.

2. 기본 Containerfile / 기본 이미지 빌드는 단일 repo context에서 돌아야 한다.
- sibling repo checkout 유무에 따라 깨지는 기본 빌드는 허용하지 않는다.

3. 로컬 통합 검증은 선택 경로로 분리한다.
- 필요 시 `go.work`
- 필요 시 임시 local replace
- 필요 시 별도 integration-only build script
- 하지만 이것들은 기본 경로가 아니라 opt-in 경로여야 한다.

4. 제품 경로 반영은 `spawner` 쪽 정식 버전 전파로 닫는다.
- 필요한 필드나 계약이 생기면
  `spawner` 변경
  -> 테스트
  -> 버전 bump
  -> `JUMI` 의존 갱신
  순서로 간다.

## 현재 상태

이번 작업에서 확인된 것:
- `spawner`에 `WorkingDir`, `ServiceAccountName` 필드를 추가했다.
- `JUMI` adapter도 해당 필드를 채우도록 준비했다.
- 하지만 기본 `JUMI` dependency는 아직 릴리스된 `spawner` 버전을 보고 있다.

따라서 현재 해석은 이렇다:
- `cleanup TTL`, `placement` wiring은 현재 contract로도 진행 가능
- `WorkingDir`, `ServiceAccountName`의 typed contract 전파는
  `spawner` 버전 전파 이후에 기본 경로에 반영해야 한다

## 권장 다음 단계

1. `spawner` 변경을 정식 버전으로 정리
2. `JUMI`가 그 버전을 사용하도록 의존 업데이트
3. 그 다음에만 `JUMI` adapter의 typed field 사용을 기본 경로로 승격

## 금지할 것

- 기본 `JUMI` `go.mod`에 장기적 `replace ../spawner` 고정
- 기본 이미지 빌드를 workspace 상위 context 의존으로 전환
- local-only 구조를 제품 기본 경로처럼 취급
