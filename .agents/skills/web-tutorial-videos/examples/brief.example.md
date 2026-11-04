# Brief — vídeos tutoriais do <produto>

> Preencha antes de escrever qualquer fluxo. O brief é o contrato: o que cada vídeo mostra, para
> quem, com que estado de partida, e o que pode ser preparado fora do vídeo.

## Público e tom
- Quem assiste: <ex.: pessoa recém-chegada ao perfil Analista; nunca viu o sistema>.
- Tom: frases curtas, segunda pessoa ("Clique em…"), o nome do botão entre aspas exatamente como
  está na tela. Sem jargão interno, sem falar de como o sistema foi construído.
- Idioma das legendas: pt-BR. Duração alvo: 1–3 min por vídeo (curtos: < 1 min).

## Ambiente
- URL: `http://localhost:4200` (`BASE_URL`). API: `http://localhost:3000` (`API_BASE`).
- Login por perfil: `SESSION_URL_TEMPLATE=http://localhost:4200/__session-{profile}.html`
  (ou `SESSION_MODULE` / `SESSION_JSON`). Perfis: `admin`, `analista`, `fornecedor`.
- Repositório do front para a janela de silêncio: `QUIET_REPO=../frontend` (10 min).
- Restrições: não reiniciar serviços; não editar o app; sem commits.

## Vídeos

| # | Nome (= semente da música) | Perfil | Mostra | Estado de partida (setup, fora do vídeo) |
|---|---|---|---|---|
| 1 | `pedido-1-abrir` | admin | Abrir um pedido e enviar | nenhum |
| 2 | `pedido-2-aprovar` | analista | Aprovar o pedido enviado | pedido criado e enviado por API |

## Regras de honestidade
- Tudo que a legenda afirma tem de estar visível na tela naquele momento (texto conferido na
  fonte do front, não de memória).
- O que foi preparado por API é dito na legenda quando muda a leitura do vídeo
  (ex.: "neste exemplo, as duas guias já foram analisadas").
- Upload é de arquivo real (`setInputFiles`), nunca simulado.

## Entrega
- `out/*.mp4` (H.264 1280×800 + AAC), `out/INDEX.md`, zip `tutoriais.zip`.
- Relatório: duração de cada vídeo, o que falhou e como foi consertado, dados que ficaram no banco.