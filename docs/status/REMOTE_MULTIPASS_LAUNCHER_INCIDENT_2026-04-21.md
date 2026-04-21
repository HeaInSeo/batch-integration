# Remote Multipass Launcher Incident

기준일: `2026-04-21`

## 대상

- 관리 호스트: `100.123.80.48`
- 사용자: `seoy`
- 의도된 관리 영역: `multipass-k8s-lab`

## 증상

원격 호스트에 SSH 접속은 가능하지만 `multipass list`가 바로 실패했다.

대표 오류:

```text
cannot find mount entry for snap core22 revision /var/lib/snapd/snap/core22/2411
```

## 확인 결과

원격에서 확인된 상태:

- `hostname`: `localhost.localdomain`
- `systemctl is-active snapd`: `active`
- `mount` 기준 `core22_2411.snap` 마운트는 존재
- `snap list multipass` 결과:
  - `multipass 1.16.1`
- 실행 경로:
  - `command -v multipass` -> `/usr/local/bin/multipass`

`/usr/local/bin/multipass` 내용:

```bash
#!/bin/bash
# multipass CLI wrapper: snap namespace가 stale해지는 문제 우회
# snap-discard-ns로 매번 fresh namespace 생성
/usr/libexec/snapd/snap-discard-ns multipass 2>/dev/null
exec /usr/bin/snap run multipass "$@"
```

추가 관찰:

- `/usr/local/bin/multipass`는 실제 바이너리가 아니라 셸 래퍼다.
- `/snap/bin/multipass` 표준 경로는 존재하지 않았다.
- `snap run multipass ...`도 동일한 `core22` mount entry 오류로 실패했다.

## 판단

현재 문제는 단순히 `dev-space`가 없는 수준이 아니다.

실제 블로커는 다음 순서다:

1. 원격 `multipass` 실행 경로가 비표준 래퍼에 의존한다.
2. 이 래퍼는 `snap-discard-ns multipass` 후 `snap run multipass`를 강제한다.
3. 현재 호스트의 snap namespace/mount 상태와 이 래퍼 동작이 충돌하면서
   `core22` mount entry 오류가 발생한다.
4. 따라서 `multipass-k8s-lab` 내부 VM 목록조차 아직 확인할 수 없다.

즉, `vm + dev-space` 스프린트에 들어가기 전에
원격 `multipass` launcher 복구가 선행되어야 한다.

## 현재 영향

- user 기준 `multipass` CLI는 여전히 불안정
- 그러나 root 기준 표준 CLI 경로로는 상태 확인이 가능해졌다
- 확인된 VM:
  - `lab-master-0`
  - `lab-worker-0`
  - `lab-worker-1`
- `lab-master-0` 내부 k8s 3노드 클러스터 `Ready` 확인
- kubeconfig 위치 확인:
  - `/etc/kubernetes/admin.conf`
- `dev-space` 신규 구축은 아직 시작 전

## 권장 복구 방향

우선순위는 아래 순서가 맞다.

1. `/usr/local/bin/multipass` 래퍼 의존 제거
2. root/user 모두에서 표준 CLI 안정화
3. `multipass list`가 세션 간 일관되게 동작하는지 확인
4. 이후 `multipass-k8s-lab` 내부 VM과 k8s 경로를 지속적으로 사용
5. 그 다음 dev-space 설치 또는 대체 워크플로우 선정

## 스프린트 해석

이 이슈 때문에 현재 스프린트 운영 원칙은 더 분명해진다.

- 주 개발 트랙:
  - `artifact-handoff`
  - `JUMI`
  - `kube-slint`
- 환경 트랙:
  - 원격 `multipass` launcher 복구
  - k8s VM 식별
  - dev-space 신규 구축

즉, 환경 트랙은 여전히 병행 구축 대상이고
주 개발 트랙의 즉시 블로커로 승격시키면 안 된다.
