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
- 현재 Harbor project가 private이면 `batch-int-dev` namespace에
  `harbor-regcred` pull secret이 있어야 한다.

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
- mutable tag 예: `:dev`를 재사용할 때
  deployment가 `imagePullPolicy: IfNotPresent`면
  클러스터가 예전 캐시 이미지를 계속 쓸 수 있다.
- 따라서 VM lab 검증에서는 가능하면 unique tag를 쓰는 편이 안전하다.

실제 배포 전 체크:

- 기존 Harbor 운영 규칙 확인
  - 기존 project를 재사용할지
  - `batch-int` 같은 신규 project를 만들지
- push 계정/robot 계정 또는 사용자 계정 확보
- 노드가 해당 Harbor endpoint를 pull 가능한지 확인
- Harbor는 `<project>/<repository>` 형식을 요구하므로 단일 repository 이름은 피한다

## 적용 순서

먼저 pull secret을 준비한다.

원격 호스트의 기존 `podman login` 정보를 그대로 재사용하는 예시:

```bash
ssh seoy@100.123.80.48
sudo scp -i /var/snap/multipass/common/data/multipassd/ssh-keys/id_rsa \
  ~/.config/containers/auth.json ubuntu@10.113.24.254:/home/ubuntu/auth.json
sudo ssh -i /var/snap/multipass/common/data/multipassd/ssh-keys/id_rsa ubuntu@10.113.24.254 '
  sudo kubectl -n batch-int-dev create secret generic harbor-regcred \
    --from-file=.dockerconfigjson=/home/ubuntu/auth.json \
    --type=kubernetes.io/dockerconfigjson \
    --dry-run=client -o yaml | sudo kubectl apply -f -
'
```

그 다음 매니페스트를 적용한다.

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

적용 스크립트 기준 예시:

```bash
cd /opt/go/src/github.com/HeaInSeo/batch-integration
export KUBECONFIG=/etc/kubernetes/admin.conf
REGISTRY_HOST=harbor.10.113.24.96.nip.io \
REGISTRY_PROJECT=batch-int \
IMAGE_TAG=dev \
./scripts/apply-vm-lab-manifests.sh
```

기본 권장 빌드 경로는 `ko`다.

이유:

- `JUMI`, `artifact-handoff` 모두 Go 바이너리 중심 서비스다.
- registry/project 변경 시 `KO_DOCKER_REPO`만 바꾸면 된다.
- 현재 `Dockerfile`/`Containerfile`은 fallback 경로로 유지한다.

`ko` 기준 예시:

```bash
cd /opt/go/src/github.com/HeaInSeo/batch-integration
REGISTRY_HOST=harbor.10.113.24.96.nip.io \
REGISTRY_PROJECT=batch-int \
IMAGE_TAG=dev \
KO_BIN=ko \
./scripts/build-vm-lab-images-ko.sh
```

이미지 push 예시:

```bash
podman login harbor.10.113.24.96.nip.io
podman build -f /opt/go/src/github.com/HeaInSeo/artifact-handoff/Containerfile -t harbor.10.113.24.96.nip.io/batch-int/artifact-handoff:dev /opt/go/src/github.com/HeaInSeo/artifact-handoff
podman build -f /opt/go/src/github.com/HeaInSeo/JUMI/Containerfile -t harbor.10.113.24.96.nip.io/batch-int/jumi:dev /opt/go/src/github.com/HeaInSeo/JUMI
podman push harbor.10.113.24.96.nip.io/batch-int/artifact-handoff:dev
podman push harbor.10.113.24.96.nip.io/batch-int/jumi:dev
```

빌드 스크립트 기준 예시:

```bash
cd /opt/go/src/github.com/HeaInSeo/batch-integration
REGISTRY_HOST=harbor.10.113.24.96.nip.io \
REGISTRY_PROJECT=batch-int \
IMAGE_TAG=dev \
OCI_TOOL=podman \
./scripts/build-vm-lab-images.sh
```

Docker 기준 예시:

```bash
docker login harbor.10.113.24.96.nip.io
docker build -f /opt/go/src/github.com/HeaInSeo/artifact-handoff/Dockerfile -t harbor.10.113.24.96.nip.io/batch-int/artifact-handoff:dev /opt/go/src/github.com/HeaInSeo/artifact-handoff
docker build -f /opt/go/src/github.com/HeaInSeo/JUMI/Dockerfile -t harbor.10.113.24.96.nip.io/batch-int/jumi:dev /opt/go/src/github.com/HeaInSeo/JUMI
docker push harbor.10.113.24.96.nip.io/batch-int/artifact-handoff:dev
docker push harbor.10.113.24.96.nip.io/batch-int/jumi:dev
```

메모:

- 기본 경로는 `ko`
- `podman`/`docker` 경로는 fallback
- 현재 `Containerfile`와 `Dockerfile`은 동일 기준의 최소 빌드 자산이다.
- 추후 `nodekit`, `nodevault` 통합 경로는 별도 단계에서 정리한다.

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

## Live Smoke Eval

VM lab에서 실제 smoke run과 `kube-slint` gate를 한 번에 돌릴 때는 아래 스크립트를 사용한다.

```bash
cd /opt/go/src/github.com/HeaInSeo/batch-integration
bash scripts/run-vm-lab-live-smoke-eval.sh
```

이 스크립트는 다음을 수행한다.

- run 전 `jumi`, `artifact-handoff` metrics 수집
- 원격 smoke run 실행
- run 후 metrics 수집
- live fixture, summary, gate 파일 생성

기본 산출물:

- `deploy/vm-lab/fixtures/kube-slint-jumi-ah-smoke-metrics.live.json`
- `artifacts/vm-lab/jumi-ah-smoke-live-sli-summary.json`
- `artifacts/vm-lab/gate/slint-gate-live-summary.json`

메모:

- replay fixture 정책과 live 환경 정책은 분리했다.
- live 환경에서는 AH retention backlog가 남을 수 있으므로
  `policy/vm-lab/jumi-ah-live-thresholds.yaml`을 기본 사용한다.

## 아직 남은 것

- 기존 Harbor project/권한 정책 확인
- 실제 이미지 빌드/푸시 실행
- JUMI API submit fixture
- kube-slint 수집/summary 경로
- `dev-space` 또는 대체 동기화 워크플로우
