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

아래 이미지는 아직 placeholder다.

- `ghcr.io/heainseo/artifact-handoff:dev`
- `ghcr.io/heainseo/jumi:dev`

실제 배포 전에는 이 태그를 실제 빌드/푸시 결과로 치환해야 한다.

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

- 실제 이미지 빌드/푸시 경로
- JUMI API submit fixture
- kube-slint 수집/summary 경로
- `dev-space` 또는 대체 동기화 워크플로우
