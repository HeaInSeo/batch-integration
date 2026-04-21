# VM Lab Deployment

대상 환경:
- 호스트: `100.123.80.48`
- multipass VM: `lab-master-0`
- kubeconfig: `/etc/kubernetes/admin.conf`

목적:
- `artifact-handoff`와 `JUMI`를 VM lab Kubernetes 위에 최소 형태로 올려
  HTTP/metrics/lifecycle seam을 확인한다.

현재 전제:
- `dev-space`는 아직 없다.
- `multipass` user CLI는 불안정하다.
- 따라서 원격 호스트에서 root 기준 CLI로 `lab-master-0`에 접근하는 운영이 필요할 수 있다.

## 구성

- namespace: `batch-int-dev`
- `artifact-handoff`
  - Deployment 1 replica
  - Service `artifact-handoff`
  - port `8080`
- `jumi`
  - Deployment 1 replica
  - Service `jumi`
  - HTTP `8080`, gRPC `9090`
  - `JUMI_AH_URL=http://artifact-handoff.batch-int-dev.svc.cluster.local:8080`
  - `JUMI_NAMESPACE=batch-int-dev`
  - `JUMI_KUBECONFIG` 비워 둠
    - spawner는 빈 kubeconfig에서 in-cluster config를 먼저 시도한다.

## 필요한 이미지

현재 Harbor endpoint:

- `http://harbor.10.113.24.96.nip.io`

현재 클러스터에서 확인한 기존 사용 예:

- `harbor.10.113.24.96.nip.io/nodeforge/controlplane:latest`

즉 현재 관행은 대략 아래 형태다.

- `<harbor-host>/<project>/<component>:<tag>`

임시 예시 project:

- `batch-int`

기본 예시 이미지:

- `harbor.10.113.24.96.nip.io/batch-int/artifact-handoff:dev`
- `harbor.10.113.24.96.nip.io/batch-int/jumi:dev`

중요:

- Harbor endpoint, project, tag는 개발 중이라 추후 변경될 수 있다.
- 따라서 매니페스트 본문에는 고정 주소를 직접 박지 않고,
  `kustomization.yaml`의 `images:` override를 통해 바꾸도록 구성했다.
- 즉, 향후 Harbor 주소가 바뀌거나 GHCR 등 다른 registry로 전환돼도
  `deploy/vm-lab/kustomization.yaml`만 바꾸면 된다.

실제 배포 전 체크:

- 기존 Harbor 운영 규칙 확인
  - 기존 project를 재사용할지
  - `batch-int` 같은 신규 project를 만들지
- push 계정/robot 계정 또는 사용자 계정 확보
- 노드가 해당 Harbor endpoint를 pull 가능한지 확인
- Harbor는 `<project>/<repository>` 형식을 요구하므로 단일 repository 이름은 피한다

## 적용 순서

원격 호스트에서:

```bash
ssh seoy@100.123.80.48
sudo systemctl restart snapd
sudo /usr/libexec/snapd/snap-discard-ns multipass || true
sudo /usr/libexec/snapd/snap-update-ns multipass || true
sudo /usr/bin/snap run multipass exec lab-master-0 -- bash -lc '
  export KUBECONFIG=/etc/kubernetes/admin.conf
  kubectl apply -k /path/to/batch-integration/deploy/vm-lab
'
```

이미지 push 예시:

```bash
podman login harbor.10.113.24.96.nip.io
podman build -f /opt/go/src/github.com/HeaInSeo/artifact-handoff/Containerfile -t harbor.10.113.24.96.nip.io/batch-int/artifact-handoff:dev /opt/go/src/github.com/HeaInSeo/artifact-handoff
podman build -f /opt/go/src/github.com/HeaInSeo/JUMI/Containerfile -t harbor.10.113.24.96.nip.io/batch-int/jumi:dev /opt/go/src/github.com/HeaInSeo/JUMI
podman push harbor.10.113.24.96.nip.io/batch-int/artifact-handoff:dev
podman push harbor.10.113.24.96.nip.io/batch-int/jumi:dev
```

registry가 바뀌는 경우:

```bash
sed -n '1,120p' deploy/vm-lab/kustomization.yaml
```

여기서 `images:` 항목만 현재 registry 기준으로 바꾸면 된다.

## 1차 확인 항목

```bash
kubectl -n batch-int-dev get deploy,pod,svc
kubectl -n batch-int-dev get sa,role,rolebinding
kubectl -n batch-int-dev logs deploy/artifact-handoff
kubectl -n batch-int-dev logs deploy/jumi
kubectl -n batch-int-dev port-forward deploy/artifact-handoff 18080:8080
kubectl -n batch-int-dev port-forward deploy/jumi 18081:8080 19090:9090
```

확인 포인트:
- `/healthz`
- `/metrics`
- JUMI가 in-cluster config로 Job 생성 권한을 가지는지
- JUMI가 AH HTTP 경로에 도달하는지

## 아직 남은 것

- 기존 Harbor project/권한 정책 확인
- 실제 이미지 빌드/푸시 경로
- JUMI API submit fixture
- kube-slint 수집/summary 경로
- `dev-space` 또는 대체 동기화 워크플로우
