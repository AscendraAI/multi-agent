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
# 한계 (정직하게 — 과장 금지):
#   이 훅은 **직접 쓰기**를 막는다. 다음은 못 막는다:
#   - **허용 명령의 간접 쓰기**: `pnpm test`·`npx tsc --incremental`·`pytest`는 캐시·coverage·
#     snapshot·증분빌드 산출물을 쓴다. 허용해야 워커가 검증을 할 수 있으므로 의도적으로 남긴 구멍이다.
#   - **allowlist 안 도구의 창의적 오용**: 예컨대 `git`·`jq`·`awk`의 미열거 쓰기 서브커맨드.
#   ⇒ 따라서 이것은 `write_scope=none`의 **완전한 기계적 강제가 아니라 부분 완화**다.
#      "사고·표류 방지"이지 **적대적 샌드박스가 아니다**. 적대적 워커를 가정하지 말 것.
#      진짜 격리가 필요하면 codex-main처럼 sandbox 백엔드(프로세스 레벨)를 쓸 것.
#   실측 이력: 초판은 denylist였고 python3 -c / node -e / `>|` / /usr/bin/touch / eval+base64 /
#   curl -o / rsync 를 전부 통과시켰다(codex-critic 2026-07-17). allowlist로 뒤집어 전부 차단했으나,
#   위 두 구멍은 설계상 남는다.

set -uo pipefail

# ── fail-closed (반드시 다른 무엇보다 먼저) ──
# PreToolUse에서 **exit 2 = 차단**, 그 외 non-zero = *비차단* 에러(툴이 그냥 진행)다.
# 즉 이 훅이 크래시하면 가드가 **없는 것과 같아진다** — 안전장치가 자기 버그로 사라지는 최악.
# 실측(2026-07-17): ROOT unbound로 죽자 명령이 검사 없이 통과했다. ERR 트랩은 `set -u`
# 위반을 못 잡았고, 트랩을 대입문 뒤에 걸어 그 이전 크래시도 놓쳤다.
# ⇒ EXIT 트랩으로 "판정을 못 냈으면 차단"을 강제한다. 트랩은 스크립트 **최상단**에 건다.
_decided=0
_fail_closed() {
  [ "$_decided" -eq 1 ] && return
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"worker_write_guard 내부 오류 — 판정을 내지 못해 안전을 위해 차단한다. Orchestrator가 가드를 점검할 것."}}\n'
  exit 2
}
trap _fail_closed EXIT

deny() {
  _decided=1
  jq -nc --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}
allow() { _decided=1; printf '{}\n'; exit 0; }

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

input="$(cat)"

# 의존성·입력을 못 믿으면 판정할 수 없다 → 차단. (실측 2026-07-17: jq가 없으면
# tool이 빈 문자열이 되고 `*)` 분기로 떨어져 **allow** — 가드가 조용히 무력화됐다.)
command -v jq >/dev/null 2>&1 || deny "worker_write_guard: jq 없음 — 판정 불가라 차단한다."

tool="$(printf '%s' "$input" | jq -r '.tool_name // ""')"
[ -n "$tool" ] || deny "worker_write_guard: tool_name을 읽지 못했다 — 판정 불가라 차단한다."

case "$tool" in
  Write|Edit|NotebookEdit)
    deny "claude-main은 파일을 직접 쓰지 않는다(CLAUDE.md Worker 파일 쓰기 정책: write_scope=none, Orchestrator 경유). 변경은 diff/전체 내용을 텍스트로 반환하라 — Orchestrator가 적용한다."
    ;;
  Bash)
    cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""')"

    # ── allowlist ──
    # denylist는 원리적으로 진다. 실측(2026-07-17, codex-critic)에서 초판 denylist는
    #   python3 -c open(w) / node -e writeFileSync / echo >| f / /usr/bin/touch /
    #   eval "$(base64 -d)" / curl -o / rsync … 를 전부 통과시켰다.
    # ⇒ 실패 모드를 뒤집는다: 아는 것만 허용하고 나머지는 막는다.
    #   과차단은 복구 가능하다(워커가 result에 적고 Orchestrator가 실행 — 기존 계약 그대로).
    #   미탐은 조용히 정책을 무너뜨린다. 이 시스템의 fail-safe 방향은 전자다.

    # 무해한 리다이렉션(`2>&1`·`>/dev/null`)을 먼저 제거한다.
    # 순서 중요: 이걸 남긴 채 `&`로 세그먼트를 쪼개면 `2>&1`이 조각나 `1`이 명령으로 읽힌다.
    probe="$(printf '%s' "$cmd" | sed -e 's/[0-9]*>&[0-9]*//g' -e 's#[0-9]*>>*[[:space:]]*/dev/null##g')"

    # 남은 리다이렉션은 전부 쓰기로 본다 — 명령이 무엇이든 차단.
    if printf '%s' "$probe" | grep -qE '>'; then
      deny "claude-main의 셸 리다이렉션 쓰기가 차단됐다(write_scope=none). 산출물은 텍스트로 반환하라 — Orchestrator가 파일로 남긴다. (2>&1 · >/dev/null 은 허용)"
    fi

    # 세그먼트 분해: ; && || | 로 나눠 각 조각의 첫 토큰을 본다.
    # (한 조각이라도 allowlist 밖이면 deny — `cat f | tee g` 류를 잡기 위함)
    segs="$(printf '%s' "$probe" | tr ';|&\n' '\n\n\n\n')"

    # 읽기·검증 전용 명령만. 여기 없는 것은 전부 deny.
    ALLOWED='ls|cat|head|tail|wc|grep|rg|egrep|fgrep|find|file|stat|du|df|tree|
diff|cmp|jq|yq|awk|sed|cut|sort|uniq|tr|xxd|od|basename|dirname|realpath|readlink|
echo|printf|true|false|test|which|command|type|env|pwd|date|sleep|
node|npx|pnpm|npm|yarn|bun|deno|tsc|eslint|prettier|vitest|jest|
python3|python|pip|pytest|ruff|mypy|
go|cargo|rustc|make|
git|gh|
codex|claude|agy'

    bad=""
    while IFS= read -r seg; do
      seg="$(printf '%s' "$seg" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      [ -z "$seg" ] && continue
      tok="$(printf '%s' "$seg" | awk '{print $1}')"
      # 변수대입 프리픽스(FOO=bar cmd) 건너뛰기
      case "$tok" in *=*) tok="$(printf '%s' "$seg" | awk '{for(i=1;i<=NF;i++) if ($i !~ /=/) {print $i; exit}}')" ;; esac
      [ -z "$tok" ] && continue
      tok="$(basename "$tok")"   # /usr/bin/touch → touch (절대경로 우회 차단)
      printf '%s' "$tok" | grep -qxE "$(printf '%s' "$ALLOWED" | tr -d '\n')" || { bad="$tok"; break; }
    done <<EOF
$segs
EOF

    [ -n "$bad" ] && deny "claude-main의 Bash는 읽기·검증 명령 allowlist로 제한된다(write_scope=none). '$bad'는 목록에 없다. 필요하면 무엇을 왜 실행해야 하는지 result에 적어라 — Orchestrator가 수행한다."

    # allowlist 안이어도 쓰기 서브커맨드·플래그는 차단.
    if printf '%s' "$cmd" | grep -qE '(^|[[:space:]])git[[:space:]]+(add|commit|push|checkout|switch|reset|clean|rebase|merge|stash|rm|mv|apply|restore|config|tag|branch[[:space:]]+-)([[:space:]]|$)'; then
      deny "claude-main의 git 상태 변경이 차단됐다. 커밋·브랜치는 Orchestrator 소관이다. 읽기(log/diff/show/status/blame)는 허용된다."
    fi
    if printf '%s' "$cmd" | grep -qE '(^|[[:space:]])(sed|perl|python3?|ruby)[[:space:]]+[^;|&]*(-i|-c|-e)([[:space:]]|$)'; then
      deny "claude-main의 in-place 편집·인라인 스크립트(sed -i / python3 -c 등)가 차단됐다 — 임의 파일쓰기 경로다. 변경은 diff로 반환하라."
    fi
    if printf '%s' "$cmd" | grep -qE '(^|[[:space:]])node[[:space:]]+-(e|p|-eval|-print)([[:space:]]|$)'; then
      deny "claude-main의 node -e 인라인 스크립트가 차단됐다 — 임의 파일쓰기 경로다."
    fi
    if printf '%s' "$cmd" | grep -qE '(^|[[:space:]])(npm|pnpm|yarn|bun)[[:space:]]+(i|install|add|remove|uninstall|link|publish|update|up)([[:space:]]|$)'; then
      deny "claude-main의 패키지 설치·변경이 차단됐다(lockfile·node_modules 쓰기). 필요한 의존성은 result에 적어라."
    fi
    if printf '%s' "$cmd" | grep -qE '(^|[[:space:]])(awk|sed)[[:space:]]+[^;|&]*(-i|print[[:space:]]*>)'; then
      deny "claude-main의 awk/sed 파일쓰기가 차단됐다."
    fi

    # ── 통과한 명령은 sandbox로 감싼다 (커널 레벨 쓰기 제한) ──
    # allowlist는 **직접 쓰기**만 막는다. 허용된 `pnpm test`·`npx tsc`·`pytest`가
    # 하위 프로세스에서 쓰는 캐시·coverage는 훅이 보지 못한다. 커널에서 가둔다.
    # 쓰기 허용: repo · TMPDIR · /tmp · /dev. 그 밖(~/.claude·타 repo·/etc)은 차단.
    # ⇒ KI-2를 닫지 않는다. **범위를 좁힐 뿐** — repo 안 쓰기는 남는다(커널은 캐시와 소스를 구분 못 함).
    PROFILE="$ROOT/_shared/adapters/worker-sandbox.sb"
    if [ -f "$PROFILE" ] && command -v sandbox-exec >/dev/null 2>&1; then
      tmp="${TMPDIR:-/tmp}"; tmp="${tmp%/}"
      # printf %q — 원본 명령을 단일 인자로 안전하게 인용(따옴표 지옥 회피)
      wrapped="sandbox-exec -f $(printf '%q' "$PROFILE") -D REPO=$(printf '%q' "$ROOT") -D TMP=$(printf '%q' "$tmp") /bin/bash -c $(printf '%q' "$cmd")"
      _decided=1
      jq -nc --arg c "$wrapped" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",updatedInput:{command:$c}}}'
      exit 0
    fi
    allow   # sandbox-exec 없는 환경(비-macOS 등) → 래핑 없이 allowlist만으로 진행
    ;;
  *)
    allow
    ;;
esac
