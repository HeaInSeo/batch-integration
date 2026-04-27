# Multipass VM Lab Recovery

기준일: `2026-04-27`

## 목적

- 원격 호스트 `100.123.80.48`의 `multipass` 장애를 복구해
  VM lab 배포/검증 경로를 다시 usable 상태로 되돌린다.

## 초기 증상

- `multipass list` 실패
- `snap.multipass.multipassd` 재시작 루프
- host에서 `10.113.24.254:22` timeout 또는 route failure
- host에서 Harbor endpoint 접근 실패
- `mpqemubr0`가 없거나 `linkdown`

## 원인 축

이번 장애는 단일 원인이 아니라 아래 세 축이 연쇄적으로 겹친 상태였다.

1. `multipass` snap interface 연결 부족
2. `multipassd -> dnsmasq -> mpqemubr0` 네트워크 계층 불안정
3. 인스턴스가 `Suspended`로 남아 bridge에 carrier가 붙지 않음

추가로 표준 user CLI 경로인 `snap run multipass`는 별도 결함이 남아 있었다.

- 오류:
  - `cannot find mount entry for snap core22 revision /var/lib/snapd/snap/core22/2411`

즉 daemon/service 경로와 user CLI 경로를 분리해서 봐야 했다.

## 실제 복구 내용

1. `multipass` 관련 snap interface를 재연결했다.
   - `network`
   - `network-bind`
   - `network-control`
   - `network-observe`
   - `firewall-control`
   - `multipass-support`
   - `kvm`
   - `libvirt`
2. 호스트 재부팅 후 `snapd`, `multipassd`, socket 상태를 재확인했다.
3. `snap.multipass.multipassd`가 다시 `active`로 올라온 것을 확인했다.
4. `lab-master-0`, `lab-worker-0`, `lab-worker-1`를 다시 기동했다.
5. bridge/route가 복구된 것을 확인했다.
   - `mpqemubr0 state UP`
   - `10.113.24.0/24 dev mpqemubr0`
   - `10.113.24.96 via 10.113.24.254 dev mpqemubr0`
6. nested SSH와 Harbor reachability를 재확인했다.

## 복구 결과

- `multipassd`: `active`
- `lab-master-0`: `Running 10.113.24.254`
- `lab-worker-0`: `Running 10.113.24.35`
- `lab-worker-1`: `Running 10.113.24.216`
- host -> VM SSH: 복구
- host -> Harbor HTTP: 복구
- Harbor image push: 복구
- VM lab redeploy/live smoke: 재개 가능

## 표준 CLI 상태

사용자가 직접 사용하는 `multipass` 명령은 복구됐다.

- `/usr/local/bin/multipass` wrapper를 재작성해
  root-home 경로와 stale namespace 재시도를 묶었다.
- `multipass list`, `version`, `info`, `exec`가
  반복 호출에서도 성공하는 것을 확인했다.

다만 아래 raw snap 경로는 여전히 안정적이지 않다.

- `snap run multipass`
- `sudo snap run multipass`

즉 현재 결론은 다음과 같다.

- VM lab 운영 복구: 완료
- 사용자 `multipass` CLI 복구: 완료
- raw `snap run multipass` platform bug: 별도 debt

## 운영 판단

현재 스프린트 목표 기준으로는
VM lab을 다시 사용 가능하게 만든 것이 더 중요하다.

따라서 당장은:

1. 복구된 VM lab으로 배포/회귀 검증 계속 진행
2. raw `snap run multipass` 결함은 플랫폼 debt item으로만 추적

이 순서가 맞다.
