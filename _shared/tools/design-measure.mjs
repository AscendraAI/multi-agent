#!/usr/bin/env node
// design-measure.mjs — UI 표면의 결정적(무모델) 측정. 의존성 0 (node 내장 WebSocket + CDP).
//
// 왜: 스크린샷은 거짓말한다. headless `--window-size=390`은 진짜 디바이스 에뮬레이션이 아니라
//     넓은 레이아웃 뷰포트로 렌더 후 크롭돼 "우측 잘림" 아티팩트를 만든다. 2026-07-15
//     noi-works-home-design에서 이 아티팩트가 오버플로우 오탐 → box-sizing 헛수정을 유발했고,
//     CDP 실측이 오버플로우 부재를 확정했다(_shared/learnings.md [2026-07-15]).
//     ⇒ 레이아웃 판정의 ground truth는 DOM이다.
//
// 사용:
//   1) Chrome을 원격 디버깅으로 띄운다:
//      /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
//        --headless=new --remote-debugging-port=9222 --user-data-dir=$(mktemp -d) about:blank
//   2) node _shared/tools/design-measure.mjs <url> [--port 9222] [--widths 390,1440]
//
// 출력: JSON 1개. M1(blocking)만 pass/fail을 판정하고, 나머지는 warn-only로 관측값만 싣는다.
//       임계값 근거가 확립되지 않았기 때문 — 근거 없는 숫자로 게이트를 세우지 않는다
//       (codex-critic 2026-07-17). blocking 승격은 실측 3건 이후.
//
// exit: 0 = M1 통과(경고는 있을 수 있음), 1 = M1 실패, 2 = 실행 오류

const args = process.argv.slice(2);
const url = args.find((a) => !a.startsWith('--'));
const port = Number(getFlag('--port') ?? 9222);
const widths = (getFlag('--widths') ?? '390,1440').split(',').map(Number);

function getFlag(name) {
  const i = args.indexOf(name);
  return i === -1 ? undefined : args[i + 1];
}

if (!url) {
  console.error('usage: design-measure.mjs <url> [--port 9222] [--widths 390,1440]');
  process.exit(2);
}

const MEASURE = `(() => {
  const de = document.documentElement;
  const vw = de.clientWidth;
  const offenders = [];
  for (const el of document.querySelectorAll('*')) {
    const r = el.getBoundingClientRect();
    if (r.width === 0 && r.height === 0) continue;
    if (r.right > vw + 1 || r.left < -1) {
      offenders.push({
        tag: el.tagName.toLowerCase(),
        cls: (el.className && String(el.className).slice(0, 60)) || null,
        left: Math.round(r.left), right: Math.round(r.right),
      });
      if (offenders.length >= 20) break;
    }
  }
  const sizes = new Set();
  for (const el of document.querySelectorAll('body *')) {
    if (!el.textContent || !el.textContent.trim()) continue;
    sizes.add(getComputedStyle(el).fontSize);
  }
  const tap = [];
  for (const el of document.querySelectorAll('a,button,input,select,textarea,[role=button]')) {
    const r = el.getBoundingClientRect();
    if (r.width === 0 && r.height === 0) continue;
    if (r.width < 44 || r.height < 44) {
      tap.push({ tag: el.tagName.toLowerCase(), w: Math.round(r.width), h: Math.round(r.height) });
      if (tap.length >= 20) break;
    }
  }
  const fonts = new Set();
  for (const el of document.querySelectorAll('body *')) fonts.add(getComputedStyle(el).fontFamily);
  return {
    viewportWidth: vw,
    scrollWidth: de.scrollWidth,
    clientWidth: de.clientWidth,
    overflow: de.scrollWidth > de.clientWidth,
    offenders,
    uniqueFontSizes: sizes.size,
    fontFamilies: [...fonts].slice(0, 10),
    tapTargetsUnder44: tap.length,
    tapSamples: tap.slice(0, 5),
  };
})()`;

// 층 1 — 명백한 제네릭 마커. frontend-design 스킬이 명시적으로 금지한 것만 센다.
// "좋아 보인다"가 아니라 셀 수 있는 것. 회색지대는 여기 넣지 않는다.
const GENERIC_FONTS = /\b(Inter|Roboto|Arial|Helvetica Neue|system-ui|-apple-system|Space Grotesk)\b/i;

async function cdp(port, url) {
  const listRes = await fetch(`http://127.0.0.1:${port}/json/list`);
  const targets = await listRes.json();
  let target = targets.find((t) => t.type === 'page');
  if (!target) throw new Error('page 타겟 없음 — Chrome이 --remote-debugging-port로 떠 있나?');

  const ws = new WebSocket(target.webSocketDebuggerUrl);
  let id = 0;
  const pending = new Map();

  await new Promise((res, rej) => {
    ws.addEventListener('open', res, { once: true });
    ws.addEventListener('error', () => rej(new Error('CDP 연결 실패')), { once: true });
  });

  ws.addEventListener('message', (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.id && pending.has(msg.id)) {
      const { resolve, reject } = pending.get(msg.id);
      pending.delete(msg.id);
      msg.error ? reject(new Error(JSON.stringify(msg.error))) : resolve(msg.result);
    }
  });

  const send = (method, params = {}) =>
    new Promise((resolve, reject) => {
      const mid = ++id;
      pending.set(mid, { resolve, reject });
      ws.send(JSON.stringify({ id: mid, method, params }));
    });

  await send('Page.enable');
  await send('Runtime.enable');

  const results = {};
  for (const w of widths) {
    // 핵심: --window-size가 아니라 진짜 디바이스 메트릭 오버라이드.
    await send('Emulation.setDeviceMetricsOverride', {
      width: w,
      height: 900,
      deviceScaleFactor: 2,
      mobile: w < 768,
    });
    await send('Page.navigate', { url });
    await new Promise((r) => setTimeout(r, 1500)); // 렌더 정착 대기
    const { result } = await send('Runtime.evaluate', { expression: MEASURE, returnByValue: true });
    results[w] = result.value;
  }
  ws.close();
  return results;
}

try {
  const per = await cdp(port, url);

  const m1Failures = [];
  const warnings = [];
  for (const [w, m] of Object.entries(per)) {
    if (m.overflow || m.offenders.length > 0) {
      m1Failures.push({ width: Number(w), scrollWidth: m.scrollWidth, clientWidth: m.clientWidth, offenders: m.offenders });
    }
    // warn-only: 임계값에 근거가 없다. 관측만 하고 판정하지 않는다.
    if (m.uniqueFontSizes > 6) warnings.push(`[${w}] 고유 font-size ${m.uniqueFontSizes}개 (참고대역 3~6 — 근거 미확립, 판정 아님)`);
    if (m.tapTargetsUnder44 > 0 && Number(w) < 768) warnings.push(`[${w}] 44px 미만 탭타겟 ${m.tapTargetsUnder44}개`);
    const generic = m.fontFamilies.filter((f) => GENERIC_FONTS.test(f));
    if (generic.length) warnings.push(`[${w}] 제네릭 폰트 마커: ${generic.slice(0, 3).join(' / ')} (design-contract에 의도적 선택 사유가 있으면 무시)`);
  }

  const out = {
    url,
    widths,
    m1_overflow: { blocking: true, pass: m1Failures.length === 0, failures: m1Failures },
    warnings: { blocking: false, note: '임계값 근거 미확립 — 관측만. blocking 승격은 실측 3건 후', items: warnings },
    raw: per,
  };
  console.log(JSON.stringify(out, null, 2));
  process.exit(out.m1_overflow.pass ? 0 : 1);
} catch (e) {
  console.error(JSON.stringify({ error: String(e && e.message || e) }, null, 2));
  process.exit(2);
}
