# VM DevSpace Validation Target

기준일: `2026-04-21`

## 목적

사용자가 직접 회귀 여부를 확인할 현실 검증 타깃을 고정한다.
현재 주 개발 트랙은 repo-local test와 local integration을 사용하고,
기능 묶음이 어느 정도 올라오면 아래 VM 경로로 옮겨 검증한다.

## 현재 타깃

- 관리 호스트: `100.123.80.48`
- 표준 랩 운영 저장소: `infra-lab`
- 실제 검증 타깃: `infra-lab`이 관리하는 원격 Kubernetes 랩
- 현재 확인 상태:
  - `100.123.80.48:22` 접속 가능
  - `infra-lab/scripts/k8s-tool.sh status`로 원격 상태 확인 가능
  - 표준 운영 경로는 host profile 기반 `infra-lab` 명령 사용
  - `dev-space`는 아직 존재하지 않는 것으로 전제함

해석:
- `100.123.80.48` 자체를 곧바로 검증 VM으로 취급하면 안 된다.
- 먼저 `infra-lab` 기준 경로로 원격 랩 상태와
  실제 Kubernetes 타깃을 확인해야 한다.
- `dev-space`는 후속 구축 항목이다.

현재 확인된 실제 VM:
- `lab-master-0`
- `lab-worker-0`
- `lab-worker-1`

현재 확인된 Kubernetes 상태:
- 3노드 모두 `Ready`
- control-plane: `lab-master-0`
- `infra-lab`의 `status` 경로로 노드/파드 상태 확인 가능
- `dev-space`는 아직 설치/구축되지 않음

## 언제 이 경로로 넘길지

아래 조건이 맞으면 `vm + dev-space` 검증을 시작한다.

- `artifact-handoff`
  - resolver happy path 안정화
  - finalize/evaluateGC 최소형 안정화
- `JUMI`
  - artifact register seam 반영
  - resolve seam 반영
  - 최소 metrics family 반영
- `kube-slint`
  - JUMI/AH minimum guardrail spec 반영
  - 최소 summary 또는 테스트 출력 경로 반영

즉, 현재 스프린트 기준으로는
`AH + JUMI + kube-slint`의 최소 cross-repo seam이 한 번 더 올라온 뒤
VM 검증으로 넘기는 것이 맞다.

그 시점에 필요한 첫 확인 항목:
- `HOST_PROFILE=hosts/remote-lab.env ./scripts/k8s-tool.sh status`
- 대상 노드와 워크로드 상태 확인
- `infra-lab` 표준 경로로 kubeconfig/cluster 접근 확인

그 다음 구축 항목:
- dev-space 설치 또는 대체 워크플로우 선택
- 소스 동기화/배포 경로 고정
- JUMI/AH/kube-slint 검증 fixture 실행 경로 고정

## 사용자가 VM에서 확인할 항목

1. JUMI run 성공/실패가 의도대로 보이는지
2. AH artifact register / resolve 호출이 최소 경로에서 보이는지
3. JUMI resolve/materialization 메트릭이 기대대로 증가하는지
4. kube-slint summary가 fallback, retention, churn 계열 변화를 잡는지
5. 기능 추가 전후로 같은 fixture를 넣었을 때 회귀가 없는지

## 현재 원칙

- 빠른 개발 루프를 VM 검증으로 대체하지 않는다.
- VM 검증은 milestone 또는 기능 묶음 단위에서 수행한다.
- `100.123.80.48`은 현재 실제 검증 환경으로 사용 가능하다.
- 다만 VM lifecycle과 상태 확인은 `infra-lab` 표준 경로를 우선 사용한다.
- 사용자가 직접 확인 가능한 단계가 되면, 접속 경로와 확인 명령을 별도 정리해 제공한다.
