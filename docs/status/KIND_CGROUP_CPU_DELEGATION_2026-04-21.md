# Kind Cgroup CPU Delegation Issue (2026-04-21)

## Status

진단 중. 재현은 안정적이며, `batch-int-dev` kind 클러스터 bootstrap이
control-plane 단계에서 멈추는 직접 원인은 확인했다.

## Summary

`rpm` DB 이슈를 복구한 뒤 rootful podman 경로는 정상화되었지만,
`kind create cluster --name batch-int-dev`는 여전히 control-plane bootstrap을 완료하지 못했다.

직접 원인은 kind node 내부 kubelet이 static pod sandbox를 만들 때
cgroup v2의 `cpu.weight` 경로를 열지 못하는 것이다.

관측된 대표 에러:

```text
error setting cgroup config for procHooks process:
openat2 ... /cpu.weight: no such file or directory
```

## Observed Facts

아래 사실을 확인했다.

- rootful `podman info --format json`는 정상 반환
- rootful podman node container `batch-int-dev-control-plane`는 실제로 기동됨
- node 내부 `/sys/fs/cgroup` 파일시스템 타입은 `cgroup2fs`
- node 내부 kubelet은 apiserver/scheduler sandbox 생성 단계에서 실패
- host의 현재 delegation 상태:
  - `/sys/fs/cgroup/cgroup.subtree_control`
    - `cpuset io memory hugetlb pids rdma`
  - `/sys/fs/cgroup/user.slice/cgroup.subtree_control`
    - `cpuset io memory pids`
  - `/sys/fs/cgroup/user.slice/user-1001.slice/cgroup.subtree_control`
    - `cpuset io memory pids`
- 즉, `cpu` 컨트롤러가 실제 위임 목록에서 빠져 있음
- root `cgroup.controllers`에는 `cpu`가 존재하지만, root `subtree_control`에는 반영되지 않음
- host kernel config:
  - `/lib/modules/$(uname -r)/config` -> `CONFIG_RT_GROUP_SCHED=y`
- local systemd documentation:
  - `/usr/share/doc/systemd/README`
  - cgroup v2/systemd 사용 시 `CONFIG_RT_GROUP_SCHED=n` 권장 문구 확인
- `echo +cpu > /sys/fs/cgroup/cgroup.subtree_control` 시도 결과:
  - `write error: Invalid argument`
- `echo +cpu > /sys/fs/cgroup/user.slice/cgroup.subtree_control` 시도 결과:
  - `write error: No such file or directory`
- `echo +cpu > /sys/fs/cgroup/user.slice/user-1001.slice/cgroup.subtree_control` 시도 결과:
  - `write error: No such file or directory`

## Current Interpretation

현재 해석은 다음과 같다.

1. rootful podman/provider 경로 자체는 살아 있음
2. 하지만 kind node 내부 kubelet이 요구하는 CPU cgroup 제어 파일(`cpu.weight`)이
   부모 cgroup 트리에서 정상적으로 준비되지 않음
3. host delegation 계층에서 `cpu`가 빠져 있어 bootstrap에 필요한 하위 cgroup 생성이
   불완전하게 끝나는 것으로 보임
4. 특히 root `subtree_control`에서 `cpu` enable이 `EINVAL`로 실패하므로,
   현재 문제는 단순 user slice 설정 누락보다 더 상위의 host cgroup 제약일 가능성이 큼
5. 현재 가장 유력한 root cause는 Rocky 8.10 / 4.18 기반 호스트 커널이
   `CONFIG_RT_GROUP_SCHED=y`로 빌드되어 있어 `cpu` controller delegation 경로가
   깨지는 점이다

## Failed Workarounds

다음 우회도 시도했지만 해결되지 않았다.

### 1. Rootful Podman `cgroup_manager=systemd`

- 결과:
  - kind node container는 기동
  - kubelet static pod sandbox 생성 실패
  - `cpu.weight` path missing 지속

### 2. Rootful Podman `cgroup_manager=cgroupfs`

- 임시 설정 파일:
  - `scripts/podman-cgroupfs.containers.conf`
- 확인 결과:
  - `podman info`에서 `cgroupManager: cgroupfs` 반영 확인
- 하지만 실제 bootstrap 로그:

```text
WARN Failed to add conmon to cgroupfs sandbox cgroup:
write /sys/fs/cgroup/cgroup.subtree_control: invalid argument
```

- 그리고 kubelet 쪽 `cpu.weight` 관련 실패도 계속 발생

결론:
- `systemd` manager만의 문제가 아니라
  이 호스트의 root cgroup CPU delegation 자체가 현재 막혀 있는 것으로 봐야 한다

### 3. Host Kernel Constraint (`CONFIG_RT_GROUP_SCHED=y`)

로컬에서 직접 확인한 사실:

```text
/lib/modules/$(uname -r)/config
CONFIG_RT_GROUP_SCHED=y
```

그리고 systemd 배포 문서에는 다음 권고가 있다.

- Real-Time group scheduling은 systemd 사용 시 끄는 편이 좋음
- 권장값: `CONFIG_RT_GROUP_SCHED=n`

현재 환경은 정확히 그 반대 설정이며, 실제 증상도 다음과 같이 맞아떨어진다.

- root `cgroup.controllers`에는 `cpu` 존재
- 하지만 root `cgroup.subtree_control`에 `+cpu` 적용 시 `EINVAL`
- user slice 방향으로 `cpu`를 내려보낼 수 없음
- kind node 내부 kubelet은 `cpu.weight` 경로를 만들지 못함

즉, 현재 장애는 단순 스크립트 문제보다 host kernel/cgroup 정책 제약일 가능성이 매우 높다.

## Difference From Previous RPM Incident

이 이슈는 앞선 `rpm` DB incident와 별개다.

- 이전 incident:
  - `podman info` 자체가 멈춤
  - 원인: `/var/lib/rpm/__db.*` stale 상태
- 현재 incident:
  - `podman info`는 정상
  - 원인 후보: host cgroup delegation에서 `cpu` 누락

즉, 현재 kind bootstrap 경로에는 적어도 두 개의 독립 이슈가 있었다.

## Next Actions

다음 순서로 계속 진행한다.

1. host 최상위 및 `user.slice` 계층에서 `cpu` controller availability 확인
2. host-level 해결책 검토:
   - `CONFIG_RT_GROUP_SCHED=n` 커널/호스트 사용
   - Docker 기반 host 또는 다른 dev machine 사용
   - rootful podman 외 다른 런타임 경로 검토
3. 해결 환경에서 `batch-int-dev` kind cluster 재생성
4. kubeconfig 반영 확인
5. `tilt up --host 0.0.0.0 --port 10350` 진입

## Related Docs

- RPM/podman 선행 incident:
  [`KIND_PODMAN_RPM_RECOVERY_2026-04-21.md`](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/status/KIND_PODMAN_RPM_RECOVERY_2026-04-21.md:1)
- 기존 rootless/rootful cgroup troubleshooting 기록:
  `/opt/go/src/github.com/HeaInSeo/hello-operator/docs/TROUBLESHOOTING_STEP1.md`
