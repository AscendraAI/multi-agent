# Changelog

이 파일은 MultiAgent orchestration 시스템의 주요 변경을 기록한다.
형식은 [Keep a Changelog](https://keepachangelog.com/), 버전은 [Semantic Versioning](https://semver.org/lang/ko/)을 따른다.

## [1.4.0] - 2026-07-18

자가점검을 규약에서 실행으로(G7), gemini API 폴백 실구현, 워커 쓰기의 커널 레벨 제한.
공통 주제: **"선언은 있는데 구현이 없다"를 실물로 메운다.**

### Added
- **자가점검 자동화 (G7)** — `_shared/tools/self-check.sh`(INV1~15 + 구조위생, **exit code가 판정**) · `selfcheck-hook.sh`(시스템 파일 변경 세션에서만 발동하는 Stop 훅, fail-open 알림) · `.github/workflows/self-check.yml`(PR·main push CI 게이트, 어댑터 실행권한·워커 가드 회귀 18종·추적금지 파일 검사). `system-invariants.md`는 D11에 따라 스크립트 본문 126줄을 포인터로 교체(표=정의, 스크립트=검사). 음성 대조군으로 CI가 깨진 PR을 실제 red 처리함을 실증.
- **gemini API 폴백 실구현** — `gemini_api.sh`가 2026-06-02부터 "슬롯만 정의됨" 스텁이라 무조건 exit 4였다(선언≠구현). 실제 Gemini REST(`generateContent`) + **이미지 자동 첨부**(brief 본문의 절대경로를 inline base64로 — agy CLI는 헤드리스에서 `read_file` 권한 자동거부로 이미지를 못 읽는다). 시크릿은 `_local/gemini-api-key`(gitignored, env 우선). agy 쿼터 소진 시 디스패처가 api로 자동 폴백(E2E 확인).
- **워커 쓰기 커널 제한 (KI-2 2차 완화)** — `worker-sandbox.sb`(seatbelt 프로파일: 읽기·실행 자유, 쓰기만 repo·TMPDIR·/tmp·/dev로 제한) + 가드가 allowlist 통과 명령을 `sandbox-exec`로 래핑. 문자열 검사가 못 잡는 **난독화 쓰기**를 커널이 EPERM으로 차단(E2E: `String.fromCharCode` 우회 실패). 가드에 **fail-closed** EXIT 트랩(크래시·jq부재 시 deny — 그전엔 조용히 통과).

### Fixed
- **design-measure.mjs 오탐/미탐 2건** — M1 오버플로우 판정을 `scrollWidth`(클립된 컨테이너에서도 커짐)에서 **실효 `overflow-x`**(CSS 전파) 기준으로. 탭타겟 임계값 44px(AAA/HIG)를 표준 근거별 2등급으로(WCAG 2.2 AA 24px = 결함 / 24~44 = 참고).
- **backends.json 폴백 모델명** — `gemini-3.1-pro-high`(agy CLI 전용 명명, API에 부존재) → `gemini-3.1-pro-preview`.

### Notes
- **KI-2는 여전히 열림** — 커널은 캐시(`node_modules/.cache`)와 소스(`src/`)를 같은 "repo 쓰기"로 본다. repo 안 쓰기는 남는다. 범위 축소이지 해소 아님.
- **디자인 모드는 실험적** — 통제실험 2라운드에서 "계약은 규율을 준다"(2/2)는 재현됐으나 "규율 → 미적 품질"은 미검증(R1·R2 블라인드 순위 역전). routing 반영 보류.

## [1.3.0] - 2026-07-17

자율 운용 전환(D9·D10) 백필 + 정본 소유 규칙(D11) 신설. 1.2.2 이후 미기록분을 함께 정리한다.

### Added
- **D11 정본 소유 규칙 + INV15** — 사실의 *종류별* 단일 소유를 명문화. 호출 기전(`call_type`·`sandbox`·`approval-policy`·`model`·`timeout`·`fallbacks`)은 `_shared/backends.json`, 역할·선택 정책·토폴로지는 `_shared/routing.md`가 유일 정본. routing은 기전 값을 재기술하지 않고 포인터만 둔다. 모순 시 "높은 문서가 이긴다"가 아니라 "그 종류를 소유한 파일이 이긴다". D4(gemini 한정)의 일반화. (`tasks/multiagent-v2-build/`)
- **`_shared/autonomy-policy.md` + D10 + INV14** — 승인 단위를 스텝 → **결과 위험도 티어**(AUTO 무프롬프트 / HARD-STOP 6트리거)로 전환. 승인은 **웨이브 1회 배치**, 사람 게이트는 **PR/diff 리뷰 하나**. 권위 슬롯: CLAUDE.md > autonomy-policy > routing/approval/orchestrator-rules.
- **원격 승인 알림 (D9 + INV13)** — 승인 요청 시 Slack DM + 폰 푸시 병행, `ScheduleWakeup` 폴링으로 원격 답장 수용. **best-effort 보조 채널** — 미가용 시 터미널 승인으로 폴백(알림 실패가 작업을 막지 않음). 정본은 `approval-policy.md` "원격 승인 알림" 절.
- **`_shared/adapters/notify.sh`** — Slack Incoming Webhook loud-ping 액터. self-message가 푸시를 못 띄우는 문제 때문에 도입, `@멘션` 프리픽스 + `link_names`로 푸시 강제.
- **`HANDOFF.md`** — 랩탑 간 재개 절차(클론·피처브랜치 체크아웃·CC 유저메모리 이관 포함).

### Changed
- **`.claude/settings.json` `defaultMode: bypassPermissions`** — 원격 자율 운용에서 하네스 프롬프트를 제거. AUTO 티어 허용목록도 함께 정렬. ⚠️ 이로써 **프롬프트라는 마지막 그물이 사라졌다** — `write_scope`는 현재 산문으로만 강제되며 기계적 경계가 없다(알려진 공백, `KNOWN_ISSUES.md` KI-2).

### Fixed
- **backends.json ↔ routing.md 정본 모순** — `codex-main`이 backends에선 `sandbox: read-only`·`approval-policy: never`, routing에선 `workspace-write 고정`·`on-failure 권장`이었다. backends를 따르면 codex-main이 **자기 존재 이유(`tasks/<task>/` 산출물 작성)를 수행할 수 없다.** 디스패처가 `native|mcp`를 `die`시켜(`call_worker.sh:61`) 런타임에 안 읽혔기에 **무증상 잠복**했고 어느 INV도 이 쌍을 검사하지 않았다. D11에 따라 backends 값을 설계 의도(`workspace-write`/`on-failure`)로 정정하고 routing의 중복 게재를 포인터로 대체. INV15가 재발을 막는다.
- **`_shared/adapters/call_worker.sh`·`gemini_api.sh` 실행 권한 부재** — `rw-r--r--`로 `./call_worker.sh` 직행이 `permission denied`. `chmod +x`(mode 100644→100755). 실제로 2026-07-17 리서치 웨이브에서 디스패처 호출이 막혔다.

## [1.2.2] - 2026-07-04

### Fixed
- **gemini 워커 폴백 실패 사유 유실** — 디스패처(`call_worker.sh`)가 api 폴백의 필수 env
  (`GEMINI_API_KEY`) 부재 시 실패 사유 없이 죽던 문제를 에러 envelope 반환으로 수정,
  호출 시작 시 폴백 불가 사전 경고 추가.

### Changed
- routing.md gemini — 소스·다중파일 검토 인라인 필수(agy 헤드리스 300s 타임아웃 실측),
  폴백 조건(`GEMINI_API_KEY`) 명문화, 시간 제한 작업 전 경량 스모크 권장.

## [1.2.1] - 2026-07-03

### Fixed
- **gemini(agy) 워커 프롬프트 미전달 수정** — Antigravity CLI 1.0.16에서 `-p` 단축 플래그가
  제거되어 backends.json의 `args_template: ["-p", …]`가 프롬프트를 조용히 무시(모델 미호출·사용량 0).
  `["--prompt", …]`로 교정. 증상: gemini 워커가 온보딩 인사만 반환.

## [1.2.0] - 2026-06-28

### Added
- **opt-in goal 요금가드 배선(`--with-guard`)** — 설치 시 `--with-guard`를 주면 `.claude/settings.json`에
  Stop 훅(`coach --hook`)이 주입된다. `/goal` 자율 루프가 주간 사용량 한도에 닿으면 자동 정지(루프
  중에만 — `stop_hook_active` 게이트). 기본 미설치, 런타임 on/off=`coach guard on/off`. 정책은 `coach`
  (usage-coach, codexbar 의존)가 갖고 미설치·조회실패는 fail-open(작업 안 죽임).

## [1.1.0] - 2026-06-10

카파시(Karpathy) 4원칙을 층별로 도입. 기존 규칙과 충돌 없음(보강).

### Added
- **CLAUDE.md "운영 원칙 (Operating Principles)" 섹션** — 4원칙(Think Before Coding / Simplicity First / Surgical Changes / Goal-Driven Execution) verbatim 차용 + 층별 적용 규칙. Orchestrator 전용 풀버전.
- **`_templates/worker-brief.md` "Worker 행동 규약" 고정 블록** — 워커층 번역형: ②③ 그대로, ①은 가정 명시·표면화(워커는 one-shot이라 사용자 질문 채널 없음), ④는 오케스트레이터 전용.
- **`_templates/worker-result.md` 체크리스트 항목** — "가정·불일치가 Issues/Caveats에 표면화됨".
- **design-basis D8 / system-invariants INV12** — 층별 적용 결정 명문화 + 자가점검.
- **`NOTICE`** — 출처·라이선스 표기 (multica-ai/andrej-karpathy-skills, MIT 선언·LICENSE 파일 부재).

## [1.0.1] - 2026-06-01

모델·추론 정책 표기 정리(문서 patch). 동작 변경 없음.

### Changed
- **모델 식별자 별칭화** (`_shared/routing.md`): claude-main을 버전 문자열(`claude-opus-4-7` 등) 대신 별칭 `opus`로 표기 — 모델이 올라가도 문서 갱신 불필요. codex 예시 일반화, gemini는 `gemini-3.1-pro-low` 핀 유지 + "프록시 업그레이드 시에만 갱신" 노트.
- **claude-main 추론 강도(effort) 명문화**: `effort` 핀 없음 → 세션 `/effort` 상속(현 기본). 고정하려면 frontmatter `effort:`.

### Added
- **design-basis D7**: 모델 식별자 표기 정책(별칭 원칙 / gemini 핀 예외·세부는 D4 정본 / effort 비대칭 근거).

### Verification
- codex-critic adversarial 검수: 치명 0, 권장 3 반영(잔존 핀 제거 포함). INV9/INV10/INV11 PASS, 회귀 없음.

## [1.0.0] - 2026-06-01

첫 버전 태깅. 기존 실사용 시스템을 1.0.0 기준선으로 고정하고, harness(revfactory) 참고 버전 업그레이드를 함께 반영한다.

### Added
- **작업 재진입 프로토콜** (`_shared/orchestrator-rules.md` §3): 콜드세션이 끝난 작업에 다시 들어갈 때 재정박(re-anchor) → 6분기 판단 → 에러 후 진행. `status↔log 불일치`는 다른 분기보다 먼저 적용하는 정규화 단계로 명시.
- **토폴로지 4패턴표** (`_shared/routing.md`): Pipeline / Fan-out·Fan-in / Expert Pool / Producer-Reviewer + Fan-in 규칙.
- **CLAUDE.md** Task Lifecycle에 재진입 프로토콜 포인터.
- **불변식 INV11** (`_shared/system-invariants.md`): 재진입·토폴로지 규정 자동 자가점검(11a/b/c).
- **design-basis D6**: 4패턴 채택 + Supervisor·Hierarchical Delegation 배제 근거.

### Excluded (설계 결정)
- Supervisor·Hierarchical Delegation 패턴: 단일 orchestrator·worker간 무통신·file-as-memory와 충돌하여 미채택 (근거 D6).

### Baseline (1.0.0 시점 핵심 구조)
- 고정 4-worker pool (claude-main / codex-main / codex-critic / gemini), Claude Code 세션 = orchestrator.
- file-as-memory (런타임 상태 0): task / context / log / brief / result.
- 승인 게이트(`workers_approved`), 외부 쓰기 4조건, progressive disclosure(게이트 로드), 권위 우선순위(CLAUDE.md > routing/approval/orchestrator-rules > 매뉴얼).

### Verification
- 배선(INV11a/b/c) PASS · 회귀 없음, 탁상 분기 커버리지, 실전 콜드세션 3/3 PASS, codex-critic adversarial 리뷰 5 ISSUE 반영.

[1.0.1]: https://github.com/netwaif/multi-agent-starter/releases/tag/v1.0.1
[1.0.0]: https://github.com/netwaif/multi-agent-starter/releases/tag/v1.0.0
