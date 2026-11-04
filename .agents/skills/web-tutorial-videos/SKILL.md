---
name: web-tutorial-videos
description: >-
  Grava vídeos tutoriais de aplicações web com legendas pt-BR sincronizadas, cursor e realce
  visíveis, cartões de abertura/encerramento e trilha procedural sem direitos autorais:
  Playwright + screencast CDP → ffmpeg (H.264 1280×800 + AAC). Use quando pedirem "vídeo
  tutorial", "gravar a tela do portal", "screencast com legenda", "vídeo de onboarding",
  "demo gravada de um fluxo", ou para refazer/regravar tutoriais quando a tela mudar.
---

# Vídeos tutoriais de aplicações web

Motor que gravou de ponta a ponta 9 tutoriais (1–2:30 min cada) de um portal Angular com
vários perfis de usuário. Cada vídeo é um **fluxo** `.mjs` com passos (`caption` + `run`).
O gravador executa os passos num Chromium headless, captura a tela, anota quando cada legenda
começa, e a montagem junta tudo com cartões e música.

```
brief → flows/*.mjs → ensaio (--dry) → [front quieto] → gravação → montagem → ffprobe
      → conferência de quadros → INDEX.md → zip
```

## Quando usar

- Tutorial de tela para recém-chegados, um vídeo por tarefa, com legenda queimada.
- Fluxos que precisam de **estado de partida** (dados preparados por API fora do vídeo).
- Fluxos com **troca de perfil** no meio (`ui.as('outro-perfil')` sem corte).
- Regravar depois que o texto da tela mudou: o fluxo é código, regravar custa um comando.

Não serve para narração por voz (não há TTS) nem para vídeo mobile por gestos. Para gestos,
use a skill `browser-mobile-media`.

## Pré-requisitos

| O quê | Para quê | Instalar |
|---|---|---|
| Node ≥ 20 (testado no 25) | recorder | sistema |
| Playwright **próprio do diretório de trabalho** + Chromium | captura | `npm install && npx playwright install chromium` |
| ffmpeg/ffprobe com **libass**, libx264, aac | encode, legendas | `sudo apt install ffmpeg` (confira com `ffmpeg -filters \| grep ass`) |
| `uv` + Python ≥ 3.10 com numpy | música e montagem | `uv run -q --with numpy python …` (não precisa de venv) |
| Fonte Noto Sans | legendas e cartões | `sudo apt install fonts-noto-core` (ou `FONT`/`FONT_DIR`) |
| `zip`/`unzip` | entrega | `sudo apt install zip unzip` |
| Locale `pt_BR.UTF-8` gerado no SO | datas dd/mm/aaaa no `<input type=date>` | `locale -a \| grep pt_BR`; se faltar: `sudo locale-gen pt_BR.UTF-8` |

## Montar o diretório de trabalho

Copie o motor para um diretório **fora do repositório do app** (algo gitignored, como `.dumps/`):

```fish
set W .dumps/videos-tutoriais
mkdir -p $W/flows $W/fixtures
cp -r ~/.agents/skills/web-tutorial-videos/scripts/. $W/
cp ~/.agents/skills/web-tutorial-videos/examples/brief.example.md $W/BRIEF.md
cd $W; npm install; npx playwright install chromium
```

Árvore resultante: `recorder.mjs`, `lib/{session,api}.mjs`, `montage.py`, `music.py`,
`record-all.sh`, `check-quiet.sh`, `probe-all.sh`, `make-index.mjs`, `package-zip.sh`,
`flows/`, `fixtures/` e a saída em `out/`.

### Configuração (ambiente)

| Variável | Padrão | Uso |
|---|---|---|
| `BASE_URL` | `http://localhost:4200` | origem do app; `file:///dir` também funciona |
| `OUT_DIR` | `out` | saída |
| `FLOWS_DIR` | `flows` | onde o `record-all.sh` procura `<fluxo>.mjs` |
| `LOCALE` / `TIMEZONE` | `pt-BR` / `America/Sao_Paulo` | contexto **e** processo do Chromium |
| `VIEWPORT` | `1280x800` | tamanho da captura e do vídeo final |
| `READ_PAUSE_MS` | `1800` | pausa de leitura padrão depois de cada clique |
| `STEP_TIMEOUT_MS` | `10000` | timeout padrão do Playwright |
| `SESSION_URL_TEMPLATE` | — | `http://host/__session-{profile}.html`: página com `localStorage.setItem(...)` |
| `SESSION_JSON` | — | `{ "perfil": { "chave": "valor" } }` |
| `SESSION_MODULE` | — | módulo próprio que exporta `sessionItems(profile)` |
| `API_BASE` | `BASE_URL` | backend para o `setup` |
| `API_TOKEN_KEY` | — | chave do localStorage com o bearer token |
| `API_UNWRAP` | — | desembrulha envelope `{ data }` → `data` |
| `BRAND` / `SUBTITLE` / `OUTRO_TEXT` | — | textos dos cartões (o fluxo pode sobrescrever) |
| `FONT` / `FONT_DIR` / `CARD_BG` / `CARD_SECONDS` | Noto Sans / noto / `0x1d0b33` / 2 | visual dos cartões |
| `QUIET_REPO` / `QUIET_MINUTES` / `FORCE` | — / 10 / 0 | trava da gravação final (ver passo 4) |

Exemplo de quem tem login por página de sessão e API com envelope:

```fish
set -x BASE_URL http://localhost:4200
set -x SESSION_URL_TEMPLATE 'http://localhost:4200/__session-{profile}.html'
set -x API_BASE http://localhost:3000; set -x API_TOKEN_KEY app.auth.token; set -x API_UNWRAP data
set -x BRAND 'Portal X'; set -x SUBTITLE 'Tutorial · Portal X'
```

## O fluxo que funcionou, passo a passo

1. **Brief** (`BRIEF.md`, modelo em `examples/brief.example.md`). Lista os vídeos, o nome de cada
   um (que é também a semente da música), o perfil, o que o vídeo mostra e o estado de partida.
   Diz também o que pode ser preparado por API. As regras de honestidade ficam escritas no
   brief antes de qualquer código.
2. **Um fluxo por vídeo** em `flows/<nome>.mjs` (ver "Como escrever um fluxo"). **Leia o texto da
   tela na fonte do front** (templates, catálogos de ajuda), não de memória: a legenda cita o
   rótulo do botão exatamente como ele aparece.
3. **Ensaio**: `node recorder.mjs flows/<nome>.mjs --dry`. O ensaio executa tudo sem capturar e
   imprime `[t] legenda` de cada passo. Repita até passar. Com `--headed` você vê o navegador.
   Se um passo falhar, a tela do erro fica em `out/<nome>.error.png`.
4. **Esperar o front ficar quieto** antes da gravação **final**. A árvore precisa estar limpa e o
   último commit precisa ter mais de 10 min:
   `bash check-quiet.sh ../frontend`. O `record-all.sh` aplica essa trava sozinho com
   `QUIET_REPO=../frontend`. Se alguém mexer no texto da tela depois de você gravar, **regrave
   aquele fluxo**: a legenda passou a mentir.
5. **Gravar**: `bash record-all.sh [fluxo…]`. Os fluxos rodam em série, na ordem dada
   (dependências primeiro). Para cada fluxo saem `out/<nome>.raw.mp4` (t=0 no primeiro passo),
   `.captions.json` (`[{start,end,text}]` no mesmo relógio) e `.meta.json`. Em seguida o script
   monta o vídeo. Os logs ficam em `out/logs/<nome>.rec.log` e `.mont.log`.
6. **Montagem** (o `record-all.sh` já chama, mas dá para rodar sozinha):
   `uv run -q --with numpy python montage.py <nome>`.
   - Trilha do `music.py`: pad, arpejo e baixo, com tom, BPM e progressão sorteados pela
     **semente = nome do fluxo**. O mesmo fluxo gera sempre a mesma música, e fluxos diferentes
     geram músicas diferentes. O nível final é `loudnorm` a **−18 LUFS** (`--music-lufs`).
   - Legendas `.ass` (libass), deslocadas pelo cartão de abertura. Cada legenda termina 80 ms
     antes da próxima, para o fade não sobrepor duas caixas.
   - Cartões de **2 s** de abertura (`<brand> — <title>` e subtítulo) e de encerramento.
   - Saída em H.264 (crf 18, `-tune stillimage`), yuv420p, AAC 160k, `+faststart`, no tamanho do
     viewport.
7. **ffprobe + quadros**: `bash probe-all.sh` mostra duração, tamanho e streams, e extrai 4
   quadros por vídeo (12/38/62/88 %) em `out/frames/`.
8. **Conferir 3–6 quadros por vídeo com `read_image`**: a legenda bate com a tela? O dado
   aparece em dd/mm? Sobrou lixo de ensaio na tela? Quadro "errado" pode ser só o meio de um
   passo: extraia um quadro 2 s depois antes de concluir
   (`ffmpeg -ss <t> -i out/x.mp4 -frames:v 1 out/frames/x-check.jpg`).
9. **INDEX.md**: `node make-index.mjs [ordem…]`. Ele lê `summary` e `outsideVideo` de cada fluxo e
   a duração e o formato do ffprobe. Célula vazia sai como "⚠️ preencher". **Revise à mão**:
   observações (cosméticos não corrigidos, dependências entre vídeos) entram numa seção abaixo
   da tabela.
10. **Zip**: `bash package-zip.sh tutoriais` junta os `.mp4` finais (sem `.raw`), os `.ass` e o
    `INDEX.md` em `<OUT_DIR>/../tutoriais.zip`.
11. **Relatório** a quem pediu: duração de cada vídeo, o que falhou e como foi consertado, o que
    ficou cosmético e **os dados que ficaram no banco** (registros criados, ids, registros inativados).

## Como escrever um fluxo

```js
export default {
  name: 'pedido-1-abrir',            // arquivo de saída e semente da música
  title: 'Abrir e enviar um pedido', // cartões
  brand: 'Portal X', subtitle: 'Tutorial · Portal X',   // opcionais (senão BRAND/SUBTITLE)
  summary: 'O que o vídeo mostra (vai para o INDEX).',
  outsideVideo: 'O que o setup fez por API (vai para o INDEX).',
  profile: 'admin',                  // sessão inicial (lib/session.mjs); omita se não há login
  start: '/pedidos',                 // primeira tela, carregada ANTES do cronômetro
  initScript: 'Math.random = () => 0.2;',  // opcional: roda na página antes do app
  async setup({ api, session, log }) {     // opcional: estado de partida, fora do vídeo
    const admin = await api('admin');
    return { id: (await admin.post('/pedidos', { titulo: 'X' })).id };
  },
  steps: [
    { caption: 'Clique em "Novo pedido".',
      run: async (ui) => { await ui.click('button:has-text("Novo pedido")'); } },
    { caption: (c) => `O pedido ${c.id} aparece na lista.`,   // legenda pode usar o ctx
      run: async (ui, c) => { await ui.highlight(`tr:has-text("${c.id}")`, 2600); },
      hold: 800 },                                             // pausa extra no fim do passo
  ],
};
```

**A legenda aparece no início do passo e fica até o próximo começar.** Por isso a regra é: o
passo *faz* o que a legenda *diz*, e dá tempo para ler. Uma frase de ~10 palavras pede uns
2,5 s de tela.

API do `ui` (todas as ações movem o cursor desenhado, realçam o alvo e fazem a pausa):

| Método | O quê |
|---|---|
| `goto(path, {pause})` | navega (path relativo a `BASE_URL`) e espera `networkidle` |
| `click(sel, {pause, force})` | move, mostra o anel do clique e clica; **repete uma vez** se falhar |
| `clickOnce(sel, …)` | igual, sem a nova tentativa (para cliques não idempotentes) |
| `confirm(opener, botão, {dialog, pause, timeout})` | abre o diálogo, **espera ele abrir**, confirma e **espera ele fechar** |
| `type(sel, texto, {pause, clear})` | digitação visível (45 ms/tecla) |
| `fill(sel, valor, {pause})` | preenche de uma vez (texto longo; **data em ISO `aaaa-mm-dd`**) |
| `select(sel, opção, {pause})` | `<select>` |
| `upload(input, arquivos, {show, pause})` | `setInputFiles` com arquivo real; `show` é o alvo a realçar |
| `highlight(sel, ms)` | só realça, para a legenda apontar algo |
| `scroll(dy, {pause})` | roda do mouse |
| `banner(texto, sub, ms)` | faixa central (troca de cena) |
| `as(perfil, path)` | troca de perfil sem corte (regrava o localStorage e navega) |
| `sleep(ms)`, `page`, `ctx`, `api` | saída para o Playwright cru |

**Cliques que abrem um diálogo**: use `ui.confirm(...)`, ou, à mão, o padrão abaixo. Nunca
deixe o passo seguinte presumir que o clique pegou.

```js
await ui.click(OPEN, { pause: 1200 });
await ui.page.locator(CONFIRM).waitFor({ state: 'visible' });
await ui.click(CONFIRM, { pause: 600 });
await ui.page.locator('.dialog-actions').waitFor({ state: 'hidden', timeout: 15000 });
await ui.sleep(1600);
```

Seletores: prefira `:has-text("Rótulo")` / `aria-label` / `#id` estáveis, e `>> nth=1` quando
houver duplicata. Seletor por classe gerada (CSS module) quebra a cada build.

### Estado preparado por API, fora do vídeo, com honestidade

- O `setup` leva o sistema até o **estado de partida** do vídeo: por exemplo, o pedido já
  disparado, entregue e analisado. Ele devolve ids e valores para os passos (`ctx`).
- **A legenda diz quando o preparo muda a leitura**: "Neste exemplo, as duas guias já foram
  analisadas." Um arquivo "respondido offline" que o setup monta por API é **entregue pela
  própria tela** (no `<input type=file>` dela), e a legenda conta que ele foi preparado antes.
- O `outsideVideo` de cada fluxo diz no INDEX o que foi feito fora da câmera.
- Para que regravar dê o mesmo vídeo, o setup é **idempotente**: ele escolhe a primeira
  competência ou o primeiro código livre e desfaz o que um ensaio anterior deixou (ver
  Armadilhas).
- Não invente regra de negócio para encaixar o vídeo. Se a tela não deixa, o vídeo não mostra.

### Upload de arquivo

Use arquivo **real**, em `fixtures/`, via `ui.upload('input[type=file]', caminho, { show: 'label do campo' })`.
Isso é `setInputFiles`, que dispensa o diálogo nativo do SO. Para input escondido atrás de um
botão estilizado, passe o input em `input` e o botão em `show`.

## Armadilhas já pagas

| Sintoma | Causa | Conserto (já no motor, salvo indicação) |
|---|---|---|
| Texto miúdo borrado, ilegível no vídeo | `recordVideo` do Playwright grava VP8 a ~1 Mbps | **Screencast CDP** (JPEG q92): cada quadro carrega o instante de pintura, e o ffconcat usa a duração real de cada quadro. Legenda e imagem ficam no mesmo relógio, sem marcador de sincronia. |
| `<input type=date>` mostra **mm/dd/aaaa** com a tela dizendo dd/mm/aaaa | O `locale` do contexto **não chega** ao widget de data do Chromium | `LANG`/`LC_ALL`/`LANGUAGE` no **processo** + `--lang=pt-BR`. Precisa de `pt_BR.UTF-8` gerado no SO. |
| Botão nativo do arquivo aparece **"Choose File" / "No file chosen"** | Rótulo dos recursos internos do Chromium headless; o locale não muda | **Não corrigido.** Não cite esse botão na legenda; prefira realçar o rótulo do app (`show`). |
| Gravação final falha (`waitFor timeout`) num passo que passava no ensaio | Sob a carga da captura, o clique de confirmar um diálogo **se perdeu**, e o estado ficou parado no servidor | `ui.confirm` / o padrão de esperar o diálogo abrir e fechar. Depois de uma falha, **confira o estado que ficou** (o registro ficou parado numa etapa) e conte no relatório. |
| Overlay do Vite / tela recarregando no meio do passo | Outro agente editando o front; o HMR recompila | Overlay escondido por CSS; `ui.click` tenta de novo uma vez; **gravação final só com o front quieto** (`check-quiet.sh`). |
| Lista mostrando lixo de ensaio (ITEM, ITEM-2, ITEM-3 já marcados) | Ensaios criam registros, o código único não se libera ao inativar, e associações ficam | O setup **devolve o estado semeado** (ex.: a associação documento × itens exata do dado de demonstração) e **inativa só o que ensaios criaram**, por regex de código com sufixo. Os códigos do seed vão numa lista de exclusão. Confira no script de seed o que é seed **antes** de inativar. Use códigos de base novos (`-RESP`, `-DOC`) para não colidir com o seed. |
| Legenda descrevendo uma dica que não é a que aparece | A dica é sorteada com `Math.random` | `initScript: 'Math.random = () => 0.2;'` fixa o sorteio **só na página gravada**. Calcule o índice pela ordem do catálogo filtrado do perfil e confira no quadro. Diga isso no INDEX. |
| Dica ou aviso some na segunda gravação | "Dispensado" gravado no localStorage | O storageState nasce limpo a cada execução, só com os itens da sessão. Não reaproveite perfil do Chrome. |
| Token de API recusado | Banco local recriado; token de arquivo velho | Leia a sessão da página que o front serve (`SESSION_URL_TEMPLATE`), que sempre traz o token vigente. |
| Quadro "não bate" com a legenda | O quadro extraído caiu no meio do passo | Extraia outro 1–2 s depois antes de mexer no fluxo. |
| Vídeo repetindo um dado que já existe (o mesmo registro do vídeo anterior) | Competência ou código fixo no fluxo | O setup procura o **primeiro livre** (`freeCode`, primeiro período livre). |
| Dois fluxos brigando pelo backend | Gravação em paralelo | O `record-all.sh` roda **em série**, na ordem dada; o fluxo dependente vem depois. |
| Shell do agente bloqueia laços ("N operações") | Política do harness | Laços ficam em script (`record-all.sh`, `probe-all.sh`), nunca inline. |

## Exemplo incluído

`examples/` contém uma página estática (`demo-site/index.html`) com dica sorteada, campo de
data, upload e confirmação com atraso. Contém também o fluxo `flows/exemplo-pedido.mjs`, que
exercita todas as armadilhas acima, a fixture `fixtures/orcamento-exemplo.txt` e o
`brief.example.md`. Teste de fumaça em diretório limpo:

```fish
set T (mktemp -d /tmp/wtv.XXXX)
cp -r ~/.agents/skills/web-tutorial-videos/scripts/. ~/.agents/skills/web-tutorial-videos/examples/. $T/
cd $T; npm install; npx playwright install chromium
set -x BASE_URL file://$T/demo-site
node recorder.mjs flows/exemplo-pedido.mjs --dry
bash record-all.sh exemplo-pedido; and bash probe-all.sh; and node make-index.mjs; and bash package-zip.sh
```

Resultado esperado: `exemplo-pedido.mp4` com ~29 s, `h264,1280,800 aac`. O quadro em 38 %
mostra a data "01/12/2026" e a dica "você confirma antes de enviar…".