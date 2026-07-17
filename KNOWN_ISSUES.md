# 알려진 이슈

해결되지 않은 알려진 결함을 추적한다. 고쳐지면 해당 항목을 닫고(✅) PR 링크를 단다.
시스템이 깨지는 크리티컬은 즉시 수정 대상, 표시·미관 한정은 보류 가능.

출처: `repo-consistency-audit` (2026-05-19, claude-main·codex-main 병렬 + Orchestrator 교차검증).
상세 근거표(`repo-consistency-audit`)는 공개 배포본에 미포함 — 유지보수자 전용.

---

## KI-2 — `write_scope`가 산문으로만 강제된다 (bypassPermissions 하에서 기계적 경계 0)

- **상태**: 🟡 **부분 완화 (3차)** — 열린 채로 둔다. 1차 allowlist 가드 / 2차 sandbox 래핑 / 3차 우회·fail-open 경화(codex-critic 2026-07-18). 2026-07-17~18, `tasks/multiagent-v2-build/` W2 + `worker-sandbox` + `final-polish`
- **심각도**: 높음 → **중간**. repo **밖** 쓰기는 커널이 막는다. **완전한 기계적 강제는 아니다**(아래 남은 구멍 — 단수 아님).
- ⚠️ **"해소"로 표기했다가 되돌림** — codex-critic이 초판 denylist의 우회 7종을 실측으로 뚫었다. 완화를 해소로 부르지 말 것.

### 완화 내용

`.claude/agents/claude-main.md` frontmatter에 `hooks: PreToolUse (matcher: Write|Edit|NotebookEdit|Bash)`로 가드를 부착. 실측 근거 2건:

1. **PreToolUse `permissionDecision: "deny"`는 `bypassPermissions`를 이긴다** — 격리 probe로 확정(deny 케이스 파일 미생성, 대조군 정상 생성). 그간 문서 주장만 있고 아무도 확인하지 않던 미지수.
2. **PreToolUse 입력엔 `agent_type`이 없다**(실측: `session_id`·`cwd`·`permission_mode`·`tool_name`·`tool_input`·`tool_use_id`만). 워커/오케 구분은 훅을 **agent 정의에 부착**해 해결.

E2E 실측: 프롬프트에 "이 호출에 한해 write_scope 승인됨"이라 써넣어도 **차단**됨 — 가드가 프롬프트가 아니라 역할로 강제한다.

**denylist → allowlist 전환** (codex-critic 실측 후): 초판 denylist는 `python3 -c open(w)` · `node -e writeFileSync` · `echo >| f` · `/usr/bin/touch` · `eval "$(base64 -d)"` · `curl -o` · `rsync`를 **전부 통과**시켰다. denylist는 원리적으로 진다 → 읽기·검증 명령 allowlist로 뒤집어 실패 모드를 "조용히 뚫림"에서 "과차단"으로 바꿨다. 과차단은 복구 가능하다(워커가 result에 적고 Orchestrator가 실행 — 기존 계약). 회귀 28/28 PASS(우회 14 DENY / 정상작업 14 ALLOW).

### 2차 완화 — sandbox 래핑 (2026-07-17)

allowlist 통과 명령을 `sandbox-exec`(seatbelt)로 감싸 **커널 레벨에서 쓰기를 제한**한다. 쓰기 허용은 **repo·TMPDIR·/tmp·/dev**뿐 — `~/.claude`·타 repo·홈·`/etc`는 차단. 읽기·실행은 자유.

**닫은 것**: 문자열 검사로는 원리적으로 못 잡는 **난독화 쓰기**. E2E 실측에서 워커가 `String.fromCharCode`로 `fs`와 `/`를 난독화해 홈에 쓰려 했으나 커널이 EPERM. 훅이 놓친 `node -p`를 샌드박스가 잡았다 — 계층 방어 작동 확인.

**배제한 경로 (실측 근거)**:
- `isolation: worktree` — worktree엔 `tasks/`가 없다(gitignored) → 워커가 **brief를 못 읽는다**
- **완전 차단**(write_scope=none 문자 그대로) — `pnpm test`가 캐시를 못 써 죽고, 워커가 자기 코드를 검증하지 못한다. codex-critic이 지적한 "역할 불변 vs 전 쓰기 차단" 모순. 품질 손실이 이득보다 크다

### 남은 구멍 (이 이슈를 닫지 못하는 이유)

1. **repo 안 쓰기** (주된 잔여) — 커널은 캐시와 소스를 구분하지 못한다. `pnpm test`가 쓰는 `node_modules/.cache`와 워커가 `src/`를 건드리는 것을 seatbelt는 같은 "repo 쓰기"로 본다. $()/백틱·find -exec·리다이렉션 같은 우회를 3차에서 막았으나, **막아도 repo 안이면 커널이 허용**한다.
1b. **sandbox 비가용 시 조용한 강등** — `sandbox-exec`나 프로파일이 없으면(비-macOS CI 등) 가드는 allowlist-only로 통과시킨다. 그 환경에선 커널 경계가 없다. INV16d가 프로파일 부재는 잡으나, `sandbox-exec` 바이너리 부재(Linux)는 설계상 강등.
1c. **의도적 미추적 우회** — awk `system()`·sed `w file`은 검색어 오탐(`grep "system("`) 때문에 일부러 안 막는다. 전부 repo-내부 쓰기라 (1)과 같은 이유로 어차피 열림.
2. ⇒ 이것은 **사고·표류 방지**이지 **적대적 샌드박스가 아니다.** 적대적 워커를 가정하지 말 것.
3. 완전히 닫으려면 repo를 읽기전용으로 두고 캐시만 오버레이로 빼야 하는데, 그건 worktree 격리와 같은 문제(`tasks/` 부재)에 부딪힌다. **현재 알려진 깨끗한 경로 없음.**

**운영 유의**: agent frontmatter는 **세션 시작 시 로드** — 가드는 새 세션부터 유효하다.

### (이하 해소 전 기록 — 재발 시 참조)

### 증상

`workers_approved`의 `write_scope`(`none`/`tasks-only`/패턴)는 승인 계약이지만, 이를 강제하는 기계적 수단이 없다.

- `.claude/agents/claude-main.md:5` — `tools: '*'` (Write/Edit 전권, `disallowedTools` 부재). "파일 시스템에 직접 쓰지 않는다"는 **agent 본문의 산문 지시**일 뿐
- `.claude/settings.json` — `defaultMode: bypassPermissions` (1.3.0). 위반해도 **승인 프롬프트가 뜨지 않음**
- `_shared/autonomy-policy.md`가 "AUTO = write_scope 내"를 전제하는데 그 경계가 실재하지 않음. 정책 §5는 스스로 "규약이 아니라 CI가 강제자"라 선언해놓고 **자기 정책은 규약으로만** 지킨다 (자기모순)

### 기각된 수정안 (그대로 채택 금지)

`disallowedTools: Write, Edit, NotebookEdit` 추가 — **codex-critic이 무너뜨림**(2026-07-17):
- **강제되지 않음** — `tools: '*'` 유지 시 Bash `sed -i`·셸 리다이렉션·빌드 스크립트로 우회. Write/Edit 차단은 쓰기 경로의 **부분집합**일 뿐
- **자기모순** — Write/Edit 영구 제거는 "write_scope별 강제"가 아니라 **claude-main 영구 read-only화**이며, routing.md가 규정한 "메인 코딩·코드 구현·수정" 역할을 도구 수준에서 박탈

### 미해결 선결 과제

1. **실측 필요**: `bypassPermissions` 하에서 `PreToolUse` 훅의 `permissionDecision: "deny"`가 실제로 우선하는가? (문서 주장만 존재 — 실행 확인 안 됨)
2. **설계 필요**: 훅이 현재 호출의 승인된 `task`·`target_repo`·경로 패턴을 **어떤 권위 데이터 소스**에서 읽을 것인가. `write_scope`는 task별 승인값이라 고정 경로 판정으론 계약을 구현할 수 없다
3. Bash를 포함한 **모든 쓰기 경로**를 덮어야 함

### 참고

- 근거: `tasks/multiagent-v2-research/artifacts/upgrade-proposal.md` §2 R1, `workers/codex-critic/result.md` §1

---

## KI-1 (audit C3) — 표준 `worker-brief.md`를 쓰면 mat이 워커 목적을 ` ```yaml `로 표시

- **상태**: 열림 / **보류** (경미·표시 한정. 크리티컬 C1·C2는 PR #3·#5에서 해소됨)
- **심각도**: 낮음 — 시스템·워커 호출·데이터에 영향 없음. [mat](https://github.com/netwaif/mat) **모니터 화면 표시만** 오염. mat 미사용 시 영향 0.
- **재현**: 항상. `_templates/worker-brief.md` 표준 구조를 그대로 채운 brief를 쓰는 모든 작업. (이 audit의 codex-main brief에서도 실증됨.)

### 증상

mat의 핵심 화면 요소인 "워커 한 줄 목적"이 실제 Objective가 아니라 문자열 ` ```yaml `로 표시된다.

### 근본 원인

| repo | 파일·라인 | 내용 |
|------|-----------|------|
| starter | `_templates/worker-brief.md` | 1행 `# Brief`(heading), 2–4행 `<!-- -->`(comment), 6행 `## Execution Context`(heading), **8행 ` ```yaml ` fence** |
| mat | `internal/parser/task.go:280` | brief 존재 시 무조건 `w.Purpose = firstMeaningfulLine(brief 내용)` |
| mat | `internal/parser/task.go:499–515` | `firstMeaningfulLine`은 **빈 줄·`#`시작·`<!--`시작만 skip**, 그 다음 줄을 그대로 반환 |
| mat | `internal/parser/task.go:71–76` | `w.Purpose == ""`일 때만 `planned_workers.purpose`로 fallback |

표준 brief에서 heading·comment를 건너뛴 첫 "의미 있는" 줄은 `## Execution Context` 다음의 ` ```yaml ` fence다. 이 값이 비어있지 않으므로 `planned_workers.purpose` fallback도 발동하지 않는다.

### 수정 후보 (택1, 미결정)

- **(a) starter 템플릿** — `_templates/worker-brief.md`를 첫 의미 있는 줄이 실제 한 줄 목적이 되도록 재구성 (예: Execution Context yaml 위에 평문 목적 1줄, 또는 Objective를 평문으로 선두 배치).
  - 장점: starter 단독 수정, mat 재빌드 불필요, 자기완결.
  - 단점: 전 worker 공용 템플릿 변경. 1200자 한도·codex Execution Context yaml 요구와 양립해야.
- **(b) mat 파서** — `firstMeaningfulLine`이 코드펜스(` ``` `/` ```yaml `)도 skip하거나, 명시적 purpose 필드를 우선.
  - 장점: 임의 brief에 견고.
  - 단점: mat 재빌드·재배포 필요(`go build -o mat .` + 재실행). mat은 선택적 외부 도구라 비-mat 환경엔 무의미.

### 참고

- 공개 흔적: `_shared/learnings.md` [2026-05-19] (곁다리 언급), PR #5 본문.
- 크리티컬 해소 이력: PR #3 (C1 gemini 기본 모델), PR #5 (C2 gemini 단일 브리지).
