> **STATUS: IMPLEMENTADO — v1 fechado (mecânica).** Este documento nasceu como um contrato comportamental PRÉ-implementação (5B.1) e evoluiu, ao longo de 5B.2 até 5B.3-G, para também registrar os números/formulas reais que foram implementados — cada seção de "Blocker" abaixo agora tem uma nota de resolução apontando pro código real (`scripts/core/DragonEvent.gd`, `scripts/core/RivalAI.gd`, `scripts/core/WorldEventTrigger.gd`) em vez de deixar o número em aberto. Uma seção nova, "Mecânicas adicionadas após o contrato original", documenta tudo que foi implementado e nunca fazia parte do contrato inicial (modos de deslocamento, dano em área, cobertura continental, ranking de dano, reação da IA rival, modal de resolução). O ÚNICO blocker genuinamente ainda aberto é **#4 (modelo de recompensa)** — v1 foi fechado deliberadamente SEM recompensa nenhuma além do ranking de dano (groundwork pro 5B.4, não implementado). Todo número marcado "PROVISÓRIO/NÃO CALIBRADO" no código continua exatamente isso — provisório, não uma decisão de balanceamento final. A frente de trabalho ATIVA agora (fora deste documento, que é sobre mecânica) é o modelo visual 3D custom do Dragão em `Unit._build_dragon_body()` — ver memória do projeto (`project-dragon-event-visual-status`) pro estado dessa frente especificamente.

# Dragon World Event — Contrato Comportamental (Step 5B)

Este documento fecha o comportamento de jogo do `DragonEvent` antes de qualquer número de combate/recompensa entrar no código — complementa `WORLD_EVENT_CONTRACT.md` (arquitetura genérica) e `GAME_DESIGN_BIBLE.md` (visão), sem repetir o que já está resolvido lá. Escopo: só o Dragão. Regras genéricas de qualquer evento futuro continuam no contrato técnico.

Duas decisões fechadas antes deste documento (ver conversa): **o Dragão é uma `Unit` real no mapa** durante `Active` — reusa as primitivas já existentes (`Unit`, movimento, `CombatResolver` e, quando compatível, `MonsterAI`), mas **não herda automaticamente as regras de lifecycle/ecologia do sistema de monstros** (lair, lifecycle de spawn/despawn, pressupostos do comportamento `hunter`); `CombatResolver` é claramente reutilizável, `MonsterAI` é compatibilidade de implementação onde fizer sentido, nunca contrato de design — e **a decisão de participação começa binária** (participar sim/não por civilização) — contribuição diferenciada (tropas/magia/economia) é refinamento posterior, não bloqueia esta v1.

---

## Contrato por fase

| Fase | Informação pública | Decisão da civilização | Efeitos |
|---|---|---|---|
| `Dormant` | nenhuma | nenhuma | nenhum — evento ainda não é presença real no mundo |
| `Announced` | região aproximada (não o tile exato — ver Blocker #1, "origem/spawn"), rótulo qualitativo de ameaça, **alvo anunciado** (travado nesta fase, ver Blocker #3) | nenhuma — só notificação (`world_event_announced`) | nenhum |
| `Preparation` | mesma info de `Announced` | **participar: bool**, uma vez por civ_index, em `participants` — compromisso/elegibilidade, NÃO ainda uma promessa de tropas específicas (ver seção "Participação vs. contribuição" abaixo) | nenhum no mundo — só coleta de decisão |
| `Active` | posição/HP reais do Dragão (é um `Unit`; o tile exato de spawn só é sorteado nesta transição, ver Blocker #1) | nenhuma em v1 (retirar-se/reforçar fica pra depois) | Dragão Unit age no mapa (movimento/combate reais); civs participantes têm a OPORTUNIDADE de contribuir com unidades que efetivamente cheguem ao confronto — ver "Participação vs. contribuição" |
| `Resolution` | desfecho (derrotado / fugiu / devastou o alvo) + ranking de dano por civ | nenhuma | `result` escrito ANTES de virar `Completed`; **nenhuma recompensa de verdade é aplicada em v1** (Blocker #4 continua aberto) — só o desfecho e o ranking informativo, comunicados por modal bloqueante |
| `Completed` | só `result` | nenhuma | nenhum — qualquer coisa permanente já aconteceu em `Resolution` |

## Decisões que pertencem às civilizações

Só uma em v1: **participar da expedição, sim ou não**, coletada durante `Preparation`. Simétrica entre humano e IA — mesmo princípio já usado por `decide_arcane_ritual`: uma função `RivalAI.decide_world_event_participation(player, event)` decide pela IA: escreve em `event.participants[civ_index]`; o humano escreve o mesmo dict por uma ação de UI (botão "participar" no painel do evento, `HUD._on_world_event_participate_pressed`, hoje implementado). Nenhuma lógica de evento distingue os dois caminhos — só a origem da escrita muda.

Não participar **não é uma decisão negativa por padrão**: sem custo, sem penalidade automática, sem efeito diplomático (ver "Itens em aberto" abaixo pra quando isso pode mudar).

## Participação vs. contribuição (distinção decidida nesta revisão)

`participar: bool` em `Preparation` significa **compromisso/elegibilidade para recompensa**, não "todas as tropas da civ já estão automaticamente envolvidas no combate". A contribuição REAL é decidida separadamente por quais unidades da civ efetivamente chegam perto do Dragão Unit quando o confronto acontece em `Active` — o combate em si continua resolvido pelo sistema normal de movimento/combate, não por uma lista fixa amarrada à decisão binária.

Isso permite uma civilização dizer "sim, vou participar" e depois não conseguir chegar a tempo (história emergente, não um bug) — e combina diretamente com o refinamento futuro de contribuição diferenciada (tropas vs. magia vs. economia), que passa a ser só "que TIPO de unidade/ação chegou", sem precisar reabrir esta decisão binária.

## Efeitos globais vs. específicos do Dragão

- **Globais** (afetam o mundo, não só o registro do evento): dano real a cidades/território do alvo durante `Active`; recompensas para participantes em `Resolution` (ouro/mana/unidade — modelo exato ainda em aberto). Importante: o `DragonEvent` **coordena**, não implementa uma segunda lógica de dano — o caminho é sempre `DragonEvent → Dragon Unit → sistema normal de movimento/combate → consequência em cidade/território`, nunca um atalho tipo `DragonEvent.damage_city()`. Isso mantém só UM sistema de combate no jogo, com o evento como orquestrador, não como implementação paralela.
- **Específicos do Dragão** (vivem só no `DragonEvent`, nunca vazam pra `GameManager`/outros sistemas): posição atual, alvo escolhido, `participants`, `result`.

## Participação ≠ aliança (herdado da Bible, reafirmado aqui)

Participar juntas de uma expedição contra o Dragão não muda `Diplomacy` entre as civilizações participantes — nenhuma paz automática, nenhuma aliança, nenhum efeito colateral em `war_weariness`. Duas civilizações em guerra entre si podem ambas participar sem que isso as reconcilie; a única forma de mudar a relação diplomática continua sendo `Diplomacy.propose_peace`/`declare_war`, nunca um efeito colateral de evento.

---

## Open Design Decisions / Blockers

Nenhum destes é um requisito implícito já decidido — cada um é um bloqueio real que precisa de uma decisão explícita antes do código que depende dele. Não assumir nenhum comportamento aqui a partir da tabela de fases acima até o item correspondente ser fechado.

### Blocker #1 — Identidade, origem/spawn, ownership e trigger do Dragão do evento

**Parte já resolvida** (decisão desta conversa): o Dragão do World Event **não reusa** a entidade `MonsterDatabase`/lair rara existente. São conceitualmente coisas diferentes:

| | Monster Dragon (já existe) | Event Dragon (`DragonEvent`) |
|---|---|---|
| Papel | entidade PvE normal, parte da ecologia de monstros | personagem/evento mundial |
| Lifecycle | possui lair, spawn/despawn normal, comportamento `hunter` | possui anúncio, alvo, janela temporal (`Preparation`), participação de civilizações, resolução e consequências |
| Ownership | `HexGrid`/`MonsterAI`, `MonsterDatabase.global_cap` | `DragonEvent`, cria/controla sua própria `Unit` especial durante `Active` |

Podem compartilhar stats/base de combate (reduz duplicação de números), mas **nunca** ownership de lifecycle — o World Event não deveria depender de `MonsterDatabase.dragon.global_cap == 1`, nem a lógica normal de covis deveria reagir à morte do Dragão-evento como se fosse um evento ecológico comum. Isso evita os dois problemas degenerados: "o único Dragão do mapa já existe numa lair → o evento não pode acontecer" e "o evento mata o Dragão → o sistema de covis interpreta isso como um estado ecológico".

**Ownership da Event Dragon Unit** (parte que faltava, agora explícita): a `Unit` do Dragão-evento **não pertence a nenhuma civilização** — é uma entidade neutra/PvE, mesma categoria de `owner_player == null` já usada pelos monstros comuns (`MonsterDatabase`). Sua lifecycle é controlada pelo `DragonEvent` (criada ao entrar em `Active`, removida ao sair); ao ser derrotada/desaparecer, o resultado volta pro `DragonEvent` via seu próprio `advance_turn()`, nunca por um sistema externo observando a unidade. Criar/remover essa `Unit` **nunca** deveria alterar contagem de unidades de nenhuma `PlayerData` — ela não é "a unidade do jogador 0" por acidente; isso importa porque população/upkeep/guerra/IA/vitória hoje leem `player.units` diretamente.

**Cadeia de origem/spawn** (pergunta que faltava no título original — "onde o Dragão nasce"): a tabela de fases já promete "região aproximada" em `Announced` mas "posição/HP reais" em `Active` — isso só é consistente com uma escolha explícita de QUANDO o tile exato é sorteado:

```
trigger → escolha de REGIÃO/origem → Announced (só a região, nunca o tile exato)
        → Preparation
        → sorteio do TILE exato + spawn da Unit → Active
```

Decisão recomendada nesta revisão: o tile exato só é sorteado na transição pra `Active`, nunca antes — em `Announced`/`Preparation` só existe a região (permite "um Dragão despertou no oeste, provavelmente ameaça os Humanos" em vez de uma coordenada exata exposta cedo demais, e combina melhor com "mundo vivo" do que expor `(x,y)` de saída).

**Ainda aberto**: o TRIGGER em si — quando/por que `WorldEventManager` decide que um evento deve nascer. Não deveria ser um `if turn == 50: spawn_dragon()` fixo, nem deveria virar `if dragon_conditions: DragonEvent.new()` direto dentro do manager (isso começa a transformar `WorldEventManager` num catálogo de eventos). Também não vale o oposto — não vamos desenhar agora um `WorldEventTrigger`/`WorldEventDefinition`/`WorldEventRegistry` genérico só para um tipo de evento. Solução de tamanho certo pra v1: um helper pequeno e SEPARADO da lógica comportamental do `DragonEvent`, chamado pelo `WorldEventManager`:

```
WorldEventManager → avalia condições de spawn do mundo (helper separado)
                  → decide que tipo de evento deve nascer
                  → cria o evento concreto (ex.: DragonEvent)
```

Preserva a regra já estabelecida: "quando o mundo decide criar um evento" ≠ "como o evento funciona depois de criado". Condição de spawn em si (chance por turno após certo ponto, no estilo de `HexGrid.LAIR_SPAWN_CHANCE`/`THREAT_TURN_RAMP_TURNS`) ainda não decidida — só a FORMA (helper separado) está fechada aqui.

**Consequência de determinismo (importante, fácil de esquecer)**: o trigger acontece **antes** de existir `event_id` — nenhum evento foi criado ainda nesse ponto. Isso significa que o RNG do trigger **não pode** usar a fórmula já estabelecida em `WorldEvent.event_rng()` (`map_seed + event_id + turn`), porque `event_id` simplesmente não existe até o trigger decidir criar o evento. Precisa de uma fonte determinística própria pra essa decisão — conceitualmente `map_seed + event_type + turn` (ou equivalente: o ponto é usar algo que já exista ANTES da criação do evento, nunca o `event_id`). Fórmula exata não precisa ser decidida agora, só o princípio: o RNG de trigger é uma família separada do RNG de evento, pela mesma razão que o RNG de evento já é separado do RNG de IA.

**RESOLVIDO (implementação v1)**: `WorldEventTrigger.should_trigger_dragon` — a partir do turno `DRAGON_TRIGGER_MIN_TURN = 30`, `DRAGON_TRIGGER_CHANCE_PER_TURN = 0.02` por turno, usando `trigger_rng(map_seed, DragonEvent.EVENT_TYPE, turn)` (família de RNG separada do `event_rng`, exatamente o princípio pedido acima — nunca usa `event_id`). Origem escolhida por `WorldEventTrigger.choose_dragon_origin_region` (prefere a zona Principal do mapa, evita nascer num continente especial distante — ajuste da revisão 5B.3-E). Tile exato: `DragonEvent._choose_spawn_coord`, chamado só na transição `Preparation → Active`, varredura em anéis crescentes (`SPAWN_SEARCH_MAX_RINGS = 6`) a partir de `origin_region` até achar um tile sem cidade/unidade (água/lava são válidos — o Dragão voa). Ownership: `hex_grid.spawn_monster_at` cria a `Unit` com `owner_player == null`; `world_event_managed = true` (setado por `_mark_dragon_unit`) garante que ela nunca ganha veterania/cura por kill (`Unit.register_kill` tem guard explícito) e nunca é afetada pelo roaming normal de lair (`HexGrid._maybe_roam_lair` checa o mesmo flag). Ambos os números de trigger seguem marcados `PROVISÓRIO/NÃO CALIBRADO` no código.

### Blocker #2 — Duração de `Preparation`

Quantos turnos até a janela de decisão fechar. Valor inicial não calibrado, mas o FSM precisa de uma transição real por CONTAGEM DE TURNOS nesta fase (hoje o skeleton só avança uma fase por CHAMADA de `advance_turn()`, sem noção de duração — 5B.1 troca isso por uma contagem real, pelo menos em `Preparation`).

**Semântica de `turn_deadline` a fixar antes do código** (para não gerar off-by-one no FSM): `turn_deadline` representa o **último turno em que uma decisão de participação ainda pode ser registrada** — ou seja, se `turn_deadline = 43`, a decisão pode acontecer nos turnos 40, 41, 42 e 43; a transição pra `Preparation → Active` só acontece no processamento do turno 44. (A semântica inversa — `turn_deadline` como o primeiro turno já fora da janela — funcionaria igualmente bem, mas precisa ser escolhida UMA vez e documentada aqui antes do código, nunca inferida implicitamente por quem implementar.)

**RESOLVIDO (implementação v1)**: `DragonEvent.PREPARATION_DURATION_TURNS = 3`, semântica exatamente como fechada acima (`turn_deadline = TurnManager.turn_number + PREPARATION_DURATION_TURNS` no momento de `Announced → Preparation`; a transição real só acontece quando `TurnManager.turn_number > turn_deadline`). Ainda `PROVISÓRIO/NÃO CALIBRADO` no código.

### Blocker #3 — Escolha e travamento do alvo

Como o alvo é escolhido (civ mais próxima da posição anunciada? maior/menor força militar? aleatório ponderado?) — fórmula exata ainda aberta.

**Decisão já fechada nesta revisão**: o alvo é **travado no fim de `Announced` / início de `Preparation`** e não muda para a v1, exceto por uma causa explícita do mundo que viermos a adicionar no futuro (não existe hoje). Dito de forma explícita, sem ambiguidade temporal: **o alvo é determinado antes ou durante a transição `Announced → Preparation`, e permanece imutável durante `Preparation`** — `Announced` não tem decisão de civilização nenhuma, então travar o alvo nessa transição (não depois, não durante `Preparation`) é o que garante que toda civilização já vê o mesmo alvo definitivo antes de precisar decidir se participa. Motivo: se o jogador decide participar com base em "o alvo é X" e o alvo muda arbitrariamente antes de qualquer ataque acontecer, a decisão de participação deixa de ser estratégica — o suspense interessante é "quem vai ajudar o alvo anunciado", não "qual vai ser o alvo de verdade".

**Revisão 1 (pós-5B.3, causa arquitetural real)**: um mapa com civs de cidade única expunha um caso não previsto aqui — a civ anunciada, tendo só uma cidade, era martelada até o limite de devastação e o Dragão sumia sem nunca tocar as outras civs do mapa, mesmo com o orçamento de raids ainda sobrando. Fix aplicado nessa revisão: a partir do primeiro raid em `Active`, o Dragão podia perseguir a cidade mais próxima de qualquer civ, não só a anunciada.

**Revisão 2 (5B.3-G, "o Dragão é uma ameaça continental")**: pedido explícito do usuário substituiu por completo a mecânica de término (`DEVASTATION_RAID_LIMIT`, N raids totais) por cobertura continental — toda civ viva precisa ser visitada `CIV_VISIT_TARGET` vezes (ver `DragonEvent.civ_visits`) antes do Dragão poder concluir sua marcha. Isso também tornou a Revisão 1 obsoleta: a escolha de alvo (`DragonEvent._choose_target_city`) não distingue mais "civ anunciada" de "qualquer civ" em nenhum momento — ela sempre prioriza a(s) civ(s) viva(s) com o **menor número de visitas**, desempatando por distância, contemplando explicitamente uma varredura em RODADA completa (toda civ recebe sua 1ª passagem antes de qualquer civ receber a 2ª, exemplo do próprio pedido do usuário). A garantia de que a civ anunciada seja a **primeira a ser avisada** (texto de `Preparation`) continua valendo — só a garantia de que ela seja a primeira **raidada de verdade** é que não existe mais (pedido explícito do usuário: "a ordem NÃO deve ser fixa"). `target_civ_index` sobrevive apenas como a formula de qual civ é nomeada no aviso inicial, sem nenhum efeito sobre a ordem real de raids.

**Revisão 3 (RESOLVIDO para v1)**: `_choose_target_city` final tem 3 prioridades em cascata: (1) a mesma cidade já sendo perseguida (`current_target_city_coord`), enquanto ela existir; (2) entre civs vivas, o conjunto com o MÍNIMO exato de visitas (não um corte binário "abaixo do alvo" — isso quebraria a garantia de rodada completa); (3) dentro desse conjunto, a cidade mais próxima, excluindo `last_raided_city_coord` sempre que houver alternativa. `CIV_VISIT_TARGET = 2` (`PROVISÓRIO/NÃO CALIBRADO`). Uma vez que toda civ viva atinge o alvo de visitas, a busca reabre pra qualquer cidade — condição verificada por `_all_living_civs_covered`, que dispara o outcome `"devastated"`. Um alvo pode ser abandonado antes de ser raidado se o Dragão gastar `DRAGON_TARGET_ABANDON_THRESHOLD = 8` ticks seguidos perseguindo-o sem sucesso (cidade fortemente defendida) — isso NUNCA conta como visita, só torna a cidade temporariamente inelegível via o mesmo mecanismo de exclusão de `last_raided_city_coord`.

### Blocker #4 — Modelo de recompensa em `Resolution` — resolvido em 17/09/2026

Quando o Dragão é derrotado, cada civilização que aceitou participar e causou dano recebe `25 + floor(300 × fração do dano elegível)` de ouro e `10 + floor(150 × fração)` de mana. A fração considera somente contribuintes elegíveis. Não há prêmio exclusivo pelo último golpe; sobre-dano não aumenta contribuição. Fuga/devastação e participação sem dano não pagam prêmio.

`DragonEvent.damage_by_civ` registra ataques e magia. `result.rewards` registra o pagamento e `result.rewards_applied` impede repetição após carregar. Índices dos participantes são restaurados como inteiros após o JSON. O ranking de contribuição permanece no desfecho; o jogador recebe notificação do ouro e da mana concedidos. Testes cobrem proporção 75/25 e pagamento único após duas passagens por JSON. Artefatos exclusivos continuam como possibilidade futura, sem promessa de implementação atual.

### Blocker #5 — Custo de não participar

**Decisão v1**: não participar não gera custo, penalidade ou efeito diplomático automático. Mantém participar puramente uma oportunidade, nunca uma obrigação disfarçada. Reconsiderar só se o playtest mostrar que "nunca participar" é estrategicamente dominante demais — e, se isso acontecer, é uma mudança de design explícita registrada aqui, nunca um ajuste silencioso no código.

**RESOLVIDO (confirmado para v1)**: nenhuma mudança — não participar continua sem custo/penalidade/efeito diplomático em todo o código atual. Nada no fechamento de v1 tocou nisso.

## Mecânicas adicionadas após o contrato original (todas v1, todas `PROVISÓRIO/NÃO CALIBRADO` salvo indicação contrária)

Nada disto existia quando o contrato original foi escrito — surgiu ao longo de 5B.3-B a 5B.3-G, quase sempre em resposta a um playtest real do usuário. Registrado aqui pra não ficar só em comentário de código.

**Modos de deslocamento** (`DragonEvent.travel_mode`): `FLYING` quando a distância até o alvo atual é maior que `DRAGON_GROUND_ENGAGE_RANGE = 3` tiles (movimento `movement_left = DRAGON_FLYING_TILES_PER_TURN = 10` só naquele tick, ignora terreno/água, reusa `RivalAI.move_unit_toward`); `GROUND` quando mais perto (movimento normal do Dragão, ~2/turno). Sem pathfinding novo — é sempre o mesmo `move_unit_toward`/`compute_reachable`, só com orçamento de movimento diferente.

**Combate**: dano em área via `CombatResolver.resolve_with_splash` (`DRAGON_SPLASH_RADIUS = 1`, `DRAGON_SPLASH_DAMAGE_FRACTION = 0.4` do dano do alvo primário pros secundários). Raid contra cidade via `CombatResolver.resolve_city_attack` com `DRAGON_RAID_DAMAGE_FRACTION = 0.35` (um raid nunca tira mais que 35% do HP ATUAL da cidade numa passada — evita nocautear em 1 golpe; jogador/rival continuam sem esse cap). O Dragão nunca captura cidade (guard em `resolve_city_attack` pra atacante neutro) — é sempre raid, nunca conquista.

**Redes de segurança contra estagnação** (achadas por reprodução de playtests longos, nunca uma árvore de decisão de verdade): `GROUND_COMBAT_STREAK_LIMIT = 3` (combate parado no mesmo lugar por N turnos seguidos → `_break_off_toward`, um salto GRANDE — orçamento de FLYING — em direção à cidade-alvo, com fallback pra `_reposition_nearby` e depois `_reposition_escaping_siege` se o Dragão estiver cercado); `DRAGON_STUCK_TURNS_ESCAPE_THRESHOLD = 6` (rede geral: posição E `raids_done` idênticos por N ticks seguidos, qualquer motivo → força reposicionamento de emergência); `DRAGON_TARGET_ABANDON_THRESHOLD = 8` (ver Blocker #3, Revisão 3 acima).

**Reação da IA rival** (`RivalAI`, reusa infraestrutura existente — nunca uma árvore de IA nova): durante `Preparation`, só a civ anunciada entra em produção militar de emergência (`prepare_for_world_event` → `_troop_only_candidates`, restringe produção a tropas/prédios de treino, exclui muralhas/prédios econômicos). Durante `Active`, `defend_against_dragon` faz defesa POR CIDADE (não uma única unidade global): toda unidade cuja cidade mais próxima esteja a `DRAGON_CITY_AGGRO_RADIUS = 5` do Dragão ataca; senão retorna à guarnição se estiver a mais de `GARRISON_RETURN_RADIUS = 2` dela. `react_to_dragon` NÃO usa `is_favorable_attack` (removido especificamente daqui — matematicamente uma guarnição normal vs. o Dragão é sempre "desfavorável", mas defender uma ameaça existencial deveria lutar mesmo assim) e mede dano real antes/depois de `CombatResolver.resolve` pra alimentar `damage_by_civ`. `is_civ_threatened` decide quem está "em alerta": a civ anunciada durante `Preparation`; durante `Active`, qualquer civ já visitada (`civ_visits > 0`) OU com cidade a `THREAT_DETECTION_RADIUS = 8` do Dragão (sem violar fog of war — a Unit do Dragão já é `always_visible = true` por design).

**Ranking de dano**: ver nota em Blocker #4 acima.

**Comunicação do desfecho**: `_resolve_with_outcome(outcome)` só define `result = {"outcome": outcome}` e entra em `Resolution` — não emite mais toast (removido na 5B.3-G, era fraco demais pra um evento de vários turnos). `HUD._on_world_event_phase_changed` escuta a transição de fase e mostra um MODAL bloqueante com os textos finais aprovados pelo usuário:
- `defeated` → título "🐉 O DRAGÃO FOI DERROTADO", texto sobre os defensores terem derrubado a criatura.
- `devastated` (cobertura continental completa) → título "🐉 O DRAGÃO RECUOU", texto deixando claro que a criatura NÃO foi derrotada, só saciada.
- `no_target` (caso raro — civ-alvo sem cidade nenhuma) → título "🐉 O DRAGÃO DESAPARECEU".
O modal também lista o ranking de dano (Blocker #4) quando houver pelo menos uma civ com dano > 0.

## Ordem de trabalho

Cada etapa responde uma pergunta necessária pra próxima — não tentar resolver tudo de uma vez. **Status real, pós-fechamento de v1:**

1. ✅ **Trigger + identidade + origem/spawn + ownership da Unit** (Blocker #1 completo) — afeta a arquitetura de `DragonEvent` diretamente (como ele nasce, o que possui desde o `_init()`, quando o tile exato é sorteado, quem é dono da futura `Unit`), por isso vem antes mesmo de `Preparation`. **Implementado** — ver nota de resolução no Blocker #1.
2. ✅ **`Preparation` + participação** (Blocker #2, com a semântica de `turn_deadline` já fechada acima) — totalmente testável sem combate nenhum: `DragonEvent` recebe seu estado inicial (região/origem), anuncia com o alvo já travado (Blocker #3), determina quem pode participar, cada civilização toma a decisão binária de compromisso/elegibilidade (`RivalAI.decide_world_event_participation` pro lado IA, botão de UI pro humano — mesmo princípio de `decide_arcane_ritual`), participação NUNCA mexe em `Diplomacy` automaticamente, `participants` fica persistido, `Preparation` tem deadline real em turnos. **Implementado.**
3. ✅ **`Active` + Dragão como `Unit`** — sorteio do tile exato + spawn da Unit neutra (dono nenhum), combate de verdade via `CombatResolver`/movimento normal (`DragonEvent` coordena, nunca implementa dano diretamente), contribuição real decidida por quais unidades de fato chegam ao confronto (não pela decisão binária em si). **Implementado**, e muito além do previsto aqui — ver "Mecânicas adicionadas após o contrato original" (modos de deslocamento, dano em área, cobertura continental, redes de segurança contra estagnação, reação da IA rival).
4. ⚠️ **`Resolution`** — desfecho **implementado** (modal bloqueante com textos finais + ranking de dano informativo). Recompensas em si (Blocker #4) continuam **deliberadamente em aberto** — é o único item real que falta pra v1 ser considerado 100% fechado mecanicamente, e está fora de escopo até uma decisão explícita futura (5B.4).
5. ➖ **Consequências persistentes** (Blocker #5 e além) — decisão v1 confirmada: nenhuma consequência persistente além do que já existe (sem penalidade por não participar). Não expandir sem pedido explícito — ver a lista de "não fazer agora" combinada com o usuário no fechamento de v1 (destruição/reconstrução de prédios, reputação, diplomacia específica do Dragão, novas fases, múltiplos dragões etc. seguem fora de escopo).
