# HANDOFF — 타 노트북에서 이 작업 이어가기

> 생성 2026-07-07. 이 문서는 스냅샷이다. 이어서 작업 후 갱신 권장.
> 핵심: 이 시스템은 **file-as-memory** 설계 — 채팅 맥락이 아니라 **파일**을 옮기면 새 Claude Code 세션이 `tasks/`에서 **재정박**(orchestrator-rules §3)해 이어간다.

## 1. 무엇을 옮기나 (2 repo + gitignore된 상태 + 시크릿)

| 자산 | 경로 | git | 전송 |
|------|------|-----|------|
| 오케스트레이터 | `/Users/noi/multi-agent` | 로컬, **원격 0** | 원격 push 또는 폴더 복사 |
| 제품 | `/Users/noi/raceplanner` | 로컬, **원격 0** | 원격 push 또는 폴더 복사 |
| 오케스트레이션 메모리 | `multi-agent/tasks/` | **gitignore** | ⚠️ 별도 복사(Drive/rsync) |
| 웹훅 시크릿 | `multi-agent/_local/slack-webhook` | **gitignore** | ⚠️ 재입력 권장(복사 금지) |

**브랜치 상태 (미머지 — 옮길 때 브랜치째로):**
- `multi-agent`: `autonomy-policy-adoption` (main 대비 5커밋 — autonomy 정책+알림+웹훅+권한+bypass)
- `raceplanner`: `w0-w3-foundation` (`a1295db` W1 → `4c8015d` W0+W3 → `265a99f` supabase config → `b2db0d0` init)

## 2. 전송 (둘 중 택1)

### A. git 원격 (코드용, 권장)
```bash
# 이 노트북에서 (GitHub 비공개 repo 2개 미리 생성 후)
git -C /Users/noi/multi-agent  remote add origin <multi-agent-repo-url>
git -C /Users/noi/multi-agent  push -u origin --all
git -C /Users/noi/raceplanner  remote add origin <raceplanner-repo-url>
git -C /Users/noi/raceplanner  push -u origin --all
```
⚠️ `tasks/`·`_local/`은 gitignore라 **push에 안 실린다** → 아래 별도 복사.
```bash
# 오케스트레이션 메모리 + 시크릿은 out-of-band (예: Drive)
rsync -a /Users/noi/multi-agent/tasks/  "<drive>/handoff/tasks/"
# 시크릿은 복사 대신 타 노트북에서 재입력 권장
```

### B. 폴더 통째 복사 (한 번에)
```bash
# node_modules·.temp 제외하고 두 폴더 전체(.git·tasks·_local 포함)
rsync -a --exclude node_modules --exclude 'supabase/.temp' \
  /Users/noi/multi-agent  /Users/noi/raceplanner  "<drive>/handoff/"
```

## 3. 타 노트북 — 복원

1. **도구 설치**: Claude Code, node 26+/pnpm, Docker+`supabase` CLI(2.109), `codex`(+`~/.codex/config.toml`), `agy`(gemini 백엔드), `coach`(Stop 훅; 없으면 훅은 `|| true`로 무해 skip).
2. **MCP 재인증** (대화형이라 필수): Slack MCP·codex MCP 재로그인.
3. **경로 배치**: 두 repo를 **같은 절대경로**(`/Users/noi/...`)에 두면 무수정. 사용자명이 다르면 아래 절대경로 수정:
   - `multi-agent/.claude/settings.json` → `permissions.additionalDirectories`
   - (brief의 `target_repo`는 재생성되므로 무시 가능)
4. `tasks/` 복원 + `_local/slack-webhook`에 **웹훅 URL 재입력**:
   ```bash
   echo 'https://hooks.slack.com/services/…' > /Users/noi/multi-agent/_local/slack-webhook
   ```
5. **raceplanner 의존성·스택**:
   ```bash
   cd /Users/noi/raceplanner
   npx pnpm@latest install --lockfile=false
   supabase start        # W0 마이그레이션 검증 원하면 supabase db reset
   npx pnpm@latest --filter @rp/mobile web -- --port 8081   # 앱: http://localhost:8081/
   ```
6. **재개**: `cd /Users/noi/multi-agent && claude --continue` (또는 새 세션) → **"raceplanner 이어서"** 라고 하면 `tasks/`에서 재정박.

## 4. 현재 작업 상태 (재개 시 참고)

- **W0**(계약 잠금) done · **W3**(Expo 스캐폴드) done · **W1**(엔진 구현) done — 셋 다 raceplanner `w0-w3-foundation`에 커밋.
- 앱 실행: `localhost:8081` (RaceType 배선 홈 화면). 엔진: computePlan·estimateAbility 실구현+골든 4/4.
- **미해결/후속**: (a) W0 critic 2건 carry(engine throw 리터럴, SQL 매핑주석), (b) base `tsconfig.base.json`의 `ignoreDeprecations: "6.0"` TS6 잔재 정리, (c) 두 repo 모두 feature 브랜치라 **main 미머지** — 리뷰 후 머지 결정, (d) `raceplanner/packages/engine/tsconfig.tsbuildinfo`는 빌드 산출물 → gitignore 고려.
- **관제/알림**: Slack `#claude-orchestrator` (`C0BGH4K5LL8`) + 웹훅 `_shared/adapters/notify.sh`. 권한 `bypassPermissions`(세션 재시작 시 활성).

## 5. 대안 — 옮기지 않고 원격 접속
"타 노트북 이전"이 아니라 "같은 세션 원격 조종"이 목적이면 **Remote Control**(claude.ai/code)로 이 세션을 폰·타 브라우저에서 보고 조종. 단 이 노트북 세션·프로세스는 살아 있어야 함.
