# VM Lab First Deployment Recovery

기준일: `2026-04-22`

## 목적

`100.123.80.48`의 `multipass-k8s-lab` 경로를 통해
`batch-int-dev` namespace에 `artifact-handoff`, `JUMI`를
처음 배포하는 과정에서 발생한 장애와 복구 절차를 기록한다.

이 문서는 원본 일정 문서를 대체하지 않는다.
이번 스프린트의 실제 운영 이슈와 복구 기준점을 남긴다.

## 배포 결과

최종 상태:

- `artifact-handoff` Ready
- `JUMI` Ready
- namespace: `batch-int-dev`
- image registry:
  - `harbor.10.113.24.96.nip.io/batch-int/artifact-handoff:dev`
  - `harbor.10.113.24.96.nip.io/batch-int/jumi:dev`

확인 로그:

- `artifact-handoff resolver listening on :8080`
- `jumi starting http server on :8080`
- `jumi starting grpc server on :9090`

## 장애 증상

초기 배포 직후 두 deployment 모두 `ImagePullBackOff` 상태가 되었다.

대표 이벤트:

- `failed to resolve image`
- `authorization failed: no basic auth credentials`

즉 문제는 이미지 자체가 없거나 네트워크가 끊긴 것이 아니라,
Harbor private project에 대한 pull 인증 정보가
배포 namespace에 연결되지 않은 상태였다.

## 원인

원인은 두 단계였다.

### 1. Harbor pull secret 미연결

이번 스프린트에서 Harbor project `batch-int`를 새로 만들고
그곳에 이미지를 push했다.

하지만 `batch-int-dev` namespace 배포 매니페스트에는:

- `imagePullSecrets` 지정이 없었고
- `artifact-handoff`는 전용 ServiceAccount 없이 `default`를 사용했고
- `jumi` ServiceAccount에도 pull secret이 없었다

따라서 kubelet이 인증 없이 private registry pull을 시도했고 실패했다.

### 2. 원격 VM 매니페스트 경로에 이전 파일이 남아 있었음

초기 수정 후 `kubectl apply -k /home/ubuntu/vm-lab`를 다시 실행했지만
`artifact-handoff` ServiceAccount가 생성되지 않았다.

원인을 확인해 보니:

- 최신 수정본은 원격 호스트의 `/tmp/batch-int-vm-lab`에 복사되어 있었고
- 실제 apply 대상인 VM 내부 `/home/ubuntu/vm-lab`에는 이전 파일이 남아 있었다

즉, 첫 재적용은 최신 매니페스트가 아니라 stale 파일을 보고 있었다.

## 복구 절차

### 1. Harbor auth 재사용으로 pull secret 생성

원격 호스트 `100.123.80.48`에는 이미
`podman login` 정보가 `~/.config/containers/auth.json`에 존재했다.

이 파일을 그대로 이용해 VM cluster에 secret을 만들었다.

개념상 절차:

1. 원격 호스트의 `auth.json`을 VM으로 복사
2. `batch-int-dev` namespace에 `kubernetes.io/dockerconfigjson` secret 생성
3. secret 이름을 `harbor-regcred`로 고정

### 2. 배포 매니페스트 수정

`deploy/vm-lab/` 기준으로 다음을 반영했다.

- `artifact-handoff` 전용 ServiceAccount 추가
- `artifact-handoff` ServiceAccount에 `imagePullSecrets: harbor-regcred` 연결
- `jumi` ServiceAccount에 `imagePullSecrets: harbor-regcred` 연결
- README에 private Harbor 사용 시 pull secret 준비 절차 추가

### 3. VM 내부 stale 매니페스트 덮어쓰기

호스트의 최신 파일을 VM 내부 `/home/ubuntu/vm-lab`에
명시적으로 덮어쓴 뒤 다시 `kubectl apply -k`를 실행했다.

적용 결과:

- `serviceaccount/artifact-handoff created`
- `serviceaccount/jumi configured`
- `deployment.apps/artifact-handoff configured`

### 4. 롤아웃 재시작

이미 생성돼 있던 pod는 이전 pull 설정을 보고 있었으므로
두 deployment를 `rollout restart` 했다.

그 이후:

- `artifact-handoff` 새 pod `Running`
- `JUMI` 새 pod `Running`

## 이번 이슈에서 얻은 운영 기준

- Harbor project가 private이면 첫 배포 자산에 pull secret 절차를 반드시 포함해야 한다.
- namespace 부트스트랩 문서와 실제 매니페스트가 같이 움직여야 한다.
- remote host와 VM 내부에 같은 디렉토리 이름을 둘 경우,
  어느 경로가 apply 대상인지 명시적으로 확인해야 한다.
- `multipass exec`가 불안정한 현재 환경에서는
  direct SSH + explicit file copy가 더 예측 가능하다.

## 일정 영향

이 이슈는 이번 스프린트에서 해결 가능했고,
상위 일정 전체를 미루는 수준의 지연은 만들지 않았다.

다만 다음 항목은 앞으로의 배포 기본 체크리스트에 포함해야 한다.

- registry auth secret 존재 여부
- ServiceAccount 연결 여부
- 실제 apply 대상 경로 확인

## 다음 작업

- `artifact-handoff`와 `JUMI`의 VM lab 상호 호출 경로를 실제 요청으로 검증
- JUMI submit fixture 또는 최소 API 호출로 AH resolve/register/finalize seam 확인
- kube-slint에 VM lab 관찰 결과를 반영할 회귀 기준 연결
