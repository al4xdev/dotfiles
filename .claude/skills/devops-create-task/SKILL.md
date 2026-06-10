---
name: devops-create-task
description: This skill should be used when the user asks to "criar bug", "criar issue", "criar task", "abrir work item", "criar work item no devops", "azure devops", "az boards", or discusses creating/listing/updating work items in Azure DevOps via CLI. Documents the validated process for the configured org/project (read from fish universal vars) including PAT auth, required custom fields, bulk creation pattern, and field discovery.
version: 2.0.0
---

# Azure DevOps — Criar work items via CLI

Processo validado para criar Bug/Task/Issue na organização/projeto configurados, usando `az` CLI + extensão `azure-devops`.

> **Dados sensíveis vivem em variáveis universais do fish, não no skill.** Org, projeto e assignee (e o PAT) não são hardcoded aqui — são lidos do ambiente. Isso permite versionar/publicar o skill sem vazar nome de org, projeto ou e-mail corporativo.

## Quando aplicar

- Usuário pede para criar/abrir/listar bugs, tasks, issues, work items no Azure DevOps
- Usuário menciona `az boards`, `dev.azure.com`, ou referencia tickets do projeto
- Usuário pede para registrar achados de code review como issues rastreáveis

## Pré-requisitos do ambiente (já configurados no host)

- `az` CLI 2.83+ com extensão `azure-devops` instalada (`az extension list | grep azure-devops`)
- **Variáveis universais do fish** com os dados do tenant (definidas uma vez via `set -Ux`):
  ```fish
  set -Ux AZURE_DEVOPS_EXT_PAT  <pat>                       # PAT com escopo Work Items: Read & Write
  set -Ux AZURE_DEVOPS_ORG_URL  https://dev.azure.com/<org> # URL da organização
  set -Ux AZURE_DEVOPS_PROJECT  <project>                   # nome do projeto
  set -Ux AZURE_DEVOPS_ASSIGNEE <email>                     # assignee default (--assigned-to)
  ```
- Para gerar PAT novo: `$AZURE_DEVOPS_ORG_URL/_usersSettings/tokens`

## ⚠️ Pegadinha de auth + leitura das vars (importante)

O processo do Claude Code é spawnado **antes** do `set -Ux` do fish ser exportado, então a tool Bash (que é `/bin/bash`, não fish) **não enxerga** as variáveis universais diretamente.

**Solução**: ler cada valor via `fish -c` no começo de todo bloco bash (fish lê universal vars do disco em tempo real):

```bash
export AZURE_DEVOPS_EXT_PAT=$(fish -c 'echo -n $AZURE_DEVOPS_EXT_PAT')
ORG=$(fish -c 'echo -n $AZURE_DEVOPS_ORG_URL')
PROJECT=$(fish -c 'echo -n $AZURE_DEVOPS_PROJECT')
ASSIGNEE=$(fish -c 'echo -n $AZURE_DEVOPS_ASSIGNEE')
```

Validar que pegou tudo:
```bash
for v in AZURE_DEVOPS_EXT_PAT ORG PROJECT ASSIGNEE; do
  [ -n "${!v}" ] && echo "$v OK" || echo "$v FAIL — rodar set -Ux no fish"
done
```

Conta logada via `az login` interativo do tenant é tratada como **guest user** pela org DevOps e falha com `TF909091`. Sempre usar PAT.

## 📅 Política de datas (regra do skill)

O template **não tem** campos editáveis de data (sem `StartDate`/`TargetDate`/`DueDate`/`FinishDate` para Task). Os únicos campos de data são system-computed: `System.CreatedDate`, `System.ChangedDate`, `Microsoft.VSTS.Common.ActivatedDate`, `Microsoft.VSTS.Common.StateChangeDate`.

**Política**: sempre embutir uma linha de data **no início do description/ReproSteps** em HTML:

```html
<p><b>Data:</b> 2026-04-29</p>
<p>...resto do conteúdo...</p>
```

Regras:
1. **Se o usuário fornecer data** (ex.: "marca pra 28/04"), normalizar para `YYYY-MM-DD` e usar.
2. **Se o usuário NÃO fornecer**, usar `date '+%Y-%m-%d'` (dia atual) como default — **nunca** perguntar nem deixar sem data.
3. **Em lote (batch)**: todas as tasks ganham **a mesma data de partida** (não distribuir entre dias). Se o usuário pedir um cálculo de horas/distribuição, pode estimar totais (ex.: "soma 12h em 6 tasks de 2h") mas a `<b>Data:</b>` é única para o lote.
4. Para múltiplas datas (ex.: "início" e "prazo"), use `<b>Início:</b> 2026-04-29 — <b>Prazo:</b> 2026-05-03` na mesma linha.

A data fica pesquisável via WIQL com `[System.Description] CONTAINS '2026-04-29'`.

## Campos obrigatórios do template

| Campo | Reference name | Tipo | Obrigatório | Default sugerido |
|---|---|---|---|---|
| Testing Phase | `Custom.TestingPhase` | free text | ✅ sim | `"N/A"` |
| Title | `System.Title` | string | ✅ sim | — |
| Type | — (`--type`) | enum | ✅ sim | `Bug` / `Task` / `Issue` / `User Story` |

Campos opcionais úteis:
- `Microsoft.VSTS.Scheduling.RemainingWork` — horas (decimal). Use para "X horas estimadas".
- `Microsoft.VSTS.Scheduling.Effort` — story points (não horas).
- `--assigned-to "$ASSIGNEE"` — funciona com email corporativo.

**Não existe** `Microsoft.VSTS.Scheduling.OriginalEstimate` neste template — não tente usar.

## ⚠️ Pegadinha CRÍTICA: campo de descrição varia por tipo

A flag `--description` do `az boards work-item create` mapeia para `System.Description`. Mas **a UI mostra campos diferentes dependendo do tipo**:

| Tipo | Campo visível na UI (form principal) | Campo que `--description` preenche |
|---|---|---|
| **Bug** | `Microsoft.VSTS.TCM.ReproSteps` (Repro Steps / Passos para Reproduzir) | `System.Description` (oculto no form padrão) |
| Task | `System.Description` | `System.Description` ✅ |
| User Story | `System.Description` | `System.Description` ✅ |
| Issue | `System.Description` | `System.Description` ✅ |

**Resultado**: para `--type Bug`, usar apenas `--description "..."` faz o bug aparecer **vazio na UI**, mesmo com `System.Description` preenchido por baixo. Confirma via:
```bash
az boards work-item show --id <id> --org "$ORG" \
  --query "{desc:fields.\"System.Description\", repro:fields.\"Microsoft.VSTS.TCM.ReproSteps\"}"
```

**Solução** ao criar Bug — sempre setar **ReproSteps** (e duplicar em Description por segurança):
```bash
az boards work-item create \
  --type Bug \
  --title "..." \
  --description "$desc" \
  --fields "Custom.TestingPhase=N/A" \
           "Microsoft.VSTS.Scheduling.RemainingWork=1" \
           "Microsoft.VSTS.TCM.ReproSteps=$desc"
```

**Tip**: ReproSteps aceita HTML. Para listas/quebras de linha visuais, pode passar `<br>`, `<ul><li>...`. Texto puro funciona — quebras de linha viram um único parágrafo. Para itens de code review, formato sugerido:
```html
<b>Local:</b> tef/pipelines/tef.py:1503-1506<br><b>Problema:</b> dropDuplicates...<br><b>Sugestão:</b> usar Window + row_number.
```

## ⚠️ Pegadinha CRÍTICA: `System.State` não aceita estado intermediário no `create`

`az boards work-item create` aceita apenas o **estado inicial** do tipo (Task → `To Do`, Bug → `New`, etc.). Tentar passar `--fields "System.State=In Progress"` falha com:
```
ERROR: The field 'State' contains the value 'In Progress' that is not in the list of supported values.
```

**Solução**: criar primeiro, depois transicionar via `update --state`:

```bash
id=$(az boards work-item create \
  --org "$ORG" \
  --project "$PROJECT" \
  --type Task \
  --title "..." \
  --description "..." \
  --assigned-to "$ASSIGNEE" \
  --fields "Custom.TestingPhase=N/A" "Microsoft.VSTS.Scheduling.RemainingWork=2" \
  --query "id" -o tsv)

az boards work-item update --id "$id" \
  --org "$ORG" \
  --state "In Progress"
```

**Estados válidos por tipo** (descobrir via `az devops invoke --area wit --resource workitemtypes --route-parameters project=$PROJECT type=... --query "states[].name" -o tsv`):

| Tipo | Estados |
|---|---|
| Task | `To Do` → `In Progress` → `Done` (ou `Removed`) |
| Bug | `New` → `Active` → `Resolved` → `Closed` |
| User Story | `New` → `Active` → `Resolved` → `Closed` |
| Issue | `To Do` → `Doing` → `Done` |

⚠️ Não confundir: Task usa **`In Progress`** (com espaço), Issue usa **`Doing`**, Bug/User Story usam **`Active`**.

## Comando base (single work item)

```bash
export AZURE_DEVOPS_EXT_PAT=$(fish -c 'echo -n $AZURE_DEVOPS_EXT_PAT')
ORG=$(fish -c 'echo -n $AZURE_DEVOPS_ORG_URL')
PROJECT=$(fish -c 'echo -n $AZURE_DEVOPS_PROJECT')
ASSIGNEE=$(fish -c 'echo -n $AZURE_DEVOPS_ASSIGNEE')
TODAY=$(date '+%Y-%m-%d')   # data default — usar o que o usuário deu, senão hoje

desc="<p><b>Data:</b> ${TODAY}</p><p>Descrição com file:line e contexto.</p>"

az boards work-item create \
  --org "$ORG" \
  --project "$PROJECT" \
  --type Bug \
  --title "[BUG] título curto" \
  --description "$desc" \
  --assigned-to "$ASSIGNEE" \
  --fields "Custom.TestingPhase=N/A" "Microsoft.VSTS.Scheduling.RemainingWork=1" \
           "Microsoft.VSTS.TCM.ReproSteps=$desc" \
  --query "{id:id, url:url, state:fields.\"System.State\"}" \
  -o json
```

URL humana resultante:
```
$ORG/$PROJECT/_workitems/edit/<id>
```

## Pattern de criação em lote (recomendado para >3 itens)

Escrever JSONL → loop bash. Evita problemas de escaping com aspas/acentos/quebra-de-linha em descrições.

**Passo 1**: gerar `/tmp/items.jsonl`, uma linha por item, com schema `{"title": "...", "desc": "..."}`.

**Passo 2**: loop:

```bash
export AZURE_DEVOPS_EXT_PAT=$(fish -c 'echo -n $AZURE_DEVOPS_EXT_PAT')
ORG=$(fish -c 'echo -n $AZURE_DEVOPS_ORG_URL')
PROJECT=$(fish -c 'echo -n $AZURE_DEVOPS_PROJECT')
ASSIGNEE=$(fish -c 'echo -n $AZURE_DEVOPS_ASSIGNEE')
> /tmp/items_results.tsv
i=0
while IFS= read -r line; do
  i=$((i+1))
  title=$(printf '%s' "$line" | jq -r '.title')
  desc=$(printf '%s' "$line" | jq -r '.desc')
  out=$(az boards work-item create \
    --org "$ORG" \
    --project "$PROJECT" \
    --type Bug \
    --title "$title" \
    --description "$desc" \
    --assigned-to "$ASSIGNEE" \
    --fields "Custom.TestingPhase=N/A" \
             "Microsoft.VSTS.Scheduling.RemainingWork=1" \
             "Microsoft.VSTS.TCM.ReproSteps=$desc" \
    --query "id" -o tsv 2>&1)
  if [ $? -eq 0 ]; then
    printf '%s\t%s\t%s\n' "$i" "$out" "$title" | tee -a /tmp/items_results.tsv
  else
    printf 'FAIL[%s]\t%s\t%s\n' "$i" "$title" "$out" | tee -a /tmp/items_results.tsv
  fi
done < /tmp/items.jsonl
echo "OK: $(grep -cv '^FAIL' /tmp/items_results.tsv)  FAIL: $(grep -c '^FAIL' /tmp/items_results.tsv)"
```

**Tip**: descrições/títulos sem caracteres especiais não-ASCII na geração inicial reduzem risco de erro em jq/shell. Acentos funcionam, mas evite aspas duplas dentro do valor (escape ou prefira aspas simples).

## Padrão para code reviews / batches de findings (recomendado)

Quando os work items vêm de uma análise (lista de bugs, code smells, refactor TODOs), gere o JSONL via **Python** — escapa HTML/JSON automaticamente, mantém estrutura, e o ReproSteps fica formatado bonito na UI.

### Convenção de type: findings → `Bug`, work items operacionais → `Task`

Validado: o ícone do `Bug` no quadro DevOps é visualmente mais distintivo (vermelho/inseto) do que o ícone genérico de `Task`. Quando findings de code review viram work items, **classificar todos como `--type Bug`** independente da gravidade — `[SMELL]` e `[NIT]` ganham o mesmo tratamento de `[BUG]`. A granularidade fica preservada pelo **prefixo do título** (`[BUG]`/`[SMELL]`/`[NIT]`/`[PERF]`), que continua filtrando bem em WIQL e Ctrl+F.

| Tag no título | `--type` no DevOps | Justificativa |
|---|---|---|
| `[BUG]` | `Bug` | Bug real |
| `[SMELL]` | `Bug` | Ícone melhor; tag preserva a classificação |
| `[NIT]` | `Bug` | Mesma razão |
| `[PERF]` | `Bug` | Mesma razão |
| `[TASK]` / `[REFACTOR]` / `[CR]` | `Task` | Trabalho operacional, não finding |

**Mapear em código** — cada item carrega `tag` (display) e `type` (DevOps); o helper deriva `type` de `tag` se não vier explícito:

```python
TAG_TO_TYPE = {
    "[BUG]": "Bug", "[SMELL]": "Bug", "[NIT]": "Bug", "[PERF]": "Bug",
    "[TASK]": "Task", "[REFACTOR]": "Task", "[CR]": "Task",
}
```

⚠️ **Type não pode ser alterado depois do create.** `az boards work-item update` não aceita `--type`. Se você criou como `Task` e precisa virar `Bug`, o caminho é **delete (soft) + recreate** com a mesma desc — exemplo na seção "Operações além de criar". Por isso confirme o type **antes** do bulk.

### Workflow validado (8 passos)

1. **Listar findings em conversa** com seções claras (`🐛 Bugs`, `🟡 Smells`) e padrão `título — file:linha` + corpo curto
2. **Mapear tag → type** via tabela acima (findings = Bug, operacionais = Task) — fica embutido no JSONL como campo `type`
3. **Confirmar com o usuário** quais entram, hours por tag, e quem assigna; reforçar que type **não é alterável** depois do create
4. **Validar PAT + vars** uma única vez (ver bloco de validação na seção de auth) — todas devem retornar não-vazio
5. **Gerar JSONL** via script Python (template abaixo) — uma linha por item, com `type`/`title`/`desc`
6. **Criar 1 sample** primeiro, mostrar URL pro usuário inspecionar
7. **Aguardar OK** explícito antes do bulk
8. **Loop bash** para os restantes; salvar IDs em `/tmp/<x>_results.tsv` para rollback fácil

### Estrutura de cada item no Python

```python
{
    "tag": "[BUG]" | "[SMELL]" | "[NIT]" | "[PERF]" | "[TASK]" | "[REFACTOR]" | "[CR]",
    "type": "Bug" | "Task",                   # derivar de tag via TAG_TO_TYPE (ver convenção acima)
    "title": "descrição curta do problema",   # sem o ref
    "ref": "arquivo.py:linha",                # ou range, ou "vs outro_arquivo.py:linha"
    "code": "snippet relevante" | None,       # vira <pre>...</pre> escapado
    "body_html": "<p>...</p><ul><li>...</li></ul>",  # explicação completa em HTML
}
```

O loop bash do bulk lê `.type` de cada linha do JSONL e:
- Passa para `--type "$type"`.
- Anexa `Microsoft.VSTS.TCM.ReproSteps=$desc` em `--fields` **só quando `type == "Bug"`** (Task usa só `System.Description`).

A **data do batch** é única (ver "Política de datas") — passada uma vez para o gerador, não por item:

```python
from datetime import date
BATCH_DATE = date.today().isoformat()   # ou data passada pelo usuário (YYYY-MM-DD)
```

### Render do title e do ReproSteps

```python
def render_title(item):
    return f'{item["tag"]} {item["title"]} — {item["ref"]}'

def render_repro(item, batch_date):
    parts = [
        f'<p><b>Data:</b> {batch_date}</p>',
        f'<p><b>Local:</b> <code>{item["ref"]}</code></p>',
    ]
    if item.get("code"):
        parts.append(f'<pre>{html_escape_code(item["code"])}</pre>')
    parts.append(item["body_html"])
    return "".join(parts)

def html_escape_code(s):  # apenas dentro de <pre>
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
```

### HTML que renderiza bem na UI do Bug

| Tag | Uso |
|---|---|
| `<p>...</p>` | Parágrafo — única forma confiável de quebrar linha |
| `<b>Label:</b>` | Destaque (ex.: `<b>Local:</b>`, `<b>Sugestão:</b>`) |
| `<pre>...</pre>` | Bloco de código multilinha — fonte mono |
| `<code>nome</code>` | Identificador inline (variável, função, classe) |
| `<ul><li>...</li></ul>` | Lista com bullets — bom para enumerar casos/sintomas |

⚠️ **Não use `<br>` solto** — `<p>` sempre rende mais consistente. Não use `<h1>`/`<h2>` (a UI do Bug já tem cabeçalho próprio).

### Snippet final do gerador

```python
import json
from datetime import date

TAG_TO_TYPE = {
    "[BUG]": "Bug", "[SMELL]": "Bug", "[NIT]": "Bug", "[PERF]": "Bug",
    "[TASK]": "Task", "[REFACTOR]": "Task", "[CR]": "Task",
}

ITEMS = [ {...}, {...}, ... ]  # lista de dicts no schema acima
BATCH_DATE = date.today().isoformat()  # ou data fornecida pelo usuário

with open("/tmp/items.jsonl", "w", encoding="utf-8") as f:
    for it in ITEMS:
        item_type = it.get("type") or TAG_TO_TYPE[it["tag"]]
        f.write(json.dumps(
            {"type": item_type, "title": render_title(it), "desc": render_repro(it, BATCH_DATE)},
            ensure_ascii=False
        ) + "\n")
```

### Loop bash adaptado para `type` por item

```bash
export AZURE_DEVOPS_EXT_PAT=$(fish -c 'echo -n $AZURE_DEVOPS_EXT_PAT')
ORG=$(fish -c 'echo -n $AZURE_DEVOPS_ORG_URL')
PROJECT=$(fish -c 'echo -n $AZURE_DEVOPS_PROJECT')
ASSIGNEE=$(fish -c 'echo -n $AZURE_DEVOPS_ASSIGNEE')
> /tmp/items_results.tsv
i=0
while IFS= read -r line; do
  i=$((i+1))
  type=$(printf '%s' "$line" | jq -r '.type')
  title=$(printf '%s' "$line" | jq -r '.title')
  desc=$(printf '%s' "$line" | jq -r '.desc')

  fields_args=("Custom.TestingPhase=N/A" "Microsoft.VSTS.Scheduling.RemainingWork=1")
  # ReproSteps so faz sentido em Bug — Task usa System.Description direto
  if [ "$type" = "Bug" ]; then
    fields_args+=("Microsoft.VSTS.TCM.ReproSteps=$desc")
  fi

  out=$(az boards work-item create \
    --org "$ORG" \
    --project "$PROJECT" \
    --type "$type" \
    --title "$title" \
    --description "$desc" \
    --assigned-to "$ASSIGNEE" \
    --fields "${fields_args[@]}" \
    --query "id" -o tsv 2>&1)
  if [ $? -eq 0 ]; then
    printf '%s\t%s\n' "$out" "$title" | tee -a /tmp/items_results.tsv
  else
    printf 'FAIL[%s]\t%s\t%s\n' "$i" "$title" "$out" | tee -a /tmp/items_results.tsv
  fi
done < /tmp/items.jsonl
echo "OK: $(grep -cv '^FAIL' /tmp/items_results.tsv)  FAIL: $(grep -c '^FAIL' /tmp/items_results.tsv)"
```

### Exemplo concreto (item gerado)

**Title**: `[BUG] dropDuplicates() após orderBy() em get_df_main — não-determinístico — tef.py:1503-1506`

**ReproSteps (HTML)**:
```html
<p><b>Data:</b> 2026-04-29</p>
<p><b>Local:</b> <code>tef.py:1503-1506</code></p>
<pre>df: SparkDataFrame = self.tables.cascata.orderBy(F.abs(F.col("DIF"))).dropDuplicates()</pre>
<p><code>dropDuplicates</code> reordena via shuffle/hash, então a ordenação por <code>abs(DIF)</code> é descartada. Se a intenção é manter a linha de menor |DIF| por chave, precisa <code>Window.partitionBy(...).orderBy(F.abs("DIF")) + row_number()==1</code>.</p>
```

## Regras / checklist antes de subir no DevOps

1. ☐ Usuário **confirmou explicitamente** o type, hours, e quem assigna — lembrar que **type não é alterável** depois do create (precisa delete + recreate)
2. ☐ Findings (`[BUG]`/`[SMELL]`/`[NIT]`/`[PERF]`) usam `--type Bug` para ícone visualmente distintivo no quadro; `[TASK]`/`[REFACTOR]`/`[CR]` usam `--type Task`
3. ☐ PAT + vars (`ORG`/`PROJECT`/`ASSIGNEE`) visíveis via `fish -c` (testar antes do loop)
4. ☐ Para `--type Bug`, **sempre** passar `Microsoft.VSTS.TCM.ReproSteps` além de `--description` (Task usa só `System.Description`)
5. ☐ `Custom.TestingPhase` setado (default `"N/A"` — ou pedir valor ao usuário se contexto exigir)
6. ☐ **Data** embutida no body: `<b>Data:</b> YYYY-MM-DD` no início — usar a fornecida pelo usuário ou `date '+%Y-%m-%d'` (hoje). Em batch, **mesma data para todas**.
7. ☐ Se o usuário pediu estado intermediário (`In Progress`/`Active`/`Doing`): criar primeiro, depois `update --state` — nunca via `--fields "System.State=..."` no create.
8. ☐ Title prefixado com tag `[BUG]`/`[SMELL]`/etc — facilita filtros no quadro
9. ☐ Title inclui `file:linha` no fim — facilita WIQL e Ctrl+F
10. ☐ Ref também aparece em `<b>Local:</b>` no body para quem abre o item
11. ☐ Criar **1 sample** e pedir validação visual antes do bulk (>3 itens)
12. ☐ IDs salvos em `/tmp/*_results.tsv` para rollback fácil
13. ☐ Rollback testado: `az boards work-item delete --project "$PROJECT" --yes` (lembrar `--project`)

## Comandos de descoberta (úteis quando o template muda)

```bash
ORG=$(fish -c 'echo -n $AZURE_DEVOPS_ORG_URL')
PROJECT=$(fish -c 'echo -n $AZURE_DEVOPS_PROJECT')
```

**Listar campos obrigatórios de um type**:
```bash
az devops invoke --area wit --resource workitemtypes \
  --route-parameters project=$PROJECT type=Bug \
  --org "$ORG" \
  --query "fields[?alwaysRequired].{name:name, ref:referenceName}" -o json
```

**Inspecionar campo específico (ver se é picklist, allowedValues)**:
```bash
az devops invoke --area wit --resource fields \
  --route-parameters fieldNameOrRefName=Custom.TestingPhase \
  --org "$ORG" -o json
```

**Listar tipos de work item disponíveis**:
```bash
az boards work-item show --help  # mostra estrutura
az devops invoke --area wit --resource workitemtypes \
  --route-parameters project=$PROJECT \
  --org "$ORG" \
  --query "[].name" -o tsv
```

## Operações além de criar

**Atualizar**:
```bash
az boards work-item update --id <id> \
  --org "$ORG" \
  --state "Active" \
  --fields "Microsoft.VSTS.Scheduling.RemainingWork=2"
```

**Trocar type (Task ↔ Bug ↔ User Story)** — `update` não aceita `--type`. Caminho validado: soft-delete + recreate com mesma desc:
```bash
export AZURE_DEVOPS_EXT_PAT=$(fish -c 'echo -n $AZURE_DEVOPS_EXT_PAT')
ORG=$(fish -c 'echo -n $AZURE_DEVOPS_ORG_URL')
PROJECT=$(fish -c 'echo -n $AZURE_DEVOPS_PROJECT')
ASSIGNEE=$(fish -c 'echo -n $AZURE_DEVOPS_ASSIGNEE')

# 1. Capturar desc/title antes de deletar
old=$(az boards work-item show --id <id> \
  --org "$ORG" \
  --query "{title:fields.\"System.Title\", desc:fields.\"System.Description\"}" -o json)
title=$(echo "$old" | jq -r '.title')
desc=$(echo "$old" | jq -r '.desc')

# 2. Soft-delete (recuperável ~30 dias)
az boards work-item delete --id <id> \
  --org "$ORG" \
  --project "$PROJECT" --yes -o tsv

# 3. Recriar com novo type — adicionar ReproSteps se virar Bug
az boards work-item create \
  --org "$ORG" \
  --project "$PROJECT" \
  --type Bug \
  --title "$title" --description "$desc" \
  --assigned-to "$ASSIGNEE" \
  --fields "Custom.TestingPhase=N/A" "Microsoft.VSTS.Scheduling.RemainingWork=1" \
           "Microsoft.VSTS.TCM.ReproSteps=$desc" \
  --query "id" -o tsv
```
⚠️ O ID **muda** após recreate. Atualizar referências externas (links em PRs, comentários, queries).

**Deletar (soft, vai para Recycle Bin — fica recuperável ~30 dias)**:
```bash
az boards work-item delete --id <id> \
  --org "$ORG" \
  --project "$PROJECT" \
  --yes
```
⚠️ `--project` é **obrigatório** no delete (mensagem de erro `--project must be specified` se faltar). `--yes` pula confirmação interativa.

**Deletar permanente** (`--destroy` requer permissão elevada):
```bash
az boards work-item delete --id <id> --destroy \
  --org "$ORG" \
  --project "$PROJECT" --yes
```

**Bulk delete** (a partir de TSV `id\ttitle`):
```bash
export AZURE_DEVOPS_EXT_PAT=$(fish -c 'echo -n $AZURE_DEVOPS_EXT_PAT')
ORG=$(fish -c 'echo -n $AZURE_DEVOPS_ORG_URL')
PROJECT=$(fish -c 'echo -n $AZURE_DEVOPS_PROJECT')
for id in $(awk -F'\t' '{print $2}' /tmp/items_results.tsv | sort -n); do
  az boards work-item delete --id "$id" \
    --org "$ORG" \
    --project "$PROJECT" --yes -o tsv
done
```

**Buscar work items atribuídos**:
```bash
ORG=$(fish -c 'echo -n $AZURE_DEVOPS_ORG_URL')
PROJECT=$(fish -c 'echo -n $AZURE_DEVOPS_PROJECT')
az boards query --org "$ORG" \
  --wiql "SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.AssignedTo] = @Me AND [System.TeamProject] = '$PROJECT'"
```

## Erros comuns e como tratar

| Erro | Causa | Fix |
|---|---|---|
| `TF909091: Guest users are not permitted` | `az login` interativo sem PAT | Usar PAT via `AZURE_DEVOPS_EXT_PAT` |
| `TF401320: Rule Error for field X. Required, InvalidEmpty` | Campo custom obrigatório não passado | Adicionar em `--fields "X=<valor>"` |
| `TF401347: Field is read-only` | Tentativa de atualizar campo system computado | Remover do update |
| Auth funciona via `fish -c` mas falha em outro contexto | Universal var só nas sessões fish | Persistente; se quebrar, `set -Ux` de novo |
| Bug aparece sem descrição na UI mesmo com `--description` setado | Bug usa `Microsoft.VSTS.TCM.ReproSteps` na UI, não `System.Description` | Adicionar `--fields "Microsoft.VSTS.TCM.ReproSteps=$desc"` |
| `--project must be specified` no `az boards work-item delete` | Delete exige `--project` (create não exige) | Sempre passar `--project "$PROJECT" --yes` |
| `The field 'State' contains the value 'In Progress' that is not in the list of supported values` no create | Create só aceita estado inicial do tipo (Task → `To Do`, Bug → `New`) | Criar primeiro, depois `az boards work-item update --id $id --state "In Progress"` |
| Quero trocar `--type` de um work item já criado | `update` não aceita `--type` (read-only após create) | Soft-delete + recreate com mesma `desc` (ver "Trocar type" em "Operações além de criar"). ID muda. |
| `[SMELL]`/`[NIT]` criados como `Task` aparecem com ícone genérico no quadro | Convenção do skill: findings = `Bug` (ícone melhor); operacionais = `Task` | Recriar como `Bug` mantendo o prefixo `[SMELL]`/`[NIT]` no título |
| Alguma var (`ORG`/`PROJECT`/`ASSIGNEE`) vem vazia | `set -Ux` não rodado, ou nome errado | Rodar o bloco de validação na seção de auth; redefinir via `set -Ux` no fish |

## Boas práticas

1. **Sempre confirmar com o usuário** antes de criar em lote (>3 work items) — ação visível para outros.
2. **Salvar resultado** (`/tmp/*_results.tsv`) — facilita rollback se precisar deletar em massa.
3. **Prefixar título** com tag (`[BUG]`, `[SMELL]`, `[TASK]`, `[CR]`) ajuda filtros/queries.
4. **Não commitar segredos** — PAT, org, projeto e e-mail vivem em variáveis universais do fish, nunca hardcoded no skill ou no código.
5. **Cuidado com 1h estimada como default** — confirmar com usuário antes de assumir; itens grandes precisam decompor.

## Referências

- Org URL: variável `$AZURE_DEVOPS_ORG_URL`
- Projeto: variável `$AZURE_DEVOPS_PROJECT`
- Assignee: variável `$AZURE_DEVOPS_ASSIGNEE`
- Tokens: `$AZURE_DEVOPS_ORG_URL/_usersSettings/tokens`
- Docs CLI: `https://learn.microsoft.com/cli/azure/boards/work-item`
