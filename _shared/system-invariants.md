# System Invariants — 시스템 수정 후 자가 점검

> **로드 정책**: 평소 미로드. 시스템 파일 수정·검증 작업일 때만 (`orchestrator-rules.md` §2).
> 목적: 시스템 변경 후 **전면 멀티에이전트 재감사 대신** 이 점검만 돌려 모순 재발을 잡는다.
> 통과해야 커밋. 깨지면 고치거나, 의도된 변경이면 `design-basis.md` 결정(D*)·이 표를 함께 갱신.

## 불변식 목록

| ID | 불변식 | 깨지면 |
|---|---|---|
| INV1 | `write_scope` 값 집합이 CLAUDE.md(정의처)·routing.md·_templates/worker-brief.md·task-folder.md·매뉴얼에서 동일 (`none`/`tasks-only`/패턴) | D1 위반 — 어디든 한 곳만 다르면 시스템 자체 모순 |
| INV2 | codex-critic 선행조건에 "claude-main result.md 존재 필수" 같은 **전용 강제** 표현 없음 (일반화 표현이어야) | D2 위반 |
| INV3 | log 태그 = 정확히 `DECISION\|WORKER_CALL\|VERIFICATION\|ERROR\|APPROVAL\|COMPLETE` 6종 (_templates/log.md, 매뉴얼) | 파서·일관성 깨짐 |
| INV4 | context.md 한도 1500자, brief 한도 1200자 수치가 CLAUDE.md·매뉴얼·_templates 헤더에서 동일 | 한도 불일치 |
| INV5 | **(유지보수자 전용)** 외부 매뉴얼 메인 섹션 개수 == manual-repo `CLAUDE.md`의 메인 섹션 목록 개수 | 매뉴얼↔manual-repo 빌드 스펙 불일치 (현재 R3 미해소 시 의도적 FAIL) |
| INV6 | 매뉴얼 `workers_approved` 예시 스키마가 approval-policy.md와 일치 (`worker:`/date-only/`purpose:`/`approved_by:`, `HH:MM` 없음) | B1/B6 재발 |
| INV7 | 권위 우선순위 문구가 매뉴얼 §3과 design-basis.md §2에서 동일 (CLAUDE.md > routing/approval/orchestrator-rules > 매뉴얼) | Clash 해소 규칙 붕괴 |
| INV8 | (오케스트레이터 세션) 인터랙티브 전용 + worktree/백그라운드 세션 금지 규칙이 orchestrator-rules.md에 존재. 워커의 target_repo worktree 허용은 별개(D10) | D5 위반 |
| INV9 | gemini 백엔드가 `_shared/backends.json`에서 `agy` CLI(call_type cli·command agy)이고 기본 모델 `gemini-3.1-pro-high`, routing.md·D4가 backends를 정본으로 참조 | 정본이 폐기 프록시/known-bad 경로 호출 (D4 위반) |
| INV10 | 폐기 브리지 **`mcp__gemini__gemini_*`(CLI 래퍼) 및 `mcp__gemini-pro__*`(프록시)** 가 routing.md·task-folder.md·CLAUDE.md에 **활성 호출**로 없음. 잔여 언급은 **폐기 안내 문맥에서만** | C2 재발 — 폐기 브리지 잔존 호출이 즉시 실패 (D4 위반) |
| INV11 | 재진입 프로토콜이 orchestrator-rules.md §3 **와** CLAUDE.md Task Lifecycle 포인터에 **둘 다** 존재. routing.md 토폴로지표에 4패턴(Pipeline/Fan-out·in/Expert Pool/Producer-Reviewer) 모두 존재하고, Supervisor·Hierarchical은 "배제" 줄에만 등장(채택표 행으로 등장 금지) | D6 위반 — 재진입/패턴 규정 유실 또는 배제 패턴 부활 |
| INV12 | 카파시 4원칙: CLAUDE.md에 "운영 원칙 (Operating Principles)" 섹션 존재, _templates/worker-brief.md에 "Worker 행동 규약" 고정 블록 존재, **블록 안에 사용자질문 지시(질문/ask) 없음**, worker-result.md 체크리스트에 표면화 항목 존재 | D8 위반 — 층별 적용 붕괴(워커 one-shot 구조와 모순) 또는 워커 규약 유실 |
| INV13 | approval-policy.md 에 "원격 승인 알림" 절 존재 + `best-effort`/폴백 표현 있음(하드게이트로 변질 아님) | D9 위반 — 알림이 작업을 막는 하드 의존이 되거나 절 유실 |
| INV14 | autonomy-policy.md에 소비스 티어(AUTO/HARD-STOP)·PR 체크포인트·linear 기본/병렬=독립섬 절 존재 + design-basis §2 권위순위에 autonomy-policy 포함 | D10 위반 — 스텝단위 게이트 회귀/무제한 병렬/권위 슬롯 유실 |
| INV15 | **정본 소유 분리**: routing.md에 호출 기전 값(`sandbox:`/`approval-policy:`/`call_type:`/`args_template:`)의 **재기술이 없음**(포인터·효과 설명은 허용) + backends.json의 codex-main이 `workspace-write`(역할=산출물 작성과 정합) + codex-critic이 `read-only` | D11 위반 — 값 이중화가 조용히 갈라짐. 2026-07-17 실증: backends `read-only` ↔ routing `workspace-write`가 디스패처 `die` 뒤에 무증상 잠복 |
| INV16 | **어댑터·가드 무결성**: (a) backends.json JSON 유효 (b) 어댑터·도구 스크립트 6종 실행권한 (c) **선언된 폴백 = 실구현**(gemini_api가 스텁이 아님) (d) 가드가 참조하는 sandbox 프로파일 실재 (e) **가드 fail-closed 행동 검사** — 깨진 입력·치환 우회는 deny, 정상 읽기는 통과. 문자열 존재가 아니라 **실제 동작**을 본다 | 실증된 사고 유형들: 실행권한 부재로 디스패처 막힘(2026-07-17) · 스텁 폴백의 거짓 안전감(6주 잠복) · 가드가 크래시 시 fail-OPEN(2026-07-18 codex-critic). **문자열 검사는 fail-open을 PASS시킨다 → 행동 검사 필수** |

> ※ **매뉴얼(외부 repo) 비교 항목은 유지보수자 전용(optional)**. 공개 설치본에는 매뉴얼이 없으므로 핵심 점검(INV1–4·6–14)은 시스템 파일 자체 일관성만 본다. INV5와 각 INV의 매뉴얼 측 일치 검사, INV12e/f의 3 flavor 교차 점검은 아래 스크립트의 optional 블록에서 해당 자산이 있을 때만 실행된다.

## 자가 점검 실행

```bash
bash _shared/tools/self-check.sh            # 전체 (사람이 볼 때)
bash _shared/tools/self-check.sh --quiet    # FAIL만 (훅·CI용)
```

**exit code가 판정이다** — 0=PASS, 1=FAIL. "PASS 문자열이 보이는지 사람이 눈으로" 확인하는 방식은 점검이 아니다(초판 INV15b가 정확히 그래서 false-PASS였다 — codex-critic 적발 2026-07-17).

**정본 소유 (D11)**: 위 표가 불변식 **정의**를 소유하고, `_shared/tools/self-check.sh`가 그 **검사**를 소유한다. 스크립트 본문을 이 문서에 재기술하지 않는다 — 같은 사실을 두 곳에 적으면 조용히 갈라진다.

**자동 실행**:
- **Stop 훅** — 시스템 파일(`_shared/`·`_templates/`·`CLAUDE.md`·`.claude/`)이 변경된 세션에서만 발동. 무관 작업은 no-op(노이즈 억제 — 시끄러우면 무시당한다)
- **CI** — `.github/workflows/self-check.yml`이 PR에서 실행. main branch protection의 **required status check**로 지정됨(2026-07-18) → red면 머지 불가. D10상 사람 게이트가 PR이므로 **CI가 그 자리의 강제자**다. (required 지정이 유지될 때 참 — 풀리면 사후 탐지로 격하)

**스크립트를 고쳤으면 일부러 깨서 검증하라.** 각 INV를 하나씩 위반시켜 실제로 exit 1이 나는지 확인한다. 안 그러면 "돌긴 도는데 아무것도 안 잡는" 점검이 된다.


## 전면 재감사가 필요한 경우 (이 점검으로 부족)

- 새 외부 개념·레퍼런스를 시스템에 도입할 때 (개념↔규칙 매핑 자체가 바뀜)
- worker pool 구성·역할이 바뀔 때
- 위 불변식으로 표현 불가한 구조 변경
→ 그때만 `tasks/<new>/`로 새 점검 작업 + 필요 시 codex-critic/gemini. 그 외 일반 수정은 이 스크립트로 충분.
