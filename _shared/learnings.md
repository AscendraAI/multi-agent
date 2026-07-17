# Shared Learnings

작업 완료 후 재사용 가능한 교훈만 추가. append-only.  
중복·일회성·작업 특화 내용은 기록하지 말 것.

## 분류 규칙 (어디에 적을지)

- **시스템 운영 자체**에 대한, 어떤 작업에든 적용되는 교훈 → **이 파일** (`_shared/learnings.md`, git 추적·공개).
- **특정 외부 프로젝트/repo에 묶인** 교훈(예: mat·hwpx 내부) → **`_local/learnings.md`** (git 추적 안 함·미배포. 없으면 새로 생성. 오케스트레이터는 명시 요청 없이는 로드하지 않음).

## 형식

```
## [YYYY-MM-DD] [작업명]
**교훈**: 한 문장. 다음 작업에 그대로 적용 가능한 형태로.
**근거**: 왜 그런지, 어떤 작업에서 발견했는지.
**worker**: [관련 worker명]
```

---

<!-- 이 아래부터 교훈 추가 -->

## [2026-05-13] [mat-mvp]
**교훈**: orchestrator-cwd가 git이 아니면 Task tool sub-agent 호출에서 worktree 격리가 실패할 수 있다. 다른 git repo를 다룰 때는 그 repo로 `cd` 후 claude를 시작하거나, worktree를 요구하지 않는 일반 에이전트로 폴백.
**근거**: claude-test(비-git) cwd에서 `subagent_type: claude` 호출 시 "Cannot create agent worktree" 에러. `general-purpose`로 재시도하니 격리 없이 성공.
**worker**: claude-main 호출 경로

## [2026-05-14] [mat-mvp]
**교훈**: `task.md`는 ` ```yaml ` 블록을 2개 갖는 게 표준 패턴(메타 + Worker Plan)이다. 어떤 키든 첫 yaml fence만 보는 파서는 깨진다 — 문서 전체의 모든 yaml block을 스캔하도록 작성할 것.
**근거**: mat의 `readPlannedWorkers`가 첫 fence 닫는 ``` 에서 return하는 바람에 `planned_workers`(두 번째 블록)를 못 봤다. codex-critic이 MAJOR로 잡고 fix iter로 수정.
**worker**: codex-critic (지적), claude-main (수정)

## [2026-05-14] [mat-mvp]
**교훈**: 같은 worker의 재호출(fix iter)은 별도 폴더 만들지 말고 같은 worker 폴더 안에서 `brief-fix.md` / `result-fix.md` 명명으로 진행. 1차 산출물·승인 기록을 보존하면서 변경 이력이 시각적으로 드러난다.
**근거**: codex-critic 리뷰 후 claude-main에 MAJOR 2건 패치 재호출 시 적용. `workers_approved`는 그대로 두고 brief/result 한 쌍을 추가하는 것만으로 충분했고 깔끔했다.
**worker**: claude-main (fix iter)

## [2026-05-14] [yt-thumbnail-multiagent]
**교훈**: MultiAgent 작업은 worktree 진입 금지. orchestration 산출물(`tasks/<task>/`)은 gitignore라 worktree에 만들어도 본체로 옮기려면 수동 복사 사족이 생긴다. tracked 시스템 파일도 단순 append/수정에 worktree+commit+merge는 과한 오버헤드.
**근거**: 배경 세션 harness가 자동으로 EnterWorktree를 강제해 task 폴더와 시스템 파일 수정 양쪽에서 `cp -R` 또는 머지 사족이 발생했다. 외부 `target_repo` 쓰기는 codex-main의 cwd로 따로 격리되므로 MultiAgent repo 자체에 워크트리는 불필요. 인터랙티브 세션에서는 EnterWorktree를 자발적으로 호출하지 말 것.
**worker**: orchestrator (세션 초기화 시 EnterWorktree 호출 안 함)

## [2026-05-14] [yt-thumbnail-spring]
**교훈**: log.md는 표준 형식 엄수 — (a) 태그는 정해진 6종(`DECISION | WORKER_CALL | VERIFICATION | ERROR | APPROVAL | COMPLETE`)만 사용, (b) 타임스탬프 `[YYYY-MM-DD HH:MM]`까지 기록, (c) 작업 완료 시 마지막 줄에 `[COMPLETE]` 엔트리 필수.
**근거**: yt-thumbnail-spring log에서 `INIT/BRIEF/CALL/RESULT` 새 태그 사용, HH:MM 누락, [COMPLETE] 부재. mat 같은 도구가 표준 형식 가정하고 파싱하면 일관성 깨짐.
**worker**: orchestrator (로그 작성 규율)

## [2026-05-15] [hwpx-math-final]
**교훈**: codex MCP 호출이 비정상적으로 길어질 때(>2-3분) 첫 의심은 외부 MCP 도구 hang이지 모델·reasoning이 아니다. `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`의 event timestamp gap을 보면 어느 function_call에서 막혔는지 즉시 식별 가능.
**근거**: 표면 원인(reasoning=high, brief 길이, AGENTS preamble)으로 잘못 짚었다가 사용자 재질문 후 turn timing 분석으로 진단. 탐색·normalize는 50초, hang난 function_call→output 사이가 399초로 명확. session jsonl이 정답지.
**worker**: orchestrator (디버깅 절차)

## [2026-05-15] [hwpx-math-final]
**교훈**: `mcp__codex__codex`의 reject 응답이 codex backend 작업을 중단시키지 않는다. 사용자 거부 후에도 backend는 끝까지 실행되어 파일·부수 효과가 남을 수 있음. 거부한 호출 직후엔 대상 디렉토리 상태를 반드시 확인.
**근거**: reject된 codex MCP 호출 두 건이 backend에서 작업을 계속해 cwd에 산출 파일 생성. orchestrator는 처음에 그 파일들이 어디서 왔는지 추적 못 함. `~/.codex/sessions/` 세션 jsonl로 확인 가능.
**worker**: orchestrator (MCP reject 의미 이해)

## [2026-05-15] [manual-final-review]
**교훈**: `mcp__gemini-pro__*`(로컬 프록시 기반 gemini-pro 브리지)가 `Proxy 400 INVALID_ARGUMENT`를 내면 프롬프트 크기 문제가 아니라 모델 티어 문제일 수 있다 — 압축 재시도로 시간 쓰지 말고 폴백 순서를 `pro-high → pro-low(같은 프록시, 종종 정상) → Flash 브리지`로 단계 강등하라. 어느 경우든 model deviation을 result.md·리포트에 명시한다. gemini는 FS 접근이 없어 brief "경로 참조"가 안 통하므로 필요한 자료는 orchestrator가 MCP prompt에 직접 inline하고 그 사실을 brief·log에 적는다. FS 미접근 모델이 낸 *시스템 사실 주장*은 codex-critic/권위문서로 교차검증 후에만 채택한다(never-trust-upstream — 리뷰어 출력에도 동일 적용).
**근거**: pro-high가 큰/압축 프롬프트 모두 동일 400. Flash는 1회 성공했으나 문서 우선순위를 오추정, 같은 프롬프트로 pro-low는 정상 동작하며 더 날카로운 비평을 냈다(같은 프록시인데 pro-high만 막힘). pro-low조차 매뉴얼 용도(런타임 미적재 사람용 문서)를 오판해 "이론=토큰낭비"라는 틀린 전제로 소절 삭제를 권고 → 사실검증으로 불채택했다.
**worker**: gemini (프록시 장애·FS 미접근), codex-critic (사실 교차검증), orchestrator (폴백 강등·리뷰어 출력 검증)

## [2026-05-19] [repo-consistency-audit]
**교훈**: 다중 repo 일관성 감사에서 claude-main·codex-main을 **추상화 레이어로 분담**시키면(claude-main=의미·규칙 레벨, codex-main=파일·파서·코드 레벨) 같은 입력 중복 호출 대신 상호보완 커버리지가 나온다 — 이번에 codex만 검출(표준 brief→mat 파서가 worker 목적을 ` ```yaml `로 표시)·claude만 검출(manual↔mat 상태 우선순위 순서/단계 불일치)이 각각 진성 크리티컬이었고 둘 다 독립 검출한 항목(gemini 기본 모델 pro-high 충돌)은 신뢰도 최상으로 분류. 병렬 brief에 "다른 worker 결과 미참조" 명시는 codex result checklist에 그대로 확인됨. 또한 claude-main이 초기 가설 2건을 self-retract했어도 orchestrator가 인용 라인을 sources에 **직접 재대조**(never-trust-upstream을 worker 출력에도 적용)해야 false-positive·false-negative 둘 다 막힌다.
**근거**: 단일 worker였으면 크리티컬 3건 중 1건씩 누락. orchestrator 재검증에서 firstMeaningfulLine(task.go:499)·.mcp.json·routing.md:111을 직접 확인해 codex/claude 주장과 retraction을 모두 사실검증 후 취합.
**worker**: claude-main(의미·규칙 레이어), codex-main(파일·파서 레이어), orchestrator(레이어 분담 설계·인용 직접 재대조·취합)

## [2026-05-25] [autokakao-dup-guard]
**교훈**: 안전장치 코드의 codex-critic 비평을 반영할 때, Orchestrator가 비평을 **직접 재현 검증**하면(순수함수=단위테스트로, 구조적 결함=정적 grep/인덱스 비교로) 2차 worker 검수 호출 없이도 루프를 신뢰성 있게 종료할 수 있다 — 비평 맹신·맹기각 둘 다 회피. 이번엔 #3(정규화 충돌 `verify_room('스터디 2','스터디')=True`)을 단위로, #2(제목 후보 수집범위=메인창 전체→거짓양성)·#1(Enter가 포커스검증보다 먼저)을 정적으로 재현해 진성임을 확정하고, v2도 같은 방식으로 재검증(9케이스+정적 8항목 PASS) 후 사용자가 2차 검수 대신 수락. 더불어 안전장치는 **미확정 의존성(여기선 열린 방 헤더 AX 위치)을 파라미터+TODO로 외부화하고 미설정 기본값을 fail-closed**(전부 거부)로 두면, 라이브 검증 전 단계에서 절대 오발송이 안 나는 안전한 중간 산출물이 된다.
**근거**: codex High 3건이 모두 진성이었고 Orchestrator 재현으로 확정. read_open_room_title이 expected와 일치하는 후보를 메인창 어디서든 신뢰하던 v1은 "거짓 음성 방향" 주장과 달리 거짓 양성(오발송) 경로였음 — worker 자기평가도 never-trust-upstream로 교차검증해야 함. v2는 HEADER_* 미설정=항상 None=fail-closed로 안전하게 게이트.
**worker**: claude-main(구현·v2 반영), codex-critic(High3 비평), orchestrator(비평 직접 재현검증·fail-closed 수락 판단)

## [2026-05-25] [autokakao-jobs-demo]
**교훈**: 외부 GUI 자동화에서 "설계 단계의 가정"은 **라이브 테스트 전까지 미검증**으로 취급하라. 동명이인 안전장치를 브레인스토밍 때 전략 A(열린 방 헤더 제목 읽기)로 골랐지만, 라이브 probe 결과 KakaoTalk이 단일 창이라 헤더가 구분 가능한 AX 요소로 노출되지 않아 A는 원천 불가였다. 진짜 해법은 라이브 probe가 알려줬다 — ⌘F 검색 결과 셀(AXCell)의 `AXSelected`로 하이라이트를 읽어, room_title과 정확 일치하는 결과가 선택될 때까지 ↓ 후 Enter(전략 B). "첫 결과 ↓1회+Enter"는 '테스트' 검색이 '테스트1234'를 먼저 열어 오발송함을 라이브로 실증. 즉 GUI 자동화는 (1) 설계 가정에 과투자 말고 빨리 라이브 probe로 실제 AX 구조를 확인하고, (2) 안전장치는 '열고 나서 검증'(abort만 가능)보다 '정확한 대상을 애초에 선택'(B)이 더 강하다.
**근거**: 헤더 probe가 메인창 단일 창만 찾고(별도 창 없음) 열린 방 제목을 단일 요소로 못 줌. 반면 검색결과 probe에서 ↓1=테스트1234 selected, ↓2=테스트 selected가 깔끔히 노출돼 전략 B가 바로 구현됨. staging→--send 2/2 성공.
**worker**: orchestrator(라이브 probe·전략 전환·전략 B 구현), gemini(영수증·회의록 비전 정리)

## [2026-06-01] [harness-vup-reentry]
**교훈**: 외부 레퍼런스(harness)를 시스템에 도입하는 v-up에서, 6패턴을 통째로 받지 말고 **이 시스템 불변식으로 환원되는 것만 흡수하고 충돌하는 것은 "배제 근거를 design-basis(D6)에 명문화"**하는 방식이 정체성을 지킨다 — Pipeline/Fan-out·in/Expert Pool/Producer-Reviewer는 흡수(대부분 기존 암묵 구현, Fan-in 충돌해소만 신규), Supervisor·Hierarchical은 단일 orchestrator·worker간 무통신·file-as-memory와 충돌해 배제. codex-critic adversarial 리뷰가 진성 결함 2건(치명)을 잡음: ①재진입 분기를 result.md 유무로만 판단하면 status=waiting_<role>·늦은 응답·status↔log 불일치·외부 write_scope 재승인을 놓침 → 재정박에 brief+status 추가·분기 확장으로 해소, ②신설 불변식(INV11)의 grep이 `grep -lin`이라 "둘 중 하나만 맞아도 통과" → per-file `grep -q`+4패턴 positive+배제 negative check로 자동 FAIL 판정 가능하게 교정. 배제 근거 문구도 "Supervisor 개념 배제"가 아니라 "기존 orchestrator 위에 별도 long-lived 조정자/재귀 위임 **계층 추가**를 배제"로 정밀화해야 정확(orchestrator 자신이 이미 중앙 조정자이므로).
**근거**: orchestrator가 critic ISSUE 6건을 사실검증(never-trust-upstream을 리뷰어에도 적용) → #3만 PASS, 5건 진성 → 전부 반영. 자가점검 INV11a/b/c 신규 PASS, INV1~10 회귀 없음. 새 상시로드 비용은 CLAUDE.md 1줄 포인터뿐, 본문은 orchestrator-rules(온디맨드)·routing(라우팅시)·design-basis/invariants(게이트)에 배치.
**worker**: orchestrator(흡수/배제 설계·라이브 파일 편집·ISSUE 사실검증·자가점검), codex-critic(변경안 adversarial 리뷰 5 ISSUE)

## [2026-06-01] [model-policy-cleanup]
문서 일관성 변경(예: 모델 버전 문자열 → 별칭화)은 "정책 섹션"만 고치면 안 된다. 같은 식별자가 워커 상세·비용 설명·예시 등 여러 위치에 흩어져 있어, 한 곳만 바꾸면 같은 파일 안에서 정책↔본문이 모순된다. codex-critic이 routing.md의 잔존 핀(:62 claude-opus-4-7, :65 Opus 4.7, :120 gpt-5.4-mini)을 잡았다. → 표기 정책을 바꿀 땐 `grep`으로 그 식별자의 전 등장 위치를 먼저 훑고 일괄 처리할 것. 또한 "결정적/영속" 같은 단정어는 환경 설정(config·env·profile)으로 바뀔 수 있는 값엔 과장이므로 피한다.

## [2026-06-02] [gemini-backend-agy]
"pro-high 쓰지 마라"(D4/INV9) 같은 **환경 한계발 금지 규칙**은 그 환경(백엔드)이 바뀌면 근거가 사라진다. pro-high 제외 사유는 옛 antigravity-claude-proxy의 `400 INVALID_ARGUMENT`였는데, 백엔드를 `agy` CLI로 바꾸니 pro-high가 정상 작동(spike 실증). → 금지 규칙엔 **"무엇 때문에 금지인지(원인 계층)"를 함께 적어야**, 원인이 사라졌을 때 안전하게 해제할 수 있다. 또 모델 셀렉션이 도구마다 다름을 확인: agy는 모델이 **전역·계정단위**(`/model`)라 per-call 핀 불가 → worker별 다른 모델 동시 사용은 안 되고, gemini 전용 전역을 pro-high로 고정해 운용. 마이그레이션은 D4·INV9·INV10·routing·validate C6를 **한 묶음으로** 갱신해야 내부 모순(validate가 새 정본을 FAIL)이 안 생긴다.
**근거**: agy spike S1 GREEN + 3자 검수(codex #8이 "옛 정책과 충돌" 지적 → 검증하니 정책을 갱신해야 하는 것이었음). backends.json이 gemini 호출 정본, mcp__gemini-pro__/mcp__gemini__ 브리지 폐기.
**worker**: orchestrator(마이그레이션·라이브 편집), codex-critic+gemini=agy(검수)

- [2026-07-09] **HARD-STOP은 Slack 병행 발사가 필수 실행단계**: AskUserQuestion(터미널)만으로 끝내면 정책 위반(2026-07-09 실제 누락). 매 HARD-STOP에 `slack_send_message(C0BGH4K5LL8, 질문)` + `_shared/adapters/notify.sh "요약"`(loud ping) 둘 다 쏜 뒤 답장 수용(터미널·Slack 무관). 인프라는 검증됨(webhook→채널 도착, MCP 읽기 정상) — 유일 실패모드는 "안 쏘는 것". 정본 approval-policy.md §원격승인알림.

- [2026-07-09] **스택 PR 머지: base 브랜치 삭제 전에 종속 PR을 먼저 재타겟하라.** GitHub는 PR의 base 브랜치가 삭제되면 그 PR을 자동 재타겟이 아니라 **CLOSED**(재오픈 불가) 처리한다(gh pr merge --delete-branch 연쇄). 선형 스택(A→B→C→main) 머지 시: ①맨 아래부터 머지하되 ②다음 PR의 base를 main으로 **먼저** `gh pr edit N --base main` 재타겟한 뒤 아래 브랜치 삭제. 닫힌 PR은 같은 head로 새 PR 재생성해 복구. 또 `gh`는 **cwd의 git remote**로 repo를 판단 → 다른 repo(오케스트레이터 폴더)에서 실행하면 엉뚱한 repo를 봄, `--repo OWNER/NAME` 명시가 안전.

## 링크 존재 검증은 쿼리/프래그먼트 허용해야 (webtool-e2, 260712)
이중언어(EN/KO) 페이지의 내부 링크가 `?lang=en`/`?lang=ko` 쿼리를 달고 있어, orchestrator의 크로스링크 검증기가 정확일치(`/guide/nutrition/`)로 보면 **거짓 FAIL**을 낸다. 링크 존재/깨짐 검증 시 href에서 `[?#].*` 제거 후 매칭할 것. 워커 자기보고(3/3)를 실측이 뒤집는 듯 보였으나, 실제는 검증기 결함 → 재검으로 PASS 확정. 교훈: 워커 주장과 검증이 충돌하면 검증기 자체를 먼저 의심(never-trust 양방향).

## [2026-07-15] [responsive-verify-cdp]
반응형(모바일) 오버플로우 검증에 headless Chrome `--window-size=390` **스크린샷은 신뢰하지 마라** — 진짜 디바이스 에뮬레이션이 아니라 넓은 레이아웃 뷰포트로 렌더 후 크롭돼 "콘텐츠 우측 잘림" 아티팩트를 만든다(실측: 미디어쿼리는 적용되나 콘텐츠가 잘려 보임). 진짜 판정은 **CDP `Emulation.setDeviceMetricsOverride({width, mobile:true, deviceScaleFactor:2})` 후 `Runtime.evaluate`로 `documentElement.scrollWidth` vs `clientWidth` + 오버플로우 요소 나열**, 스크린샷도 CDP `Page.captureScreenshot`로. node25 global WebSocket로 의존성 0 CDP 클라이언트 작성 가능(scratchpad measure.mjs/shot.mjs 참고).
**근거**: noi-works-home-design 웨이브에서 --window-size 스샷이 모바일 오버플로우를 오탐→box-sizing 등 헛수정. CDP 실측(vw390·docSW390·offenders[])으로 오버플로우 부재 확정, codex-critic 코드판정이 옳았음을 검증. 브라우저 확장(claude-in-chrome) 탭그룹 반복 소실로 대체 경로 필요했던 정황도 동일 결론.
**worker**: orchestrator(라이브 검증), claude-main=general-purpose(빌드), codex-critic(코드비평), gemini=agy(시각비평)

## [2026-07-17] [shared-worktree-branch-drift]
사용자가 **같은 repo 작업트리에서 병행 작업**(raceplanner: 오케스트레이터 feature 브랜치 vs 사용자 product-DB `fueling-db-schema`)하면, 내가 커밋·푸시한 뒤에도 **작업트리 브랜치가 나 모르게 바뀔 수 있다**. 실제로 healthkit-fitness 커밋(d814855) 직후 사용자가 fueling-db-schema로 checkout→제품DB 커밋 4개를 쌓았고, 실기기에 그 브랜치 JS가 서빙돼 "피트니스 버튼 없음"으로 나타남(코드 문제로 오인하기 쉬움). → **디바이스/브라우저에 뜬 것이 예상과 다르면 코드부터 의심하지 말고 `git branch --show-current`·reflog·Metro 서빙 경로부터 확인**. 브랜치 전환이 필요하면 (1)사용자 커밋·stash 무결 먼저 확인 (2)내 빌드가 남긴 미커밋(expo prebuild의 package.json 자동수정 등)만 원복 (3)전환→테스트→**원 브랜치 복귀**를 한 묶음으로. Xcode 툴바의 브랜치 이름표가 실제 HEAD를 보여줬는데 "cosmetic"으로 넘긴 게 초기 오판이었음.
**부수 교훈(무료 iOS 실기기 dev build)**: `expo run:ios --device <udid>` = 개인팀(무료 Apple ID) 서명이면 (a)Xcode Accounts 로그인+Signing&Capabilities에서 Team 지정은 **사용자 수기**(자격증명이라 대행 불가) (b)codesign이 키체인 접근에서 **SecurityAgent 팝업으로 무한 대기** → "항상 허용" 눌러야 진행(pgrep SecurityAgent+codesign으로 감지 가능) (c)설치 후 iOS가 "개발자 신뢰"(설정>일반>VPN 및 기기 관리) 전엔 실행 거부. native dep 0 변경은 기존 바이너리에 JS만 핫스왑돼 재빌드 불필요.
**worker**: orchestrator 단독(실기기 배포·검증)

## [2026-07-17] [multiagent-v2-research·build]
**워커가 우리 자신의 log.md를 인용하면 그 로그의 *행위 주체*를 확인하라.** claude-main이 2026-07-15 오버플로우 오탐을 "gemini 비전의 실패"로 귀속했고 orchestrator가 검증 없이 채택해 사용자 보고까지 나갔다. 실제 로그: gemini는 오버플로우를 **판정한 적이 없고**(abstain한 건 codex-critic), 오탐 주체는 **orchestrator 자신의 `--window-size` 스크린샷 해석**이었다. 자기 오류를 남의 것으로 읽을 때 방어기제가 작동하지 않는다 — codex-critic이 잡았다. never-trust-upstream의 사각지대는 **자기 로그**다.
**denylist 가드는 원리적으로 진다.** 워커 쓰기 차단을 denylist(리다이렉션·sed -i·rm…)로 짰더니 `python3 -c open(w)`·`node -e writeFileSync`·`>|`·`/usr/bin/touch`·`eval "$(base64 -d)"`·`curl -o`·`rsync`가 전부 통과(codex-critic 실측 7종). allowlist로 뒤집어야 실패 모드가 "조용히 뚫림"→"과차단"이 된다. 과차단은 복구 가능(워커가 result에 적고 orchestrator가 실행)하나 미탐은 정책을 소리 없이 무너뜨린다.
**`git add -A`는 웨이브 커밋에서 금지에 가깝다.** 세션 최초 `git status`에서 `?? .venv/`를 보고 사용자에게 보고까지 해놓고 `git add -A`로 1,498파일·277,270줄을 커밋했다. 경로를 명시해 스테이징하거나, 최소한 커밋 전 `git diff --cached --stat | tail -1`로 규모를 볼 것.
**측정 도구의 판정 근거는 ground truth 하나로 좁혀라.** M1 오버플로우 판정에 `documentElement.scrollWidth`와 `getBoundingClientRect` 기반 offender 목록을 OR로 묶었더니, 부모 `overflow:hidden`에 클립된 장식요소가 정상 UI를 반려시켰다. rect는 부모 클립을 모른다 → scrollWidth만 판정, offender는 진단정보로 강등.
**자가점검 스크립트는 일부러 깨서 검증하라.** INV15 초판은 정규식이 `` - `sandbox`: `` 표기만 잡아 `**sandbox**:`·표·산문을 놓쳤고, `jq select`는 값이 틀려도 exit 0이라 false-PASS였다. "PASS 문자열이 보이는지 사람이 눈으로" 확인하는 점검은 점검이 아니다.
**worker**: claude-main(목적1 리서치·목적2 설계), gemini=agy(제3자 디자인 진단), codex-critic(적대적 비평 2회 — 리서치안 4건 반려 + 구현 NO-GO 5건). orchestrator(실측·구현·자기정정 3회)

## [2026-07-17] [parallel-session-collision]
사용자가 **다른 세션에서 같은 repo 작업트리에 실시간 커밋 중**일 때 내가 그 브랜치에 git 수술(cherry-pick·amend)을 하면 충돌한다. 실제: fueling-db-schema에 피트니스(#20)·CP토글(#21)을 cherry-pick하는 사이 사용자가 병행 커밋(368ee9f→c37ec98→e623069)을 쌓았고, 내 `git commit --amend`가 **엉뚱하게 사용자의 최신 커밋(e623069)을 amend**해버림(HEAD가 그새 이동). 다행히 내용 유실은 없었으나(내 index.tsx 수정이 사용자 커밋에 흡수) 남의 커밋 해시를 재작성한 셈 → 위험. 또 cherry-pick 충돌 블록을 **전부 grep 안 하고** 하나만 고쳐 마커째 커밋(f56f120에 마커 3줄 잔존)하는 실수도 겹침.
**교훈**: (1) 공유 작업트리 브랜치에 수술 전 "지금 다른 세션에서 작업 중인지" 먼저 확인하고, 병행 중이면 **격리 worktree로만** 하거나 사용자에게 그 세션 중단을 요청. (2) `--amend`/`reset`처럼 HEAD 재작성 명령은 병행 세션에선 특히 금물(HEAD가 내 밑에서 이동). (3) cherry-pick/merge 충돌 해결 시 반드시 `grep -c '^<<<<<<<'`로 **전체 블록 수**를 세고 다 해결했는지 커밋 전 재검(`git show HEAD:file | grep -c 마커`). backup ref도 최신 HEAD로(내가 85a2d57로 스테일하게 잡음).
**부수(네이티브 dep)**: 사용자가 react-native-webview 추가 → 기존 dev build엔 `RNCWebViewModule` 없음 → `TurboModuleRegistry.getEnforcing` Invariant Violation 크래시(+ErrorBoundary/default-export 연쇄). JS만 바뀌면 리로드, **새 네이티브 모듈이면 `expo run:ios --device` 재빌드 필수**. 판별: Metro 로그의 `could not be found ... registered in the native binary`.
**worker**: orchestrator 단독(실기기·git)

## [2026-07-17] [clipper-rebrand]
**문자열 인벤토리 DoD에 `grep -I`를 쓰면 바이너리 메타데이터를 통째로 놓친다.** D1("브랜드 참조 0건")을 codex-main도 orchestrator도 `grep -rIiE`로 측정해 **양쪽 다 "529→0 PASS"라는 동일한 오판**에 도달했다. 실제로는 PNG 6개 XMP에 `<pdf:Author>Timjipraks</pdf:Author>`가 살아 있었고, codex-critic이 잡았다. 핵심은 도구가 아니라 구조다 — **공유 맹점은 자기검증으로 못 깬다**. 검증자가 검증 대상과 같은 방법을 쓰면 독립성이 0이다. 리브랜딩·시크릿 스캔류 DoD는 `grep -a`(바이너리 포함)를 명시하고, 검증자에게는 *다른 방법*을 지시할 것.
**갓 생성된 repo의 첫 스냅샷을 결론으로 쓰지 마라.** "README 1개뿐인 빈 껍데기"라고 사용자에게 보고했으나, 8분 뒤 `Add files via upload`로 100파일이 들어왔다(내 조회가 그 사이였음). 생성 직후 repo는 *채워지는 중*일 수 있다. 사용자의 "다시 확인해줘" 3회가 없었으면 오보가 그대로 굳었다 — **사용자가 같은 요청을 반복하면 내 관측이 틀렸을 확률을 먼저 의심**할 것.
**시크릿 스테이징 가드가 삭제를 유출로 오탐한다.** `git status | grep -iE 'cookies'`가 **삭제되는 문서**(`COOKIES.md`)에 매칭돼 2회 연속 false "LEAK ✗". 파일명 매칭은 (1)`--diff-filter=d`로 삭제 제외 (2)`grep -x` 정확일치 (3)내용 기반. 오탐 가드는 진짜 유출 때 무시하게 만들어 더 위험하다.
**DoD를 실패했을 때 DoD를 고치는 선택지는 반드시 사용자에게 올려라.** PNG 메타데이터가 D1에 걸렸을 때 "저작자 메타데이터는 예외로 하자"는 기술적으로 타당했으나 **내가 세운 기준을 실패 후 내가 완화하는 것**이었다. 골대 이동임을 명시하고 3안(제거/예외/자산교체)으로 올렸더니 사용자는 내 추천(예외)이 아니라 **교체**를 골랐다 — 삭제도 완화도 아닌 길이 있었다. 자기 기준을 자기가 못 고치게 하는 게 요점.
**brief의 지시와 sandbox 설정은 정합해야 한다.** codex-critic에 `sandbox=read-only`를 주고 brief엔 "result.md 작성"을 지시 → 워커가 판정을 내고도 기록하지 못해 `patch rejected`. CLAUDE.md상 codex-critic=`write_scope: none`(Orchestrator 경유)이 정본이므로 **brief에서 쓰기 지시를 빼는 게** 맞다.
**MIT 리브랜딩의 실제 관문은 라이선스가 아니라 인프라 탯줄이다.** LICENSE 병기는 5분이면 끝났고, 실제 작업량은 원저자 폰홈(`api.ytclip.org` 업데이트 체크)·유료 API 프로바이더·수익화 훅 3종 제거였다. "이름 바꾸기"로 접근하면 남의 서버를 계속 호출하는 앱이 우리 브랜드로 나간다.
**부수(환경)**: CustomTkinter GUI 앱 검증엔 **tkinter 포함 Python**이 필요한데 pyenv 빌드는 기본적으로 `_tkinter` 없이 만들어진다(3.11.13 실측). `brew install python-tk@3.11`로 해소. GUI 기동 검증은 `App(); a.after(3000, a.destroy); a.mainloop()` 하네스로 자동 종료 가능 — 창 구성 단계에서 깨진 import·자산 경로가 전부 드러난다. `screencapture -R`은 화면 기록 권한 없으면 `could not create image from rect`로 실패(육안 검증은 사람 게이트로).
**worker**: codex-main(리브랜딩 구현·D2 미완료를 정직하게 표면화), codex-critic(적대적 리뷰 — NO-GO 1건, 양측 공유 맹점 적발). orchestrator(LICENSE·NOTICE·.gitignore·아이콘 6종 자체제작·D2 실측·자기정정 1회)

## [2026-07-17] [multiagent-v2 · selfcheck · design-trial]

**never-trust-upstream의 사각지대는 *자기 로그*다.** claude-main이 2026-07-15 오버플로우 오탐을 "gemini 비전의 실패"로 귀속했고 나는 검증 없이 채택해 사용자 보고까지 냈다. 실제 로그: gemini는 그 사안을 **판정한 적이 없고**(abstain은 codex-critic), 오탐 주체는 **내 `--window-size` 스크린샷 해석**이었다. codex-critic이 잡았다. 워커가 우리 log.md를 인용하면 **그 로그의 행위 주체를 확인하라** — 자기 오류를 남의 것으로 읽을 때 방어기제가 작동하지 않는다.

**n=1로 규칙을 만들지 마라 — 이 세션에서 그 함정 앞까지 갔다.** 디자인 모드 통제실험 R1에서 "스킬 단독은 baseline보다 해롭다"(정량 3/5 악화 + 블라인드 꼴찌)를 강하게 보고하고 routing 반영을 시사했다. **R2가 정면 반증**: 같은 조건·같은 brief인데 블라인드 순위가 **완전 역전**(B 꼴찌→1위, A 2위→꼴찌). ⇒ arm당 n=1에서 미적 평가는 **조건 효과가 아니라 출력 분산이 지배**한다. 살아남은 결론은 "계약은 시킨 것을 시킨 대로 시킨다"(font-size 정확히 4단계, 2/2 재현)뿐 — **"규율 → 아름다움"은 여전히 미검증.** 사용자가 반복을 지시하지 않았으면 근거 없는 규칙이 박혔다.

**"선언은 있는데 구현이 없다"는 조용히 6주를 산다.** `backends.json`이 2026-06-02부터 gemini `api` 폴백을 선언했으나 `gemini_api.sh`는 "슬롯만 정의됨" 스텁이라 무조건 exit 4였다. 디스패처의 "GEMINI_API_KEY 미설정 → 폴백 불가" 경고는 **키를 설정해도 참**인 이중 거짓이었고, agy 쿼터가 소진되고 나서야 발각됐다. **정본 모순(D11)도 같은 병**이다 — backends `read-only` ↔ routing `workspace-write`가 디스패처 `die` 뒤에 무증상 잠복. ⇒ 선언한 폴백·계약은 **자가점검이 실물인지 확인**해야 한다(self-check에 추가함).

**denylist 가드는 원리적으로 진다.** 워커 쓰기 차단을 denylist로 짰더니 `python3 -c open(w)`·`node -e writeFileSync`·`>|`·`/usr/bin/touch`·`eval "$(base64 -d)"`·`curl -o`·`rsync`가 전부 통과(codex-critic 실측 7종). **allowlist로 뒤집어야** 실패 모드가 "조용히 뚫림"→"과차단"이 된다. 과차단은 복구 가능(워커가 result에 적고 orchestrator가 실행)하나 미탐은 정책을 소리 없이 무너뜨린다. 단 그래도 **적대적 샌드박스는 아니다** — 허용 명령(`pnpm test`)의 간접 쓰기는 설계상 남는다.

**점검·검증은 반드시 일부러 깨서 확인하라.** INV15 초판은 `jq select`가 값이 틀려도 exit 0이라 false-PASS였고, 내 깨뜨림 검증 1차는 **zsh가 `$SC`를 단어분할하지 않아** command-not-found로 죽은 exit code를 "탐지"로 오독해 9/9 가짜 통과였다(고치려던 결함 그 자체). "PASS 문자열이 보이니 됐다"는 점검이 아니다. **CI 게이트도 음성 대조군으로 확인**하라 — 일부러 깬 PR이 red 나는 걸 봐야 게이트가 실물이다.

**`git add -A`는 웨이브 커밋에서 금지에 가깝다.** 세션 최초 `git status`에서 `?? .venv/`를 보고 사용자에게 보고까지 해놓고 `git add -A`로 1,498파일·277,270줄을 커밋했다. 경로 명시 스테이징 + 커밋 전 `git diff --cached --stat | tail -1`로 규모 확인. **병행 세션이 같은 작업트리를 쓰면 남의 미커밋 작업까지 쓸어담는다**(실제 발생).

**측정 도구의 판정은 ground truth 하나로 좁히고, 임계값엔 표준 근거를 대라.** M1 오버플로우 판정에 `scrollWidth`와 `getBoundingClientRect` offender를 OR로 묶었더니 부모 `overflow:hidden`에 클립된 장식요소를 오탐 → 정상 UI 반려. 그런데 `scrollWidth`도 **클립된 컨테이너에서 계속 커진다** → 실효 `overflow-x`(CSS 전파: html이 visible이면 body로) 기준으로 재수정. 탭타겟 44px도 근거 없었다 — **웹 표준은 WCAG 2.2 AA 24px**, 44는 AAA/Apple HIG(네이티브). 실측 14건 중 12건이 AA 통과였다.

**agy CLI는 헤드리스에서 이미지를 못 읽는다.** `read_file` 권한을 프롬프트할 수 없어 자동 거부 → `--dangerously-skip-permissions` 필요. 2026-07-15의 1회 성공은 재현되지 않았다. **REST(`gemini_api.sh`)는 inline base64라 그 권한 협상이 없다** — 멀티모달 판정은 API 경로가 안정적. API 모델명은 agy 명명과 다르다(`gemini-3.1-pro-high` → `gemini-3.1-pro-preview`).

**worker**: claude-main(리서치 2 + 통제실험 6), gemini=agy/api(제3자 진단 + 블라인드 시각평가 2R), codex-critic(적대적 비평 2회 — 리서치안 4건 반려 + 구현 **NO-GO 5건**, 전부 타당). orchestrator(실측·구현·**자기정정 8회**)

## [2026-07-17] [grep-miscount-and-evidence-integrity]
**집계는 grep 한 방으로 끝내지 말고 모집단을 먼저 못박아라.** 같은 웨이브에서 동종 오류를 3번 냈다. ①`grep -i "fix"`가 제품명 `FIXX`("3 FIXX products")를 잡아 fix 커밋을 12개로 셈(실제 `^fix(` 11개). ②AI 인용 도메인 집계에서 `youtube.com`을 언론사로 분류해 8→9로 셈. ③`--all`(74)과 HEAD(63)를 섞을 뻔함. 교훈: 세는 대상은 **앵커 붙인 정규식**(`^fix\(`)으로, 분류는 **항목을 눈으로 나열**해서, 뺄셈은 **같은 모집단**에서. 그리고 `A - B = C`를 쓸 거면 `B + C == A` 검산을 반드시 출력할 것.
**적대적 검증자도 틀린다. 전제를 재검산하라.** codex-critic이 `rev-list HEAD --count`=74로 전제하고 "모집단 혼합" blocking 2건을 냈으나 실측 HEAD=63이었다. critic 지적 12건 중 11건은 타당했으나 최대 지적 2건이 무효였다. **NO-GO를 통째로 수용하는 것도, 통째로 무시하는 것도 게으르다** — 지적마다 명령을 돌려 판정하고, 기각할 땐 근거를 log에 남긴다.
**인용은 증거다. 줄이면 조작이다.** 초안이 커밋 메시지 2건을 잘라 인용하면서 "자르지 않고 그대로 옮기겠습니다"라고 썼다(`GPX read on SDK 54+ filesystem`에서 `+ open saved plans` 누락 등). git을 증거로 내세우는 글에서 git 인용을 손댄 셈. **규칙 충돌 시 해법은 "몰래 고치기"가 아니라 "고쳤다고 밝히기"** — em dash 금지(규칙1) vs 인용 왜곡 금지(규칙5)는 "원문의 대시 하나만 표기 규칙에 맞춰 쉼표로 바꿨고 나머지는 손대지 않았습니다"를 본문에 넣어 동시 충족했다.
**사용자 수정본은 diff부터 뜨고 파급을 좇아라.** 사용자가 도입부에서 "경영정보시스템"을 뺐는데 다음 문단이 그걸 계속 설명하고 있었다(붕 뜬 참조). 또 "IT 스타트업 5년 이상"은 PDF 재검산 결과 3년 11개월이었다. 사용자 편집도 검수 대상이다.
**브라우저 확장이 죽으면 CDP로 직접 몰아라.** claude-in-chrome이 탭그룹 경합·타임아웃으로 반복 실패 → 헤드리스 크롬 `--remote-debugging-port` + WebSocket CDP 직결로 우회해 Expo web 실화면 3장 캡처 성공(`_shared/tools/design-measure.mjs`와 동일 원리). RN web은 body가 아니라 내부 ScrollView가 스크롤하므로 `captureBeyondViewport`가 아니라 스크롤 컨테이너를 찾아 `scrollTop`을 옮겨야 한다.
**worker**: deep-research 하네스(107 에이전트·5.3M 토큰·확정10/기각15), codex-critic 2회(전략 NO-GO, 글 NO-GO), orchestrator(실측·집계·자기정정 3회)
**"안 먹었다"는 판정도 검증 대상이다.** BlogPost.astro에 이미지 CSS를 넣고 실측했더니 computed `max-height: none`이라 "규칙이 안 붙는다"고 오판하고 셀렉터·스코프를 파기 시작했다. 실제로는 `http-server`가 캐시한 옛 HTML을 재고 있었고 규칙은 처음부터 정확했다(`-c-1`로 캐시 끄니 즉시 적용). **측정이 부정 결과를 내면 대상보다 계측기를 먼저 의심하라.** 같은 세션에서 낸 4번째 자기오류이자, 앞의 3건(grep 오검출·모집단 혼합)과 같은 뿌리 — 한 번의 관측을 결론으로 승격시킨 것.

## [2026-07-17] [worker-sandbox · KI-2 2차완화]

**훅의 기본값은 fail-OPEN이다 — 안전장치가 자기 버그로 사라진다.** PreToolUse에서 **exit 2만 차단**이고 다른 non-zero는 *비차단* 에러다(툴이 그냥 진행). 실측: `ROOT` unbound로 가드가 죽자 **명령이 검사 없이 통과**했다. `ERR` 트랩은 `set -u` 위반을 못 잡고, 트랩을 대입문 뒤에 걸면 그 이전 크래시를 놓친다. ⇒ **`EXIT` 트랩을 스크립트 최상단에** 걸어 "판정을 못 냈으면 차단"을 강제하라. 의존성 실패도 같다 — `jq`가 없으면 tool_name이 빈 문자열이 되어 기본 분기로 떨어져 **allow**됐다. **판정 못 하면 차단**이 원칙.

**문자열 검사는 난독화를 원리적으로 못 잡는다 — 커널을 쓰라.** allowlist 가드가 `node -p`를 놓쳤는데(내 deny 규칙은 `node -e`만), 워커가 `String.fromCharCode`로 `fs`와 `/`를 난독화해 홈에 쓰려 하자 **seatbelt가 EPERM으로 막았다**(E2E 실측). `sandbox-exec -f prof.sb -D REPO=... /bin/bash -c "$(printf %q "$cmd")"` — 훅이 `updatedInput`으로 명령을 **재작성할 수 있다**(실측 확인). 계층 방어: 훅이 의도를 보고, 커널이 결과를 막는다.

**`isolation: worktree`는 gitignored 자산이 있으면 못 쓴다.** 워커 격리에 하네스 네이티브 worktree를 쓰려 했으나, worktree엔 `tasks/`가 없어(gitignored) **워커가 brief 자체를 못 읽는다**. 격리 수단을 고를 때 **워커의 입력이 추적 대상인지 먼저 확인**하라.

**보안 강화가 역할을 죽이면 자충수다.** `write_scope: none`을 문자 그대로 강제하면(전 쓰기 차단) `pnpm test`가 캐시를 못 써 죽고 워커가 자기 코드를 검증하지 못한다 → 틀린 코드를 더 많이 반환. codex-critic이 지적한 *"역할 불변 vs 전 쓰기 차단"* 모순. **repo+tmp만 허용**이 실용적 타협 — 밖은 커널이 막고 워커는 산다. 단 **repo 안 쓰기는 남는다**(커널은 캐시와 소스를 구분 못 함) → KI-2는 여전히 열림. **완화를 해소로 부르지 말 것.**

**zsh는 변수를 단어분할하지 않는다 — 이 세션에서 3번 당했다.** `out=$($CMD)` / `set -- $pair` / `sandbox-exec ... $SBX`가 전부 조용히 오작동했고, 그중 하나는 **깨뜨림 검증 9/9를 가짜 통과**로 만들었다(command-not-found의 exit code를 "탐지"로 오독). bash 스크립트를 zsh에서 테스트할 때는 **함수로 감싸거나 `bash -c`로 명시**하라.

**worker**: claude-main(E2E 가드 프로브 — 자기 한계까지 정직하게 보고), orchestrator(실측·구현·자기정정 2회)
