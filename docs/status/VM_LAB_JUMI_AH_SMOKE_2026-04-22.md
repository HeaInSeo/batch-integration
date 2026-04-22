# VM Lab JUMI to AH Smoke

기준일: `2026-04-22`

## 목적

VM lab에서 `JUMI -> artifact-handoff` seam을
실제 run 제출 경로로 검증하기 위한 최소 자산과 절차를 남긴다.

검증 대상:

- `JUMI` gRPC `SubmitRun`
- producer node 성공 후 `RegisterArtifact`
- consumer node 시작 전 `ResolveBinding`
- run 종료 시 `FinalizeSampleRun`, `EvaluateGC`

## 추가 자산

- fixture:
  - `deploy/vm-lab/fixtures/jumi-handoff-smoke.json`
- gRPC smoke submit 도구:
  - `tools/jumi-smoke/`

## fixture 구성

두 노드 DAG를 사용한다.

- `produce`
  - `busybox:1.36`
  - 성공 후 `report` output을 가진 것으로 간주
- `consume`
  - `produce/report`를 binding으로 참조
  - resolve 결과가 주입한 env를 그대로 출력

핵심은 실제 파일 handoff가 아니라,
이번 스프린트 seam인 `register -> resolve -> finalize -> evaluateGC` 왕복을
최소 형태로 확인하는 것이다.

## 실행 절차

### 1. smoke client 빌드

```bash
cd /opt/go/src/github.com/HeaInSeo/batch-integration/tools/jumi-smoke
go mod tidy
go build -o /tmp/jumi-smoke .
```

### 2. JUMI gRPC 포트 전달

VM 내부 `jumi` service를 `19090`으로 노출한다.

```bash
ssh seoy@100.123.80.48
sudo ssh -i /var/snap/multipass/common/data/multipassd/ssh-keys/id_rsa ubuntu@10.113.24.254 \
  "sudo kubectl -n batch-int-dev port-forward svc/jumi 19090:9090"
```

별도 터미널 또는 세션에서 submit 도구를 실행한다.

### 3. fixture 제출

```bash
/tmp/jumi-smoke \
  -addr 100.123.80.48:19090 \
  -spec /opt/go/src/github.com/HeaInSeo/batch-integration/deploy/vm-lab/fixtures/jumi-handoff-smoke.json
```

참고:

- SSH 터널을 로컬에 잡는 방식이면 `-addr 127.0.0.1:19090`로 바꿔도 된다.
- fixture의 `runId`, `sampleRunId`, `submittedAt`은 필요 시 갱신한다.

## 검증 포인트

- run status가 `Succeeded`인지
- node `produce`, `consume` 모두 `Succeeded`인지
- event에 `node.input_resolved`가 보이는지
- `consume` pod/job 로그에 resolve env가 출력되는지
- JUMI metrics 증가
  - `jumi_artifacts_registered_total`
  - `jumi_input_resolve_requests_total`
  - `jumi_sample_runs_finalized_total`
  - `jumi_gc_evaluate_requests_total`
- AH metrics 증가
  - `ah_artifacts_registered_total`
  - `ah_resolve_requests_total`

## 현재 한계

- 현재 fixture는 실제 artifact materialization을 하지 않는다.
- producer output URI는 `jumi://...` 형태의 logical URI다.
- 따라서 이번 단계는 lifecycle seam smoke 검증이지,
  실제 object storage fetch 검증은 아니다.

## 다음 단계

- 실행 결과를 수집해 별도 status 문서에 기록
- kube-slint minimum guardrail에 이 smoke 결과 기준을 반영
- 이후 VM + dev-space 검증 단계에서 churn 회귀 기준으로 승격
