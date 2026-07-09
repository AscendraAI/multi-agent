#!/usr/bin/env bash
# Slack Incoming Webhook 알림 발송기 — autonomy-policy §3 loud ping 주체.
# 웹훅 URL은 시크릿 → gitignored `_local/slack-webhook` 에서 읽는다 (커밋 금지).
# 사용: notify.sh "메시지 텍스트"
# best-effort: URL 미설정/실패해도 작업을 막지 않는다(exit 0로 스킵, D9/D10 일관).
# @멘션 prefix로 사용자에게 실제 push가 뜨게 강제(채널 "멘션만" 설정에서도). 대상=SLACK_MENTION(기본 관제실 소유자 U0AR027F953). 빈값이면 멘션 생략.
set -euo pipefail

MSG="${1:?usage: notify.sh <message>}"
SLACK_MENTION="${SLACK_MENTION-U0AR027F953}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
URL_FILE="$ROOT/_local/slack-webhook"

if [ -n "$SLACK_MENTION" ]; then
  MSG="<@${SLACK_MENTION}> ${MSG}"
fi

if [ ! -s "$URL_FILE" ]; then
  echo "notify: webhook URL 없음 ($URL_FILE) — 스킵(best-effort)" >&2
  exit 0
fi
URL="$(tr -d '[:space:]' < "$URL_FILE")"

payload="$(printf '%s' "$MSG" | python3 -c 'import json,sys; print(json.dumps({"text": sys.stdin.read(), "link_names": 1}))')"
code="$(curl -sS -m 10 -o /dev/null -w '%{http_code}' -X POST \
  -H 'Content-type: application/json' --data "$payload" "$URL" 2>/dev/null || echo 000)"

echo "notify: HTTP $code"
[ "$code" = "200" ] || { echo "notify: 발송 실패(best-effort 스킵)" >&2; exit 0; }
