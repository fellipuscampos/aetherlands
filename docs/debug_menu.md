# Ferramentas de debug

O painel aberto pelo menu de pausa foi organizado em quatro abas, usando o
mesmo tema pixelado do HUD. Cabeçalho, fechamento e atalhos de animação ficam
fixos; somente o conteúdo da aba rola. A largura, as colunas e os espaçamentos
se adaptam à janela e à escala da interface.

- **Magos e VFX:** invoca Clérigo, Bruxo Infernal, Necromante, Druida, Arcanista
  e Elementalista, com quantidade de 1 a 50. A invocação não exige edifícios
  nem produção. Os modelos usam a raça da civilização humana e aparecem nos
  tiles livres mais próximos da seleção, da primeira cidade ou da primeira unidade.
- **Manifestações:** preserva as seis invocações existentes e sua quantidade.
- **Ambiente:** chuva, neve, dia/noite e aceleração do ciclo.
- **Partida:** modo debug, névoa, ouro, pesquisa atual, dragão, ecologia e telas de fim de jogo.

## Testar magias

A opção **Preparar escola e mana para VFX**, marcada inicialmente, conclui
somente as pesquisas até a quarta magia da escola escolhida e garante pelo
menos 1.000 mana. Desmarcar a opção cria apenas a unidade, preservando mana e
pesquisas. O primeiro mago invocado fica selecionado.

Feche o painel e lance a magia pelos controles normais da unidade. Para
repetir, use **Renovar ação e recargas** no conjurador selecionado. Para cura,
**Deixar seleção com 50% de vida** prepara uma unidade própria. Esses controles
não alteram o turno, não removem status e mantêm as regras normais de alvo.
Os quatro botões de animação tocam apenas os clipes; não lançam feitiços.

A preparação mantém os eventos reais de unlock e silencia temporariamente
somente os avisos individuais de pesquisa. O resultado aparece em uma linha
no painel, evitando uma pilha de notificações sobre os controles. Pesquisas
normais continuam produzindo seus avisos.

## Conferência

`review_debug_menu.gd` invoca os seis magos pelos botões reais, verifica as
quatro magias e seus modelos animados, executa uma magia pelo caminho real
de VFX e renova sua ação sem avançar o turno. Também confere limites da janela,
fechamento, rodapé e rolagem em 1600×900, 1280×720 e 960×720, incluindo escala
de 150%. Capturas e resultado: `docs/previews/debug_menu/`.

Os testes cobrem quantidade, preparação opcional, isolamento das escolas,
mana, recargas, unidades existentes, avisos normais, abas e manutenção das
manifestações, do HUD e do menu de pausa.
