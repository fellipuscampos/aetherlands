# Loading pixelado

`LoadingScreen.tscn` permanece no fluxo real de `Main.gd`, usando o cenário aprovado do menu, marca em Pixelify Sans, faixa escura de leitura e barra de bronze com textura em pixels. `LoadingScreenTheme.gd` é local à tela; os menus já aprovados não foram modificados.

O indicador de atividade usa o emblema do menu com oito gemas quadradas, em uma grade inteira e passos discretos. O cenário é estático. Movimento reduzido interrompe o indicador e a animação indeterminada; os textos e estados continuam visíveis.

## Estados e progresso

- Nova partida: os callbacks reais de `HexGrid.generate_map` atualizam fase e porcentagem. A barra não avança sozinha.
- Atualizações rápidas cancelam o tween anterior, impedindo saltos de animações antigas. Completar uma etapa em 100% aplica o valor imediatamente.
- Carregar partida: o pipeline atual de restauração é síncrono e não informa porcentagem. A tela usa “AGUARDE” e indicador indeterminado, sem números artificiais. Esse pipeline não foi alterado.
- `set_message` reinicia o estado para um novo carregamento e mantém sua assinatura existente. `set_progress` também mantém a assinatura existente.
- A primeira abertura acomoda os containers em dois frames, já cedidos por `Main`, para que textos inicialmente ocultos não deslocassem a barra depois da apresentação.
- Mensagens de fase têm espaço reservado; o progresso mantém sua posição durante mudanças de texto. A referência mínima de 640 pixels usada pelas verificações existentes foi preservada.

## Reprodução e verificação

- `tools/art_pipeline/build_loading_menu.py`: reproduz a cena, o shader do véu e os dois SVGs próprios da barra.
- `tools/art_pipeline/review_loading_menu.gd`: captura e verifica a cena em `Main.tscn`, sem iniciar ou salvar uma partida.
- Capturas e relatório: `docs/previews/loading/`.
- Verificado em 1280×720, 1600×900, 1920×1080, 3440×1440 e 1280×720 com escala 150%, incluindo geração, restauração, movimento reduzido e mensagens longas.
- Uma geração real pequena (12×8) percorreu os callbacks existentes e chegou a 100%. Também foram verificados bloqueio/liberação de entrada, ausência de progresso inventado e cancelamento de tweens anteriores.
- 16 testes existentes passaram, com 41 asserções: frontend, configuração de nova partida e título.
