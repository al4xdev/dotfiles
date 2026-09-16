# agy scout MCP

Servidor MCP local para despachar o `agy` como scout de contexto longo.

O Codex carrega o servidor pela entrada `mcp_servers.agy_scout` em
`~/.codex/config.toml`. O servidor usa somente a biblioteca padrão do Python;
o processo externo é o binário `agy`.

As tools retornam dados compactos:

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
