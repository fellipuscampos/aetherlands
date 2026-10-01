# Aetherlands — Strategic Pacing & Objectives Design (Fase 33C)

**Status:** design fechado para implementação na F33D. **Nada foi implementado nesta etapa**: nenhuma regra, custo,
peso de IA, geração de mundo ou save mudou. A única adição de código é uma análise somente leitura
(`tools/balance/BalanceWorldSurvey.gd`, `--world-survey`) usada para medir covis/Dragão por capital.

Fontes: `docs/AETHERLANDS_RELEASE_BALANCE_BASELINE.md` (F33B, 48 partidas), `docs/balance/F33C_world_survey.json`
(48 mundos iniciais), playtest qualitativo do desenvolvedor e leitura do código atual (monstros/covis, World Events,
Dragão, `V2StrategicAI`, `V2AIWorldView`, Event Center, Attention, Vitória, geração de mapa, save).

---

## Implementation Status (F33D)

| Etapa | Status |
|---|---|
| **D1 — Correções + núcleo de era** | **CONCLUÍDA** (detalhes abaixo) |
| **D2 — Ameaças regionais e Guardiões** | **CONCLUÍDA** (ver "D2 Implementation Status") |
| **D3 — Midgame e endgame** | **CONCLUÍDA** (ver "D3 Implementation Status") |

### Decisões de produto fechadas (F33C → F33D)

- **Q1 Supremacia (canônica, implementação junto dos imperativos na D3):** para cada rival, a condição de captura é
  satisfeita ao conquistar **qualquer cidade cujo City Level seja igual ao MAIOR City Level possuído por aquele rival no
  instante da captura**, ou ao eliminá-lo. Empate no maior nível: **todas** as empatadas qualificam; a capital é só o
  desempate preferencial para UI, imperativo e alvo sugerido à IA — nunca para a validade da captura. A D1 não altera
  `V2VictoryConditions`.
- **Q2:** Exército Supremo concluído e segunda Manifestação distinta ativa serão anúncios públicos (sem cidade, tile,
  exército, composição, Escola nem posição). Implementação na D3.
- **Q3:** Relicário aprovado para o 1.0 como SHOULD e primeiro corte de escopo; só na D3 se D1 e D2 passarem.
- **Q4:** nomes finais — Era do Despertar, Era da Ascensão, Era da Convergência (em uso na D1).
- **Q5:** Dragão ONCE_PER_GAME (implementado na D1); elegibilidade por era, garantia, recompensa e participação da IA
  ficam na D3.

### D1 — o que foi implementado

| Item | Implementação |
|---|---|
| Bug #1 — fila da cidade capturada | `City.production_eligibility_reason()`/`revalidate_production_for_owner()`, chamados em `HexGrid.capture_city`. Elegibilidade = pesquisa do novo dono, prédio de treino/pré-requisito, cópias/slots, nível de cidade/fortificação, slot de Lendária e de Manifestação. As travas de *início* (Mana, Suprimentos/Déficit, Ouro do City Project) não entram: nada é cobrado de novo. Item ilegítimo → cidade ociosa, progresso zerado, nenhuma escolha automática |
| Bug #2 — distância entre capitais | `WorldSetup.MIN_CAPITAL_DISTANCE = 12` (distância hex) dentro de `find_start_tile`, em estágios (grama → floresta/colina/deserto → qualquer terra firme). Mapa pequeno demais: tile mais afastado + `push_warning` + `WorldSetup.start_distance_violations` (gate do laboratório = 0). Ordem de busca inalterada: onde a distância já era respeitada, a capital não se move |
| Bug #3 — Dragão repete | `WorldEventManager.REPEAT_POLICY` (`dragon: ONCE_PER_GAME`) + `completed_event_types` (salvo) + `can_start_event_type`. `debug_force_dragon_event` continua override de desenvolvedor |
| Bug #4 — onisciência de covis | `V2AIWorldView.known_lairs` (covis ativos em tiles explorados pela civ) e `HexGrid.get_lair_danger_at(coord, known)`; exploração (`StrategicAI.explore`) e escolha de local (`CitySite.evaluate` com contexto de conhecimento) só pesam covis descobertos, pelo tipo, sem ler população escondida. Estado derivado de `explored_tiles` (já salvo) — nenhum campo novo no save |
| Bug #5 — nome de classe no Event Center | `WorldEvent.display_name()/public_summary()` (Dragão: "O Dragão desperta") usados pelo `UIEventService` |
| Núcleo de eras | `scripts/core/WorldPhaseRules.gd` (regras puras); estado, histórico `{phase, turn, cause}` e reset por partida em `WorldEventManager`; avaliação única por rodada em `GameManager._finish_turn` (depois dos eventos, antes de `check_victories`); `EventBus.world_phase_changed(old, new, turn, cause)` |
| Save | `SAVE_VERSION` 21 → **22** (uma vez); 21 migrável. Save antigo: era reconstruída pelo estado (`WorldPhaseRules.reconstruct`), histórico com uma entrada `MIGRATED`, nenhum sinal/recompensa retroativa, nenhum evento concluído inferido |
| UI | `GlobalBar`: "T62 · Ascensão" (tooltip com o nome completo); mudança de era publicada como evento `WORLD`/IMPORTANT (Toast + Event Center), sem Attention |
| Telemetria | `BalanceTelemetry`: timeline de eras e causa, primeiro contato/combate PvP/ataque a cidade/captura/uso de unidade, `units_without_purpose_lag`, EMPTY/LOW_ACTIVITY_WAR por par, inatividade máxima por era, schema de monstros/covis/ameaça regional/objetivos (D2/D3 preenchem); sinais de observabilidade `lair_cleared`, `tile_pillaged` e `combat_engagement` com alvo `lair` |

Não implementado de propósito (D2/D3): planner regional, covis garantidos, dormente/desperto, população regional,
Trolls guardiões, ataque da IA a estrutura de covil, recompensas novas, elegibilidade/recompensa/participação do Dragão,
imperativos, anúncios públicos, Relicário, nova regra de Supremacia. Nenhum número de balanceamento mudou.

## D2 Implementation Status

O design das seções 6, 7, 10, 12 e 13 foi implementado sem alterar o original abaixo; esta seção registra o que
foi feito, as decisões de implementação e o que ficou para a D3.

| Item | Implementação |
|---|---|
| Bug #6 — onisciência do CitySite | `CitySite.build_context(…, known)` em modo IA contém só cidades próprias, cidades estrangeiras conhecidas (`known_enemy_cities`/visíveis) e o território delas, monstros **visíveis** e covis em tiles conhecidos. A pré-legalidade da busca (`known_rejection_reason`) usa o mesmo conhecimento; a legalidade real continua em `WorldSetup.found_city_from_settler`. Recusa do runtime → o tile vai para `Unit.settle_rejected_sites` (sessão) e o Colonizador replaneja, sem saber o motivo |
| Planner | `RegionalThreatPlanner` (estático): anel 7–10 no mesmo componente terrestre da **capital real**; fora da visão inicial; corredor evitado para capitais a < 16 (hemisfério oposto; faixa de ±4 hexes = "corredor"); reuso de covil selvagem Goblin/Esqueleto intocado quando não pior em corredor/visibilidade; covil selvagem a < 7 da capital nova realocado para 11–16 (ou removido); covil já observado/danificado/alertado nunca é movido; tipo pelo bioma (deserto/tundra → Esqueleto; grama/planície/floresta/colina → Goblin); tile de recurso só como último recurso (anel nunca ampliado). RNG `map_seed + 8000 + assento × 7919`, varreduras ordenadas por coordenada |
| Criação | Capitais do setup: planejadas juntas no fim de `GameManager._spawn_starting_forces` (todas as âncoras conhecidas; assento sem cidade usa o Colonizador inicial). Fundação manual: `HexGrid.found_city` (não silenciosa) → `RegionalThreatSystem.on_city_founded`, só se a civ ainda não tem registro. Segunda cidade, captura e load nunca criam ameaça |
| Estados | `DORMANT` (sem reforço, sem saque, guarda a porta, pode ser descoberto/destruído) → `AWAKE` em `capital_founded_turn + 8..12` (uma vez, no tick de covis) → `RESOLVED` (permanente, sem substituto). Registro por civ em `WorldEventManager.regional_threats` |
| População | 3 por covil regional (chefe + 2), contada por `Unit.source_lair_coord`; mesma cadência de reforço existente; fora do teto global por tipo (que continua valendo para selvagens) |
| Comportamento | Despertar: Goblin = Saqueador preso ao teatro (âncora no covil, raio = distância até a capital + 3); Esqueleto = pressão no mesmo teatro; sem promoção a Invasor. Ascensão: comportamento normal do tipo. Monstros nunca capturam cidade; saque existente |
| Recompensas | Regional Goblin 40 Ouro; Esqueleto 40 Ouro + 5 Mana; Guardião 75 Ouro — substituem a recompensa do tipo (nunca somam); recompensa por abate preservada; nunca Conhecimento. **Provisórias** (F33E calibra) |
| Guardiões Troll | Na entrada da Ascensão, uma vez: até 1 por civ ativa em recurso existente de alto valor (Ferro, Cavalos, Gemas, Seda, Nódulo), livre (sem cidade/território/melhoria/construção/unidade), a 12–20 da capital e ≥ 12 de todas; o **tipo** é sorteado entre os disponíveis (evita concentrar em Nódulo); nunca a única cópia do teatro (raio 20); recurso compartilhado = um site. Caverna ao lado, Troll-chefe em cima do recurso, sem reforço, raio de Guardião do tipo; destruir a caverna resolve e mantém o recurso |
| IA | `V2AIWorldView.known_lairs` ganha o papel (público); `known_lair_defense` = monstros visíveis ou o chefe típico do tipo se a área está na névoa. `V2StrategicAI.lair_response_plan`: covil Goblin/Esqueleto conhecido a ≤ 10 de cidade própria (Guardião: ≤ 12, sem guerra); força local (≤ 10 do covil) ≥ `CityDefense.OVERMATCH` × defesa → `attack`; senão `gather` (+30 de produção a unidade de linha enquanto exército relevante + fila < 3, depois do teto de tokens). Pressão grave (Ritual rival, inimigo em guerra perto, campanha ativa) → nada. Execução: `StrategicAI.respond_to_lair` (movimento normal, ataque ao defensor visível que não mata o atacante, estrutura via regra canônica); guarnição única em guerra fica |
| Ataque a covil | `CombatResolver.can_attack_lair` = regra canônica (humano: destaque do `SelectionManager`; IA: `respond_to_lair`); `resolve_lair_attack` a exige (alcance real, movimento, covil indefeso) |
| UI | Event Center WORLD/IMPORTANT com foco no tile: descoberta ("Ameaça regional" / "Um covil hostil ameaça os arredores de seu reino."), despertar só ao dono que já conhece ("Uma ameaça desperta perto de seu reino."), resolução (sem revelar o reino que resolveu), Guardião surgindo junto a recurso que o jogador conhece. Chip "Ameaça regional" na barra global (foco no covil) só depois da descoberta. TileInspector: papel, Adormecido/Desperto, recompensa do papel; nunca o turno de despertar. Nada vira Attention nem alerta crítico |
| Objetivo | Derivado (nunca salvo): `RegionalThreatSystem.objectives_for` — categoria `world_threat`, só após descoberta, status `active`/`resolved`/`resolved_by_other` |
| Save | `SAVE_VERSION` 22 → **23** (uma vez; 22 migrável). Novo: bloco `regional` em `world_events`, `lair_state` (covis criados/removidos/papéis) e `source_lair` por monstro. Save 22: ameaças desligadas, nada retroativo (nem Guardião na Ascensão) |
| Telemetria | Por civ: `regional_threat` (tipo, origem, criação, despertar, descoberta, primeira resposta, limpeza, resolvido por self/other, vigia de guerra precoce), `lairs` (limpezas por papel, ataques à estrutura e **ataques a covil desconhecido — auditoria, exige 0**), `guardian` (descoberta, engajamento, resolvidos), objetivos issued/resolved/resolved_by_other. Partida: `world_threats` (vivas no T30/50/75, Guardiões criados/resolvidos por recurso) |

Números de fechamento: survey 48 mundos — 192/192 ameaças a 7–10 tiles (mín 7 · p25 8 · mediana 8 · p75 9 · máx 10),
0 fora do componente, 0 visíveis na criação, 0 no corredor (26 com vizinho a < 16), 150 Goblin / 42 Esqueleto,
140 criadas / 52 reusadas, 52 covis selvagens realocados, 0 removidos; Guardiões 190 sites (Seda 45, Ferro 38,
Cavalos 39, Gemas 37, Nódulo 31), 2 compartilhados, 8 cópias únicas poupadas. Resumos em `docs/balance/F33D2_*`.

Fica para a D3: Dragão por era/recompensa/participação, imperativos, marcos públicos, Relicário, nova Supremacia,
chips de endgame. Tuning (recompensas regionais, cadência, pesos de resposta) é F33E.

## D3 Implementation Status

As seções 8, 9, 10, 12 e 13 foram implementadas sem apagar o design original; a decisão Q1 (Supremacia) substitui a
regra antiga só no critério de qual cidade qualifica.

| Item | Implementação |
|---|---|
| Supremacia (Q1) | `V2VictoryConditions.is_supremacy_qualifying_city(city, owner)`: qualifica a cidade cujo City Level, no instante da captura (avaliado em `HexGrid.capture_city` antes de a cidade sair do rival), é igual ao MAIOR City Level do rival; empates todos qualificam; rival só de Cidades I é satisfazível. Semântica de posse preservada da Fase 16: o crédito fica gravado na cidade (`v2_supremacy_captured_from`) e só conta enquanto o captor a mantém; perdê-la (inclusive recaptura) remove o crédito; eliminação satisfaz; desenvolvimento posterior do rival não reavalia uma captura feita |
| Alvos conhecidos | `PlayerData.known_enemy_city_levels` (último nível OBSERVADO; gravado em `known_enemy_cities` do save) + `V2VictoryConditions.known_supremacy_targets` (maior nível conhecido → capital pública = primeira cidade própria ainda possuída → distância). IA (`V2StrategicAI.supremacy_target_coord`) e UI nunca recebem cidade escondida |
| Imperativos | `StrategicImperatives` (derivado, sem estado): Supremacia ("Prove sua supremacia", linha por rival, alvo conhecido ou "Explore o território…"), Transcendência na ordem real do runtime (Escolas → pesquisa → Estrutura Ritual → 1ª Manifestação → 2ª Manifestação distinta → Mana → iniciar → manter), Dominação ("Restam N reinos rivais"). Tela de Vitória: "Próximo passo" por rota (mesmo campo, sem redesign). Chip "Próximo passo" só na Convergência |
| Marcos públicos (Q2) | `PublicVictoryMilestones`, uma vez por rodada: Exército Supremo e 2 Manifestações distintas ativas → evento público uma vez por civ por partida (`WorldEventManager.public_milestones`, salvo); só o fato; a IA lê em `V2AIWorldView.public_milestones` (desempate de alvo entre inimigos já em guerra, sem mudar pesos de guerra/paz) |
| Dragão | Só INICIA na Ascensão; elegível na Ascensão+10; gatilho existente de 2%/rodada; garantido na Ascensão+35; na virada para a Convergência é anunciado na mesma rodada se nunca ocorreu (ou SUPERSEDED/NO_VALID_TARGET); pode terminar na Convergência. Nunca mira civ com uma cidade (adia sem alvo elegível). Alvo sempre defende; os demais DECIDEM (`V2StrategicAI.dragon_participation`: guerra defensiva/perdendo, força móvel mínima 2, distância ≤ 20 da região anunciada) e quem aceita desloca até 3 unidades por movimento normal. Recompensa: pool 175 Ouro / 80 Mana só para quem causou dano, piso 15/5, resto por dano (maiores restos, desempate por índice, soma nunca acima do pool), uma vez. Desfecho no Event Center com ranking/recompensas; sem modal de resultado; participação deixou de ser Attention REQUIRED |
| Relicário (Q3) | `ReliquaryEvent`: só anunciado na Ascensão, uma vez por partida; elegível na Ascensão+15; com o Dragão ativo espera (e +5 depois dele); antes do Dragão só se a duração máxima (5 preparação + 10 ativo + 3 escolha) termina antes da garantia do Dragão; SUPERSEDED pela Convergência. Local: continente Principal, terra livre, 6–22 de cidades, mesmo componente de ≥ 2 civs, minimiza a diferença de distância entre as duas civs mais próximas (RNG dedicado `map_seed + 8200`). 3 Esqueletos guardiões ligados ao evento (`Unit.source_event_id`). Posse: unidade própria no local, sem hostil adjacente, sem guardião vivo, 2 rodadas globais consecutivas (trocar ou contestar zera). Vencedor escolhe 90 Ouro ou 60 Mana (IA pela própria orientação/Mana; pessoa pelo painel de evento existente, padrão Ouro em 3 rodadas); sem vencedor em 10 rodadas ativo, expira |
| Exclusividade | No máximo um grande evento (Dragão/Relicário) ativo; ameaças regionais e Guardiões não contam |
| Save | `SAVE_VERSION` 23 → **24** (uma vez; 23 migrável): `dragon_schedule`, `reliquary_schedule`, `public_milestones` em `world_events`, Relicário como evento salvo, `source_event` por monstro, nível observado por cidade conhecida. Save 23: agendadores derivam no próximo round (nada nasce no load); marcos já satisfeitos contam como anunciados |
| Telemetria | `dragon` (elegível, forçado, anúncio, alvo, decisões e motivos, dano, recompensas, desfecho, era no início/fim, superado), `reliquary` (elegível, anúncio, ativo, local, respondentes, guardiões limpos, progresso máximo, rodadas contestadas, vencedor, escolha, superado/expirado), marcos por civ, imperativos na Convergência e no fim, sobreposição de pressões na Ascensão, vocabulário de objetivos issued/resolved/resolved_by_other/superseded para Dragão e Relicário |

Interpretação registrada: "Nunca atrasar o Dragão garantido por causa do Relicário" + exclusividade exigem que o
Relicário tenha duração máxima; por isso ele expira sem vencedor em 10 rodadas ativas e só é anunciado antes do
Dragão quando cabe inteiro antes da garantia.

Números de fechamento (smokes, 24 partidas até T200 — observação, não baseline): Ascensão mediana T48,5,
Convergência T114; Dragão anunciado 24/24 (18 pela garantia, anúncio mediano T83 = Ascensão+35), 13 derrotados,
11 devastações, recompensas 2.275 Ouro / 1.040 Mana no total (máximo individual 175); nenhuma civ não-alvo aceitou a
caçada (distância 28, sem força 21, guerra 18); Relicário anunciado 22/24 (2 superados), 3 reivindicados, 19
expirados; Exército Supremo público 35×, 2ª Manifestação 8×; 122 capturas qualificadas; 6 vitórias por Supremacia e 6
por Transcendência. Resumo em `docs/balance/F33D3_smoke_summary.json`.

## F33D Post-Implementation Review

Revisão de corretude da camada inteira (D1–D3) antes da baseline F33E: código real, não só documentos. Critério:
algo que invalidaria 48+ partidas automáticas, a comparação agregada com a F33B ou o tuning seguinte. Nenhum
número de balanceamento mudou; os sinais de participação, garantia, expiração e densidade de pressão continuam
intocados como perguntas da F33E.

**Ordem canônica da rodada global** (`GameManager._finish_turn`, uma vez por rodada, depois de humano + IAs +
monstros): expiração de Técnicas/feitiços → zonas ambientais → Ritual Final → fog → `maybe_spawn_dragon` →
`maybe_start_reliquary` → `WorldEventManager.advance_turn` (eventos ativos; conclusão grava o agendador) →
`advance_world_phase` (na virada para a Convergência, `_close_ascension_events` anuncia o Dragão pendente ou o
supersede e supersede o Relicário não anunciado; Guardiões na entrada da Ascensão) →
`PublicVictoryMilestones.evaluate_round` → `check_victories`. Despertar das ameaças regionais e reforço dos covis
rodam antes, no tick de covis (`process_monster_lairs`). Um evento que conclui numa rodada libera a vaga de grande
evento para a virada de era da MESMA rodada.

**Relicário — ordem de controle × expiração:** na rodada final ativa a posse é avaliada ANTES da expiração. Uma
civ que já tinha 1/2 e mantém o local chega a 2/2 e reivindica; uma civ que só chega a 1/2 na rodada final expira
com o evento (determinístico, sem "expira ganhando").

| Achado | Classe | Situação |
|---|---|---|
| R1 — Relicário anunciado antes do Dragão só respeitava Ascensão+35; a Convergência pode chegar antes (piso T100). Com Ascensão em T69–70, Convergência exatamente no piso e posse reivindicada na última rodada ativa (ou vencedor humano adiando a escolha), o Relicário ainda estaria ativo na virada, e a exclusividade faria o Dragão ser SUPERSEDED — o Relicário teria anulado o Dragão da partida | P2 | **CORRIGIDO** — `WorldEventManager.dragon_guarantee_deadline()` = mín(Ascensão+35, `CONVERGENCE_FLOOR_TURN`); o Relicário antes do Dragão precisa terminar antes das DUAS garantias. Nunca observado nos 24 smokes; a correção só muda partidas com Ascensão ≥ T67 (1/24 smokes: F33B-014, Ascensão T70 — o Relicário agora espera o Dragão e é superado pela Convergência) |
| R2 — a perseguição do Dragão (`_choose_target_city`, prioridade 1) continuava numa cidade cujo dono caiu para uma cidade só; a regra "nunca mira civ de uma cidade" valia na seleção, não na perseguição | P2 | **CORRIGIDO** — perseguição só continua com dono elegível; senão reescolhe entre elegíveis; nenhum elegível → `no_target`. Raides nunca capturam nem destroem cidade (dano limitado à fração do HP atual), então o efeito antigo era assédio, não execução |
| R3 — marcador público do Relicário é filho direto do `HexGrid` e não era removido por `_clear_entities` (novo jogo, load, volta ao menu): o pilar dourado sobrevivia na partida seguinte e duplicava num load com Relicário | P1 (ciclo de vida, só visual) | **CORRIGIDO** — grupo `HexGrid.WORLD_EVENT_MARKER_GROUP`, limpo em `_clear_entities`. Não é salvo e o laboratório desmonta o grid por partida: a baseline headless nunca foi afetada |

Sem achado (verificado no código): revalidação da fila capturada (único caminho de troca de dono é
`HexGrid.capture_city`, revalida depois de a cidade entrar no novo dono; PP inválido zerado sem reembolso;
Lendária/Manifestação/prédio/cópias/slots/City Level/Fortificação); distância 12 + massa de terra 120 +
fallback com aviso e contador, sem dependência do assento humano; era uma vez por rodada, um passo, sem
regressão e sem leitor de gameplay; Dragão ONCE_PER_GAME (load, restart via `setup_players`; só o override de
DEBUG ignora); fronteira de informação da IA (`V2AIWorldView`: covis só explorados, nível de cidade só o último
OBSERVADO — atualizado só por visão em `recompute_fog`/`capture`/`_scout_enemy_cities` —, marcos públicos só o fato,
eventos só local/região anunciados; `CitySite`/`CityDefense` com névoa; Dragão é `always_visible`); telemetria
nunca lida por decisão; ameaça regional (âncora = primeira capital real, capital capturada mantém dono conceitual e
teatro, sem ameaça nova; população 3 por covil fora do teto dos selvagens, órfãos voltam a selvagem sem respawn;
DORMANT sem reforço, AWAKE uma vez, RESOLVED permanente; recompensa do papel substitui a do tipo); Guardiões uma vez
na Ascensão, reforço zero; regra de Supremacia avaliada antes da troca de dono, empate, rival só de Cidade I,
recaptura reescreve o crédito pela mesma regra; imperativos derivados que caem no motivo canônico do runtime;
marcos uma vez por civ (chaves de texto consistentes no save), migração sem anúncio retroativo; pool do Dragão
(1–4 participantes, piso limitado, maiores restos, soma = pool, uma vez, chaves int após load); todas as fontes de
dano creditam o Dragão pelo mesmo caminho (`apply_direct_unit_damage`, Ataque da Cidade); Relicário (contagem
ativa começa quando os guardiões nascem, 10 avaliações, expiração limpa guardiões e marcador sem recompensa,
escolha humana/timeout/save; guardiões por `source_event_id`, fora do teto); cadeia de save 17–23 → 24 num único
desserializador com padrões, nada nasce nem é anunciado no load (ameaças desligadas até o bloco ser lido); reset
completo em `setup_players`/`end_match`; RNG dedicado por sistema; regras de mundo por índice de assento (só a
ESCOLHA da recompensa pergunta quem controla o assento); nada por frame; flags de teste (`min_target_cities`,
`regional_threats_on_new_match`, `ai_controls_human_seat`) não salvas, sem UI, restauradas pelos testes.

**Watchpoints (não corrigidos):**
- W1 — `V2AIWorldView.known_enemy_cities` atribui uma cidade lembrada ao DONO ATUAL real (semântica da Fase 24):
  uma troca de dono fora da vista é conhecida pela IA; `known_supremacy_targets` herda isso. Só a posse, nunca
  nível/prédios. Anterior à F33D; candidato a hardening.
- W2 — Dragão anunciado na virada grava `phase_at_start = ASCENSION` (a era muda depois, na mesma rodada);
  `convergence_edge` distingue o caso na telemetria.
- W3 — escolha do local do Relicário ~214 ms síncrona, uma vez por partida: pode aparecer como um engasgo de um
  frame no jogo com janela. Remédio trivial identificado (pré-computar coordenadas de melhoria e distância a covis
  em vez de varrer cidades/covis por tile); fica para o hardening, sem otimização ampla aqui.
- W4 — save ≤ v21 com Dragão já concluído pode ter outro Dragão (concluídos antes do v22 não são inferidos;
  documentado na D1).
- Balanceamento para a F33E (não tocados): nenhuma participação não-alvo no Dragão; 18/24 Dragões na garantia;
  duração mediana 37; 19/22 Relicários expirados; 59/96 ameaças regionais vivas no T100; descoberta→limpeza mediana
  46; 58/92 civs entraram na primeira guerra com a ameaça viva; 838/1577 rodadas da Ascensão com as quatro
  pressões; vitória mediana T170 (smoke, não baseline).

**Validação da revisão:** +5 testes em `test/unit/test_phase33d_review.gd` (o de R1 falha sem a correção);
suíte completa 3546/3546, 175 scripts, 372.490 asserts (antes 3541/174/372.473); reexecução dos smokes D3 até T200: 24/24 sem erro; 23 idênticas aos registros pré-revisão; só F33B-014 mudou (efeito de R1: TIMEOUT T200 → Supremacia T197), com reexecução idêntica (determinismo); R2 não foi acionada em nenhum smoke.

**CLEARED AFTER FIXES — FIXES APPLIED AND VERIFIED.**

---

## 1. Problem Statement

### Evidência objetiva (F33B + survey desta etapa)

| Sinal | Valor | Leitura |
|---|---|---|
| Primeira produção da IA | T17 (15 turnos de capital ociosa) | abertura sem decisão |
| Cidade ociosa | 19% dos city-turns; 24.664 de 27.394 com opção disponível | a IA não vê razão para produzir |
| Primeira unidade de combate × primeira guerra da civ | T53 × T68; lag mediano **18 turnos** (p75 41) | unidades existem antes de ter uso |
| Tokens relevantes | 5 no T100, 11 no T200 | exército é tardio e pequeno |
| Covil mais próximo da capital | mediana ~11 tiles, mínimo **1**, máximo **39** | ameaça inicial é loteria |
| Capitais sem covil a ≤ 10 / ≤ 15 tiles | **99/192 (52%)** / 49/192 (26%) | metade dos reinos não tem ameaça local |
| Covis no mapa grande | 7–16 (mediana ~12; ~10 no continente Principal); teto global de 5 vivos por tipo | reforço de covil é estrangulado pelo teto global |
| Quem limpa covis | **só o humano** (`SelectionManager` → `CombatResolver.resolve_lair_attack`) | a IA nunca resolve uma ameaça local |
| Dragão | gatilho ≥ T30, 2%/turno; 1º disparo mediano **T61** (p25 40, p75 92); dispara 4–6× em T30–240 | chega cedo ou tarde por sorte, e **repete** |
| Guerras | 693; capturas por guerra mediana 0; 71 `possible_stalemate` | guerra existe, mas é rasa |
| Vitória | mediana T200; 24/48 TIMEOUT no T240 | a cauda é o problema de pacing |
| Assento 0 (centro) | 14/48 eliminações, 5 antes do T60 | ver causa-raiz em "Bug Register": capitais a 1–8 tiles |

### Percepção humana (playtest do desenvolvedor)

"Produzi unidades porque sei que o jogo possui guerra, não porque o mundo naquele momento me deu uma razão."
Early: explorar/pesquisar/produzir sem ameaça; midgame: monstros interessantes quando aparecem, mas por sorte;
late: guerra, capstones e vitória dão finalmente propósito aos sistemas.

### Conclusão

As duas fontes concordam em três pontos independentes: (1) a ameaça inicial depende da posição do covil mais próximo
(52% dos reinos não têm nenhuma a 10 tiles); (2) as primeiras unidades esperam em média 18 turnos por um uso; (3) o
único "evento" do midgame chega em momento aleatório e pode repetir. Reduzir custos não muda nenhum desses três.
O problema é **ausência de razões do mundo**, não falta de sistemas.

## 2. Design Goals

1. Toda capital tem, de forma justa e previsível na estrutura, **uma ameaça regional** que dá uso às primeiras tropas.
2. A partida muda de escala em **três eras globais** observáveis no mundo, disparadas pelo estado real da partida.
3. O midgame tem **pelo menos uma grande razão para mover forças** que não depende de sorte de posição.
4. O endgame mostra **o próximo passo real** da estratégia e **quem está perto de vencer**, sem regra nova.
5. A IA reage aos mesmos acontecimentos pelos mesmos sinais, sem onisciência e sem uma segunda IA.
6. Nada disso alonga a partida: mais interação **dentro** do mesmo número de turnos.
7. Tudo medível na próxima baseline (engagement density), sem índice sintético de diversão.

## 3. Non-Goals

- Não copiar a camada administrativa do Civilization (população, felicidade, religião, governadores, turismo, distritos,
  rotas comerciais).
- Não adicionar economia nova, moeda de missão, nem nova condição de vitória.
- Não adicionar diplomacia profunda (alianças, tributos, comércio).
- Não preencher os continentes Vulcânico e de Cristal.
- Não implementar multiplayer nem networking.
- Não rebalancear (custos, rendimentos, pesos de IA) nesta camada — isso é F33E, depois de medir.
- Não criar quest log de checklist ("produza 3 Guardas", "construa 2 Academias").

## 4. World Phase Model

| Modelo | Prós | Contras |
|---|---|---|
| 2 fases (antes/depois do contato) | simples | junta expansão e endgame; o midgame (T45–T110, onde está o "esperando minha estratégia") fica sem forma |
| **3 fases** | casa com os três arcos medidos: local (T1–45), regional (T45–112), decisivo (T112+) | exige 2 transições robustas |
| 4 fases (dividir o midgame) | granularidade | a F33B não mostra ruptura dentro de T45–112; 4ª era vira texto decorativo |

**Decisão: 3 eras globais**, com orientação estratégica individual por civilização.

| Interno | Nome no jogo | Significado | O que muda no mundo |
|---|---|---|---|
| `FOUNDATION` | **Era do Despertar** | conhecer e assegurar a terra onde o reino nasceu | ameaças **regionais** ativas (uma por capital); nenhum evento mundial maior |
| `ASCENSION` | **Era da Ascensão** | transformar o assentamento em potência regional | Guardiões territoriais (Troll) passam a disputar recursos; **o Dragão** e (se no escopo) o **Relicário** ficam elegíveis; covis selvagens ficam mais ativos |
| `CONVERGENCE` | **Era da Convergência** | converter poder em vitória | nenhum evento maior novo; alertas públicos de pressão de vitória; imperativos estratégicos em destaque |

A era governa **o ritmo do mundo** (ameaças, eventos, prioridade das notificações). Não dá bônus de dano/Ouro, não
bloqueia unidade nem pesquisa: unlocks continuam vindo só de pesquisa e cidade.

## 5. Phase Transition Rules

Avaliadas **uma vez por rodada**, no fim do turno (junto de `WorldEventManager.advance_turn`, antes de
`check_victories`). "Civs ativas" = não eliminadas. Nunca por frame.

| Transição | Piso | Condição (maioria real do mundo) | Fallback | Projeção sobre a F33B |
|---|---|---|---|---|
| Despertar → Ascensão | T35 | **2 civs ativas com ≥ 2 cidades** | T70 | mediana **T45** [37–47], máx 50, fallback 0/48 |
| Ascensão → Convergência | T100 | **2 civs ativas com o 1º N9** (qualquer árvore) **ou** 1 civ com capstone de vitória | T150 | mediana **T112** [106–115], máx 127, fallback 0/48 |

- "2 civs" e não "a primeira": uma civ adiantada não arrasta o mundo; duas já indicam mudança de escala.
  Com só 2 civs vivas, a regra vira "todas as ativas".
- O capstone (Exército Supremo/Transcendência) acelera a Convergência porque alguém já pode vencer — é a exceção
  deliberada ao §19, justificada por ser pressão de vitória real e pública (seção 9).
- Piso impede fases curtas demais; fallback impede era eterna. O fallback usa **a mesma mensagem** da transição
  normal ("os ecos se espalham pelo continente"): o jogador nunca vê "contador chegou a 70".
- Bands provisórias para validar (não asserts): Ascensão entre T38–T60 em ≥ 80% das partidas; Convergência entre
  T100–T135. As projeções mudam depois da F33D (ameaças regionais alteram a abertura) — a F33E remede.
- Sem regressão de era (eliminações nunca devolvem o mundo à era anterior).

**Orientação individual** (não é era pessoal): cada civilização atrasada recebe uma linha de orientação derivada do
próprio estado ("Sua capital está exposta: resolva a ameaça regional", "Reconstrua: você não tem segunda cidade") —
ver seção 10, categoria Orientação.

## 6. Early Game Threat Model — Ameaça Regional

### Colocação (world generation, determinística)

- Depois que os tiles iniciais são reservados (`GameManager._spawn_starting_forces`, onde já existe `claimed_starts`),
  cada assento recebe **exatamente uma Ameaça Regional**: um covil no anel **7–10 tiles** da sua capital, em terra do
  continente Principal, fora da visão inicial, preferindo bioma do tipo e caminho terrestre existente
  (`HexGrid.compute_path`, componentes já cacheados).
- **Reuso primeiro**: se um covil selvagem Goblin/Esqueleto já cai no anel, ele é promovido a regional; senão um é
  colocado. Covis selvagens a **< 7 tiles** de qualquer capital são removidos/deslocados (nada adjacente à capital).
- RNG próprio (`map_seed + 8000`), ordem de assentos fixa → mesma seed, mesmos covis.

### Threat budget (interno, não exposto)

Cada região inicial recebe o mesmo orçamento: 1 covil regional, distância 7–10, arquétipo early (Goblin ou Esqueleto),
população máxima 3 (chefe + 2), nenhum outro covil a < 7 tiles. O orçamento **não soma** ao risco geográfico: a
correção da distância mínima entre capitais (Bug Register #2) vem antes, e o covil regional nunca fica no corredor
entre duas capitais a menos de 16 tiles uma da outra (fica do lado oposto).

### Ativação (dormente → desperto)

| Estado | Quando | Comportamento |
|---|---|---|
| Dormente | geração → T8 | covil existe no mapa (descoberto por exploração normal); chefe parado; sem reforço, sem saque |
| Desperto | T8–T12 (determinístico por assento) | reforço até a população regional; Goblin como Saqueador (raio 4) / Esqueleto como Saqueador preso à região (nunca Invasor de mapa inteiro na Era do Despertar) |
| Pressão | enquanto vivo | saque de melhoria (`PILLAGE_DURATION_TURNS`, perda de Ouro existente), ataque a unidade isolada, aproximação da cidade sem capturá-la |
| Resolvido | estrutura destruída | **permanente**: nunca respawna nem é substituído na região; mini-arco concluído |

Garantias: a ameaça não pode tomar cidade (regra já existente: monstro nunca captura), não nasce adjacente e só
desperta depois de o jogador ter 8+ turnos para produzir a primeira resposta (hoje a IA só produz no T17 e a primeira
tropa sai em mediana no T53, mínimo T30 — ver interação com a abertura na seção 16).

### Resposta possível sem força bruta

Destruir o covil (resposta completa), **ou** conviver: Muralhas I e guarnição reduzem o saque (defesa de cidade da IA já
dispara em monstro adjacente), **ou** Construtor adiado para fora do raio. Ignorar custa Ouro e melhorias, nunca a
cidade.

### Aplicação a todas as civs

As quatro civilizações, humana ou IA, recebem a mesma estrutura. O mundo não sabe quem é humano.

## 7. Monster Roles

Nenhum mob novo: os cinco tipos atuais já cobrem os papéis.

| Tipo | Papel 1.0 | Onde | Comportamento (existente) | Ajuste de design |
|---|---|---|---|---|
| **Goblin** | ameaça regional principal (Despertar) | floresta/planície/campo | Saqueador raio 4; bando ≥ 2 vira Invasor | na função regional, promoção a Invasor só na Ascensão |
| **Esqueleto** | ameaça regional alternativa (deserto/tundra) | deserto/tundra | Invasor em grupos de 3 | na função regional, preso ao raio (sem marcha de mapa inteiro) até a Ascensão |
| **Troll** | **Guardião territorial** (Ascensão) | montanha/taiga/tundra | Guardião raio 5, forte (atk 6, HP 20; chefe ×2,5 HP) | colocado junto a recursos de alto valor a 12–20 tiles das capitais: "quero aquele recurso, mas há um Troll" |
| Vivern | selvagem dos continentes especiais | Vulcânico/Cristal | Caçador | inalterado (pós-1.0) |
| Dragão de covil | selvagem raro do continente Vulcânico | lava | Caçador | inalterado (pós-1.0); distinto do Dragão-evento |

Goblin e Esqueleto não viram esponja de HP: o desafio é número, mobilidade, saque e chefe — exatamente o que já
existe. O teto global de 5 vivos por tipo não vale para covis regionais (população própria de 3 por covil), senão
quatro covis regionais de Goblin se estrangulam.

Escalada desejada: Despertar = inconveniente regional; Ascensão = problema estratégico (Troll guardando recurso,
Dragão, Relicário); Convergência = os outros reinos.

## 8. Midgame World Events

### Dragão (major threat da Ascensão)

**Auditoria do estado atual:**

| Pergunta | Hoje |
|---|---|
| Quando | a partir do T30, 2% por turno (`WorldEventTrigger`) — 1º disparo mediano T61, p25 40, p75 92, 1 mapa sem Dragão até T240 |
| Por que pode não aparecer | só pela sorte do gatilho |
| Repete? | **sim**: `maybe_spawn_dragon` só barra Dragão **ativo**; concluído, o gatilho volta a valer (4–6 disparos em T30–240 por mapa) |
| Proteção pós-resolução | **nenhuma** (sem flag salvo, sem teste) — o bug histórico continua possível |
| Fluxo | Dormente → Anunciado (região + civ-alvo) → Preparação 3 turnos (participação) → Ativo (Unit real, voa até o alvo, ataca cidades com splash) → Resolução (modal com ranking de dano) |
| Recompensa | por participante que causou dano: `25 + 300×fração` Ouro e `10 + 150×fração` Mana, uma vez (`rewards_applied`) |
| IA | sempre participa (`decide_world_event_participation`); só a civ-alvo entra em produção de emergência; `defend_against_dragon` intercepta |
| Event Center | `world_event_announced` publicado com título genérico (mensagem usa `get_class()`); resolução por modal bloqueante |

**Design 1.0:**
- **ONCE_PER_GAME.** Um Dragão por partida; resolvido (derrotado, saciado ou sumido) não volta.
- **Elegível só na Ascensão**, a partir de 10 turnos após a transição (mediana ~T55), com o gatilho existente; se não
  disparou até 35 turnos depois da Ascensão, dispara no turno seguinte (garantia de presença sem data fixa visível).
- **Alvo**: mantém a cascata atual, mas nunca uma civ com uma única cidade (evita execução da mais fraca).
- Papel: exige exército claramente maior que o necessário para o Goblin — prévia indireta do peso de uma Manifestação.
- Recompensa limitada (seção 11). Participação da IA passa a ser decisão (seção 12).

### Um evento competitivo localizado — "Relicário Desperto" (SHOULD HAVE)

Objetivo: criar **movimento** (contato, desvio de força, encontro) no meio da Ascensão sem depender de onde o Dragão
nasceu.

- Um sítio físico no continente Principal, escolhido para ter distâncias parecidas às **duas capitais ativas mais
  próximas** (minimiza a diferença entre elas; nunca dentro de território de ninguém).
- Reusa o FSM de `WorldEvent`: Anunciado (região pública) → Preparação (5 turnos, janela de deslocamento) → Ativo
  (guardiões reais spawnados com `spawn_monster_at`, tipo Esqueleto) → Resolução.
- Resolve quem **mantiver uma unidade no sítio por 2 rodadas seguidas sem hostil adjacente** depois de os guardiões
  caírem — múltiplas respostas: força, mobilidade (voo/Portal/infiltração), magia (dano/controle de zona).
- Recompensa para o primeiro que resolver; os outros vêem "resolvido por X" (sem "falhou").
- Ignorar é válido: o custo é o rival ganhar a recompensa.
- Uma instância por partida na Ascensão, nunca simultânea ao Dragão Ativo.

### Densidade

No máximo **1 objetivo mundial maior ativo** (Dragão ou Relicário) + as ameaças regionais e Guardiões restantes.

## 9. Endgame Strategic Imperatives

Nenhum catálogo novo de missões: o jogo existente assume. A camada só **expõe o próximo requisito real**,
derivado do runtime canônico (nada duplicado).

| Rota | Imperativo | Fonte |
|---|---|---|
| Supremacia | "Prove sua supremacia" + uma linha por rival: `Elenor — conquistar cidade desenvolvida` / `Clãs de Ferro — satisfeito` / `Clãs Primordiais — eliminado` | `V2VictoryConditions.military_supremacy_status` |
| Supremacia (alvo) | "Cidade que importa agora: X" — só cidades **conhecidas e visíveis** do rival pendente | `V2AIWorldView` / `known_enemy_cities` |
| Transcendência | lista ordenada: 2ª Escola N9 → Transcendência → Estrutura Ritual → 1ª/2ª Manifestação → 120 Mana → iniciar Ritual; o primeiro item não cumprido é o imperativo | `V2VictoryConditions.transcendence_status`, `V2TranscendenceSystem.start_unavailable_reason` |
| Dominação | "Restam N reinos" | `VictoryConditions.civilizations_remaining` |
| Pressão rival | "X está perto da vitória" (só o que for público, abaixo) | `public_rituals` + marcos públicos |

**O que é público (proposta):** Ritual iniciado (já é); **Exército Supremo concluído** e **segunda Manifestação
ativa** passam a ser anúncios públicos sem localização ("rumores"). Nada revela cidade, exército, recurso ou pesquisa
secreta além disso. É decisão de produto (seção 22).

## 10. Objective Taxonomy

| Categoria | O que é | Exemplo | Recompensa | Vive onde |
|---|---|---|---|---|
| **A. Orientação** | leitura do estágio da partida para a própria civ | "Explore os arredores da capital", "Você ainda não tem segunda cidade" | nenhuma | derivada do estado (nunca salva) |
| **B. Ameaça/Oportunidade do mundo** | existe algo físico no mapa | ameaça regional, Troll guardião, Dragão, Relicário | pequena, pela coisa resolvida | no próprio objeto (covil, evento) |
| **C. Imperativo estratégico** | próximo passo real da vitória | "Produza sua segunda Manifestação" | nenhuma | derivada do runtime de vitória |

Formato data-driven (catálogo, não código por objetivo):

```
id, category, phase_eligibility (tags), trigger, visibility (private|public|owner),
target (coord|entity|none), reward (resource ranges), completion, resolution_by_other,
expiration (none|phase_end|turns), ai_relevance (weight hint), public, repeat_policy
```

`repeat_policy`: `ONCE_PER_GAME` (Dragão, Relicário), `ONCE_PER_CIV` (ameaça regional), `PER_INSTANCE` (Guardião
Troll, um por covil), `DERIVED` (Orientação/Imperativos — recalculados, sem histórico). Nenhum objetivo "falha":
estados são `active`, `resolved`, `resolved_by_other`, `superseded` (a era mudou e a Orientação não se aplica mais).

**Anti-checklist:** B só existe se há algo físico no mapa; C só repete a regra; A é informativa e some sozinha.
Nenhum objetivo pede "construa/produza N de X".

## 11. Rewards & Anti-Snowball

Recursos existentes somente (Ouro, Mana, XP pela destruição, acesso a tile/recurso, informação). **Sem Conhecimento**
(a F33B mostra diferença de ~2× entre orientações; uma fonte extra amplificaria).

| Objetivo | Hoje | Faixa recomendada (F33E calibra) | Razão |
|---|---|---|---|
| Ameaça regional (covil) | Goblin 75 Ouro; Esqueleto 85 Ouro + 10 Mana; + 10–15 Ouro por monstro | **30–50 Ouro** + 0–10 Mana | caixa mediano no T30 é 48 e renda líquida 0–1/turno: 75 é ~1,5× o tesouro, decide a abertura; 30–50 ≈ um upgrade N3→N5 (24–32) ou meia Cidade II (30) |
| Guardião Troll | 100 Ouro + 35 por Troll | 60–90 Ouro + **acesso ao recurso guardado** | recompensa principal é o território |
| Dragão | 25 + 300×fração Ouro; 10 + 150×fração Mana | total **150–200 Ouro, 60–100 Mana**, piso por participante que causou dano | no T60–90 o caixa mediano é ~50; 325 Ouro para o maior causador de dano é snowball |
| Relicário | — | 60–120 Ouro **ou** 40–80 Mana (escolha do vencedor) + revelação de área | ordem de uma Cidade III em Ouro (70) |
| Orientação / Imperativos | — | nenhuma | direção, não pagamento |

Anti-snowball: recompensas únicas e limitadas por era; toda civ tem a **mesma** ameaça regional; o Relicário nasce
equidistante; o Dragão não mira a civ de uma cidade; nada escala com o tamanho do exército; MILITARY não ganha
recompensa exclusiva.

## 12. AI Integration

Sem `QuestAI`. Tudo entra como contexto de `V2StrategicAI`/`RivalAI`/`CityDefense`, lido por `V2AIWorldView`.

**O que a IA pode saber:**
- covis **descobertos** (tile já explorado pela civ) — novo campo da `V2AIWorldView`; hoje `get_lair_danger_at` lê
  todos os covis do mapa (Bug Register #4);
- a própria ameaça regional (está no próprio anel, mas só vira alvo quando descoberta);
- era global, eventos anunciados (região pública), Relicário anunciado, marcos públicos de vitória;
- nunca: covis não descobertos, guardiões fora da visão, pesquisa rival, localização de Manifestação não vista.

**Decisões (prioridades, não reflexos):**

| Situação | Regra de decisão |
|---|---|
| Ameaça regional descoberta, saque ou unidade atacada na região | produzir resposta mínima (1–2 tropas) se não houver guerra ativa com ameaça maior; limpar o covil quando o poder local ≥ `CityDefense.OVERMATCH` × poder do covil (reusa `unit_power`/`assess`) |
| Covil selvagem longe das cidades | ignorar (exploração continua desviando pelo perigo conhecido) |
| Troll guardando recurso desejado | atacar só com força ≥ OVERMATCH e sem guerra no mesmo teatro |
| Dragão anunciado | participar se: não está em guerra perdendo, tem ≥ N tropas livres, distância ≤ D; a civ-alvo sempre defende |
| Relicário anunciado | ir se distância, risco e rota de vitória permitem; MILITARY/BALANCED com exército livre tendem a ir; ARCANE pode enviar voador/conjurador |
| Rival com marco público de vitória | pressão de guerra existente (`RITUAL_WAR_PRESSURE`) estendida aos marcos públicos |

Capacidade nova necessária: a IA **atacar a estrutura do covil** (`resolve_lair_attack`), hoje exclusiva do humano.

## 13. UI / UX Integration

Workstream de UI permanece fechado. Superfícies existentes:

| Necessidade | Onde | Mudança |
|---|---|---|
| Era atual | rótulo de turno da `GlobalBar` | "T62 · Ascensão" |
| Mudança de era | `CriticalAlertPresenter` (novo tipo `world_phase_changed`, severidade IMPORTANT) + Event Center | título + 2–3 linhas: o que mudou no mundo, que decisão importa agora |
| Objetivos ativos | chips do `StrategicAlertPresenter` (já mostra guerra/Déficit/Ritual) | até 2 chips: "Ameaça regional", "Relicário 3T"/"Dragão" |
| Detalhe/histórico | Event Center, categoria `WORLD` já existente | eventos de objetivo com `focus_action` para o alvo; não vira quest log |
| Imperativos | `VictoryScreen`/`VictoryPresenter` (já lista requisitos por rota) | uma linha "Próximo passo" por rota |
| Pressão rival | Event Center + alerta crítico já usado para Ritual | anúncios públicos de marco |
| Covil/Guardião no mapa | `TileInspector` | estado (dormente/desperto) e recompensa |

Objetivos **não** são Attention Required e nunca bloqueiam End Turn. O modal bloqueante de resolução do Dragão vira
evento no Event Center + alerta, sem modal.

## 14. Save / Determinism / Future Multiplayer Compatibility

| Estado | Persistir? | Onde |
|---|---|---|
| Era atual, turno de entrada, histórico `{era, turno, causa}` | sim | bloco de `WorldEventManager.to_save_dict` |
| Covis regionais `{coord, kind, assento, turno_de_despertar}` | sim (colocados depois da geração, não recriáveis por `generate_map`) | seção do grid junto de `cleared_lair_coords` |
| Covis resolvidos | já persistido | `cleared_lair_coords` |
| Dragão/Relicário em curso, participantes, recompensas pagas | já coberto pelo padrão | `WorldEvent.to_save_dict` + `rewards_applied` |
| Contagem de eventos concluídos por tipo (ONCE_PER_GAME) | sim | `WorldEventManager` |
| Orientação, imperativos, chips | **não** (derivados) | — |

`SAVE_VERSION` sobe junto com a feature (regra da Bíblia), com fallback para saves antigos (sem era → recalcula pela
regra; sem covis regionais → nenhum).

Determinismo: colocação regional por `map_seed + 8000`; despertar por assento a partir da seed; gatilhos por
`WorldEventTrigger.trigger_rng`; sítio do Relicário por RNG de evento. Mesmo seed + mesmas decisões → mesmo mundo.

Multiplayer futuro: a era e os objetivos B vivem no **estado da partida** (autoridade única), objetivos A/C são
funções puras de `PlayerData`; nada checa `human_player` (mesmo princípio 5 do contrato de World Events). Nada de
networking agora.

## 15. Telemetry & Engagement Metrics

Acrescentar ao `BalanceTelemetry` (F33D) para a F33E:

| Métrica | Definição |
|---|---|
| `first_hostile_monster_contact` | primeiro turno com monstro visível a ≤ 6 tiles de uma cidade própria |
| `first_monster_attack` | primeiro combate (qualquer lado) contra/de monstro |
| `first_lair_discovered` / `first_lair_cleared` | covil em tile explorado / estrutura destruída pela civ |
| `regional_threat_{discovered,first_response,cleared}` | descoberta → primeira unidade própria a ≤ 3 do covil → destruição |
| `first_major_event`, `major_event_resolved` | por partida: anúncio e resolução de Dragão/Relicário |
| `first_player_contact` | primeira cidade/unidade rival vista |
| `first_war`, `first_pvp_combat`, `first_city_attack`, `first_capture` | já existem ou derivam dos sinais atuais |
| `objective_{issued,resolved,resolved_by_other,superseded}` | por objetivo B |
| `world_phase_turns` | turno de cada transição e causa (condição/fallback) |
| `units_without_purpose_lag` | 1ª unidade de combate produzida → 1º uso (combate, defesa de cidade, ataque a covil) |
| `inactivity_streak` | maior sequência de turnos sem interação significativa (abaixo) |
| `EMPTY_WAR` | guerra encerrada (paz/fim) com **0 combates entre o par**, 0 ataques a cidade e 0 capturas; `LOW_ACTIVITY_WAR`: ≤ 3 combates entre o par e nenhum ataque a cidade (exige contar `combat_engagement` por par — o sinal já traz os dois donos) |

**Interação significativa** (por civ, por turno): combate de qualquer tipo; morte de unidade própria; cidade fundada,
capturada ou perdida; covil descoberto ou limpo; saque sofrido; mudança de fase de evento que envolve a civ; pesquisa
N3/N5/N7/N9 ou capstone (não todo nó); conclusão de unidade N3+, Lendária, Manifestação, nível de cidade ou
fortificação; mudança diplomática; Ritual iniciado/avançado. Research ticks e prédios comuns não contam.

Bands provisórias de `inactivity_streak` máximo (a validar no playtest, nunca assert): Despertar ≤ 12, Ascensão ≤ 15,
Convergência ≤ 10. Métricas continuam interpretáveis; nenhum "fun score".

## 16. Interaction With F33B Bottlenecks

| Gargalo | Efeito esperado desta camada | Observação para F33E |
|---|---|---|
| Execução da Supremacia | **melhora parcial**: imperativo "cidade que importa agora" + pressão pública orientam humano e IA; não resolve cidades III+ inexistentes | a regra é decisão separada (seção 22 Q1); tuning de urgência militar ainda necessário |
| Estrutura Ritual/Manifestação | **melhora parcial**: imperativo explícito "converta pesquisa em infraestrutura ritual"; **risco de piorar** se objetivos pedirem projetos — por isso nenhum objetivo pede prédio | prioridade da Estrutura Ritual na IA continua candidata |
| Conhecimento MILITARY/ARCANE | **inalterado** (nenhuma recompensa em Conhecimento, de propósito) | continua eixo de tuning |
| Cidade ociosa | **melhora provável**: ameaça regional dá score positivo a tropas cedo | medir antes de mexer em limiares de score |
| Foco de vitória travado | **inalterado** pela camada; imperativos tornam o problema visível | "iniciar Ritual quando pronto" continua candidato |
| Abertura (T17) | **risco de piorar se nada mudar**: a ameaça desperta no T8–12 e a IA hoje só produz no T17 | a regra de resposta mínima da IA (seção 12) é parte da F33D; se a abertura continuar em T17, a F33E prioriza a abertura antes de qualquer outro tuning |
| Fila de cidades (33% em projetos) | **neutro por construção**: nenhum objetivo custa projeto de cidade; respostas são mapa/ação | — |
| Duração da partida | **não alonga**: ameaças regionais ocupam a abertura ociosa, eventos ocupam a Ascensão e param na Convergência | vitória mediana não deve subir; se subir, cortar o Relicário primeiro |

Dependência de ordem: não mudar o alvo de tokens da IA junto com as ameaças regionais; medir primeiro.

## 17. 1.0 Minimum Content Set

1. Sistema de 3 eras globais (regras da seção 5, rótulo, alerta de transição).
2. Uma ameaça regional por capital com Goblin/Esqueleto existentes (colocação justa, despertar, saque, resolução
   permanente, recompensa limitada).
3. Guardiões Troll em recursos de alto valor na Ascensão (colocação; comportamento existente).
4. Dragão ONCE_PER_GAME, elegível na Ascensão, recompensa limitada, participação decidida pela IA.
5. Imperativos estratégicos derivados (Supremacia, Transcendência, Dominação) na tela de Vitória + chip.
6. Anúncios públicos de pressão de vitória (Ritual — já existe; Exército Supremo; 2ª Manifestação — sujeito a Q2).
7. IA: covis conhecidos na WorldView, resposta à ameaça regional, ataque a estrutura de covil, participação avaliada.
8. Telemetria de engagement.
9. Correções do Bug Register #1–#4.
10. (SHOULD) Relicário Desperto — um evento competitivo.

Total de conteúdo novo: **0 mobs, 0 bosses, 1 evento opcional**. O resto é colocação, regra de tempo e exposição.

## 18. Post-1.0 Expansion Hooks

O catálogo de objetivos (seção 10) e o FSM de `WorldEvent` já comportam, sem conteúdo agora:
- eventos do continente Vulcânico (Vivern/Dragão de covil) e do continente de Cristal;
- novos chefes e ameaças regionais (tags de era no catálogo);
- eventos da lista de hipóteses da Bíblia (Invasão dos Mortos, Eclipse Arcano, Portal Demoníaco);
- contribuição diferenciada no Dragão (tropas/magia/Ouro) e diplomacia/comércio futuros.

## 19. Implementation Architecture

Sem `GameDirector`. Estado, dados e orquestração separados, dentro dos donos atuais.

| Peça | Tipo | Responsabilidade |
|---|---|---|
| `WorldPhaseRules` (novo, estático) | regras puras | avalia transição a partir de `GameManager.players` (dados, sem estado) |
| `WorldEventManager` (existente) | dono do estado do mundo | guarda era/histórico/contagem de eventos concluídos; chama `WorldPhaseRules` no fim do turno; emite `EventBus.world_phase_changed`; salva |
| `WorldEventTrigger` (existente) | gatilhos | Dragão/Relicário elegíveis por era, ONCE_PER_GAME |
| `RegionalThreatPlanner` (novo, estático) | colocação | escolhe/coloca o covil regional por assento no fim de `_spawn_starting_forces`; determinístico |
| `HexGrid` (existente) | covis | `lair_role` por coord (WILD/REGIONAL/GUARDIAN), população por papel, despertar por turno; persiste covis regionais |
| `MonsterAI` (existente) | comportamento | raio regional por papel/era (sem Invasor de mapa inteiro no Despertar) |
| `ReliquaryEvent` (novo, SHOULD) | `WorldEvent` concreto | sítio, guardiões, posse por 2 rodadas, recompensa |
| `WorldObjectiveCatalog` (novo, dados) | dados | definições da seção 10 |
| `StrategicImperatives` (novo, estático) | leitura derivada | próximo passo por rota, a partir de `V2VictoryConditions`/`V2TranscendenceSystem` |
| `V2AIWorldView` (existente) | fronteira de informação | `known_lairs`, objetivos públicos, marcos públicos |
| `V2StrategicAI`/`RivalAI`/`CityDefense` (existentes) | decisão | resposta regional, ataque a covil, participação avaliada |
| UI (existentes) | apresentação | seção 13 |
| `BalanceTelemetry` (existente) | medição | seção 15 |

Tudo por limite de turno ou sinal; nenhum `_process`; nada de varrer o mapa inteiro por turno (regras de era olham
4 `PlayerData`; covis são uma lista curta).

## 20. Implementation Phases (F33D)

| Etapa | Conteúdo | Pronta quando |
|---|---|---|
| **D1 — Correções + núcleo de era** | Bug Register #1–#4; `WorldPhaseRules` + estado/salvamento em `WorldEventManager`; rótulo, alerta, Event Center; telemetria de engagement | save/load estável, determinismo 4/4, smoke do laboratório com eras |
| **D2 — Ameaças regionais e Guardiões** | planner, papéis de covil, despertar, raio regional, recompensa, IA (WorldView, resposta, ataque a covil), Trolls em recursos, TileInspector | cada assento com 1 ameaça a 7–10 tiles em 48/48 mundos; IA limpa covis em partidas do laboratório |
| **D3 — Midgame e endgame** | Dragão ONCE_PER_GAME/era/recompensa/participação; imperativos + anúncios públicos; (SHOULD) Relicário | Dragão 1× por partida; imperativos batem com o runtime de vitória |

Depois: **F33E** (baseline 2 + tuning por evidência) e **F33F** (calibração humana).

Complexidade e risco:

| Componente | Complexidade | Risco principal |
|---|---|---|
| Correções #1–#4 | LOW | #2 muda posições iniciais → nova baseline obrigatória (já prevista) |
| Núcleo de era + UI + save | LOW–MEDIUM | projeção de transição mudar depois de D2 (remedir) |
| Ameaça regional + papéis de covil | MEDIUM | fairness (anel/corredor) e interação com a abertura da IA |
| IA contra covis | MEDIUM | IA desviando força demais cedo (medir antes de tunar) |
| Guardiões Troll | LOW | recurso inalcançável em mapas pobres de montanha (fallback: sem guardião) |
| Dragão 1.0 | LOW–MEDIUM | garantia de presença colidir com guerras |
| Imperativos + anúncios | LOW | vazamento de informação — só marcos listados como públicos |
| Relicário (SHOULD) | MEDIUM–HIGH | IA de deslocamento e fairness de distância |
| Telemetria | LOW | — |

## 21. Validation Plan

- **IA:** baseline 2 com o mesmo seed set F33B (48) + reservas; comparar: 1ª produção, cidade ociosa, lag de
  unidades sem propósito, `inactivity_streak` por era, EMPTY_WAR, datas de era, vitória mediana e TIMEOUT. Critério
  de "dead air diminuiu": `units_without_purpose_lag` e `inactivity_streak` do Despertar caem sem a vitória mediana subir.
- **Fairness:** survey (`--world-survey`) antes de jogar: ameaça regional 7–10 tiles em 48/48; nenhuma capital a
  < 12 tiles de outra; eliminações antes do T60 não concentradas em um assento.
- **Humano:** 3–5 partidas com `--human-timing`, e perguntas:
  1. Em que momento você ficou sem saber o que fazer?
  2. Houve trecho em que só apertou End Turn?
  3. Produziu unidades porque precisava ou porque podia?
  4. Alguma ameaça pareceu artificial? Alguma injusta?
  5. Algum objetivo pareceu checklist?
  6. Você sabia por que estava entrando no endgame?
  7. Sabia quem estava perto da vitória?
- **Determinismo:** mesma seed 4/4 e extensão idênticas; eras e covis regionais iguais entre execuções.
- **Save/load:** T60 no meio da Ascensão e com Dragão ativo; resultado idêntico à execução contínua.
- **Performance:** avaliação de era < 1 ms/turno; turno médio da baseline 2 dentro de +10% da F33B.

## 22. Open Questions / Decisions (produto)

1. **Regra da Supremacia** (27% dos rivais pendentes não têm Cidade III+ — hoje só eliminação resolve):

   | Opção | Regra | Mantém "guerra real"? | Resolve o estado impossível? | Risco |
   |---|---|---|---|---|
   | A | manter | sim | não | execução segue travada |
   | B | Cidade III+ se existir; senão a capital | sim | sim | dois textos de regra |
   | **C** | **a cidade mais desenvolvida do rival no momento da captura (empate: capital), ou eliminação** | sim | sim | rival pode "escolher" qual é a mais desenvolvida (ruído pequeno) |
   | D | capital original | sim | sim | ignora desenvolvimento; muda o sentido da vitória |

   Recomendação: **C** — uma frase, sempre satisfatível por guerra, preserva a qualificação no instante da captura
   (mesmo mecanismo de `v2_supremacy_captured_from`).
2. **Marcos públicos:** anunciar publicamente Exército Supremo concluído e 2ª Manifestação ativa (sem localização)?
   Recomendação: sim.
3. **Relicário no 1.0:** incluir (SHOULD, D3) ou adiar para pós-1.0? Recomendação: incluir se D1–D2 fecharem no
   orçamento; a baseline 2 decide se o midgame ainda tem dead air sem ele.
4. **Nomes das eras:** Despertar / Ascensão / Convergência (provisórios).
5. **Dragão:** ONCE_PER_GAME confirmado para 1.0?

## Bug Register

| # | Bug | Evidência | Classificação |
|---|---|---|---|
| 1 | Cidade capturada mantém a fila do dono anterior sem revalidar pesquisa/slot do novo dono (`HexGrid.capture_city` → `City.change_owner`) | leitura de código; 1 recusa fail-closed de Manifestação na F33B | **RESOLVED (D1)** — 7 testes (continua/limpa unidade, prédio, Lendária, Manifestação, sem transferência de PP, save/load) |
| 2 | Capitais sem distância mínima entre si: `WorldSetup.find_start_tile` só exclui o tile exato já reservado | survey: assentos 0 e 2 a 1–8 tiles em 7/48 mapas (F33B-004: 1 tile); 4 das 5 eliminações do assento 0 antes do T60 nesses mapas | **RESOLVED (D1)** — survey 48/48: 0 pares < 12, 0 violações |
| 3 | Dragão repete após resolução (`maybe_spawn_dragon` só barra Dragão ativo; sem flag salvo) | leitura de código; gatilho dispara 4–6× em T30–240 por mapa | **RESOLVED (D1)** — ONCE_PER_GAME, sobrevive ao save/load |
| 4 | Exploração da IA usa todos os covis do mapa (`HexGrid.get_lair_danger_at` via `StrategicAI.explore`), inclusive não descobertos | leitura de código | **RESOLVED (D1)** — exploração e escolha de local só usam covis descobertos |
| 5 | Evento mundial no Event Center usa `get_class()` na mensagem (mostra nome de classe do engine) | leitura de código | **RESOLVED (D1)** |
| 6 | `CitySite.build_context` (escolha de local da IA) ainda lê monstros móveis e cidades estrangeiras de todo o mapa, não só os vistos | leitura de código na D1 | **RESOLVED (D2)** — contexto da IA só com cidades conhecidas/visíveis, monstros visíveis e covis conhecidos; pré-legalidade pelo mesmo conhecimento; legalidade real no runtime (recusa marca o tile, sem revelar a causa) |
| 7 | `CityDefense._live_lair_near` (ameaça de cidade da IA) somava pressão de covil por todos os covis do mapa e pela população escondida | leitura de código na D2 | **RESOLVED (D2)** — com filtro de névoa, só covil conhecido pelo dono da cidade conta |
| 10 | Relicário antes do Dragão podia ocupar a virada para a Convergência (piso T100 antes de Ascensão+35) e fazer o Dragão ser superado | revisão F33D-R | **RESOLVED (F33D-R)** — `dragon_guarantee_deadline()` |
| 11 | Perseguição do Dragão ignorava a elegibilidade do dono (civ reduzida a uma cidade continuava alvo) | revisão F33D-R | **RESOLVED (F33D-R)** |
| 12 | Marcador do Relicário sobrevivia a novo jogo/load/menu (filho direto do `HexGrid`, fora de `_clear_entities`) | revisão F33D-R | **RESOLVED (F33D-R)** — `WORLD_EVENT_MARKER_GROUP` |
| 9 | Participação da IA no Dragão era sempre "sim" e não movia unidade nenhuma (só habilitava recompensa) | leitura de código na D3 | **RESOLVED (D3)** — decisão por informação pública (`V2StrategicAI.dragon_participation`); quem aceita desloca uma força pequena (`RivalAI.join_dragon_hunt`) |
| 8 | Capital podia nascer numa ilhota (F33B-014 assento 1: massa de terra de 17 tiles) — sem expansão por terra nem anel 7–10 possível | survey D2 (191/192) | **RESOLVED (D2)** — `WorldSetup.MIN_START_LANDMASS = 120` (mapas menores: tiles/32); 5 capitais (todas do assento 1) mudaram; menor massa de capital agora 350 tiles; distância mínima 12 e 0 violações preservadas |

## Cut Line

| MUST HAVE (1.0) | SHOULD HAVE IF CHEAP | POST-1.0 |
|---|---|---|
| 3 eras + transições + alerta + rótulo | Relicário Desperto | eventos Vulcânico/Cristal |
| Ameaça regional por capital (Goblin/Esqueleto) | "rumores" de marcos com mais detalhe | novos chefes/mobs |
| Guardiões Troll em recursos | Orientação individual além de 3–4 frases | segundo evento competitivo |
| Dragão ONCE_PER_GAME + era + recompensa limitada + IA avaliando | | contribuição diferenciada no Dragão |
| Imperativos + anúncios públicos | | diplomacia/comércio |
| IA: covis conhecidos, resposta, ataque a covil | | multiplayer |
| Telemetria de engagement | | |
| Bugs #1–#5 | | |

## Recommendation

**A. READY FOR F33D — STRATEGIC PACING & OBJECTIVES IMPLEMENTATION**, com duas condições:

1. Bugs #1 e #2 corrigidos na D1, antes de qualquer conteúdo novo, e nova baseline obrigatória (posições iniciais
   mudam).
2. Nenhum tuning numérico da F33B aplicado junto com esta camada: a F33E mede primeiro e só então tuna (abertura,
   Supremacia, Estrutura Ritual, Conhecimento, foco travado).

A camada de Strategic Pacing & Objectives está definida com escopo de 1.0 explícito, fundamentado na baseline F33B e
no playtest humano. O design estabelece quando e por que a partida muda de escala, como ameaças regionais dão
utilidade às primeiras forças, como eventos mundiais sustentam o midgame sem virar checklist, como o endgame expõe as
estratégias de vitória já existentes, como a IA reage sem onisciência e como medir se o dead air diminuiu. Nenhuma
regra, custo, IA, geração de mundo ou save foi alterado nesta etapa.
