---
name: video-transcribe-frames
description: >-
  Transcreve uma gravação de reunião/tela com Google Cloud Video Intelligence (fala pt-BR com
  diarização, mudanças de plano e OCR) e extrai os melhores quadros para um subagente de análise.
  Use quando pedirem "transcrever o vídeo da reunião", "transcrição da gravação", "ata da
  reunião a partir do vídeo", "extrair frames do vídeo", "analisar a gravação de tela",
  "quem falou o quê no vídeo", ou ao receber um .mkv/.mp4 em ~/Videos para analisar.
---

# Transcrição de vídeo + quadros-chave

Processo provado em 2026-10-14 e 2026-11-06 (reuniões de ~18 min, `.mkv` do OBS).

```
vídeo → mp4 (remux) → GCS → videos:annotate (REST) → poll → transcript/shots/ocr → quadros → subagente
```

Saídas ficam em `.dumps/tasks/<slug>/` do projeto (local, ignorado pelo git).

## Parâmetros

Projeto, service account e bucket são do ambiente corporativo e ficam fora deste repositório
(público): leia-os de `VTF_PROJECT`, `VTF_SA` e `VTF_BUCKET`. Se faltar algum, pergunte ao
usuário em vez de chutar.

```bash
PROJECT=${VTF_PROJECT:?defina VTF_PROJECT}
SA=${VTF_SA:?defina VTF_SA}
BUCKET=${VTF_BUCKET:?defina VTF_BUCKET}
PREFIX=video-transcribe/<slug>          # prefixo no bucket
SPEAKERS=3                              # nº de falantes esperado
DIR=.dumps/tasks/<slug>; mkdir -p $DIR/frames
SK=~/.agents/skills/video-transcribe-frames/scripts/vi-outputs.sh
```

Se o usuário citar outro projeto, SA ou bucket, troque as variáveis; o resto não muda.

## 1. Localizar e inspecionar

Os vídeos ficam em `~/Videos` (ex.: `~/Videos/<pasta>/*.mkv`). Use `list`/`glob`.

```bash
ffprobe -v error -show_entries format=duration:stream=index,codec_type,codec_name -of default=nw=1 IN.mkv
```

## 2. Remux para mp4 (sem reencodar)

```bash
ffmpeg -v error -y -i IN.mkv -c copy -movflags +faststart $DIR/OUT.mp4
```

## 3. Subir para o GCS

O Video Intelligence só lê `gs://`. A conta pessoal é bloqueada pelo VPC-SC: **sempre** impersone.

```bash
gcloud storage cp $DIR/OUT.mp4 gs://$BUCKET/$PREFIX/OUT.mp4 \
  --project $PROJECT --impersonate-service-account=$SA
```

> Avise o usuário: o bucket pode ter retenção, então o objeto **não pode ser apagado** antes do
> prazo. Suba só o necessário e não repita o upload com o mesmo nome.

## 4. Pedir a anotação (REST, não o `gcloud ml`)

`gcloud ml video transcribe-speech` é beta e instalar o componente pede confirmação interativa:
não use. Token e chamada:

```bash
( umask 077; gcloud auth print-access-token --impersonate-service-account=$SA > /tmp/x.tok )

jq -n --arg uri "gs://$BUCKET/$PREFIX/OUT.mp4" --argjson n $SPEAKERS '{
  inputUri: $uri, locationId: "us-east1",
  features: ["SPEECH_TRANSCRIPTION","SHOT_CHANGE_DETECTION","TEXT_DETECTION"],
  videoContext: {
    speechTranscriptionConfig: {languageCode: "pt-BR", enableAutomaticPunctuation: true,
      enableSpeakerDiarization: true, diarizationSpeakerCount: $n, enableWordConfidence: true},
    textDetectionConfig: {languageHints: ["pt"]}}}' > $DIR/request.json

OP=$(curl -4 -sS -X POST https://videointelligence.googleapis.com/v1/videos:annotate \
  -H "Authorization: Bearer $(< /tmp/x.tok)" -H "Content-Type: application/json" \
  -H "x-goog-user-project: $PROJECT" -d @$DIR/request.json | jq -r .name)
echo "$OP"      # projects/.../locations/us-east1/operations/<id>
```

Se `OP` vier `null`, repita sem o `jq` e leia o erro (nunca imprima o token).

## 5. Poll até `done`

~18 min de vídeo levam alguns minutos. **Não faça loop apertado**: consulte a cada 30–60 s
(use a ferramenta `wait` entre chamadas, uma consulta por chamada).

```bash
curl -4 -sS https://videointelligence.googleapis.com/v1/$OP \
  -H "Authorization: Bearer $(< /tmp/x.tok)" -H "x-goog-user-project: $PROJECT" \
  > $DIR/operation.json
jq '{done, error, progress: .metadata.annotationProgress}' $DIR/operation.json
```

O token dura ~1 h; se der 401, gere outro. Quando `done: true` e sem `error`, siga.

**Resultado parcial** (visto em 2026-11-06): `TEXT_DETECTION` pode ficar parado por 30+ min com
`progressPercent` nulo enquanto fala e planos já estão em 100% e com resultados em `response`.
Não espere: gere uma cópia marcada como pronta e siga sem OCR (o original continua sendo
consultado, se quiser o OCR depois):

```bash
jq '.done = true' $DIR/operation.json > $DIR/operation.parcial.json
bash $SK outputs $DIR/operation.parcial.json $DIR
```

## 6. Gerar transcript, shots e OCR

```bash
bash $SK outputs $DIR/operation.json $DIR
```

Gera, só com `jq`: `transcript.md` (`[mm:ss] frase`, uma linha por alternativa),
`transcript-speakers.md` (turnos `Speaker N`, vindos das `words[].speakerTag` do último
resultado), `shots.json` (`start`/`end` em s), `ocr.json` (`text` + primeiro segmento) e
`frames-plan.json` (instantes dos quadros).

## 7. Extrair quadros

Plano: um quadro no meio de cada plano ≥ 1,5 s (`MIN_SHOT`), no máximo ~60 (`MAX_FRAMES`;
mantém os planos mais longos), mais quadros onde o OCR muda muito; entradas a < 3 s uma da outra
são fundidas.

```bash
bash $SK frames $DIR/OUT.mp4 $DIR
```

Cada quadro é `ffmpeg -v error -y -ss T -i OUT.mp4 -frames:v 1 -vf scale=1280:-1 frames/f-<mmss>.jpg`.
`frames/index.md` lista hora, arquivo, texto OCR vigente e a fala daquele instante.

## 8. Entrega ao subagente de análise

Dispare um `subagent` (em segundo plano) com os caminhos absolutos e a pergunta. Ele deve ler
`transcript.md` (ou `transcript-speakers.md`) e `frames/index.md`, abrir com `read_image` **só os
quadros relevantes** (não todos) e devolver notas com timestamps `[mm:ss]`. Lembre-o de que os
quadros estão em `.dumps/` (local) e que fala/OCR podem conter erros de reconhecimento.

## 9. Limpeza

```bash
rm -f /tmp/x.tok      # ou use a ferramenta trash
```

Mantenha `operation.json`, saídas e quadros em `.dumps/` (ignorado pelo git). Nunca imprima nem
grave o token em arquivo do projeto.

## Armadilhas

- **Beta do gcloud**: `gcloud ml video transcribe-speech` pede para instalar componente beta de
  forma interativa. Use REST.
- **VPC-SC / impersonação**: `PERMISSION_DENIED ... VPC_SERVICE_CONTROLS` não é IAM faltando; é
  esquecer `--impersonate-service-account`. Precisa estar no grupo que dá `serviceAccountTokenCreator`.
- **Header `x-goog-user-project`**: sem ele a API recusa (projeto de cota); mande em toda chamada.
- **IPv6**: se o gcloud/`curl` travar, use `curl -4`; gcloud (Python) espera para sempre numa rota
  IPv6 morta, então cunhe o token uma vez e reuse.
- **Retenção do bucket**: objetos não se apagam nem se sobrescrevem antes do prazo; avise o usuário.
- **Duração `0`**: a API omite `startTimeOffset` quando é 0; o script trata isso. Não escreva
  filtros `jq` que assumam o campo.
- **Diarização**: o último item de `speechTranscriptions` repete todas as palavras com
  `speakerTag`; o script o exclui de `transcript.md` para não duplicar o texto.
- **`jq`, não Python**: todo o pós-processamento é `jq` + `ffmpeg`.
