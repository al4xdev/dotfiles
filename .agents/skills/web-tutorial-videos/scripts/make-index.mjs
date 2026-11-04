// Gera <OUT_DIR>/INDEX.md: arquivo, duração (do ffprobe), o que mostra e o que foi feito fora
// do vídeo. Texto vem de `summary` e `outsideVideo` do fluxo (gravados no meta.json); sem eles
// a célula fica "⚠️ preencher" — revise à mão antes de entregar.
//
//   node make-index.mjs [ordem…]    # ordem opcional dos fluxos; padrão alfabética
import { readdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { join, resolve } from 'node:path';

const OUT = resolve(process.env.OUT_DIR ?? 'out');
const order = process.argv.slice(2);
let names = readdirSync(OUT).filter((f) => f.endsWith('.meta.json')).map((f) => f.slice(0, -10))
  .filter((n) => existsSync(join(OUT, `${n}.mp4`)));
if (order.length) names = order.filter((n) => names.includes(n));
else names.sort();

const mmss = (s) => `${Math.floor(s / 60)}:${String(Math.round(s % 60)).padStart(2, '0')}`;
const cell = (s) => (s ? String(s).replace(/\|/g, '\\|').replace(/\n/g, ' ') : '⚠️ preencher');
const rows = names.map((n, i) => {
  const meta = JSON.parse(readFileSync(join(OUT, `${n}.meta.json`), 'utf8'));
  const probe = execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration:stream=codec_name,width,height',
    '-of', 'json', join(OUT, `${n}.mp4`)], { encoding: 'utf8' });
  const p = JSON.parse(probe);
  const v = p.streams.find((s) => s.width);
  const a = p.streams.find((s) => !s.width);
  return `| ${i + 1} | \`${n}.mp4\` | ${mmss(Number(p.format.duration))} | ${v?.codec_name} ${v?.width}×${v?.height} + ${a?.codec_name ?? 'sem áudio'} | ${cell(meta.summary || meta.title)} | ${cell(meta.outsideVideo)} |`;
});

const md = `# Vídeos tutoriais — índice

Gerado em ${new Date().toLocaleString('sv-SE').slice(0, 16)}. Legendas queimadas, cartões de
abertura/encerramento, trilha procedural por fluxo (semente = nome) a −18 LUFS.

| # | Arquivo | Duração | Formato | O que mostra | Feito fora do vídeo (API/setup) |
|---|---|---|---|---|---|
${rows.join('\n')}

Os \`*.raw.mp4\` são as capturas brutas antes da montagem e não fazem parte da entrega.
`;
writeFileSync(join(OUT, 'INDEX.md'), md);
console.log(`ok: ${join(OUT, 'INDEX.md')} (${names.length} vídeos)`);