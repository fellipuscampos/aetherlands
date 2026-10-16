# Sincronização visual de combate — 15/10/2026

O feedback acontece no contato do golpe ou na chegada da magia, em vez de preceder o gesto.
Esperar a animação inteira incluiria a recuperação da pose e deixaria o combate desnecessariamente lento.

## Contrato

As regras continuam síncronas: dano, cura, status, mana, recargas, ação, posição lógica, mortes e recompensas
são calculados na chamada original. Não há `await` no fluxo de regras, espera na IA ou fase de turno nova.
Um save feito durante a apresentação guarda o resultado definitivo, e carregar o mapa cancela o feedback antigo.
Nenhum atributo, custo, fórmula, duração de status, chance, peso de IA ou regra de vitória foi ajustado.

`scripts/vfx/CombatFeedback.gd` registra somente a apresentação durante a resolução de uma ação visível.
Um temporizador publica barras/números, reação ao golpe, bloqueio e auras no momento do impacto.
O card de unidade e o inspetor usam a Vida apresentada; previsões, disponibilidade de ordens e salvamento
continuam usando a Vida real. Logs, recompensas e notificações de regras mantêm sua semântica imediata.

Também cobre contra-ataque, splash, técnicas com vários alvos, habilidades ativas de monstros e o veneno
aplicado depois da mordida. O efeito posterior do monstro retoma a mesma apresentação, sem outro temporizador.
Teleporte e empurrão mudam a ocupação imediatamente, mas o deslocamento visual acompanha o impacto.
Invocações entram no roster imediatamente e aparecem com o feitiço; a neblina respeita essa espera.
As árvores do Bosque mágico são apresentadas na chegada, com os modificadores lógicos mantidos instantâneos.

## Referência de tempo

1. Um marcador `impact` ou `IMPACT` na própria `Animation` tem prioridade.
2. A tabela `CombatTimingProfiles.gd` reúne **59 clipes de 33 modelos** com `impact_frame` nos relatórios de arte.
   O frame vira uma fração da duração importada, preservando o contato mesmo com ajuste de velocidade.
   Skins que reutilizam uma biblioteca usam o registro do clipe compartilhado.
3. Um clipe sem marcador/relatório usa 52% da duração, correspondente ao golpe do gerador-base
   (`tools/asset_factory/animation/clips.py`: frame 14 no intervalo 1–26). Não se espera a recuperação inteira.
4. Magias usam o ponto de liberação já definido em `SacredFocusProfiles`/`SchoolFocusProfiles`, ajustado pela
   velocidade da animação, mais os **0,38 s** do trajeto que os VFX já desenhavam. Feedback e VFX compartilham
   a mesma referência. Cura não ganha um segundo número por causa do VFX.

Se a unidade ainda está percorrendo uma rota, o gesto espera a chegada visual. O tempo restante dessa
caminhada entra no relógio de feedback e no início do VFX. Uma ação nova durante a recuperação reinicia o
gesto; callbacks de gestos substituídos não podem sobrepor a animação mais recente.

Atualizar os pontos depois de exportar animações:

```
python tools/art_pipeline/build_combat_timing_profiles.py
```

O gerador apenas lê os relatórios existentes e grava a pequena tabela GDScript. Não altera GLBs, Blender,
texturas ou os relatórios do outro agente. O jogo não lê JSON nem procura frames por quadro.

## Morte, neblina e concorrência

A criatura derrotada sai imediatamente dos índices, roster, proteção do covil e contagem populacional.
Seu Node visual existente é temporariamente reaproveitado como filho da apresentação: não há cópia de modelo.
Esse corpo não recebe ordens, tem Movimento 0 e é ignorado pela fila de IA. No impacto, mostra a reação e
termina com um tombo curto; então é liberado. Covis destruídos também conservam somente sua aparência até o golpe.

Callbacks guardam referências fracas. Revisões de apresentação impedem uma ação antiga de restaurar uma barra
de Vida ultrapassada. A visibilidade é verificada no impacto, corpos respeitam mudanças de neblina e a troca
de mapa cancela as apresentações. O deslocamento aleatório dos números é sorteado na chamada original e
reaproveitado depois: não se muda a sequência do RNG global entre decisões da IA.

## Desempenho

- Nenhum `_process` novo, varredura do mapa, reconstrução de neblina, espera na IA ou alteração do culling de animação.
- Máximo de **12 apresentações pendentes por mapa**, como o limite de casts do VFX. Sob saturação, o feedback
  usa o caminho imediato; as regras sempre são resolvidas. Ações ocultas e partidas headless não criam agendas.
- Um temporizador principal por ação; movimento pode usar um temporizador para iniciar o gesto depois da caminhada.
- Malhas, animações, materiais e efeitos existentes são reutilizados. Os VFX das escolas mantêm seus limites.
- Benchmark isolado da camada nova, com 1.000 amostras por cenário: **0,084 ms de média / 0,113 ms p95**
  para 3 callbacks; **0,313 ms / 0,494 ms** para 21 callbacks. Mede registro, temporizador e publicação,
  incluindo resolução do ponto de contato; não mede os modelos/VFX existentes nem FPS/GPU.
  Havia outros processos de trabalho ativos: não é uma comparação estatística de performance do jogo inteiro.

```
godot --headless --path . res://tools/perf/CombatFeedbackBench.tscn
```

Dados: [`balance/combat_feedback_cpu_20261015.json`](balance/combat_feedback_cpu_20261015.json).

## Validação

- Suíte ampla: **473/473 testes**, 20 arquivos, 4.240 asserts. Depois do ajuste final para repetir um ataque
  durante a recuperação, **134/134** na execução de contato/combate/técnicas, incluindo **21 contratos** da
  camada nova. São **474 testes distintos aprovados**, com sobreposição entre execuções.
- Os contratos incluem relógio real, cura sem duplicação, silêncio, veneno, morte, cancelamento, neblina,
  sobreposição de ações, limite de agendas, RNG, movimento, teleporte, invocação, Bosque e empurrão.
- Conferência não-headless em uma janela, com os modelos e os VFX reais. Na preparação, a Vida apresentada
  fica em 20 e 4 apesar dos resultados lógicos já calculados; no contato do machado vira 16,6; na chegada da
  magia a cura passa para 16 e a aura de silêncio aparece. Capturas: [preparação](previews/combat_sync_20261015/01_windup.png),
  [contato](previews/combat_sync_20261015/02_melee_contact.png), [chegada](previews/combat_sync_20261015/03_spell_arrival.png).
  Tempos/HP medidos: [`timeline.json`](previews/combat_sync_20261015/timeline.json). Cena de revisão removida.
- Campanha headless real, quatro IAs, seed 33102: T120, save/load bem-sucedido em T60, sem erros de script/motor,
  zero nós órfãos após teardown. T120 é um limite técnico, sem conclusão de balanceamento ou duração da partida.
- A execução combinada de fixtures ainda informa 46 objetos/7 recursos no encerramento, depreciações e um
  aviso de filhos não liberados. A suíte isolada da camada nova e o smoke não apresentaram erros de encerramento.
  Esses avisos permanecem registrados, sem modificar sistemas externos para silenciá-los.
- Duas fixtures foram isoladas das mudanças de balanceamento/IA em paralelo: o teste de alvo do Worg remove
  sobreviventes do seu cenário anterior; o teste de seleção em paz estabelece paz diretamente em vez de
  depender de a nova heurística diplomática aceitar uma proposta. Nenhuma regra de negociação foi alterada.

Resumo: [`balance/combat_visual_sync_validation_20261015.json`](balance/combat_visual_sync_validation_20261015.json).
Logs e snapshots anteriores dos arquivos: `%TEMP%/aetherlands_visual_sync_20261015/`.
