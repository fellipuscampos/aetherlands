> **STATUS: APROVADO — contrato comportamental v1.** Números de trigger, duração, combate e recompensa permanecem deliberadamente fora deste contrato até as etapas de implementação correspondentes (ver "Open Design Decisions / Blockers" no fim — cada um ainda é um bloqueio real, não um detalhe implícito já decidido, mesmo com o contrato como um todo aprovado). Não reabrir este documento durante 5B.1 salvo descoberta arquitetural real.

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
| `Resolution` | desfecho (derrotado / fugiu / devastou o alvo) | nenhuma | recompensas/consequências aplicadas e escritas em `result`, ANTES de virar `Completed` |
| `Completed` | só `result` | nenhuma | nenhum — qualquer coisa permanente já aconteceu em `Resolution` |

## Decisões que pertencem às civilizações

Só uma em v1: **participar da expedição, sim ou não**, coletada durante `Preparation`. Simétrica entre humano (UI, ainda não construída) e IA — mesmo princípio já usado por `decide_arcane_ritual`: uma função `RivalAI.decide_world_event_participation(player, event)` decide pela IA: escreve em `event.participants[civ_index]`; o humano escreve o mesmo dict por uma ação de UI equivalente. Nenhuma lógica de evento deveria distinguir os dois caminhos — só a origem da escrita muda.

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

### Blocker #2 — Duração de `Preparation`

Quantos turnos até a janela de decisão fechar. Valor inicial não calibrado, mas o FSM precisa de uma transição real por CONTAGEM DE TURNOS nesta fase (hoje o skeleton só avança uma fase por CHAMADA de `advance_turn()`, sem noção de duração — 5B.1 troca isso por uma contagem real, pelo menos em `Preparation`).

**Semântica de `turn_deadline` a fixar antes do código** (para não gerar off-by-one no FSM): `turn_deadline` representa o **último turno em que uma decisão de participação ainda pode ser registrada** — ou seja, se `turn_deadline = 43`, a decisão pode acontecer nos turnos 40, 41, 42 e 43; a transição pra `Preparation → Active` só acontece no processamento do turno 44. (A semântica inversa — `turn_deadline` como o primeiro turno já fora da janela — funcionaria igualmente bem, mas precisa ser escolhida UMA vez e documentada aqui antes do código, nunca inferida implicitamente por quem implementar.)

### Blocker #3 — Escolha e travamento do alvo

Como o alvo é escolhido (civ mais próxima da posição anunciada? maior/menor força militar? aleatório ponderado?) — fórmula exata ainda aberta.

**Decisão já fechada nesta revisão**: o alvo é **travado no fim de `Announced` / início de `Preparation`** e não muda para a v1, exceto por uma causa explícita do mundo que viermos a adicionar no futuro (não existe hoje). Dito de forma explícita, sem ambiguidade temporal: **o alvo é determinado antes ou durante a transição `Announced → Preparation`, e permanece imutável durante `Preparation` e `Active`** — `Announced` não tem decisão de civilização nenhuma, então travar o alvo nessa transição (não depois, não durante `Preparation`) é o que garante que toda civilização já vê o mesmo alvo definitivo antes de precisar decidir se participa. Motivo: se o jogador decide participar com base em "o alvo é X" e o alvo muda arbitrariamente depois, a decisão de participação deixa de ser estratégica — o suspense interessante é "quem vai ajudar o alvo anunciado", não "qual vai ser o alvo de verdade".

### Blocker #4 — Modelo de recompensa em `Resolution`

O que cada participante ganha — não decidido ainda, propositalmente adiado pra depois de `Preparation`/`Active` existirem (é a etapa de resolução/playtest, não de design abstrato). Direção que já vale registrar sem fechar: a recompensa deveria reforçar a fantasia de "participei de um acontecimento histórico", não virar um simples "+500 ouro" — a Bible menciona um "artefato arcano" pro Elfo como exemplo narrativo, e o espaço de opções (artefato, unidade veterana, mana, recurso raro, bônus temporário, participante principal vs. secundário vs. não-participante) fica registrado aqui só como inventário de ideias, nenhuma delas comprometida ainda.

### Blocker #5 — Custo de não participar

**Decisão v1**: não participar não gera custo, penalidade ou efeito diplomático automático. Mantém participar puramente uma oportunidade, nunca uma obrigação disfarçada. Reconsiderar só se o playtest mostrar que "nunca participar" é estrategicamente dominante demais — e, se isso acontecer, é uma mudança de design explícita registrada aqui, nunca um ajuste silencioso no código.

## Ordem de trabalho

Cada etapa responde uma pergunta necessária pra próxima — não tentar resolver tudo de uma vez:

1. **Trigger + identidade + origem/spawn + ownership da Unit** (Blocker #1 completo) — afeta a arquitetura de `DragonEvent` diretamente (como ele nasce, o que possui desde o `_init()`, quando o tile exato é sorteado, quem é dono da futura `Unit`), por isso vem antes mesmo de `Preparation`.
2. **`Preparation` + participação** (Blocker #2, com a semântica de `turn_deadline` já fechada acima) — totalmente testável sem combate nenhum: `DragonEvent` recebe seu estado inicial (região/origem), anuncia com o alvo já travado (Blocker #3), determina quem pode participar, cada civilização toma a decisão binária de compromisso/elegibilidade (`RivalAI.decide_world_event_participation` pro lado IA, UI futura pro humano — mesmo princípio de `decide_arcane_ritual`), participação NUNCA mexe em `Diplomacy` automaticamente, `participants` fica persistido, `Preparation` tem deadline real em turnos.
3. **`Active` + Dragão como `Unit`** — sorteio do tile exato + spawn da Unit neutra (dono nenhum), combate de verdade via `CombatResolver`/movimento normal (`DragonEvent` coordena, nunca implementa dano diretamente), contribuição real decidida por quais unidades de fato chegam ao confronto (não pela decisão binária em si).
4. **`Resolution`** (Blocker #4, ainda deliberadamente aberto) — desfecho + recompensas.
5. **Consequências persistentes** (Blocker #5 e além).
