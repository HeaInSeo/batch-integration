# Multipass Dnsmasq Netlink Incident

기준일: `2026-04-27`

## 상황

VM lab smoke 재검증을 위해 원격 호스트 `100.123.80.48`에서
새 이미지를 Harbor로 push하고, 이후 VM lab에 재배포하려고 했다.

초기에는 Harbor push timeout으로 보였지만,
추적 과정에서 VM lab 관리 plane 자체가 불안정하다는 점이 확인됐다.

## 관찰된 증상

- host에서 Harbor endpoint `10.113.24.96:80` timeout
- host에서 VM `10.113.24.254:22` timeout
- nested SSH 기반 VM 접근 실패
- `multipass list` 실패
- `snap.multipass.multipassd` daemon 재시작 루프

## 직접 확인된 상태

`systemctl status snap.multipass.multipassd`:

- `Active: activating (auto-restart)`
- `ExecStart ... status=1/FAILURE`

`journalctl -u snap.multipass.multipassd` 주요 오류:

```text
dnsmasq: cannot create netlink socket: Operation not permitted
dnsmasq died: Process returned exit code: 5
Caught an unhandled exception: dnsmasq died: Process returned exit code: 5
```

즉 현재 장애의 핵심은
Harbor application 코드나 JUMI/AH 코드가 아니라,
원격 호스트에서 `multipassd -> dnsmasq -> mpqemubr0` 관리 경로가
정상적으로 올라오지 못하는 데 있다.

## 연쇄 영향

1. `multipassd`가 비정상
2. VM 접근 경로 불안정
3. Harbor가 있는 VM network/route 경로 불안정
4. host에서 Harbor `/v2/` timeout
5. `podman push`가 장시간 정지
6. VM lab smoke 재배포 중단

## 현재 판단

이번 회차 blocker는 세 가지가 하나로 묶여 있다.

- Harbor push timeout
- VM SSH timeout
- multipass daemon/dnsmasq 실패

이 셋은 개별 이슈라기보다
원격 lab host의 multipass networking 계층 장애로 보는 편이 맞다.

## 다음 복구 순서

1. `snap.multipass.multipassd`와 관련 네트워크 bridge/dnsmasq 권한 상태 복구
2. `multipass list` 정상화
3. VM SSH `10.113.24.254:22` 복구
4. Harbor `/v2/` reachability 복구
5. image push 재시도
6. VM lab smoke 재검증 재개
