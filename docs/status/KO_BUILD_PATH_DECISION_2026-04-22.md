# KO Build Path Decision

기준일: `2026-04-22`

## 목적

`JUMI`, `artifact-handoff` VM lab 이미지 빌드 경로를
`ko` 기준으로 전환할 수 있는지 확인하고,
이번 스프린트에서 실제로 어떤 경로를 써야 하는지 결정한다.

## 결론

설계상 기본 경로는 `ko`가 맞다.
하지만 현재 스프린트에서 실제로 동작하는 경로는
`100.123.80.48`에서의 `podman/buildah` 기반 빌드/푸시다.

즉:

- 기본 전략: `ko`
- 이번 스프린트의 실동작 fallback: `remote podman/buildah`

## 확인한 사실

### 1. `ko` 자체

- 로컬 워크스페이스 호스트에는 `ko v0.18.1` 설치 완료
- 원격 `100.123.80.48`에는 `ko` 없음
- 원격에는 `go` toolchain도 없음

원격에서 `ko` 실행 결과:

```text
Error: failed to publish images: qualifying local import :
err: go command required, not found: exec: "go": executable file not found in $PATH
```

해석:
- `ko`는 로컬 Go 빌드를 전제로 하므로
  현재 원격 호스트만으로는 바로 빌드할 수 없다.

### 2. 로컬에서 Harbor 직접 push 가능 여부

로컬 워크스페이스 호스트에서:

```text
curl -I --max-time 10 http://harbor.10.113.24.96.nip.io/v2/
```

결과:

```text
curl: (28) Connection timed out after 10000 milliseconds
```

해석:
- 현재 로컬 워크스페이스 호스트는 Harbor endpoint에 직접 닿지 못한다.
- 따라서 `local ko -> Harbor push`도 지금은 바로 쓸 수 없다.

### 3. 원격 빌드 호스트 상태

`100.123.80.48`에는 아래가 있다.

- `podman`
- `buildah`
- Harbor auth file (`~/.config/containers/auth.json`)
- Harbor host auth key: `harbor.10.113.24.96.nip.io`

따라서 원격 빌드 호스트에서는
`podman/buildah -> Harbor push` 경로가 현실적으로 가장 가깝다.

## 스프린트 판단

이번 스프린트에서는 다음처럼 운영한다.

1. `ko`를 문서와 스크립트 기준의 기본 경로로 유지
2. 하지만 실제 이미지 생성/푸시는 원격 `podman/buildah` fallback 사용
3. 이후 아래 조건 중 하나가 만족되면 `ko`를 실동작 경로로 승격
   - 원격 빌드 호스트에 Go toolchain 준비
   - 로컬 워크스페이스 호스트에서 Harbor 직접 접근 가능

## 영향

- 스프린트 일정 자체를 깨지는 않음
- 다만 VM lab 첫 배포는 당분간 `ko-only`가 아니라
  fallback build 경로를 같이 유지해야 한다

## 후속 작업

- 원격 `podman/buildah` 경로로 첫 이미지 push 완료
- `lab-master-0`에 첫 배포 적용
- `ko` 실동작 승격 조건은 별도 환경 작업으로 추적
