# _shared/autonomy-policy.md — 자율 실행 & 체크포인트 정책

정본. approval-policy.md의 상위 운용 규칙. 근거: AI개발운영규격 v2(딥리서치 260707). 성격: **소비스 기반 게이팅 + PR 체크포인트 + 비동기 보고.** best-effort 알림은 D9와 동일하게 보조채널(하드게이트 아님).

> 원칙 한 줄: **스텝마다 묻지 않는다. 되돌릴 수 있으면 자동, 위험하면 하드스톱, 완료는 PR로 보고.** 사람의 유일 게이트 = diff 리뷰.

---

## 1. 소비스 티어 (승인 단위 = 스텝 아니라 결과의 위험도)

| 티어 | 대상 | 처리 |
|---|---|---|
| **AUTO** (자동승인, 무프롬프트) | 읽기·검색·`write_scope` 내 편집·테스트·린트·타입체크·비파괴 bash·`git add/commit`·worktree 내 작업 | 승인·질문 없이 진행 |
| **HARD-STOP** (멈춤 + Slack/폰 대기) | ①`write_scope` 밖 수정/삭제 ②비가역(대량삭제·`git push --force`·prod 배포·과금·패키지 publish) ③`target_repo` 외 쓰기 ④시크릿/prod 데이터 접근 ⑤범위·비용 급증(예상 워커수/토큰 2배↑) ⑥스스로 기본값 못 정하는 설계 분기 | 승인 전 진행 금지 |

- 승인 단위 = **웨이브(task) 1회 배치.** 웨이브 착수 시 `write_scope` 전체를 1회 승인 → 그 안에서 워커별 재승인·재질문 금지(approval-policy "동일 작업 내 재승인 불필요" 계승).
- 기록: HARD-STOP 승인은 `log.md` `[APPROVAL]` 태그(형식은 approval-policy와 동일, 채널 무관).

## 2. PR = 체크포인트 (사람 게이트는 여기 하나)

- 워커/웨이브 완료 → **자동 커밋·푸시 → draft PR 오픈**(브랜치=작업명). 사람은 **diff 리뷰**로만 개입.
- **remote 미설정(로컬 전용 repo) 시**: auto-push/PR 대신 **로컬 작업명 브랜치 커밋 + 오케스트레이터가 diff 제시**로 리뷰 대체. remote 생기면 원문(push·draft PR)대로. (D10 정합)
- 스텝 중간 산출물 검토 요구 금지. 검토는 PR 단위.
- PR 본문 = 완료 보고: 한 일·DoD 증거(테스트출력·스캔·diff stat)·다음 웨이브 제안 1줄.
- 회신 규약: **"GO"** → 다음 웨이브 / **"수정: …"** → 반영 후 재-PR. 회신 전 다음 웨이브 착수 금지.

## 3. 알림 2채널 (D9 확장 — 완료는 조용, 막힘만 시끄럽게)

| 이벤트 | loud 알림(주체) | 기록·회신 채널 |
|---|---|---|
| `agent_completed` (스테이징·PR, 막힌 것 없음) | 없음(조용) | 관제실 Slack (FYI 기록) |
| `agent_needs_input` (HARD-STOP·대기) | **Slack Incoming Webhook** (`_shared/adapters/notify.sh`) | 관제실 Slack (질문 게시·답장 읽기) |

- **loud ping 주체 = Slack Incoming Webhook**(앱 명의 게시 → 사용자에게 알림 옴). 발송기 `_shared/adapters/notify.sh`, 웹훅 URL은 **gitignored `_local/slack-webhook`**(시크릿 — 커밋 금지, 경로만 참조).
- ⚠️ Slack MCP(`slack_send_message`)는 **사용자 명의**라 자기 메시지 알림이 없다 → MCP는 **질문 게시·답장 폴링(읽기)** 전용, 실제 loud ping은 웹훅(다른 주체)이 담당. 폰 푸시(PushNotification)는 폴백.
- 관제실 채널: 전용 채널 `C0BGH4K5LL8`. 교체 시 이 값만.
- best-effort: 웹훅 URL 미설정·발송 실패 시 스킵·터미널 폴백(알림 실패가 진행을 막지 않음 — notify.sh가 exit 0로 처리, D9/D10 일관).

## 4. 표준 결정 규칙 (반복 질문을 위임 — 묻지 말 것)

- **critic/검증 결함:** 계약정합성·DoD·보안 영향 → **자동 수정 후 진행.** 순수 스타일 nit → 백로그 기록·진행.
- **불확실·가정:** 합리적 기본값으로 진행 + `result.md` Issues/Caveats에 표면화(워커 one-shot 구조와 일관).
- **DoD 미충족:** 스스로 고쳐 충족. 못 고치면 사유와 함께 HARD-STOP.
- **애매한 설계 분기만** HARD-STOP(스스로 기본값 불가할 때).

## 5. 품질 게이트 (CI가 강제자 — 규약 아님)

머지 전 **필수·하드**: `typecheck → lint → test → 보안스캔(시크릿·SSRF·XSS) → 사람 diff 리뷰`. 하나라도 실패 = 머지 차단.
- **크리틱 에이전트**: 빌더와 분리, **SPEC/계약 기준 판정**(테스트 아님 — 테스트도 틀릴 수 있음), diff만 봄(never-trust-upstream). 불확실 시 abstain.
- 근거: AI코드 45% 보안결함·반복 프롬프트가 보안 악화 → 외부 강제 게이트 필수.

## 6. 병렬 정책 (linear 기본, 병렬은 독립 섬만)

- **기본 = 단일 linear.** 의존 코딩(step N이 N-1 의존)에 워커 추가 금지(39~70% 악화·토큰 15배 근거).
- **병렬 허용 = "독립 섬" 태그 태스크만**: 서로 파일·계약 안 겹침. worktree 1브랜치=1워커, **동시 ≤3-4**(사람이 머지 병목).
- **컨트랙트 먼저:** 공유 타입·스키마·라우터·API 계약을 병렬 착수 전 잠금(linear 단일). 이게 안전 병렬의 전제.

## 7. 승인 예외
- Orchestrator 내부 추론(워커 호출 아님) = 승인 불필요.
- AUTO 티어 = 승인 불필요.

## 8. 불변식 후보 (system-invariants.md 연동)
- **INV14**: autonomy-policy.md에 "소비스 티어(AUTO/HARD-STOP)" + "PR 체크포인트" + "linear 기본·병렬=독립섬" 절 존재. 위반 = 스텝단위 게이트 회귀 or 무제한 병렬 부활.

---
정본: 이 파일 · 관제실 채널 C0BGH4K5LL8 · 근거 AI개발운영규격 v2(260707).
