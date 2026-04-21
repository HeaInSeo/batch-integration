# Kind/Podman/RPM Recovery Report (2026-04-21)

## Summary

`batch-integration/scripts/kind-cluster-init.sh` 실행 시 `kind create cluster --name batch-int-dev`
가 `Preparing nodes` 이후 또는 그 이전의 provider 확인 단계에서 장시간 멈췄다.

직접 원인은 `kind`가 내부적으로 호출하는 rootful `podman info --format json`이 반환하지 못한
것이다. 근본 원인은 Rocky 8 계열의 Berkeley DB 기반 RPM DB 환경 파일(`__db.*`)이 stale 상태로
남아 있었고, `rpm -q -f ...` 호출이 `/var/lib/rpm`에서 `db5 error(11)`을 반복하며
재시도 루프에 들어간 점이다.

`podman info`는 실행 파일의 package metadata를 조회하기 위해 `rpm -q -f`를 여러 번 호출한다.
따라서 RPM DB가 멈추면 rootful podman이 멈추고, 그 위에 올라가는 `kind`도 함께 정지한다.

## Impact

- `batch-int-dev` kind 클러스터 생성 불가
- `hello-operator` 기반 Tilt fast-loop 진입 불가
- 이후 예정된 JUMI/AH/kube-slint 통합 검증 경로 차단

## Symptoms

관측된 증상은 아래와 같았다.

- `bash scripts/kind-cluster-init.sh`가 `Creating kind cluster` 이후 진행하지 못함
- `kind create cluster --name batch-int-dev` 프로세스가 `podman info --format json`에서 정지
- rootful `podman ps -a`에 새 kind control-plane 컨테이너가 생성되지 않음
- `sudo podman info --format json` 단독 실행도 반환하지 않음
- `strace`상 `rpm -q -f /usr/bin/runc`, `rpm -q -f /usr/libexec/cni` 등이 반복적으로 호출됨

## Investigation

진단은 아래 순서로 진행했다.

1. `kind` 실행 중 프로세스 트리를 확인했다.
   - `kind create cluster`
   - `podman info --format json`
   - `/usr/bin/rpm -q -f ...`

2. `podman.service` / `podman.socket` 상태를 확인했다.
   - socket activation 자체는 정상
   - 서비스는 요청 시 뜨고 바로 종료되는 정상 패턴
   - 즉 systemd unit 자체가 1차 원인은 아니었음

3. `podman --log-level=debug info`로 어디서 멈추는지 확인했다.
   - storage/runtime 초기화는 통과
   - package metadata 수집 구간에서 정지

4. `strace`로 `podman` 자식 `rpm` 프로세스를 추적했다.
   - `/var/lib/rpm/.dbenv.lock`에 대한 `fcntl(F_SETLKW, F_WRLCK)` 대기 확인

5. `strace`로 `rpm -q -f /usr/bin/runc` 단독 실행을 추적했다.
   - 다음 에러를 반복 확인:

```text
error: db5 error(11) from dbenv->open: Resource temporarily unavailable
error: cannot open Packages index using db5 - Resource temporarily unavailable (11)
error: cannot open Packages database in /var/lib/rpm
```

6. 이 시점에서 원인을 RPM DB 환경 파일 stale 상태로 확정했다.

## Root Cause

이 시스템의 RPM DB는 SQLite가 아니라 Berkeley DB 환경 파일을 사용하는 형태다.
이 구조에서는 `/var/lib/rpm/__db.*` 파일이 lock/environment metadata를 담당한다.

이번 장애에서는 이전 비정상 종료 또는 중간 끊김으로 인해 `__db.*` 파일이 stale 상태로 남아 있었고,
새로운 `rpm -q -f ...` 호출이 정상적으로 DB를 열지 못했다.

그 결과는 다음과 같이 전파됐다.

1. `rpm -q -f`가 `Resource temporarily unavailable` 반복
2. `podman info`가 package metadata 조회를 끝내지 못함
3. `kind`가 provider 사전 점검을 통과하지 못함
4. `kind` 클러스터 생성이 정지

추가로, 중간 진단 과정에서 여러 `podman info`를 병렬로 띄우면 같은 RPM DB 경로에 대한 대기열이
형성되어 증상이 더 심해질 수 있다. 이것은 근본 원인이 아니라 관측을 더 복잡하게 만든 2차 현상이었다.

## Recovery Actions

복구는 아래 절차로 수행했다.

1. package manager 계열 프로세스가 없는지 확인
   - `dnf`, `packagekitd`, `pkcon`, `microdnf` 등 미실행 상태 확인

2. 진단 중 생성된 stale `podman info` / `rpm -q -f` 프로세스 정리
   - 중첩된 진단 호출이 lock 대기를 악화시키지 않도록 먼저 청소

3. Berkeley DB 환경 파일 백업 후 제거
   - 백업 경로:
     - `/tmp/rpmdb-bdb-backup-20260421-162453`
   - 조치 대상:
     - `/var/lib/rpm/__db.*`

4. RPM 단독 검증
   - `sudo rpm -q -f /usr/bin/runc`
   - 정상 반환 확인

5. Podman 단독 검증
   - `sudo podman info --format json`
   - 정상 JSON 반환 확인

6. Kind 재시도
   - `bash /opt/go/src/github.com/HeaInSeo/batch-integration/scripts/kind-cluster-init.sh`

## Why This Fix Is Safe

이번에 제거한 파일은 package payload 자체가 아니라 Berkeley DB runtime environment 파일이다.
이 파일들은 RPM DB 본체(`Packages`)와는 성격이 다르며, stale 상태일 때 제거 후 재생성이 일반적인
복구 절차다.

안전성을 위해 아래 조건을 먼저 만족시켰다.

- 활성 package manager 프로세스 없음 확인
- 대상 파일을 즉시 삭제하지 않고 `/tmp`로 백업
- 복구 후 `rpm`과 `podman`을 각각 독립 검증

## Verification

복구 직후 아래 검증이 성공했다.

- `sudo rpm -q -f /usr/bin/runc`
  - `runc-1.1.12-6.module+el8.10.0+2001+6a33db9f.x86_64`
- `sudo podman info --format json`
  - rootful podman host/store/runtime 정보가 정상 JSON으로 반환

이 두 검증이 통과했으므로 rootful podman 경로는 정상화된 것으로 판단한다.

## Operational Guidance

같은 증상이 재발하면 아래 순서를 우선 적용한다.

1. `sudo rpm -q -f /usr/bin/runc`가 즉시 반환하는지 확인
2. 반환하지 않으면 `strace`로 `/var/lib/rpm/.dbenv.lock` 및 `db5 error(11)` 여부 확인
3. package manager 프로세스가 없음을 확인
4. `/var/lib/rpm/__db.*`를 백업 후 제거
5. `rpm`과 `podman info`를 먼저 검증하고 나서 `kind`를 재시도

## Follow-up

- `batch-integration/scripts/kind-cluster-init.sh` 자체 문제는 아니었음
- 이 이슈는 rootful podman/provider 문제가 아니라 호스트 RPM DB health 문제였음
- 향후 kind가 멈출 때는 먼저 `sudo podman info --format json`와
  `sudo rpm -q -f /usr/bin/runc`를 health check로 사용한다
