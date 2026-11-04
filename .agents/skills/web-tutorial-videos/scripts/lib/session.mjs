// Login por perfil: devolve os itens de localStorage [{ name, value }] que uma sessão daquele
// perfil teria. O recorder os grava no storageState antes do primeiro carregamento, e
// `ui.as(perfil)` os regrava no meio do vídeo para trocar de perfil sem corte.
//
// Três modos, nesta ordem:
//   1. SESSION_MODULE=/caminho/sessao.mjs  — módulo próprio que exporta
//        `export async function sessionItems(profile) { return [{ name, value }, …] }`
//   2. SESSION_URL_TEMPLATE='http://localhost:4200/__session-{profile}.html'
//        — página que faz `localStorage.setItem('k', 'v')`; os pares são lidos do HTML.
//        Preferível a ler tokens de arquivo: se o banco local é recriado, token velho morre,
//        e a página sempre traz o vigente.
//   3. SESSION_JSON=/caminho/sessoes.json — { "<perfil>": { "<chave>": "<valor>", … } }
// Sem nenhum: fluxo sem login (perfil ignorado).
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const cache = new Map();
let custom;

export async function sessionItems(profile) {
  if (!profile) return [];
  if (cache.has(profile)) return cache.get(profile);
  let items = [];
  if (process.env.SESSION_MODULE) {
    custom ??= await import(pathToFileURL(resolve(process.env.SESSION_MODULE)).href);
    items = await custom.sessionItems(profile);
  } else if (process.env.SESSION_URL_TEMPLATE) {
    const url = process.env.SESSION_URL_TEMPLATE.replace('{profile}', encodeURIComponent(profile));
    const html = await (await fetch(url)).text();
    items = [...html.matchAll(/localStorage\.setItem\(\s*['"]([^'"]+)['"]\s*,\s*['"]([^'"]*)['"]\s*\)/g)]
      .map(([, name, value]) => ({ name, value }));
    if (!items.length) throw new Error(`sessão "${profile}": nenhum localStorage.setItem em ${url}`);
  } else if (process.env.SESSION_JSON) {
    const all = JSON.parse(readFileSync(resolve(process.env.SESSION_JSON), 'utf8'));
    if (!all[profile]) throw new Error(`perfil "${profile}" ausente em ${process.env.SESSION_JSON}`);
    items = Object.entries(all[profile]).map(([name, value]) => ({ name, value: String(value) }));
  }
  cache.set(profile, items);
  return items;
}