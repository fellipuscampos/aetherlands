# Revisão final dos monstros e covis — 15/10/2026

O objetivo desta rodada é dar consequência ao combate e tornar a conquista do território consistente com o
4X: o jogador pode explorar sem ativar todos os monstros avançados, mas provocar uma criatura tem resposta.
O sistema continua regional, com um controlador de população, líder por covil e trégua após a destruição.

## Comportamento implementado

- Ataque físico, técnica ou feitiço que passa pelo dano direto registra o agressor. Um ataque bloqueado pelo
  escudo também provoca; não concede ação imediata ao monstro. A reação acontece na fase normal dele.
- A defesa tem prioridade sobre patrulha/raide e independe da era, inclusive durante a preparação de um covil.
  Usa o movimento, as habilidades e as regras de combate existentes. O bônus de aproximação/golpe do Worg
  continua sendo próprio da espécie; os outros não recebem esse bônus.
- Companheiros vivos a até 2 tiles defendem a vítima se pertencem ao mesmo sítio/covil. Isso vale mesmo se o
  golpe matou a vítima. Não há propagação recursiva nem convocação de covis vizinhos.
- O local anterior ao confronto é a referência de retorno. O raio é fixado no primeiro golpe: distância ao
  agressor + 1, limitada a 4–6 tiles. Novos golpes podem mudar o alvo e renovar o alerta, mas não deslocam o
  centro nem ampliam esse raio. Não se pode arrastar uma criatura pelo continente renovando a provocação.
- A reação dura até 6 rodadas depois do último golpe. Alvo morto, fora da área, desaparecido ou guarnecido
  numa cidade encerra a perseguição. Duas tentativas sem progresso também provocam desistência. O monstro
  volta andando, continua vulnerável e pode se defender de quem estiver ao alcance durante o retorno.
- Fora de combate, os perfis por era continuam controlando detecção, patrulha e raides. Não há escalonamento
  de atributos pela era ou pelo poder do jogador.
- Estado salvo em `ability_state.retaliation`: serial do agressor, última coordenada, origem, raio e relógio.
  Passa pelo save v27 existente; não exige novo schema. A fuga subterrânea do Verme mantém sua regra de
  encerrar a perseguição ao se enterrar; atacar novamente depois de emergir volta a provocá-lo.
- O início da ação/passivas passou a ter um ponto único para os papéis ecológico, dormente e guardião. Isso
  corrige o Troll guardião que não regenerava pelo caminho de IA de seu papel. Dano real ainda interrompe
  a regeneração e não existe cura especial ao perder aggro.
- Chefes legados integrados ao controlador recuperam o movimento natural da espécie, inclusive no load.
  Seus HP, dano, defesa e bônus históricos foram preservados. Novos líderes continuam com atributos comuns.
  O Dragão de evento permanece sob seu próprio controlador.

## Ocupação, apresentação e conquista

A limpeza da decoração foi centralizada na criação física de todo covil, incluindo os originais da seed.
`NatureDecorManager.compose` consulta os índices de ocupação antes de compor: covil, cidade, prédio, melhoria,
canteiro ou unidade impedem vegetação. Rebuild, carga e atualização de terreno respeitam a ocupação atual;
a limpeza não depende só do instante de spawn. Não existe uma exclusão permanente esquecida depois que a
estrutura sai: um tile liberado pode voltar a ser composto numa atualização posterior.

Props e selos de recursos também respeitam covis durante reconstrução/refresh. O recurso lógico não é apagado.
Isso cobre os casos legados e a colocação regional excepcional em tile de recurso. A posição do covil usa a
superfície real do hexágono, corrigindo o modelo enterrado em relevos com pico visual.

Conjuradores sem ataque básico podem **desmantelar um covil indefeso adjacente**, consumindo a ação normal.
Não ganham ataque físico, alcance ofensivo, dano ou feitiço novo. Colonizadores/construtores continuam sem
essa ação. Líder vivo, embarque, falta de comando ou ação já gasta continuam bloqueando a conquista.
A seleção humana e a regra canônica de combate usam o mesmo contrato. Não se alterou o planejador das
escolas mágicas nem os arquivos de balanceamento de tropas/feitiços.

O inspetor e o card da criatura distinguem reação ao agressor e retorno ao local do confronto, em vez de
mostrar apenas o perfil territorial da era durante uma perseguição provocada.

## Análise de atributos

Fonte: os valores atuais do código, registrados em
[`balance/monster_pressure_20261015.json`](balance/monster_pressure_20261015.json).
Ferramenta reproduzível: `tools/balance/MonsterPressureProbe.tscn`; 144 comparações com
`CombatResolver.predict`, cobrindo linha de frente, arqueiro e tanque em N3/N5/N7/N9. É uma régua de atributos,
sem técnicas, habilidades, formação, barreira, bloqueio, regeneração ou movimento; não é uma simulação de duelo.

| Espécie | Grupo natural | Vida | ATQ | DEF | Golpes da linha de frente N3 / N5 / N7 / N9 para matar |
|---|---:|---:|---:|---:|---|
| Goblin | 2 | 8 | 4,5 | 3 | 2 / 1 / 1 / 1 |
| Esqueleto | 3 | 6 | 6 | 1,5 | 1 / 1 / 1 / 1 |
| Worg | 2 | 8 | 6 | 2,5 | 2 / 1 / 1 / 1 |
| Aranha gigante | 2 | 9 | 5,5 | 3 | 2 / 1 / 1 / 1 |
| Troll | 1 | 20 | 9 | 6 | 5 / 3 / 2 / 2 |
| Wyvern | 1 | 16 | 12 | 4,5 | 4 / 2 / 2 / 2 |
| Minotauro | 1 | 20 | 10,5 | 5,5 | 5 / 3 / 2 / 2 |
| Basilisco | 1 | 18 | 9 | 7,5 | 5 / 3 / 2 / 2 |
| Verme colossal | 1 | 32 | 16,5 | 7,5 | 9 / 5 / 3 / 3 |
| Ancião arbóreo | 1 | 36 | 13,5 | 10,5 | 16 / 7 / 4 / 3 |
| Devorador de mana | 1 | 28 | 18 | 6 | 7 / 4 / 3 / 2 |
| Herói corrompido | 1 | 34 | 12 | 9 | 12 / 6 / 4 / 3 |

Decisão desta rodada: **preservar vida, ataque e defesa**. Os básicos são pressão de abertura e de bando,
não rivais equivalentes de uma tropa militar avançada; a fragilidade individual do Esqueleto é compensada pelo
bando e pela Horda Crescente. Intermediários exigem 2–3 golpes da linha de frente N5, antes das habilidades.
Avançados exigem 3–4 golpes de N7 e podem derrotar a linha de frente N3 em dois ataques básicos. O Ancião,
especialmente, não precisava de mais armadura/Vida para ser perigoso.

Magia permanece relevante contra defesa alta. O Devorador já causa 18 ATQ e sua Ruptura usa 80% disso contra
conjuradores, além de barreira e silêncio; aumentar dano novamente penalizaria justamente as tropas mágicas
frágeis. Recuperar a reação e o movimento dos chefes legados aumenta a ameaça real sem empilhar um aumento
numérico em cima de uma IA que antes aceitava disparos passivamente.

Essa decisão não substitui uma amostra de partidas humanas nem a rodada do outro agente. A sonda fica
disponível para repetir as comparações se ele mudar as tropas. Nenhum arquivo de atributos militares,
mágicos, pesquisa ou feitiços foi editado nesta revisão.

## Desempenho e validação

Provocação é orientada ao evento de dano; identificação de alvo e auxílio do bando são buscas locais em índices
de coordenada. Não há `_process`, cálculo de visão novo por monstro nem varredura de tropas do mundo para
achar o agressor. O desvio de defesa explora somente a arena de até 6 hexágonos de raio (127 tiles), com os
custos canônicos de entrada do HexGrid; não chama A* pelo continente. Unidade sem movimento nem tenta desvio.
As verificações de ocupação da decoração são consultas O(1), apenas na composição/recomposição.

Os resultados finais e o resumo reproduzível desta execução estão em
[`balance/monster_refinement_validation_20261015.json`](balance/monster_refinement_validation_20261015.json).

- **369/369 testes em 15 arquivos**, 20.041 asserts. Incluem 28 contratos de covis/reação e 15 de vegetação,
  além de combate, seleção humana, feitiço Infernal real, habitats, habilidades e saves ecológicos.
- A fixture antiga de desempenho D2 pressupunha que cabia uma segunda ameaça regional num mundo já cheio.
  Foi atualizada para exigir reuso ou recusa quando não há orçamento, mantendo os limites de tempo e as
  verificações de ausência de processamento por frame.
- GUT ainda informa um aviso de filhos não liberados na fixture `test_v3_e2_abilities.gd` e modelos legados
  ausentes em testes de combate que usam o corpo procedural. Nenhum teste falhou. A campanha real terminou
  com **zero nós órfãos** após o teardown e sem erros de script/motor; os avisos das fixtures não são uma
  constatação de vazamento no jogo.
- PerfBench headless, Grande 128×72, seed 4242, três rivais, mesmos cenários e 40 turnos: média **131,89 →
  99,06 ms**, p95 **214,07 → 204,98 ms**, máximo **219,91 → 247,46 ms**. Setup **2.661,91 → 2.078,30 ms**.
  Houve aquecimento de caches e outras tarefas no workspace: isso é um smoke comparável, não demonstração
  estatística de ganho. O máximo isolado aumentou; o controlador por si continua na faixa de 1 ms. Não é
  medição de FPS/GPU.
- Controlador isolado: 100 rodadas, 50 covis/86 monstros, média **1,00 ms**, p95 **0,95 ms**, máximo **9,90 ms**.
  Não inclui IA/render; a referência anterior era 0,85 ms, também sem isolamento dos outros processos.
- Campanha final real de quatro IAs, seed 33102, até **T140**, com save/load bem-sucedido em **T60**.
  O limite T140 é técnico e terminou sem vencedor, não uma conclusão de duração/balanceamento de partida.
  Logs: `user://balance/monster_refinement_20261015/final_smoke/F33B-001.json`.

Logs de testes/PerfBench e os snapshots anteriores desta rodada ficam em
`%TEMP%/aetherlands_monster_refinement_20261015/`. Sonda de atributos fica versionável em `docs/balance/`.
