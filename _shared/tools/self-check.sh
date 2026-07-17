#!/usr/bin/env bash
# self-check.sh — 시스템 불변식(INV1~15) 자가점검. **정본은 `_shared/system-invariants.md`의 표**(정의).
# 이 스크립트는 그 표의 *검사*를 소유한다. 정의를 여기 재기술하지 않는다(D11).
#
# 왜 스크립트인가: 초판은 markdown 안의 echo 나열이라 복붙해야 돌았고, 판정이 "PASS 문자열이
#   보이는지 사람이 눈으로" 확인하는 방식이었다. 그건 점검이 아니다 — 실제로 INV15b가 그 방식이라
#   값이 틀려도 exit 0인 false-PASS였다(codex-critic 적발 2026-07-17).
#   여기서는 **exit code가 판정**이다. 0=PASS, 1=FAIL.
#
# 사용:
#   bash _shared/tools/self-check.sh              # 전체
#   bash _shared/tools/self-check.sh --quiet      # FAIL만 출력 (훅·CI용)
#   MULTIAGENT_ROOT=/path bash .../self-check.sh  # 루트 지정 (기본: 스크립트 위치 기준)

set -uo pipefail

ROOT="${MULTIAGENT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

FAILED=0
say()  { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
pass() { [ "$QUIET" -eq 1 ] || printf '  ✓ %s\n' "$*"; }
fail() { printf '  ✗ FAIL %s\n' "$*" >&2; FAILED=1; }

need_file() { [ -f "$1" ] || { fail "$2 — 파일 없음: $1"; return 1; }; return 0; }

say "self-check @ $ROOT"

# ── INV1: write_scope 값 집합이 4개 파일에 동일 ──
n=$(grep -l 'tasks-only' "$ROOT/CLAUDE.md" "$ROOT/_shared/routing.md" \
      "$ROOT/_templates/worker-brief.md" "$ROOT/_templates/task-folder.md" 2>/dev/null | wc -l | tr -d ' ')
[ "$n" = "4" ] && pass "INV1 write_scope 값 집합 4/4" || fail "INV1 — tasks-only가 $n/4 파일에만 (D1 위반)"

# ── INV2: codex-critic 전용 강제 표현 없어야 ──
if grep -qn 'result.md. 존재 필수\|claude-main 결과 필요 → 항상 후행' "$ROOT/_shared/routing.md" 2>/dev/null; then
  fail "INV2 — codex-critic 전용 강제 표현 잔존 (D2 위반)"
else pass "INV2 codex-critic 선행조건 일반화"; fi

# ── INV3: log 태그 6종 ──
grep -q 'DECISION | WORKER_CALL | VERIFICATION | ERROR | APPROVAL | COMPLETE' "$ROOT/_templates/log.md" 2>/dev/null \
  && pass "INV3 log 태그 6종" || fail "INV3 — log 태그 정의 라인 유실"

# ── INV4: 한도 수치 1500/1200 ──
grep -rqn '1500자' "$ROOT/CLAUDE.md" 2>/dev/null && grep -rqn '1200자' "$ROOT/CLAUDE.md" 2>/dev/null \
  && pass "INV4 한도 1500/1200" || fail "INV4 — 한도 수치 불일치·유실"

# ── INV6: workers_approved HH:MM 잔존 없어야 ──
if grep -qn 'approved_at: <YYYY-MM-DD HH:MM>' "$ROOT/_shared/approval-policy.md" 2>/dev/null; then
  fail "INV6 — approved_at HH:MM 스키마 잔존 (B1/B6 재발)"
else pass "INV6 workers_approved 스키마"; fi

# ── INV7: 권위 우선순위 문구 ──
grep -qiE '권위 우선순위|CLAUDE.md가 가장 높|문서가 충돌' "$ROOT/_shared/design-basis.md" 2>/dev/null \
  && pass "INV7 권위 우선순위" || fail "INV7 — 권위 우선순위 문구 유실 (Clash 해소 붕괴)"

# ── INV8: 오케스트레이터 인터랙티브 전용 ──
grep -qin 'worktree\|백그라운드\|background session' "$ROOT/_shared/orchestrator-rules.md" 2>/dev/null \
  && pass "INV8 인터랙티브 전용 규칙" || fail "INV8 — worktree/백그라운드 금지 규칙 유실 (D5 위반)"

# ── INV9: gemini 백엔드 = agy CLI + pro-high ──
if grep -q '"command": "agy"' "$ROOT/_shared/backends.json" 2>/dev/null \
   && grep -q 'gemini-3.1-pro-high' "$ROOT/_shared/backends.json" 2>/dev/null; then
  pass "INV9 gemini=agy/pro-high"
else fail "INV9 — gemini 백엔드가 agy/pro-high 아님 (D4 위반)"; fi

# ── INV10: 폐기 브리지 활성 호출 없어야 ──
if grep -rqn 'mcp__gemini__gemini_' "$ROOT/_shared/routing.md" "$ROOT/_templates/task-folder.md" "$ROOT/CLAUDE.md" 2>/dev/null; then
  fail "INV10 — 폐기 브리지 mcp__gemini__gemini_* 활성 호출 잔존 (D4 위반)"
else pass "INV10 폐기 브리지 미참조"; fi

# ── INV11: 재진입 프로토콜 + 토폴로지 4패턴 + 배제 유지 ──
grep -q '재진입 프로토콜' "$ROOT/_shared/orchestrator-rules.md" 2>/dev/null \
  && grep -q '재진입 프로토콜' "$ROOT/CLAUDE.md" 2>/dev/null \
  && pass "INV11a 재진입 프로토콜(양쪽)" || fail "INV11a — 재진입 프로토콜 유실 (D6 위반)"

miss=""
for p in 'Pipeline' 'Fan-out/Fan-in' 'Expert Pool' 'Producer-Reviewer'; do
  grep -q "$p" "$ROOT/_shared/routing.md" 2>/dev/null || miss="$miss $p"
done
[ -z "$miss" ] && pass "INV11b 토폴로지 4패턴" || fail "INV11b — 토폴로지 패턴 유실:$miss (D6 위반)"

if grep -nE 'Supervisor|Hierarchical' "$ROOT/_shared/routing.md" 2>/dev/null | grep -qv '배제'; then
  fail "INV11c — Supervisor/Hierarchical이 배제 외 문맥에 등장 (D6 위반 — 배제 패턴 부활)"
else pass "INV11c 배제 패턴 유지"; fi

# ── INV12: 카파시 4원칙 층별 적용 ──
grep -q '운영 원칙 (Operating Principles)' "$ROOT/CLAUDE.md" 2>/dev/null \
  && pass "INV12a 운영 원칙 섹션" || fail "INV12a — 운영 원칙 섹션 유실 (D8 위반)"
grep -q 'Worker 행동 규약' "$ROOT/_templates/worker-brief.md" 2>/dev/null \
  && pass "INV12b Worker 행동 규약 블록" || fail "INV12b — 워커 규약 고정 블록 유실 (D8 위반)"
if sed -n '/^## Worker 행동 규약/,/^## Execution/p' "$ROOT/_templates/worker-brief.md" 2>/dev/null | grep -qiE '질문|ask'; then
  fail "INV12c — 규약 블록에 사용자질문 지시 (D8 위반 — 워커는 one-shot이라 질문 채널 없음)"
else pass "INV12c 규약 블록에 질문 지시 없음"; fi
grep -q '표면화' "$ROOT/_templates/worker-result.md" 2>/dev/null \
  && pass "INV12d result 표면화 항목" || fail "INV12d — result 체크리스트 표면화 항목 유실"

# ── INV13: 원격 승인 알림 (best-effort) ──
grep -q '원격 승인 알림' "$ROOT/_shared/approval-policy.md" 2>/dev/null \
  && grep -q 'best-effort' "$ROOT/_shared/approval-policy.md" 2>/dev/null \
  && pass "INV13 원격 알림 절(best-effort)" || fail "INV13 — 원격 알림 절 유실 또는 하드게이트로 변질 (D9 위반)"

# ── INV14: autonomy-policy 소비스 티어 ──
if grep -q 'AUTO' "$ROOT/_shared/autonomy-policy.md" 2>/dev/null \
   && grep -q 'HARD-STOP' "$ROOT/_shared/autonomy-policy.md" 2>/dev/null \
   && grep -q 'linear' "$ROOT/_shared/autonomy-policy.md" 2>/dev/null; then
  pass "INV14a autonomy-policy 티어·linear"
else fail "INV14a — AUTO/HARD-STOP/linear 절 유실 (D10 위반)"; fi
grep -q 'autonomy-policy' "$ROOT/_shared/design-basis.md" 2>/dev/null \
  && pass "INV14b 권위순위에 autonomy-policy" || fail "INV14b — 권위 슬롯 유실 (D10 위반)"

# ── INV15: 정본 소유 분리 (D11) ──
if grep -nEi '(sandbox|approval-policy|call_type|args_template|cwd_policy|fallbacks|timeout)[^|]{0,20}(workspace-write|read-only|danger-full-access|on-failure|on-request|untrusted|never|\bmcp\b|\bcli\b|\bnative\b|isolated_tmp)' \
     "$ROOT/_shared/routing.md" 2>/dev/null | grep -viE 'backends\.json|정본|D11|포인터|jq ' | grep -q .; then
  fail "INV15a — routing.md가 호출 기전 값을 재기술 (D11 위반 — 값 이중화는 조용히 갈라진다)"
else pass "INV15a routing 기전값 재기술 없음"; fi

chk() { # worker key expected
  local got; got="$(jq -r --arg w "$1" --arg k "$2" '.workers[$w].mcp.args_template[$k] // "MISSING"' "$ROOT/_shared/backends.json" 2>/dev/null)"
  [ "$got" = "$3" ] && pass "INV15b $1.$2=$got" || fail "INV15b — $1.$2=$got (기대 $3) (D11 위반)"
}
chk codex-main   sandbox         workspace-write
chk codex-main   approval-policy on-failure
chk codex-critic sandbox         read-only

grep -q 'D11 정본 소유 규칙' "$ROOT/_shared/design-basis.md" 2>/dev/null \
  && pass "INV15c D11 절 존재" || fail "INV15c — D11 절 유실"

# ── 구조 위생 (불변식은 아니나 실증된 사고 유형) ──
jq empty "$ROOT/_shared/backends.json" 2>/dev/null \
  && pass "backends.json JSON 유효" || fail "backends.json — JSON 파싱 실패"
for f in call_worker.sh gemini_api.sh notify.sh worker_write_guard.sh; do
  [ -x "$ROOT/_shared/adapters/$f" ] && pass "adapters/$f 실행권한" \
    || fail "adapters/$f — 실행권한 없음 (2026-07-17 실증: 디스패처 호출이 막혔다)"
done

# ── 유지보수자 전용 (자산 있을 때만) ──
TPL="$ROOT/plugins/multi-agent-starter/skills/configure-multiagent/generator/templates"
if [ -d "$TPL" ]; then
  n=$(grep -l 'Worker 행동 규약' "$TPL/claude/_templates/worker-brief.md" \
       "$TPL/codex/_templates/worker-brief.md" "$TPL/antigravity/_templates/worker-brief.md" 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" = "3" ] && pass "INV12f 3 flavor 규약 블록" || fail "INV12f — 규약 블록이 $n/3 flavor에만"
else
  say "  (generator templates 없음 — 교차 flavor 점검 skip. 설치본 정상)"
fi

if [ "$FAILED" -eq 0 ]; then
  say ""; say "✅ self-check PASS — 불변식 위반 없음"
  exit 0
else
  printf '\n❌ self-check FAIL — 위 항목을 고치거나, 의도된 변경이면 design-basis 결정(D*)과 system-invariants 표를 함께 갱신하라.\n' >&2
  exit 1
fi
