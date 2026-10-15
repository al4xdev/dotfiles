---
name: press-enter
description: >
  Envia uma tecla (Enter por padrão) para a janela ativa do usuário via ydotool.
  Use quando o usuário pedir para "dar enter", "apertar enter", "mandar enter na
  janela ativa/no Teams". Use TAMBÉM (esse é o caso de uso principal) quando o
  usuário disser que vai rodar uma tarefa longa e deixar uma mensagem já
  digitada numa janela (ex. Teams) pra funcionar como aviso de "terminei" —
  nesse caso a skill tem DUAS etapas obrigatórias: testar a permissão agora
  (no início) e mandar o Enter de verdade sozinho no fim da tarefa, sem que o
  usuário precise pedir de novo. Não existe hook (política da org bloqueia
  hooks em settings.json) — a "automação" aqui é a própria instrução desta
  skill lembrando o agente de agir no fim. Requer ydotool instalado e a regra
  udev de /dev/uinput já configurada (grupo `input`) — se `ydotool key ...`
  falhar por permissão, isso não foi configurado ainda.
---

# press-enter — simular tecla na janela ativa (Wayland)

Este ambiente usa Wayland/GNOME, onde não existe forma de mirar uma janela
específica em segundo plano — o evento sempre vai para a **janela ativa/em
foco** no instante em que o comando roda. Isso é uma limitação de segurança do
protocolo, não um bug.

## Fluxo principal: "aviso de fim de tarefa longa" (sem hook)

Este é o uso real desta skill. O usuário deixa uma mensagem já digitada (não
enviada) numa janela — normalmente o Teams — e quer que o Enter seja disparado
sozinho quando a tarefa longa terminar, sem precisar pedir de novo.

Como a organização **não permite hooks** em `settings.json`, não existe um
gatilho de sistema para "quando a tarefa acabar". A automação depende de você
(o agente rodando a tarefa longa) seguir estes dois passos **na mesma
conversa**:

1. **No início**, assim que o usuário pedir esse fluxo: rode um teste
   imediato de `ydotool key enter` (ou uma tecla neutra tipo `esc`, se um
   Enter de teste for indesejado no momento) para forçar o prompt de
   permissão do Bash **agora**, enquanto o usuário está olhando e pode
   aprovar. Avise explicitamente que é só teste: "testando a permissão do
   ydotool agora, isso não é o Enter final".
2. **Anote mentalmente** (mantenha isso em contexto até o fim da resposta
   final da tarefa) que, antes de encerrar a tarefa longa e devolver o
   controle ao usuário, você deve rodar o comando de Enter de verdade — como
   **último passo**, depois que todo o trabalho estiver de fato concluído.
   Não anuncie isso como pendência para o usuário resolver; é você quem
   executa.

Se a conversa for muito longa e o contexto for resumido/comprimido no meio do
caminho, essa "lembrança" pode se perder — não há garantia forte sem hook.
Avise o usuário dessa limitação se a tarefa for muito longa.

## Pré-requisitos (já configurados nesta máquina)

- `ydotool` instalado (`/usr/bin/ydotool`, versão sem `ydotoold` — fala direto
  com `/dev/uinput`, sem daemon).
- Regra udev `/etc/udev/rules.d/99-uinput.rules` liberando `/dev/uinput` pro
  grupo `input` (`KERNEL=="uinput", GROUP="input", MODE="0660"`).
- Usuário já pertence ao grupo `input`.

Se `ydotool key enter` retornar erro de permissão, essas duas últimas etapas
não foram feitas — não tente resolver sozinho, avise o usuário.

## Como executar

Sempre rode dentro de `newgrp input` para garantir a permissão do grupo na
sessão do shell (o grupo pode não estar ativo na sessão atual mesmo que o
usuário já pertença a ele):

```bash
newgrp input <<'EOF'
ydotool key enter
EOF
```

O aviso `ydotool: notice: ydotoold backend unavailable (may have latency+delay
issues)` é esperado e **não é erro** — é só porque esta versão não usa o
daemon `ydotoold`.

### Com atraso (ex.: "espera N segundos e dá enter")

```bash
newgrp input <<'EOF'
sleep N
ydotool key enter
EOF
```

Rode em `run_in_background` se o atraso for perceptível, para não travar a
conversa esperando.

### Outras teclas

`ydotool key <nome>` aceita outras teclas (ex. `space`, `tab`, `esc`). Para
combinações ou sequências de código de tecla raw, ver `ydotool help`.

## Importante

- O efeito depende de qual janela está em foco **no momento exato** da
  execução — se o usuário quer que caia em uma janela específica (Teams,
  outro terminal), ele precisa deixá-la ativa antes do comando rodar.
- Não use isso para automatizar aceite de diálogos de segurança, prompts de
  permissão ou qualquer confirmação que deveria ser uma decisão humana
  consciente — é uma ferramenta de conveniência para fluxos benignos
  (ex.: confirmar um "Enter" em um app já esperado pelo usuário).
