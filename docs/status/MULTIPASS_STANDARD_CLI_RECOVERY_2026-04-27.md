# Multipass Standard CLI Recovery

기준일: `2026-04-27`

## 목적

- 원격 호스트 `100.123.80.48`에서 사용자가 직접 치는 `multipass` 명령을
  다시 안정적으로 동작시키고,
- 복구 과정에서 확인된 root cause와 복구 방식을 문서화한다.

## 최종 상태

사용자 기준 표준 명령인 `multipass`는 복구됐다.

- `multipass list`: 연속 호출 성공 확인
- `multipass version`: 연속 호출 성공 확인
- `multipass info lab-master-0`: 반복 호출 성공 확인
- `multipass exec lab-master-0 -- uname -srmo`: 성공 확인

검증은 원격 호스트 `seoy@100.123.80.48`에서 직접 수행했다.

## 원인 정리

문제는 한 가지가 아니었다.

1. `snap run multipass`가 stale mount namespace를 재사용하면서
   `core22` base snap mount를 못 찾는 경우가 있었다.
   - 오류:
     - `cannot find mount entry for snap core22 revision /var/lib/snapd/snap/core22/2411`
2. 기존 `/usr/local/bin/multipass` wrapper는
   namespace discard를 일반 사용자로 호출하고 있었기 때문에
   사실상 무효였다.
3. 사용자 세션에서 바로 `snap run multipass`를 타면
   `snap-confine`의 per-user mount/user-data 준비 단계에서
   아래 오류가 별도로 났다.
   - 오류:
     - `cannot create user data directory: /home/seoy/snap/multipass/16926: Permission denied`

즉 `multipassd` daemon과 VM 자체는 살아 있어도,
CLI 진입 경로가 깨져서 사용자 명령이 불안정했던 상태였다.

## 복구 방식

복구는 `raw snap run`을 억지로 정상화하는 대신,
사용자 명령 `multipass`를 안정 경로로 다시 묶는 방식으로 마무리했다.

현재 `/usr/local/bin/multipass`는 아래 원칙으로 동작한다.

1. `sudo env HOME=/home/seoy snap run multipass ...` 경로로 실행한다.
2. 실패 메시지가 `core22` mount entry 오류면
   `snap-discard-ns multipass`를 수행한다.
3. `/run/snapd/ns/` 아래의 stale metadata 파일도 같이 제거한다.
   - `multipass.mnt`
   - `snap.multipass.info`
   - `snap.multipass.fstab`
4. 짧게 대기한 뒤 최대 3회까지 재시도한다.

이 조합으로 `multipass list`를 8회 연속 성공시켰다.

## 왜 이 방식이 맞는가

이번 호스트에서는 아래 두 사실이 분리되어 있었다.

- `multipassd`, `dnsmasq`, `qemu`, bridge는 실제로 복구 가능했다.
- 반면 `raw snap run multipass`는
  Rocky + SELinux + snap namespace 경로에서 비결정적으로 깨졌다.

따라서 이번 스프린트 목표 기준에서는
사용자가 실제로 쓰는 `multipass` 명령을 복구하는 것이 더 중요했다.

즉:

- 운영/개발자 UX 기준 복구: 완료
- snap 내부 구현 결함의 완전 제거: 미완료

## 남은 한계

아래 명령은 여전히 근본적으로 안전하지 않다.

- `snap run multipass`
- `sudo snap run multipass`

이 둘은 wrapper 없이 직접 치면
동일한 `core22` mount entry 오류를 다시 낼 수 있다.

따라서 운영 규칙은 명확하다.

- 사용자는 `multipass ...`만 사용한다.
- `snap run multipass ...` 직접 호출은 금지한다.

## 운영 판단

이번 복구로 VM lab 운영, Harbor 경유 배포, smoke/회귀 검증에 필요한
실사용 CLI 경로는 닫혔다.

따라서 이후 스프린트에서는:

1. `multipass` 사용자 명령은 현재 wrapper 경로를 표준으로 사용
2. `raw snap run` 결함은 플랫폼 debt로만 추적

이 판단이 맞다.
