// Exemplo genérico: preenche e envia um pedido na página estática examples/demo-site/.
//
//   BASE_URL=file://$PWD/demo-site node recorder.mjs flows/exemplo-pedido.mjs --dry
//
// Mostra os padrões que a skill exige: legenda que descreve o que a TELA mostra, pausa de
// leitura, data em ISO no fill (o navegador desenha dd/mm/aaaa com o locale do processo),
// upload real por setInputFiles, confirmação que espera o diálogo abrir e fechar, e o sorteio
// da página fixado por initScript para a legenda saber qual dica aparece.
import { resolve } from 'node:path';

const FIXTURE = resolve(import.meta.dirname, '../fixtures/orcamento-exemplo.txt');

export default {
  name: 'exemplo-pedido',
  title: 'Enviar um pedido',
  brand: 'Demonstração',
  subtitle: 'Tutorial · exemplo da skill web-tutorial-videos',
  summary: 'Preenche título, data e anexo de um pedido e envia com confirmação.',
  outsideVideo: 'Nada: página estática local. O sorteio da dica é fixado (Math.random = 0,9).',
  start: '/index.html',
  // 0,9 → terceira dica das três (Math.floor(0,9 × 3) = 2).
  initScript: 'Math.random = () => 0.9;',
  steps: [
    {
      caption: 'No topo, a dica lembra que o pedido não volta para edição depois de enviado.',
      run: async (ui) => { await ui.highlight('#tip', 3200); },
    },
    {
      caption: 'Dê um título ao pedido.',
      run: async (ui) => { await ui.type('#title', 'Material de escritório', { pause: 1200 }); },
    },
    {
      caption: 'Escolha a data de entrega. O campo mostra dia, mês e ano.',
      run: async (ui) => { await ui.fill('#due', '2026-12-01', { pause: 2200 }); },
    },
    {
      caption: 'Anexe o orçamento. O nome e o tamanho do arquivo aparecem logo abaixo.',
      run: async (ui) => {
        await ui.upload('#attachment', FIXTURE, { show: '#attachment', pause: 1000 });
        await ui.highlight('#attached', 2200);
      },
    },
    {
      caption: 'Clique em "Enviar pedido" e confirme em "Enviar".',
      run: async (ui) => {
        await ui.confirm('#send', '#do-send', { dialog: '#confirm' });
      },
    },
    {
      caption: 'Pronto: a confirmação repete o título e a data de entrega.',
      run: async (ui) => { await ui.highlight('#ok', 3200); },
    },
  ],
};