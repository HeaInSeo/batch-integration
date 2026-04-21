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

## AH 책임

- artifact inventory의 owner
- source locality 판정의 owner
- source priority 최종 판단의 owner
- acquisition contract 응답의 owner

## 구현 메모

- 현재 `artifact-handoff`는 proto 초안과 service 로직을 먼저 두고, 생성 코드 의존성은 후속 단계로 미룬다.
- 현재 실행 경로는 HTTP shim 기반이다.
