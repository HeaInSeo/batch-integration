# VM DevSpace Validation Target

기준일: `2026-04-21`

## 목적

사용자가 직접 회귀 여부를 확인할 현실 검증 타깃을 고정한다.
현재 주 개발 트랙은 repo-local test와 local integration을 사용하고,
기능 묶음이 어느 정도 올라오면 아래 VM 경로로 옮겨 검증한다.

## 현재 타깃

- 검증 타깃 VM: `multipass-k8s-vm`
- 확인된 접근 IP: `100.123.80.48`
- 현재 확인 상태:
  - `22/tcp` 접속 가능
  - 로컬 `multipass list`에는 직접 노출되지 않음

해석:
- 이 VM은 현재 로컬 multipass 관리 명령으로 직접 다루기보다,
  원격 접근 가능한 별도 검증 타깃으로 취급하는 편이 안전하다.

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

## 사용자가 VM에서 확인할 항목

1. JUMI run 성공/실패가 의도대로 보이는지
2. AH artifact register / resolve 호출이 최소 경로에서 보이는지
3. kube-slint summary가 fallback, retention, churn 계열 변화를 잡는지
4. 기능 추가 전후로 같은 fixture를 넣었을 때 회귀가 없는지

## 현재 원칙

- 빠른 개발 루프를 VM 검증으로 대체하지 않는다.
- VM 검증은 milestone 또는 기능 묶음 단위에서 수행한다.
- 사용자가 직접 확인 가능한 단계가 되면, 접속 경로와 확인 명령을 별도 정리해 제공한다.
