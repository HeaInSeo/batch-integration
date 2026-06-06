# JUMI-AH Contract v0.1

상태: 초안

기준일: `2026-04-21`

## 목적

`JUMI`와 `artifact-handoff`가 첫 수직 통합에 필요한 최소 contract를 공유하기 위한 문서다.

## 범위

이 버전은 happy-path 중심이다.

- artifact 등록
- handoff 해석
- node terminal 통지

다음 항목은 타입/이름만 고정하고 의미론은 후속 단계에서 확장한다.

- sample run finalize
- GC evaluate

## RPC 초안

원본 proto:
- [`artifact-handoff/api/proto/ah_v1.proto`](/opt/go/src/github.com/HeaInSeo/artifact-handoff/api/proto/ah_v1.proto:1)

### RegisterArtifact

입력 핵심:
- `sample_run_id`
- `producer_node_id`
- `output_name`
- `artifact_id` optional
- `digest` optional
- `size_bytes` optional
- `node_name` optional
- `uri` optional

출력 핵심:
- `availability_state`

### ResolveHandoff

입력 핵심:
- `binding_name`
- `sample_run_id`
- `child_node_id`
- `child_input_name`
- `producer_node_id`
- `producer_output_name`
- `consume_policy`
- `required`
- `expected_digest` optional
- `target_node_name`

출력 핵심:
- `resolution_status`
- `decision`
- `source_node_name`
- `artifact_uri`
- `requires_materialization`

### NotifyNodeTerminal

입력 핵심:
- `sample_run_id`
- `node_id`
- `terminal_state`

출력 핵심:
- `accepted`

## 초기 의미론

### ResolveHandoff decision

- `local_reuse`: target node와 artifact node가 같을 때
- `remote_fetch`: artifact는 존재하지만 다른 node에 있을 때
- `unavailable`: 필수 artifact가 없거나 same-node only 조건을 만족하지 못할 때

### Resolution status

- `RESOLVED`
- `PENDING`
- `MISSING`

## JUMI 책임

- binding 목록의 owner
- child submit timing의 owner
- sample run 문맥의 owner
- AH 응답을 실행 경로에 반영하는 owner
- producer output 메타데이터 export의 owner
  - `digest`, `size_bytes`, `uri`를 생산/수집해서 `RegisterArtifact`로 넘기는 쪽은 `JUMI` runtime 책임이다.
  - 단, 이 메타데이터의 임시 export 매체는 제품 중심 계약이 아니라 runtime shim으로 취급한다.

## AH 책임

- artifact inventory의 owner
- source locality 판정의 owner
- source priority 최종 판단의 owner
- acquisition contract 응답의 owner
- artifact 상태 ledger의 owner
  - `artifact-handoff`는 bytes 저장소가 아니라 inventory/ledger다.
  - source-of-truth는 `AH inventory`이며, producer pod 내부의 임시 파일은 source-of-truth가 아니다.

## Locator 와 Inventory 의미론

- `manifest` 파일은 source-of-truth가 아니다.
  - producer runtime이 종료 직후 output 메타데이터를 export하는 임시 shim이다.
  - drift와 파편화를 막기 위해 사용자 workload가 제각각 쓰는 계약으로 두지 않는다.
- `AH inventory`가 단일 source-of-truth다.
  - `RegisterArtifact` 이후에는 `artifact_id`, `digest`, `size_bytes`, `node_name`, `uri`, lifecycle 상태를 `AH` 기준으로 본다.
- `uri`는 영구 위치가 아니라 locator다.
  - 특히 `jumi://...` 같은 값은 run-scope locator로 취급한다.
  - local path/PVC path/pod path는 retention과 cleanup에 따라 한시적일 수 있다.
- child는 파일 경로 하나를 신뢰하는 것이 아니라, `AH.ResolveHandoff`가 돌려주는 현재 유효한 acquisition 방법을 따른다.

## 구현 메모

- 현재 `artifact-handoff`는 proto 초안과 service 로직을 먼저 두고, 생성 코드 의존성은 후속 단계로 미룬다.
- 현재 실행 경로는 HTTP shim 기반이다.
