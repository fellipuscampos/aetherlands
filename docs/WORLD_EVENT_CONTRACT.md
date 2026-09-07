# World Event System — Contrato Técnico

Este documento define as invariantes arquiteturais que o código do World Event System precisa obedecer. Complementa `GAME_DESIGN_BIBLE.md`, não a substitui: a Bible define o que o sistema deve representar para o jogo (visão, identidade, o exemplo do Dragão); este contrato define como ele é construído. A Bible muda por decisão de design; este contrato evolui junto com a implementação — se um teste ou um PR descobrir que uma regra aqui estava errada, corrija aqui, não silenciosamente no código.

Ordem de implementação: `WorldEvent` → `WorldEventManager` → persistência → testes → `DragonEvent`. Nenhum código antes deste contrato estar fechado.

---

## 1. Ciclo de vida (FSM)

```
Dormant → Announced → Preparation → Active → Resolution → Completed
```

`WorldEventManager` avança o relógio; `WorldEvent` decide sua própria transição. Precisão importante: `WorldEventManager.advance_turn()` não é responsável por *forçar* uma transição de fase por turno — ele **avalia e aplica a evolução daquele evento naquele turno**, delegando a decisão de transição ao próprio `WorldEvent` (`WorldEvent.advance_turn(hex_grid, players) -> void`, virtual). Isso deixa espaço para eventos que pulam fases ou terminam antecipadamente, sem o manager precisar saber por quê.

**Ordem temporal exata** (não fica implícita em "mesma linha de `_update_victory_state()`"), dentro de `GameManager._finish_turn()`:

1. `hex_grid.refresh_construction_markers(...)` (já existe)
2. `hex_grid.recompute_fog(human_player)` (já existe)
3. `WorldEventManager.advance_turn(hex_grid, GameManager.players)` ← novo
4. `_update_victory_state()` (já existe)
5. `check_victories()` (já existe)

Motivo da posição: qualquer consequência que um evento aplique neste turno (cidade destruída, território alterado, recurso concedido) precisa estar refletida no mapa **antes** da checagem de vitória do mesmo turno — mesmo princípio já usado para prédio-concluído-antes-de-fog.

**Regra temporal, sem exceção**: eventos avançam exatamente uma vez por turno real, só de dentro de `_finish_turn()`. Nenhuma chamada de UI, preview, save/load ou verificação de vitória pode avançar um evento — mesma disciplina já validada para `_update_victory_state()` vs. os outros 3 call-sites de `check_victories()` (que só detectam, nunca avançam).

## 2. Ownership do estado

- `WorldEventManager` (novo autoload, mesmo nível de `GameManager`/`TurnManager`) possui `active_events: Array[WorldEvent]`.
- `WorldEvent` possui seu próprio estado específico. `GameManager` não conhece detalhes internos de evento nenhum — só chama `advance_turn()` e ouve o `EventBus`.
- `participants: Dictionary[int, Dictionary]` — a chave é um **civ_index estável**, nunca uma referência a `PlayerData`. `civ_index` = posição em `GameManager.players` (`[human_player] + rival_players`, na mesma ordem fixa que `setup_players()` já usa e que `SaveManager` já assume implicitamente ao salvar `rival_players[i]` por índice — nenhum campo novo em `PlayerData`, reuso do que já existe). Resolver `PlayerData` via `GameManager.players[civ_index]` só quando necessário; nunca guardar o objeto.
  - **Ressalva explícita**: `civ_index` é estável dentro do formato de save atual *desde que* a ordenação de `GameManager.players` permaneça compatível com `SaveManager`. Isto é uma convenção reutilizada, não uma garantia arquitetural eterna — se multiplayer futuro exigir IDs persistentes independentes da ordem do array, isso é uma migração explícita de identidade (novo campo, novo `SAVE_VERSION`, código de tradução), nunca uma alteração silenciosa de significado do que já está salvo.

## 3. Persistência

`SAVE_VERSION` 16 → 17.

- Eventos não são serializados como objetos; apenas seu estado mínimo e reconstruível é salvo.
- `WorldEventManager.to_save_dict()` / `from_save_dict()` serializa, por evento ativo: `event_id`, `event_type`, `phase`, `turn_started`, `turn_deadline`, `participants` (por `civ_index`), mais o estado específico do próprio evento via `WorldEvent.to_save_dict()` / `from_save_dict()` polimórfico.
- `WorldEventManager.from_save_dict()` reconstrói a instância concreta a partir de `event_type` (hoje um `match` simples — `"dragon" → DragonEvent.new()`; vira tabela de registro só se/quando o número de tipos concretos justificar, mesma disciplina de não introduzir mecanismo antes de precisar).
- Teste obrigatório desde o primeiro commit do Dragon: salvar em cada fase relevante (`Preparation`, `Active`, `Resolution`), carregar, confirmar reconstrução idêntica — mesmo padrão já usado pelo teste "salvar em pleno Ritual Arcano".

## 4. Determinismo

O RNG de eventos é **independente** do RNG global de decisão de IA (`RivalAI.decide_war`/`decide_trade`) — nenhum acoplamento temporal entre "quantos rolls a IA consumiu este turno" e o resultado de um evento.

Mecanismo: qualquer roll de evento é derivado **sem estado**, via hash determinístico de `(map_seed, event_id, turno_atual)` — nunca um `RandomNumberGenerator` com estado mutável entre turnos. Consequência prática: zero campo extra de RNG a persistir — o mesmo roll é sempre re-derivável a partir de campos que já fazem parte do estado mínimo (o `map_seed` do `HexGrid` já existe; `event_id` e o turno já são persistidos por definição do item 3).

```
AI RNG      → decisões da IA (RivalAI)
Event RNG   → decisões dos eventos (hash de map_seed+event_id+turno)
```

Os dois permanecem determinísticos, mas nunca se influenciam.

## 5. EventBus

Três sinais novos, mesmo princípio já usado por `victory_achieved` (o sinal carrega o objeto vivo + um resultado, nunca um snapshot duplicado):

- `world_event_announced(event: WorldEvent)`
- `world_event_phase_changed(event: WorldEvent, old_phase, new_phase)`
- `world_event_completed(event: WorldEvent, result: Dictionary)`

`result` é só o resultado **final** do evento, nunca um snapshot permanente — quem quiser o estado vivo consulta o objeto `event` diretamente. Sem um quarto sinal (`world_event_updated`) por enquanto: `phase_changed` + o estado vivo do objeto bastam para o primeiro evento. Não criar sinal preventivamente — se um caso de uso concreto pedir granularidade por-turno, ele entra então, não antes.

## 6. Integração com GameManager

Uma linha: `WorldEventManager.advance_turn(hex_grid, GameManager.players)` — reusa o campo `players` que `GameManager` já mantém (`setup_players()`), sem reconstruir a lista a cada chamada.

Princípio: **`GameManager` orquestra (decide quando chamar); `WorldEventManager` possui e processa o estado dos eventos (decide o que acontece).**

---

## Princípios (resumo, todos obrigatórios)

**Ownership**
- `WorldEventManager` possui os eventos ativos.
- `WorldEvent` possui seu estado específico.
- `GameManager` não conhece detalhes de eventos.

**Temporalidade**
- Um avanço por turno real.
- Nenhuma chamada de UI, preview, victory check ou load pode avançar um evento.

**Persistência**
- Somente estado mínimo/reconstruível.
- `SAVE_VERSION` incrementado.
- Fallback/teste de saves antigos (sem eventos ativos deve continuar carregando normalmente).

**Determinismo**
- RNG de eventos independente do RNG da IA.
- Toda aleatoriedade reproduzível pelo seed, sem estado de RNG a persistir.

**Identidade**
- Eventos operam sobre civilizações, não sobre "jogador humano".
- IDs estáveis (`civ_index`) em qualquer estado persistente, nunca referências de objeto.

**Multiplayer**
- Nenhum pressuposto de que uma civilização é humana ou IA.
- Participar de um evento não cria automaticamente uma aliança diplomática permanente.

**Extensibilidade**
- `WorldEventManager` não contém regra específica nenhuma de Dragão.
- `DragonEvent` não contamina `GameManager`.
