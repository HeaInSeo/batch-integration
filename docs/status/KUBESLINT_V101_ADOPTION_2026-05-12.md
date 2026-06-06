# kube-slint v1.0.1 Adoption 2026-05-12

기준일:
- `2026-05-12`

목적:
- `kube-slint` 사용 기준을 `v1.0.1`로 고정한다.
- local checkout 바이너리를 암묵적으로 사용하는 경로를 줄인다.
- 실제 운영/테스트 장비 `100.123.80.48`의 `slint-gate`를 `v1.0.1`로 맞춘다.

## 기준

사용 기준:
- GitHub release: `v1.0.1`
- tag revision:
  - `da4aa87eaa832c1bd7aa9915ced8500f67dee167`

주의:
- GitHub `origin`에 태그가 있어도 원격 장비의 local clone에는 태그가 아직 없을 수 있다.
- 이번 점검 시점에도 `100.123.80.48`의 local checkout에는 `v1.0.1` tag ref가 없었고,
  `git fetch --tags origin` 후에 local tag metadata를 맞췄다.

## 변경

### 1. remote slint-gate 갱신

원격 장비:
- `100.123.80.48`

처리:
- 먼저 local clone에 tag metadata 동기화
  - `git fetch --tags origin`
- 로컬 `kube-slint`의 `v1.0.1` 소스를 tarball로 stage
- 원격 `/tmp/kube-slint-v1.0.1-src`에 풀고
- `/usr/local/go/bin/go build -o /home/seoy/bin/slint-gate ./cmd/slint-gate`

결과:
- remote local checkout에서도 `v1.0.1` tag 조회 가능
  - `git tag --list v1.0.1`
  - `git rev-list -n 1 v1.0.1`
- `/home/seoy/bin/slint-gate` 는 `v1.0.1` 기준 바이너리로 갱신됨
- help output 기준 `--fail-on` 포함 최신 CLI shape 확인

### 2. bori remote validation

실행:

```bash
/home/seoy/bin/bori-devspace \
  --apps-dir /opt/go/src/github.com/HeaInSeo \
  --profile devspace \
  --slint-gate /home/seoy/bin/slint-gate \
  --v
```

결과:
- `jumi`: PASS
- `artifact-handoff`: PASS
- `overall`: PASS

즉 `bori -> slint-gate` 경로는 `kube-slint v1.0.1` 기준으로도 유지된다.

### 3. batch-integration gate script tightening

변경:
- [run-kubeslint-vm-lab-gate.sh](/opt/go/src/github.com/HeaInSeo/batch-integration/scripts/run-kubeslint-vm-lab-gate.sh:1)

정책:
- 기본은 설치된 `slint-gate` 바이너리만 사용
- sibling checkout fallback 은 기본 비활성
- 정말 필요할 때만
  `ALLOW_LOCAL_CHECKOUT_FALLBACK=true`
  로 opt-in

이유:
- 실제 운영/테스트 기준은 release/install 된 `slint-gate` 여야 한다.
- local checkout binary 를 암묵적으로 기준으로 삼으면
  release 기준 drift 가 생길 수 있다.

## 현재 판단

- `kube-slint` 사용 기준은 이제 `v1.0.1`로 보는 것이 맞다.
- `batch-integration`, `bori` 검증도 이 기준으로 정렬했다.
- 다음 세션에서도 `slint-gate` 문제는 우선 `/home/seoy/bin/slint-gate`가 `v1.0.1`인지 먼저 확인하면 된다.
