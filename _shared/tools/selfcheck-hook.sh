#!/usr/bin/env bash
# selfcheck-hook.sh — Stop 훅. 시스템 파일이 변경된 세션에서만 자가점검을 돌린다.
#
# 왜 게이트가 있나: 훅이 매번 시끄러우면 무시하는 습관이 생기고, 그러면 점검이 없는 것과 같다.
#   시스템 파일(_shared/·_templates/·CLAUDE.md·.claude/)을 건드린 세션에서만 발동한다.
#
# 왜 Stop인가: 작업이 끝나는 시점에 회귀를 알린다. PreToolUse로 막으면 편집 도중에도 걸려서
#   정상 작업을 방해한다(중간 상태는 일시적으로 불변식을 깨는 게 정상이다).
#
# fail-open: 이 훅의 실패가 작업을 죽이지 않는다. self-check가 FAIL이면 **알리되 막지 않는다**
#   — 진짜 게이트는 CI(PR)다. D9의 "알림은 best-effort, 하드 게이트 아님"과 같은 방향.

set -uo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$ROOT" 2>/dev/null || exit 0

command -v git >/dev/null 2>&1 || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# 게이트: 이 세션에서 시스템 파일이 바뀌었나 (미커밋 + main 대비 커밋 양쪽)
changed="$( { git diff --name-only; git diff --cached --name-only;
              git diff --name-only main...HEAD 2>/dev/null; } \
            | grep -E '^(_shared/|_templates/|CLAUDE\.md|\.claude/)' | head -1 )"
[ -z "$changed" ] && exit 0   # 무관 작업 → no-op

[ -x "$ROOT/_shared/tools/self-check.sh" ] || exit 0

out="$(bash "$ROOT/_shared/tools/self-check.sh" --quiet 2>&1)"
rc=$?

if [ "$rc" -ne 0 ]; then
  printf '⚠️  시스템 파일을 수정했고 자가점검이 FAIL했다 (커밋 전 확인):\n%s\n' "$out"
  printf '\n재현: bash _shared/tools/self-check.sh\n'
fi
exit 0   # fail-open — 알리되 막지 않는다. 강제자는 CI(PR)다.
