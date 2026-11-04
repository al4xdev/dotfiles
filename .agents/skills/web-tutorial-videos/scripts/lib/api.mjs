// Cliente REST para preparar estado FORA do vídeo (no `setup` do fluxo).
//
//   const admin = await api('admin');  const rows = await admin.get('/items');
//
// Configuração por ambiente:
//   API_BASE        origem da API (padrão: BASE_URL)
//   API_TOKEN_KEY   chave do localStorage da sessão que guarda o bearer token (ex.: app.auth.token).
//                   Sem ela, nenhuma autorização é enviada.
//   API_UNWRAP      se o backend responde em envelope { <chave>: … }, a chave a desembrulhar
//                   (ex.: data). Sem ela, a resposta volta como veio.
import { readFileSync } from 'node:fs';
import { basename } from 'node:path';
import { sessionItems } from './session.mjs';

const BACK = (process.env.API_BASE ?? process.env.BASE_URL ?? 'http://localhost:3000').replace(/\/$/, '');
const TOKEN_KEY = process.env.API_TOKEN_KEY;
const UNWRAP = process.env.API_UNWRAP;

export async function token(profile) {
  if (!TOKEN_KEY || !profile) return null;
  const item = (await sessionItems(profile)).find((i) => i.name === TOKEN_KEY);
  if (!item) throw new Error(`sessão "${profile}" sem a chave ${TOKEN_KEY}`);
  return item.value;
}

export async function api(profile) {
  const t = await token(profile);
  const auth = t ? { Authorization: `Bearer ${t}` } : {};
  async function call(method, path, body) {
    const isForm = body instanceof FormData;
    const res = await fetch(BACK + path, {
      method,
      headers: isForm || body === undefined ? auth : { ...auth, 'content-type': 'application/json' },
      body: body === undefined ? undefined : isForm ? body : JSON.stringify(body),
    });
    const text = await res.text();
    let json;
    try { json = text ? JSON.parse(text) : null; } catch { json = text; }
    if (!res.ok) throw new Error(`${profile ?? '-'} ${method} ${path} → ${res.status}: ${text.slice(0, 400)}`);
    return UNWRAP && json && typeof json === 'object' && UNWRAP in json ? json[UNWRAP] : json;
  }
  return {
    get: (p) => call('GET', p),
    post: (p, b = {}) => call('POST', p, b),
    put: (p, b = {}) => call('PUT', p, b),
    patch: (p, b = {}) => call('PATCH', p, b),
    del: (p, b) => call('DELETE', p, b),
    /** multipart: campos simples + arquivos [{ field, path, name?, type? }]. */
    upload(p, fields = {}, files = []) {
      const fd = new FormData();
      for (const [k, v] of Object.entries(fields)) fd.append(k, String(v));
      for (const f of files) {
        fd.append(f.field, new Blob([readFileSync(f.path)], { type: f.type ?? 'application/octet-stream' }), f.name ?? basename(f.path));
      }
      return call('POST', p, fd);
    },
  };
}