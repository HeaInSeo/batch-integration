# Runtime Helper Workload Image Strategy 2026-05-03

기준일:
- `2026-05-03`

목적:
- `JUMI`의 output metadata export 경로를 `wrapped-shell`에서 제품형에 더 가까운 `runtime helper`로 옮기는 이유와 방식을 정리한다.
- `artifact-handoff`의 inventory/ledger 모델과 producer-side helper의 책임을 분리해서 적는다.
- 왜 지금 스프린트에서는 `spawner` generic delivery surface 확장보다 `workload image 포함 전략`을 먼저 선택했는지 남긴다.

## 한 줄 결론

- `runtime helper`는 pod 안에서 사용자 command를 실행한 뒤 output metadata를 수집하는 짧은 in-container 프로세스다.
- `artifact-handoff`는 그 메타데이터를 inventory에 등록하고 child handoff 결정을 내리는 서비스다.
- 이번 스프린트에서는 helper를 job에 전달하는 일반화된 `spawner` 주입 경로를 새로 만들지 않고, helper가 이미 들어 있는 workload image를 쓰는 전략을 먼저 택한다.

## 문제 배경

초기 구현은 producer node에 opt-in `wrapped-shell` wrapper를 붙여 아래 일을 했다.

- 원래 workload command 실행
- `/out/_meta/artifacts.manifest.json` 생성
- `digest`, `sizeBytes`, `uri` 기록
- termination message에 manifest 요약 기록

이 방식은 live smoke를 빨리 닫는 데는 적합했지만, 다음 한계가 분명했다.

- `/bin/sh`, `wc`, `sha256sum` 존재를 가정한다.
- quoting/escaping이 복잡한 command에 취약할 수 있다.
- typed validation이나 manifest 형식 일관성을 shell 수준에서 관리해야 한다.
- 장기적으로는 runtime contract를 shell snippet에 묶어 둔다.

그래서 shell wrapper가 하던 일을 작은 Go 바이너리로 이동하는 것이 다음 단계가 됐다.

## Helper 와 AH 의 차이

둘은 역할이 다르다.

- `runtime helper`
  - producer pod 안에서 동작
  - 실제 output 파일을 직접 본다
  - `digest`, `sizeBytes`, output 존재 여부 같은 사실을 수집한다
  - manifest와 termination message를 만든다
- `artifact-handoff`
  - pod 밖 서비스로 동작
  - bytes를 저장하지 않는다
  - `RegisterArtifact`로 들어온 metadata를 inventory에 적재한다
  - child가 same-node 재사용을 할지, remote fetch를 할지, producer failure로 볼지 판단한다

쉽게 말하면:

- helper는 현장에서 송장을 쓰는 쪽이다.
- `AH`는 창고 관리 시스템이다.

## Source Of Truth

이 설계에서 가장 중요한 기준은 아래 두 가지다.

- producer pod 내부 manifest는 source-of-truth가 아니다.
  - 이것은 runtime export shim이다.
- source-of-truth는 `AH inventory`다.
  - `RegisterArtifact` 이후에는 `artifact_id`, `digest`, `size_bytes`, `uri`, lifecycle 상태를 `AH` 기준으로 본다.

즉 manifest 파일을 오래 보존하거나 child가 직접 읽는 모델로 가지 않는다.

흐름은 이렇게 본다.

1. producer runtime helper가 output metadata를 export
2. `JUMI`가 metadata를 읽음
3. `JUMI`가 `RegisterArtifact` 호출
4. `AH inventory`가 ledger를 보유
5. child는 manifest 파일이 아니라 `ResolveHandoff` 응답을 소비

관련 계약:
- [JUMI_AH_CONTRACT_v0.1.md](/opt/go/src/github.com/HeaInSeo/batch-integration/docs/contracts/JUMI_AH_CONTRACT_v0.1.md:1)

## Runtime Helper 동작 모델

helper는 pod 종료 후에 따로 뜨는 daemon이 아니다.

정확한 흐름:

1. helper 프로세스가 컨테이너 안에서 시작
2. helper가 사용자 command를 child process로 실행
3. 사용자 command가 종료
4. helper가 `/out` 아래 output을 검사
5. manifest와 termination message를 기록
6. helper가 사용자 command와 같은 exit code로 종료
7. 그 다음 컨테이너와 pod가 종료

즉 수집 시점은 `pod 종료 후`가 아니라 `종료 직전`이다.

현재 helper 구현 위치:
- helper package:
  [pkg/runtimehelper/helper.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/runtimehelper/helper.go:1)
- helper CLI:
  [cmd/jumi-output-helper/main.go](/opt/go/src/github.com/HeaInSeo/JUMI/cmd/jumi-output-helper/main.go:1)

현재 helper가 하는 일:

- 사용자 command 실행
- `/out/<outputName>` regular file 확인
- `sha256` digest 계산
- `sizeBytes` 계산
- `jumi://runs/<run>/nodes/<node>/outputs/<output>` URI 생성
- manifest JSON 작성
- `/dev/termination-log`에 요약 JSON 기록

## JUMI Backend Wiring

`JUMI` backend adapter는 output-producing node에 공통 env contract를 주입한다.

대표 env:

- `JUMI_OUTPUT_MANIFEST_ENABLED=true`
- `JUMI_OUTPUT_MANIFEST_PATH=/out/_meta/artifacts.manifest.json`
- `JUMI_OUTPUT_NAMES`
- `JUMI_RUN_ID`
- `JUMI_NODE_ID`
- `JUMI_SAMPLE_RUN_ID`

관련 코드:
- [spawner_k8s.go](/opt/go/src/github.com/HeaInSeo/JUMI/pkg/backend/spawner_k8s.go:1)

현재 output manifest mode는 두 개다.

- `wrapped-shell`
  - 기존 shell wrapper 경로
- `runtime-helper`
  - `/usr/local/bin/jumi-output-helper`를 entry command로 세우고,
    원래 workload command를 helper 인자로 넘기는 경로

즉 `runtime-helper` mode에서는 컨테이너 command가 개념적으로 이렇게 된다.

```text
/usr/local/bin/jumi-output-helper -- <original user command...>
```

## 왜 Spawner 확장 대신 Workload Image 포함 전략인가

지금 시점의 `spawner`는 다음 수준에 머물러 있다.

- single-container Job
- PVC mount
- 기본 command/env wiring

반면 현재 없는 것:

- init container 기반 helper 주입
- sidecar 기반 helper delivery
- projected volume 기반 helper binary delivery
- helper image/source 선택 정책

즉 `spawner` generic delivery surface를 이번 스프린트에 열려면 범위가 커진다.

- `RunSpec` 확장
- renderer 확장
- volume/mount 전략 설계
- helper image/source 관리
- backward compatibility 점검

이번 스프린트 목표는 generic delivery platform을 여는 것이 아니라
`runtime helper`를 실제 live 경로에 올려 provenance export를 typed code로 바꾸는 것이다.

그래서 먼저 아래 전략을 택한다.

- helper binary가 이미 들어 있는 workload image를 사용
- `JUMI`는 `runtime-helper` mode에서 command wiring만 바꾼다
- generic `spawner` helper delivery는 후속 스프린트로 미룬다

쉽게 말하면:

- `spawner` 확장은 공구 배송 체계를 새로 만드는 일이다.
- workload image 포함 전략은 작업자가 공구를 들고 현장에 들어가게 하는 일이다.

현재 스프린트에서는 후자가 더 짧고 확실하다.

## 현재 적용 경로

helper는 `JUMI` image build에 이미 포함돼 있다.

- [Containerfile](/opt/go/src/github.com/HeaInSeo/JUMI/Containerfile:1)

여기서는 아래 바이너리를 함께 만든다.

- `/usr/local/bin/jumi`
- `/usr/local/bin/jumi-output-helper`

현재 `jumi-ah-dev` smoke fixture의 producer node는
helper가 포함된 이미지를 사용하도록 바꿨다.

- fixture:
  [jumi-handoff-smoke.json](/opt/go/src/github.com/HeaInSeo/batch-integration/deploy/vm-lab/fixtures/jumi-handoff-smoke.json:1)

현재 producer 예시:

- image:
  `harbor.10.113.24.96.nip.io/batch-int/jumi:manifest-20260503-verify3`
- metadata:
  `jumi.outputManifestMode=runtime-helper`

즉 smoke는 더 이상 helper 전달용 별도 volume이나 init container에 기대지 않는다.

## Manifest 와 Termination Message

현재 helper는 두 곳에 metadata를 남긴다.

- 전체 manifest:
  `/out/_meta/artifacts.manifest.json`
- 작은 요약:
  `/dev/termination-log`

`JUMI` backend는 완료된 pod에서 먼저 termination message를 읽고,
거기 값이 없을 때만 pod exec fallback으로 manifest 파일을 읽는다.

이 순서를 둔 이유:

- 완료된 pod에서 exec readback이 항상 안정적이지 않았다
- termination message는 완료 후에도 K8s status에서 읽기 쉽다

다만 termination message는 큰 payload 운반용 채널이 아니다.

- output 수가 많아지면 JSON이 커질 수 있다
- payload가 커지면 다음 채널이 필요할 수 있다
  - manifest file 직접 readback
  - volume/object store locator
  - 더 큰 control-plane surface

즉 termination message는 작은 manifest fast-path로만 본다.

## 한계와 리스크

1. helper가 들어 있는 workload image가 필요하다.
- 지금은 smoke/dev 경로에는 적용 가능하지만,
  다양한 사용자 분석 이미지를 모두 동일하게 다루려면 추가 전략이 필요하다.

2. helper는 아직 generic spawner delivery surface를 대체하지 않는다.
- 현재 결정은 스프린트 범위를 줄이기 위한 우선순위 결정이다.
- 장기적으로는 image 포함 전략만으로 모든 workload class를 덮기 어려울 수 있다.

3. termination message는 크기 한계가 있다.
- 현재 smoke처럼 소수 output에는 적합하다.
- 대량 output provenance에는 다른 수집 채널이 필요해질 수 있다.

4. `AH inventory`는 아직 durable backend가 아니다.
- manifest/source-of-truth 분리는 맞지만,
  현재 inventory 구현은 in-memory 중심이라 durability는 후속 과제다.

## 다음 단계

1. `runtime-helper` workload image 경로를 live smoke에서 안정적으로 재검증
2. helper 기반 producer metadata가 `AH inventory`에 계속 `digest/sizeBytes`로 등록되는지 증적 유지
3. shell wrapper를 점진적으로 dev/test fallback으로 내리기
4. 필요 시 `spawner` generic helper delivery surface를 별도 스프린트로 설계
5. durable inventory와 retention/GC actuation을 다음 스프린트 본선으로 연결

## 판단

- 지금 결정은 최종 아키텍처를 영구 확정한 것이 아니다.
- 다만 이번 스프린트 범위에서 보면 `workload image 포함 전략`이 가장 작고 안전하게 `runtime helper`를 실증할 수 있는 경로다.
- generic `spawner` delivery surface는 가치가 있지만, 지금 당장 먼저 열 과제는 아니다.
