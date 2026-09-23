# agy scout MCP

Servidor MCP local para despachar o `agy` como scout de contexto longo.

O Codex carrega o servidor pela entrada `mcp_servers.agy_scout` em
`~/.codex/config.toml`. O servidor usa somente a biblioteca padrão do Python;
o processo externo é o binário `agy`.

As tools retornam dados compactos:

Todas as respostas incluem `codex_5h` com `remaining_percent` e `resets_at`
(ISO 8601 em UTC). O servidor consulta `account/rateLimits/read` pelo binário
local do Codex ao responder; se a consulta falhar ou a janela de 5 horas não
estiver disponível, o campo vem como `null`. Essa consulta não envia prompt
nem consome uma chamada de modelo.
Quando restam 5% ou menos e o reset ainda está no futuro, `codex_5h` também
inclui uma recomendação para o agente avisar, aguardar o reset e retomar a
tarefa pendente.

- `agy_scout(prompt, cwd?)`: inicia um scout e retorna `run_id` e
  `conversation_id`.
- `agy_status(run_id, tail=0)`: retorna apenas o estado do processo. Eventos e
  diagnósticos só são retornados quando `tail` é solicitado explicitamente.
- `agy_wait(run_id, timeout_seconds=300)`: aguarda a conclusão sem expor eventos
  intermediários ao contexto; retorna o resultado final ou `timeout`.
- `agy_followup(run_id, prompt)`: envia uma mensagem para a próxima janela.
- `agy_interrupt(run_id, force?)`: envia SIGTERM ou SIGKILL.
- `agy_continue(run_id, prompt)`: inicia outro processo com o mesmo
  `conversation_id`.

Cada execução grava o stream bruto em `.agy-runs/<run_id>.jsonl` e metadados em
`.agy-runs/<run_id>.meta.json`. Esses arquivos são ignorados pelo Git e nunca
são incluídos automaticamente no retorno das tools.
