#!/usr/bin/env bash
# worker_write_guard.sh — claude-main 워커의 쓰기를 툴 레벨에서 차단하는 PreToolUse 훅.
#
# 왜: CLAUDE.md "Worker 파일 쓰기 정책" 표는 claude-main 기본 쓰기 권한 = "❌ Orchestrator 경유"로
#     규정하지만, 이는 지금까지 agent 본문의 산문 지시였을 뿐이고 `tools: '*'` + bypassPermissions
#     하에서 아무 저항 없이 위반 가능했다(KNOWN_ISSUES KI-2).
#
# 설계 근거 (tasks/multiagent-v2-build/, codex-critic 3지적 반영):
#   1. Bash 우회 커버 — Write/Edit만 막으면 `sed -i`·리다이렉션으로 새어나간다. Bash도 검사한다.
#   2. disallowedTools 미사용 — 도구를 지우면 claude-main의 "메인 코딩" 역할(routing.md)이 축소되고
#      테스트·빌드 같은 read-only Bash까지 죽는다. 훅은 *쓰기 행위*만 막고 도구는 남긴다.
#   3. 권위 데이터 — claude-main의 write_scope는 task와 무관하게 항상 none(CLAUDE.md 표)이므로
#      per-task scope 파일이 필요없다. 이 훅은 claude-main 전용이며, agent frontmatter에 붙어
#      워커 호출에만 적용된다(orchestrator 세션엔 미적용 — 실측 확인 2026-07-17).
#
# 실측 근거: PreToolUse의 permissionDecision:"deny"는 bypassPermissions를 이긴다(2026-07-17 probe).
#            PreToolUse 입력엔 agent_type이 없다 → agent frontmatter 부착으로 스코프를 얻는다.
#
# 한계 (정직하게): Bash 쓰기 탐지는 휴리스틱이다. 난독화된 쓰기(eval·base64·python -c 등)는
#            잡지 못한다. 이 훅은 *사고 방지*이지 *적대적 샌드박스*가 아니다. 진짜 격리가 필요하면
#            codex-main처럼 sandbox 백엔드를 쓸 것.

set -uo pipefail

input="$(cat)"

tool="$(printf '%s' "$input" | jq -r '.tool_name // ""')"

deny() {
  jq -nc --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}
allow() { printf '{}\n'; exit 0; }

case "$tool" in
  Write|Edit|NotebookEdit)
    deny "claude-main은 파일을 직접 쓰지 않는다(CLAUDE.md Worker 파일 쓰기 정책: write_scope=none, Orchestrator 경유). 변경은 diff/전체 내용을 텍스트로 반환하라 — Orchestrator가 적용한다."
    ;;
  Bash)
    cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""')"

    # 쓰기 의도 휴리스틱. 오탐(과차단)보다 미탐을 택한 지점은 주석으로 남긴다.
    #  - `>` / `>>`: 리다이렉션. 단 `2>&1`·`>/dev/null`·`2>/dev/null`은 쓰기가 아니므로 먼저 제거.
    #  - in-place 편집·복사·이동·삭제·생성 계열 명령
    probe="$(printf '%s' "$cmd" \
      | sed -e 's/[0-9]*>&[0-9]*//g' \
            -e 's#[0-9]*>>*[[:space:]]*/dev/null##g')"

    if printf '%s' "$probe" | grep -qE '>>?[[:space:]]*[^&|[:space:]]'; then
      deny "claude-main의 셸 리다이렉션 쓰기가 차단됐다(write_scope=none). 산출물은 텍스트로 반환하라 — Orchestrator가 파일로 남긴다."
    fi

    if printf '%s' "$probe" | grep -qE '(^|[;&|[:space:]])(sed[[:space:]]+[^;|&]*-i|perl[[:space:]]+[^;|&]*-i|tee([[:space:]]|$)|dd([[:space:]]|$)|truncate([[:space:]]|$))'; then
      deny "claude-main의 in-place 편집(sed -i / perl -i / tee 등)이 차단됐다(write_scope=none). 변경은 diff로 반환하라."
    fi

    if printf '%s' "$probe" | grep -qE '(^|[;&|[:space:]])(rm|mv|cp|mkdir|rmdir|touch|chmod|chown|ln|install)([[:space:]]|$)'; then
      deny "claude-main의 파일시스템 변경 명령이 차단됐다(write_scope=none). 필요하면 무엇을 왜 해야 하는지 result에 적어라 — Orchestrator가 수행한다."
    fi

    if printf '%s' "$probe" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+(add|commit|push|checkout|switch|reset|clean|rebase|merge|stash|rm|mv|apply|restore)([[:space:]]|$)'; then
      deny "claude-main의 git 상태 변경이 차단됐다(write_scope=none). 커밋·브랜치는 Orchestrator 소관이다. 읽기(git log/diff/show/status)는 허용된다."
    fi

    allow
    ;;
  *)
    allow
    ;;
esac
