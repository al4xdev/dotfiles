// Gravador de vídeos tutoriais de aplicações web (Playwright + screencast CDP).
//
//   node recorder.mjs flows/<fluxo>.mjs [--headed] [--dry]
//
// Um fluxo exporta (default):
//   { name, title, brand?, subtitle?, summary?, outsideVideo?, profile?, start?, initScript?,
//     setup?: async ({ api, session, log }) => ctx,
//     steps: [{ caption: string | (ctx) => string, run: async (ui, ctx) => {}, hold? }] }
// `setup` roda ANTES da gravação (estado preparado por API, fora do vídeo) e o que devolve
// chega aos passos como `ctx`. `--dry` ensaia sem gravar.
//
// Configuração por ambiente (todas opcionais):
//   BASE_URL        origem da aplicação (padrão http://localhost:4200; aceita file:///dir)
//   OUT_DIR         saída (padrão ./out no diretório atual)
//   LOCALE          padrão pt-BR      TIMEZONE  padrão America/Sao_Paulo
//   VIEWPORT        padrão 1280x800   READ_PAUSE_MS  pausa de leitura após ação (1800)
//   SESSION_*       ver lib/session.mjs (login por perfil)
//
// Saída em OUT_DIR: <name>.raw.mp4 (t=0 no primeiro passo), <name>.captions.json
// ([{start,end,text}] no mesmo relógio) e <name>.meta.json. A montagem é do montage.py.
//
// Decisões (pagas em produção, ver SKILL.md › Armadilhas):
// - Captura por screencast CDP (JPEG q92), não pelo recordVideo do Playwright: o VP8 de
//   ~1 Mbps dele borra texto miúdo. Cada quadro traz o instante de parede em que foi pintado,
//   então legenda e imagem ficam no mesmo relógio, sem marcador de sincronia. O Chrome só
//   emite quadro quando a tela muda; a duração de cada quadro vai no ffconcat.
// - Cursor, anel de clique, realce e faixa são <div>s com pointer-events:none injetados por
//   addInitScript: não mexem no estilo do elemento (nada de reflow) nem no código do app.
// - O overlay de erro do Vite é escondido: com gente editando o front ele aparece a cada
//   recompilação quebrada e não é parte do produto.
// - Locale do PROCESSO (LANG/LC_ALL + --lang), não só do contexto: sem ele o
//   <input type=date> do Chromium desenha mm/dd/aaaa mesmo com locale pt-BR no contexto.
import { chromium } from 'playwright';
import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { sessionItems } from './lib/session.mjs';
import { api } from './lib/api.mjs';

const BASE = (process.env.BASE_URL ?? 'http://localhost:4200').replace(/\/$/, '');
const [VW, VH] = (process.env.VIEWPORT ?? '1280x800').split('x').map(Number);
const VIEW = { width: VW, height: VH };
const OUT = resolve(process.env.OUT_DIR ?? 'out');
const LOCALE = process.env.LOCALE ?? 'pt-BR';
const TIMEZONE = process.env.TIMEZONE ?? 'America/Sao_Paulo';
const POSIX_LOCALE = `${LOCALE.replace('-', '_')}.UTF-8`;
const READ_PAUSE_MS = Number(process.env.READ_PAUSE_MS ?? 1800);
const TYPE_DELAY_MS = 45;

const args = process.argv.slice(2);
const flowPath = args.find((a) => !a.startsWith('--'));
const DRY = args.includes('--dry');
if (!flowPath) { console.error('uso: node recorder.mjs flows/<fluxo>.mjs [--headed] [--dry]'); process.exit(2); }
const flow = (await import(pathToFileURL(resolve(flowPath)).href)).default;
const url = (path) => (/^[a-z]+:/.test(path) ? path : BASE + path);

const OVERLAY_SCRIPT = () => {
  const install = () => {
    if (document.getElementById('__rec-cursor')) return;
    const style = document.createElement('style');
    style.textContent = `
      vite-error-overlay { display: none !important; }
      #__rec-cursor { position: fixed; z-index: 2147483647; pointer-events: none;
        width: 26px; height: 26px; margin: -3px 0 0 -3px;
        transition: left .7s cubic-bezier(.4,0,.2,1), top .7s cubic-bezier(.4,0,.2,1);
        filter: drop-shadow(0 2px 3px rgba(0,0,0,.35)); }
      #__rec-ring { position: fixed; z-index: 2147483646; pointer-events: none; border-radius: 50%;
        width: 44px; height: 44px; margin: -22px 0 0 -22px; border: 3px solid #a100ff;
        opacity: 0; transform: scale(.3); }
      #__rec-ring.on { animation: __rec-ripple .6s ease-out; }
      @keyframes __rec-ripple { from { opacity: .9; transform: scale(.3) } to { opacity: 0; transform: scale(1.4) } }
      #__rec-hl { position: fixed; z-index: 2147483645; pointer-events: none; border-radius: 8px;
        border: 3px solid #a100ff; box-shadow: 0 0 0 6px rgba(161,0,255,.18);
        opacity: 0; transition: opacity .25s; }
      #__rec-hl.on { opacity: 1; }
      #__rec-banner { position: fixed; z-index: 2147483647; pointer-events: none; left: 50%; top: 42%;
        transform: translate(-50%, -50%); padding: 22px 40px; border-radius: 14px;
        background: rgba(29,11,51,.92); color: #fff; font: 600 30px/1.3 'Noto Sans', sans-serif;
        text-align: center; opacity: 0; transition: opacity .35s; box-shadow: 0 10px 40px rgba(0,0,0,.35); }
      #__rec-banner small { display: block; font-weight: 400; font-size: 20px; color: #e6c8ff; margin-top: 6px; }
      #__rec-banner.on { opacity: 1; }`;
    document.documentElement.appendChild(style);
    const cursor = document.createElement('div');
    cursor.id = '__rec-cursor';
    cursor.innerHTML = `<svg viewBox="0 0 24 24" width="26" height="26"><path d="M3 2l7 19 2.6-7.4L20 11z"
      fill="#fff" stroke="#111" stroke-width="1.6" stroke-linejoin="round"/></svg>`;
    let pos = [640, 400];
    try { pos = JSON.parse(sessionStorage.getItem('__rec-pos') ?? '[640,400]'); } catch {}
    cursor.style.left = pos[0] + 'px'; cursor.style.top = pos[1] + 'px';
    const ring = document.createElement('div'); ring.id = '__rec-ring';
    const hl = document.createElement('div'); hl.id = '__rec-hl';
    const banner = document.createElement('div'); banner.id = '__rec-banner';
    document.documentElement.append(hl, ring, cursor, banner);
  };
  if (document.documentElement) install();
  document.addEventListener('DOMContentLoaded', install);
};

const log = (...m) => console.log(' ', ...m);
const ctx = flow.setup ? await flow.setup({ api, session: sessionItems, log }) : {};

const browser = await chromium.launch({
  headless: !args.includes('--headed'),
  args: [`--lang=${LOCALE}`],
  env: { ...process.env, LANG: POSIX_LOCALE, LC_ALL: POSIX_LOCALE, LANGUAGE: `${LOCALE.replace('-', '_')}:${LOCALE.split('-')[0]}` },
});
const initialItems = flow.profile ? await sessionItems(flow.profile) : [];
const origin = new URL(BASE).origin;
const context = await browser.newContext({
  viewport: VIEW, deviceScaleFactor: 1, locale: LOCALE, timezoneId: TIMEZONE,
  // file:// não tem origem utilizável para storageState; sessão só em http(s).
  ...(initialItems.length && origin !== 'null'
    ? { storageState: { cookies: [], origins: [{ origin, localStorage: initialItems }] } }
    : {}),
});
await context.addInitScript(OVERLAY_SCRIPT);
// O fluxo pode fixar algo da página antes do app carregar (ex.: Math.random de uma dica sorteada).
if (flow.initScript) await context.addInitScript(flow.initScript);
const page = await context.newPage();
page.setDefaultTimeout(Number(process.env.STEP_TIMEOUT_MS ?? 10000));
const sleep = (ms) => page.waitForTimeout(ms);
const wall = () => Date.now() / 1000;

// --- screencast -------------------------------------------------------------------------
const framesDir = join(OUT, `.frames-${flow.name}`);
const frames = [];
let cdp;
async function startCapture() {
  rmSync(framesDir, { recursive: true, force: true });
  mkdirSync(framesDir, { recursive: true });
  cdp = await context.newCDPSession(page);
  cdp.on('Page.screencastFrame', ({ data, metadata, sessionId }) => {
    const file = join(framesDir, `f${String(frames.length).padStart(6, '0')}.jpg`);
    writeFileSync(file, Buffer.from(data, 'base64'));
    // metadata.timestamp é o instante de parede (s) em que o quadro foi pintado.
    frames.push({ t: metadata.timestamp ?? wall(), recv: wall(), file });
    cdp.send('Page.screencastFrameAck', { sessionId }).catch(() => {});
  });
  await cdp.send('Page.startScreencast', { format: 'jpeg', quality: 92, maxWidth: VIEW.width, maxHeight: VIEW.height, everyNthFrame: 1 });
}

function encode(from, to, mp4) {
  // O quadro em vigor no instante `from` entra primeiro, com a duração encurtada.
  let i = frames.findLastIndex((f) => f.t <= from);
  if (i < 0) i = 0;
  const used = frames.slice(i).filter((f) => f.t < to);
  if (!used.length) throw new Error('nenhum quadro capturado');
  const lines = ['ffconcat version 1.0'];
  used.forEach((f, k) => {
    const start = Math.max(f.t, from);
    const end = k + 1 < used.length ? used[k + 1].t : to;
    lines.push(`file '${f.file}'`, `duration ${Math.max(end - start, 0.001).toFixed(4)}`);
  });
  lines.push(`file '${used.at(-1).file}'`); // sem repetir o último, o concat ignora a duração dele
  const list = join(framesDir, 'list.ffconcat');
  writeFileSync(list, lines.join('\n') + '\n');
  execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', list,
    '-vf', `fps=25,scale=${VIEW.width}:${VIEW.height},format=yuv420p`, '-c:v', 'libx264', '-preset', 'veryfast',
    '-crf', '14', '-t', (to - from).toFixed(3), mp4], { stdio: 'inherit' });
  return used.length;
}

// --- ações visíveis ---------------------------------------------------------------------
const loc = (target) => (typeof target === 'string' ? page.locator(target).first() : target);
const settle = () => page.waitForLoadState('networkidle', { timeout: 5000 }).catch(() => {});

const ui = {
  page, ctx, api, sleep,
  async goto(path, { pause = 0 } = {}) {
    await page.goto(url(path));
    await settle();
    if (pause) await sleep(pause);
  },
  async moveTo(target, { hold = 800 } = {}) {
    const l = loc(target);
    await l.waitFor({ state: 'visible' });
    await l.scrollIntoViewIfNeeded();
    await sleep(150);
    const box = await l.boundingBox();
    if (!box) throw new Error(`alvo sem caixa visível: ${target}`);
    const x = box.x + Math.min(box.width / 2, 40), y = box.y + box.height / 2;
    await page.evaluate(([x, y, b]) => {
      const c = document.getElementById('__rec-cursor'), hl = document.getElementById('__rec-hl');
      c.style.left = x + 'px'; c.style.top = y + 'px';
      try { sessionStorage.setItem('__rec-pos', JSON.stringify([x, y])); } catch {}
      Object.assign(hl.style, { left: b.x - 5 + 'px', top: b.y - 5 + 'px', width: b.width + 10 + 'px', height: b.height + 10 + 'px' });
      hl.classList.add('on');
    }, [x, y, box]);
    await page.mouse.move(x, y, { steps: 8 });
    await sleep(hold);
    return { l, x, y };
  },
  async unhighlight() {
    await page.evaluate(() => document.getElementById('__rec-hl')?.classList.remove('on')).catch(() => {});
  },
  async ripple(x, y) {
    await page.evaluate(([x, y]) => {
      const r = document.getElementById('__rec-ring');
      r.style.left = x + 'px'; r.style.top = y + 'px';
      r.classList.remove('on'); void r.offsetWidth; r.classList.add('on');
    }, [x, y]);
    await sleep(250);
  },
  async click(target, opts = {}) {
    // Uma nova tentativa: front em dev recompila sozinho e pode recarregar no meio do passo.
    try { return await ui.clickOnce(target, opts); } catch (err) {
      console.warn(`  repetindo clique em ${target}: ${err.message.split('\n')[0]}`);
      await sleep(1500);
      return ui.clickOnce(target, opts);
    }
  },
  async clickOnce(target, { pause = READ_PAUSE_MS, force = false } = {}) {
    const { l, x, y } = await ui.moveTo(target);
    await ui.ripple(x, y);
    await l.click({ force });
    await settle();
    await ui.unhighlight();
    await sleep(pause);
  },
  /**
   * Abre um diálogo e confirma, ESPERANDO ele abrir e fechar. Sob a carga da captura o clique
   * de confirmar já se perdeu: o passo seguia e o estado nunca mudava no servidor.
   */
  async confirm(opener, confirmButton, { dialog = confirmButton, pause = 1600, timeout = 15000 } = {}) {
    await ui.click(opener, { pause: 1200 });
    await page.locator(confirmButton).first().waitFor({ state: 'visible' });
    await ui.click(confirmButton, { pause: 600 });
    await page.locator(dialog).first().waitFor({ state: 'hidden', timeout });
    await sleep(pause);
  },
  /** Digita como gente: o espectador vê o texto entrar. */
  async type(target, text, { pause = 900, clear = true } = {}) {
    const { l, x, y } = await ui.moveTo(target, { hold: 500 });
    await ui.ripple(x, y);
    await l.click();
    if (clear) await l.fill('');
    await l.pressSequentially(String(text), { delay: TYPE_DELAY_MS });
    await ui.unhighlight();
    await sleep(pause);
  },
  /** Preenche sem digitação animada (campos longos ou de data: valor ISO aaaa-mm-dd). */
  async fill(target, text, { pause = 700 } = {}) {
    const { l } = await ui.moveTo(target, { hold: 400 });
    await l.fill(String(text));
    await ui.unhighlight();
    await sleep(pause);
  },
  async select(target, option, { pause = 1200 } = {}) {
    const { l, x, y } = await ui.moveTo(target, { hold: 500 });
    await ui.ripple(x, y);
    await l.selectOption(option);
    await settle();
    await ui.unhighlight();
    await sleep(pause);
  },
  /** Anexa arquivo real pelo <input type=file> (setInputFiles); `show` é o elemento visível a destacar. */
  async upload(input, files, { show, pause = READ_PAUSE_MS } = {}) {
    if (show) { const { x, y } = await ui.moveTo(show); await ui.ripple(x, y); }
    await loc(input).setInputFiles(files);
    await settle();
    await ui.unhighlight();
    await sleep(pause);
  },
  async highlight(target, ms = READ_PAUSE_MS) {
    await ui.moveTo(target, { hold: ms });
    await ui.unhighlight();
  },
  async scroll(dy, { pause = READ_PAUSE_MS } = {}) {
    await page.mouse.wheel(0, dy);
    await sleep(pause);
  },
  /** Faixa central (troca de cena, troca de perfil). */
  async banner(text, sub = '', ms = 2200) {
    await page.evaluate(([t, s]) => {
      const b = document.getElementById('__rec-banner');
      b.textContent = t;
      if (s) { const sm = document.createElement('small'); sm.textContent = s; b.append(sm); }
      b.classList.add('on');
    }, [text, sub]);
    await sleep(ms);
    await page.evaluate(() => document.getElementById('__rec-banner').classList.remove('on'));
    await sleep(400);
  },
  /** Troca de perfil sem cortar o vídeo: regrava o localStorage da sessão e vai para `path`. */
  async as(profile, path = flow.start ?? '/', { pause = 1200 } = {}) {
    const items = await sessionItems(profile);
    await page.evaluate((items) => {
      localStorage.clear();
      for (const { name, value } of items) localStorage.setItem(name, value);
    }, items);
    await ui.goto(path, { pause });
  },
};

// A primeira tela carrega fora do cronômetro das legendas.
if (!DRY) await startCapture();
await ui.goto(flow.start ?? '/');
await sleep(600);
const t0 = wall();
const captions = [];
const captionOf = (s) => (typeof s.caption === 'function' ? s.caption(ctx) : s.caption);
let failed = false;
try {
  for (const step of flow.steps) {
    const start = wall() - t0;
    console.log(`[${start.toFixed(1)}s] ${captionOf(step)}`);
    await step.run(ui, ctx);
    if (step.hold) await sleep(step.hold);
    captions.push({ start: +start.toFixed(2), end: +(wall() - t0).toFixed(2), text: captionOf(step) });
  }
} catch (err) {
  failed = true;
  mkdirSync(OUT, { recursive: true });
  await page.screenshot({ path: join(OUT, `${flow.name}.error.png`) }).catch(() => {});
  console.error(`FALHOU: ${err.message.split('\n')[0]} — ver ${join(OUT, `${flow.name}.error.png`)}`);
  process.exitCode = 1;
} finally {
  const t1 = wall();
  if (cdp) await cdp.send('Page.stopScreencast').catch(() => {});
  await context.close();
  await browser.close();
  if (!DRY && !failed) {
    mkdirSync(OUT, { recursive: true });
    const mp4 = join(OUT, `${flow.name}.raw.mp4`);
    // Diagnóstico do relógio: atraso entre pintar o quadro e recebê-lo no Node.
    const lag = frames.length ? frames.reduce((s, f) => s + (f.recv - f.t), 0) / frames.length : 0;
    const n = encode(t0, t1, mp4);
    rmSync(framesDir, { recursive: true, force: true });
    writeFileSync(join(OUT, `${flow.name}.captions.json`), JSON.stringify(captions, null, 2));
    writeFileSync(join(OUT, `${flow.name}.meta.json`), JSON.stringify({
      name: flow.name, title: flow.title, brand: flow.brand ?? process.env.BRAND ?? '',
      subtitle: flow.subtitle ?? process.env.SUBTITLE ?? 'Tutorial', profile: flow.profile ?? null,
      summary: flow.summary ?? '', outsideVideo: flow.outsideVideo ?? '',
      source: `${flow.name}.raw.mp4`, duration: +(t1 - t0).toFixed(2), frames: n,
      frameLag: +lag.toFixed(3), width: VIEW.width, height: VIEW.height, recordedAt: new Date().toISOString(),
    }, null, 2));
    console.log(`ok: ${mp4} (${(t1 - t0).toFixed(1)}s, ${n} quadros, atraso médio do quadro ${lag.toFixed(3)}s)`);
  } else if (!failed) {
    console.log(`ensaio ok (${(t1 - t0).toFixed(1)}s)`);
  }
}