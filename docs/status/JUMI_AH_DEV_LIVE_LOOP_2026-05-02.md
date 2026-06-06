# JUMI AH Dev Live Loop 2026-05-02

목적:
- `infra-lab` shared VM의 `jumi-ah-dev` namespace를 기준으로
  `JUMI -> artifact-handoff -> kube-slint -> SF Observability` 관찰 루프를
  반복 가능한 운영 경로로 고정한다.

핵심 변경:
- 기존 `scripts/run-vm-lab-live-smoke-eval.sh`는
  `batch-int-dev`와 중간 VM hop에 기대고 있었다.
- 새 `scripts/run-jumi-ah-dev-live-smoke-eval.sh`는
  `seoy@100.123.80.48`의 `infra-lab` kubeconfig를 직접 사용한다.
- 실행 namespace는 기본값 `jumi-ah-dev`다.
- 결과물은 기존 `artifacts/vm-lab/` 경로를 그대로 사용해
  `shift-left-observability` publish 경로를 유지한다.

동작 순서:
1. 원격 `jumi`와 `artifact-handoff` rollout 상태를 확인한다.
2. `deploy/vm-lab/fixtures/jumi-handoff-smoke.json`을 원격 임시 디렉토리로 복사한다.
3. 원격에서 `tools/jumi-smoke`를 빌드한다.
4. `scripts/vm-lab-jumi-smoke-remote.sh`를 `jumi-ah-dev` 설정으로 호출한다.
5. `jumi`/`artifact-handoff` 메트릭 전후값을 수집해 live fixture를 갱신한다.
6. `kube-slint` summary와 gate를 생성한다.
7. `PUBLISH_SHIFT_LEFT_OBSERVABILITY=true`면 `SF Observability`까지 다시 publish한다.

기본 실행:

```bash
bash scripts/run-jumi-ah-dev-live-smoke-eval.sh
```

관찰면까지 같이 갱신:

```bash
PUBLISH_SHIFT_LEFT_OBSERVABILITY=true bash scripts/run-jumi-ah-dev-live-smoke-eval.sh
```

기본 출력:
- fixture:
  `deploy/vm-lab/fixtures/kube-slint-jumi-ah-smoke-metrics.live.json`
- summary:
  `artifacts/vm-lab/jumi-ah-smoke-live-sli-summary.json`
- gate:
  `artifacts/vm-lab/gate/slint-gate-live-summary.json`

운영 의미:
- 다음 스프린트의 표준 루프는 더 이상 관찰면 접근성 자체가 아니다.
- 표준 루프는 `jumi-ah-dev`에서 live smoke를 돌리고,
  그 결과를 `SF Observability`에 반영해 회귀를 읽는 것이다.
