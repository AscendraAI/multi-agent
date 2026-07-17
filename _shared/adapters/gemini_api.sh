#!/usr/bin/env bash
# gemini_api.sh — gemini worker의 API 폴백 어댑터.
# 사용: gemini_api.sh <brief-file>   (call_worker.sh가 api 폴백 시 호출)
# stdout = 모델 응답 텍스트, exit 0=성공.
#
# 왜 실구현이 필요했나 (2026-07-17):
#   초판은 **스텁**이었다 — "슬롯만 정의됨(spike S3 미완)"으로 무조건 exit 4.
#   즉 backends.json이 선언한 api 폴백은 **존재하지 않았다.** 디스패처가 매 호출 경고하던
#   "GEMINI_API_KEY 미설정 → 폴백 불가"는 키를 설정해도 참이었다(이중 거짓 안전감).
#   실제로 2026-07-17 agy 쿼터 소진 시 폴백이 발동하지 못해 웨이브가 막혔다.
#
# 왜 CLI(agy)보다 이 경로가 나은 경우가 있나:
#   agy는 헤드리스에서 이미지 첨부 시 `read_file` 권한을 요구하는데 프롬프트를 띄울 수 없어
#   **자동 거부**된다(2026-07-17 실측). 우회하려면 `--dangerously-skip-permissions`가 필요하다.
#   REST는 이미지를 inline base64로 실어 보내므로 그 권한 협상 자체가 없다.
#
# 시크릿: `_local/gemini-api-key`(gitignored)에서 읽는다. env `GEMINI_API_KEY`가 우선.
#   notify.sh의 `_local/slack-webhook` 패턴과 동일. **커밋 금지.**
#
# 이미지: brief 본문에 있는 **절대경로 이미지**(.png/.jpg/.jpeg/.webp/.gif)를 자동으로 찾아
#   inline_data로 첨부한다. 존재하지 않는 경로는 건너뛰고 stderr에 남긴다.

set -euo pipefail

ROOT="${MULTIAGENT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
BRIEF="${1:?usage: gemini_api.sh <brief-file>}"
[ -f "$BRIEF" ] || { echo "gemini_api: brief 없음: $BRIEF" >&2; exit 6; }

# 키: env 우선, 없으면 _local 파일
KEY="${GEMINI_API_KEY:-}"
if [ -z "$KEY" ] && [ -f "$ROOT/_local/gemini-api-key" ]; then
  KEY="$(tr -d '[:space:]' < "$ROOT/_local/gemini-api-key")"
fi
[ -n "$KEY" ] || { echo "gemini_api: GEMINI_API_KEY 또는 _local/gemini-api-key 필요" >&2; exit 5; }

# 모델: env > 기본. **API 모델명은 agy CLI 명명과 다르다** —
#   agy `gemini-3.1-pro-high` ↔ API `gemini-3.1-pro-preview` (2026-07-17 실측).
MODEL="${GEMINI_API_MODEL:-gemini-3.1-pro-preview}"

command -v python3 >/dev/null 2>&1 || { echo "gemini_api: python3 필요" >&2; exit 5; }

GEMINI_API_KEY="$KEY" GEMINI_API_MODEL="$MODEL" BRIEF_PATH="$BRIEF" python3 - <<'PY'
import base64, json, mimetypes, os, re, sys, urllib.error, urllib.request

key   = os.environ["GEMINI_API_KEY"]
model = os.environ["GEMINI_API_MODEL"]
brief = open(os.environ["BRIEF_PATH"], encoding="utf-8").read()

# brief 본문의 절대경로 이미지를 첨부 (중복 제거, 등장 순서 유지)
IMG_RE = re.compile(r'/[^\s`"\'<>()]+\.(?:png|jpe?g|webp|gif)', re.I)
seen, parts = set(), [{"text": brief}]
for path in IMG_RE.findall(brief):
    if path in seen:
        continue
    seen.add(path)
    if not os.path.isfile(path):
        print(f"gemini_api: 이미지 없음 — 건너뜀: {path}", file=sys.stderr)
        continue
    mime = mimetypes.guess_type(path)[0] or "image/png"
    with open(path, "rb") as f:
        parts.append({"inline_data": {"mime_type": mime, "data": base64.b64encode(f.read()).decode()}})
    print(f"gemini_api: 이미지 첨부 {os.path.basename(path)}", file=sys.stderr)

body = json.dumps({"contents": [{"parts": parts}]}).encode()
url  = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}"
req  = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})

try:
    resp = json.load(urllib.request.urlopen(req, timeout=300))
except urllib.error.HTTPError as e:
    detail = e.read().decode(errors="replace")[:400]
    # 키가 에러 본문에 반향될 수 있어 마스킹
    print(f"gemini_api: HTTP {e.code} — {detail.replace(key, '<KEY>')}", file=sys.stderr)
    sys.exit(4)
except Exception as e:
    print(f"gemini_api: 요청 실패 — {str(e)[:200]}", file=sys.stderr)
    sys.exit(4)

if "error" in resp:
    print(f"gemini_api: API 에러 — {resp['error'].get('message','?')[:300]}", file=sys.stderr)
    sys.exit(4)

try:
    cand = resp["candidates"][0]
except (KeyError, IndexError):
    print(f"gemini_api: candidates 없음 — {json.dumps(resp)[:300]}", file=sys.stderr)
    sys.exit(4)

text = "".join(p.get("text", "") for p in cand.get("content", {}).get("parts", []))
if not text.strip():
    reason = cand.get("finishReason", "?")
    print(f"gemini_api: 빈 응답 (finishReason={reason})", file=sys.stderr)
    sys.exit(4)

sys.stdout.write(text)
PY
