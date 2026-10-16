# Foco após magias e técnicas — 15/10/2026

Ao confirmar uma magia, `SelectionManager` reselecionava o conjurador e depois emitia `tile_selected` para o alvo.
O `ContextRouter` prioriza esse último sinal. Uma tropa própria não selecionada não pode abrir seu painel de
comandos; por isso a inspeção caía em Terreno, deixando o aliado transparente. No próprio tile, o mesmo sinal
também podia reabrir a aba Cidade/Terreno lembrada pelo jogador.

## Correção

- Magias e técnicas com alvo mantêm o painel e o marcador na unidade que agiu. O sinal `unit_selected` existente
  basta para atualizar comandos, custos e recargas. Não há outro `tile_selected` sobrepondo a seleção.
- A posição usada é a atual, incluindo teleporte e deslocamento por técnica. Se a unidade caiu, a inspeção do
  alvo continua como fallback, respeitando a névoa e sem manter comandos de uma unidade morta.
- Confirmação e cancelamento verificam se a unidade continua viva e no índice do mapa. Uma unidade removida
  pode continuar existindo até `queue_free` ou o impacto visual; isso não permite conjurar nem reselecioná-la.
- Cliques normais após a ação continuam selecionando aliados ou terreno. A memória de abas por tile foi mantida.

Único arquivo de produção alterado nesta correção: `scripts/autoload/SelectionManager.gd`. O diff contra a cópia
feita no início da tarefa contém apenas os quatro handlers de confirmação/cancelamento e dois helpers novos.
Não houve alteração em atributos, custos, IA, efeitos, animações, `ContextRouter` ou `VisualFocusSystem`.

## Custo

Sem `_process`, timers, novas varreduras ou recálculos de névoa. Validação de presença pela consulta O(1)
`get_unit_at`. O roteamento continua coalescido pelo `ContextRouter`; deixa de receber a inspeção conflitante
do alvo. Não foi feita afirmação de ganho de FPS.

## Validação

`test/unit/test_targeted_action_focus.gd`: 14 testes com seleção, router, unidades, magias e feedback visual reais.
Cobrem cura antes/depois do impacto, buff sobre estrutura, conjuração em guarnição, aba Terreno lembrada,
magia de terreno, teleporte, alvo que deixa de ser válido, cancelamento, técnica à distância, morte por revide,
clique normal após conjuração e confirmação/cancelamento após remoção (inclusive objeto já liberado).

Antes da correção, 7 dos 9 casos iniciais falhavam. Os dois casos acrescentados para remoção também reproduziram
conjuração indevida e reseleção antes do ajuste. A rodada final passou **194/194 testes, 1.399 asserções**, em
78,415 s, com saída 0 e sem erros de script/motor no log:

```
test_targeted_action_focus.gd
test_ui_context.gd
test_selection_manager.gd
test_combat_feedback.gd
test_v2_magic_hud.gd
test_v2_arcanism.gd
test_v2_charge.gd
test_attack_target_choice.gd
```

Uma verificação adicional de `test_v2_cavalry_flow.gd` falhou na montagem da arena em
`test_cavalry_n1_to_n9_flow_from_the_stable_to_the_griffon_across_save_and_load`: o helper `_arena` não encontra
uma área de raio 7 sem covis/cidades e distante das capitais no mapa de 40×24. Retorna `(999,999)` e a consulta
seguinte recebe tile nulo. A falha se repetiu executando somente esse teste. Não foi contada entre os 194 testes
aprovados, e o cenário não foi alterado nesta tarefa. Sem uma execução da versão anterior, não se afirma quando
essa limitação começou.

Conferência visual em **uma única execução não headless**, Vulkan/RTX 3060, 1600×900, em cena controlada com
modelos, magias e painel reais. Após cura e Égide, contexto `unit`, conjurador selecionado em `(0,0)` e
transparência máxima do aliado `0.0`. O terreno de apresentação é simplificado; não é benchmark da campanha.

- [Antes](previews/target_focus_20261015/00_before.png)
- [Após cura](previews/target_focus_20261015/01_healed.png)
- [Após Égide](previews/target_focus_20261015/02_buffed.png)
- [Estados medidos](previews/target_focus_20261015/states.json)

Cena/script descartáveis removidos depois da conferência; ausência confirmada por `git status --porcelain`.
Logs e cópia anterior do arquivo ficam em `%TEMP%/aetherlands_target_focus_20261015/`.
