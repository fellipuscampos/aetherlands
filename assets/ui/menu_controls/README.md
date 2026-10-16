# Carregar jogo e configurações

`LoadGameScreen.tscn` e `SettingsScreen.tscn` usam o cenário, a fonte pixelada e o acabamento de metal/bronze do menu inicial e do lobby. O tema `scripts/ui/FantasyMenuTheme.gd` é local a estas duas telas, inclusive menus de opções, interruptores, sliders, tooltips e confirmação de exclusão. Os temas globais, o menu inicial e o lobby aprovados não foram alterados.

## Carregar jogo

- Cartas com cidade do povo, nome do reino, turno e data local do salvamento.
- Arquivos incompatíveis/corrompidos continuam visíveis com motivo explícito e carregar desativado. Nomes recuperáveis são preservados; o identificador do arquivo pode ser consultado no tooltip.
- Lista rolável e Voltar sempre acessível, incluindo lista vazia e arquivos apenas inválidos.
- Exclusão mantém confirmação; Cancelar recebe foco inicial, preserva o arquivo e devolve o foco. Confirmar remove somente o slot escolhido e atualiza a lista.
- Refresh procura o foco apenas no momento da execução adiada, evitando referenciar botões já removidos em uma atualização seguinte.

## Configurações

- Cinco categorias existentes: Áudio, Vídeo, Interface, Controles e Ajuda. A seleção tem acabamento de bronze e marca de confirmação; foco tem contorno claro.
- Valores percentuais acompanham os sliders de volume, com um marcador de foco maior. Sliders continuam sendo HSlider reais, utilizáveis por teclado.
- Vídeo é agrupado em Tela, Qualidade visual e Ambiente/iluminação. Todas as opções existentes, inclusive padrões gráficos, permanecem ligadas às preferências reais.
- Interface preserva escala de texto/controles e movimento reduzido. Categorias e conteúdo rolam verticalmente quando necessário; Voltar permanece fora da rolagem.
- Menus de opção e interruptores têm estados pixelados claros. Não há botão Aplicar: as alterações já são aplicadas e salvas automaticamente pelo sistema existente.
- A ordem de Tab corresponde à leitura, setas conectam os grupos sem interferir no ajuste de sliders, Page Up/Down rolam o conteúdo, e Escape mantém o comportamento de retorno do título/pausa.
- Os consumidores do título e da pausa continuam utilizando as mesmas cenas e sinais. Developer Tools continua em sua rota separada.

## Fontes de projeto e reprodução

Referências: [Xbox XAG 112 — navegação e ordem de foco](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/112), [Xbox XAG 113 — foco](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/113) e [Godot Window — tema de janelas](https://docs.godotengine.org/en/stable/classes/class_window.html#theme-properties). São critérios de projeto; não constituem declaração de conformidade integral.

- `tools/art_pipeline/build_auxiliary_menus.py`: reproduz as duas cenas e os SVGs próprios, em grade de pixels.
- `tools/art_pipeline/review_auxiliary_menus.gd`: captura o fluxo real em `Main.tscn`, testa inputs/estados e restaura os valores e bytes de configurações tocados durante a execução.
- Capturas: `docs/previews/auxiliary_menus/`. As cartas das prévias usam dados de demonstração, sem representar saves reais.
- A verificação de excluir usa um único arquivo descartável em diretório de teste isolado, nunca os saves do jogador.
- 48 testes existentes passaram (148 asserções): carregar, configurações, título, pausa e verificações de UI.
- Smoke visual: cinco páginas de configurações, lista vazia, slots válidos/indisponíveis, popup, exclusão cancelada/confirmada e retorno; resoluções 1280×720, 1600×900, 1920×1080, 3440×1440 e 1280×720 com escala 150%.
