# Aetherlands V3 — Implementação

Documento técnico do que foi de fato construído na V3. A direção canônica (o **porquê**) fica em
`docs/# Aetherlands V3 — Visão e Direção.md`; aqui só o **o quê** e o **como**. Documento vivo: cada
etapa acrescenta sua seção. Baseline anterior à V3: F33D + F33D-R (3546/3546 testes, SAVE_VERSION 24);
F33E/F33F adiadas porque a V3 altera gameplay o bastante para invalidar uma baseline final agora.

---

## V3 — Combat Ecology

**Revisão de 15/10/2026 — covis unificados:** a separação histórica abaixo entre ameaça regional e
origens ecológicas sem estrutura foi substituída por um registro/controlador único de covis, líderes,
reforços e trégua regional. As etapas abaixo permanecem como histórico; o contrato atual está em
[`UNIFIED_MONSTER_LAIRS.md`](UNIFIED_MONSTER_LAIRS.md). Save v27, compatível com v26 e anteriores.

Plano original: Etapa 1 Foundation → Etapa 2 BASIC deep dive → Etapa 3 INTERMEDIATE → Etapa 4 ADVANCED → Etapa 5
Review. **Superado por decisão de produto:** a Etapa 2 passou a ser "Monster Identity & Abilities + Opening
Corrections" (habilidades e comportamento das 12 espécies de uma vez); o escopo seguinte fica aberto ao product owner.

### Etapa 1 — Foundation

**Escopo:** roster-base completo (12 espécies em 3 tiers), população ecológica desde o T1 espalhada pelo
continente principal, atividade diferente por Era, reposição ponderada pela Era, placeholders visuais,
save/load (v25), determinismo, telemetria e survey. **Sem habilidades, sem habitats, sem tuning fino.**

#### Decisões de design registradas

- Roster **4/4/4**: BASIC Goblin/Esqueleto/Worg/Aranha Gigante · INTERMEDIATE Troll/Wyvern(Vivern)/
  Minotauro/Basilisco · ADVANCED Verme Colossal/Ancião Arbóreo/Devorador de Mana/Colmeia Micótica. O
  Dragão Ancião continua evento mundial, fora do orçamento ecológico.
- **Todos os tiers existem desde o T1.** A Era não é unlock: ela muda **atividade**, nunca existência.
- **Despertar:** BASIC é a pressão dominante (raides em cidades a até 12 tiles da âncora a partir do T10,
  saque de melhorias); INTERMEDIATE territorial (4–5); ADVANCED fortemente territorial (3–4).
- **Ascensão:** BASIC local (sem city-hunt, saque oportunista a 4); INTERMEDIATE dominante (patrulha 7,
  interesse 12); ADVANCED patrulha maior (4/6) sem city-hunt.
- **Convergência:** BASIC baixa pressão (3/4); INTERMEDIATE médio (5/6, objetivos locais); ADVANCED
  dominante neutro (patrulha 7, perseguição 9, interesse 12).
- **Placeholders aceitos** (primitivas); **skills adiadas** para as Etapas 2–4.
- Sem level scaling: nada escala com o poder do jogador.
- Monstros nunca capturam cidade (atacante neutro deixa a cidade em ≥ 1 HP — regra já existente em
  `CombatResolver.resolve_city_attack`).
- **Raide, não cerco** (decisão desta etapa, ver "Achado da sonda" abaixo): depois de golpear uma cidade/
  guarnição ou saquear uma melhoria, o monstro descansa `raid_rest_turns` (8) — volta para casa e só vigia
  o território. Pressão periódica em ondas, nunca um bloqueio permanente na porta da cidade.

#### Arquitetura

| Peça | Arquivo | Responsabilidade |
|---|---|---|
| Dados do bestiário | `scripts/data/MonsterEcologyData.gd` | tier explícito por espécie, tamanho de grupo, ganchos vazios (abilities/behavior/habitat/activity/population profile), constantes de colocação/reposição, pesos de reposição por Era, fórmula de alvo |
| Stats | `scripts/data/MonsterDatabase.gd` | 8 `KIND_DATA` novos (placeholder, `V3 COMBAT ECOLOGY PLACEHOLDER — TUNE LATER`), fora de `KINDS` (nunca sorteados pelos covis da seed) |
| Atividade por Era | `scripts/core/MonsterActivityProfile.gd` | tabela tier × era (patrol/chase/city/improvement/roam/raid_rest/city_from_turn), teto por espécie, peso de reposição, rótulo player-facing |
| Colocação | `scripts/core/MonsterEcologyPlanner.gd` | terra elegível, legalidade de tile, zona de segurança, espaçamento, folga de covil, memória de esvaziamento, amostragem de reposição fora de visão, cotas/round-robin por espécie, sorteio de tier pela Era |
| Runtime | `scripts/core/MonsterEcologySystem.gd` | registro de sítios, população inicial, alvos, esvaziamento + reposição por rodada, diretiva para a MonsterAI, telemetria (`EventBus.combat_ecology_event`), save/load, dev tools |
| Comportamento | `scripts/core/MonsterAI.gd` (`_take_ecology_turn`) | executa a diretiva dentro do loop normal da MonsterAI (sem pathfinding novo) |
| Visual | `scripts/units/MonsterPlaceholderVisuals.gd` | silhuetas provisórias das 8 espécies novas |
| Telemetria | `tools/balance/EcologyTelemetry.gd` | seção `combat_ecology` do registro de partida + agregado (`ecology_summary.json`) |
| Survey | `tools/balance/BalanceWorldSurvey.gd` | `survey_ecology`/`summarize_ecology` (`world_survey_ecology.json`) |

**Sítio ecológico** = grupo ancorado `{id, species, anchor, lair, created_turn, source}`. `lair` é o covil
da seed adotado (estrutura + papel `HexGrid.LAIR_ROLE_ECOLOGY`) ou `NO_LAIR` (âncora territorial pura —
sem estrutura e sem recompensa de estrutura, então a ecologia não injeta ouro de covil no mapa). O monstro
aponta para o sítio por `Unit.ecology_site_id`. O tier é sempre derivado da espécie (não é salvo).

**Tier ≠ papel.** Covis regionais e Guardiões Troll (e, até 2026-10-12, os guardiões do Relicário, removido) mantêm o papel e o
comportamento próprios; o tier é da espécie (Goblin regional = BASIC + REGIONAL; Troll Guardião =
INTERMEDIATE + GUARDIAN; Esqueleto do Relicário = BASIC + EVENT). A diretiva ecológica só vale para
`ecology_site_id >= 0`.

**Integração com covis existentes.** Na partida nova, depois das capitais e das ameaças regionais do setup,
cada covil selvagem da seed no continente principal (Goblin/Esqueleto/Troll/Vivern) que respeita a zona de
segurança/espaçamento do tier e cabe no alvo é **adotado** (papel ECOLOGY, chefe legado + complemento até o
grupo); o resto é removido (partida nova, nada tocado). Covil adotado não usa o reforço legado nem vira
Invasor. Covis fora do continente principal e o covil de Dragão ficam intocados.

**Ordem no setup** (`GameManager._spawn_starting_forces`): mapa → capitais/tiles iniciais → ameaças
regionais do setup → `MonsterEcologySystem.populate_new_match` → primeiro turno. Âncoras de fairness =
capital da ameaça regional / primeira cidade / Colonizador inicial (humano antes de fundar).

**Rodada global** (`HexGrid.process_monster_lairs`, uma vez por rodada, antes do reforço dos covis e da
MonsterAI): conta membros vivos por sítio (uma varredura das unidades neutras), esvazia sítios sem
membros (vira memória regional), e, a cada `REFILL_INTERVAL` (2) rodadas, repõe **no máximo um** sítio.

#### Colocação

- Terra elegível: zona MAIN do mapa padrão, terreno que não bloqueia unidade terrestre, massa de terra
  ≥ 40, sem recurso. Tile de spawn também sem unidade/cidade/território/construção/covil/portal/marcador de
  evento.
- Alvos por tier: `target = round(eligible / TILES_PER_SITE)` com `TILES_PER_SITE` = 95/190/380, teto
  32/16/8 e piso 24/12/6 quando `eligible ≥ 2000` (mapa padrão). Mapas menores escalam abaixo do piso.
- Zona de segurança (setup **e** reposição): BASIC ≥ 7, INTERMEDIATE ≥ 10, ADVANCED ≥ 14 de toda âncora
  de capital. Espaçamento entre sítios: 4/6/8 (par usa o maior); folga ≥ 4 de qualquer covil.
- Ordem ADVANCED → INTERMEDIATE → BASIC; dentro do tier, cotas ≈ uniformes (resto por rotação sorteada) e
  fila round-robin (toda espécie ganha a primeira vaga antes de qualquer uma ganhar a segunda); candidatos
  = terra elegível embaralhada pelo RNG da ecologia (amostra de Poisson-disk por espaçamento).
- Grupo: BASIC 2, INTERMEDIATE 1, ADVANCED 1 (âncora + vizinhos legais em ordem estável).

#### Reposição

- Déficit por tier = alvo − sítios vivos. Tier sorteado pelos pesos da Era **entre os tiers com déficit**
  (Despertar 60/30/10, Ascensão 30/50/20, Convergência 15/35/50); espécie uniforme dentro do tier.
- Âncora por amostragem (96 tentativas) da terra elegível: fora da visão atual de **todas** as civs, a ≥ 2
  de qualquer unidade/cidade de civ, zona de segurança do tier, espaçamento, e fora do raio 8 de qualquer
  sítio esvaziado nas últimas 20 rodadas. Sem amostra válida → tenta de novo na rodada seguinte.
- Nunca respawn no tile da morte, nunca no mesmo lugar logo depois de limpo, nunca ondas infinitas.

#### Determinismo

RNG próprio `map_seed + 9300` (colocação, reposição e ronda), estado salvo como string. Não consome RNG
global, `monster_turn_rng`, RNG do planner regional, Dragão, Relicário, combate ou IA. Varreduras em ordem
de coordenada; alvos por distância com desempate por coordenada.

#### Persistência (SAVE_VERSION 24 → 25)

- Bloco `combat_ecology`: `enabled`, `sites`, `next_site_id`, `targets`, `eligible_count`, `depleted`,
  `next_refill_turn`, `rng_seed`/`rng_state`, `migrated`. Por monstro: `ecology_site`, `ecology_rest`.
  Papel ECOLOGY dos covis adotados viaja no `lair_state` existente.
- **Save v24:** carrega com a ecologia ligada e **vazia** — nenhum spawn dentro do deserialize; alvos
  calculados na primeira fronteira de rodada; a reposição normal (1 sítio / 2 rodadas, fora de visão)
  começa depois dela. Monstros existentes preservados como estavam.
- Partida nova reseta registro, contagens, sítios, relógio, estado de atividade e RNG
  (`WorldEventManager.reset_for_new_match` → `MonsterEcologySystem.reset`).

#### Flag de teste

`GameManager.combat_ecology_on_new_match` (default **true**, nunca salva, sem UI). Desligada, a partida
nova não recebe ecologia e um save ≤ v24 não liga a reposição. Só fixtures que dependem do mapa sem
monstros a desligam, restaurando no `after_each`.

#### Comandos

```
godot --headless --path . res://tools/balance/BalanceLab.tscn -- --world-survey --matches=0-47 --run=v3e1
godot --headless --path . res://tools/balance/BalanceLab.tscn -- --matches=0-11 --cap=160 --run=v3e1 --tag=smoke
godot --headless --path . res://tools/balance/BalanceLab.tscn -- --report --run=v3e1 --tag=smoke --cap=160
```

#### Achado da sonda (corrigido nesta etapa)

A primeira versão fazia o BASIC do Despertar marchar e **ficar** na porta da cidade: numa partida de 60 turnos,
240 golpes em cidade no Despertar e 244 vezes uma cidade deixada em 1 HP desde o T3 (cerco permanente, regeneração
suspensa pelo sítio). Corrigido com **raide + descanso** (`raid_rest_turns` 8) e **abertura** (`city_from_turn` 10
no Despertar para BASIC). Mesma seed depois da correção: ~41 golpes em cidade por partida no Despertar.

#### Resultados (números medidos — Etapa 1 é fundação, nada disto é conclusão de balanceamento)

**World survey (48 mundos, mapa padrão 320×84):** worldgen 48/48; 4 capitais válidas 48/48 (0 violações de
distância inicial, menor par 12); ameaça regional 192/192 no anel 7–10; colocação sem erro nem déficit.
Terra elegível 2.470–3.093 (mediana 2.777). Sítios BASIC 26–32 (mediana 29), INTERMEDIATE 13–16 (15),
ADVANCED 7–8 (7); unidades 72–88 (mediana 80: BASIC 58, INTERMEDIATE 15, ADVANCED 7). Cobertura: as 12
espécies em 48/48 mundos (por espécie: BASIC 11–16 unidades, INTERMEDIATE 3–5, ADVANCED 1–2). Covis legados
adotados 5–10 por mundo (mediana 8), removidos 0–4. Violações da zona de segurança: **0**. Spawns inválidos
(água, cidade, território/construção, tile de covil, marcador de evento, fora do continente principal): **0**
(18 chefes legados adotados estão sobre tile com recurso — colocação antiga da seed, informativo). Hostil
ecológico mais próximo de cada capital: BASIC 7–21 (mediana 7), INTERMEDIATE 10–33 (11), ADVANCED 14–51 (17);
ADVANCED mínimo 14. Distribuição: maior metade (oeste/leste ou norte/sul pela mediana da terra) ≤ 64,8%;
quadrantes com mediana 17–23 unidades cada.

**Smokes (12 partidas 4-IA até T160, `--tag=smoke`):** 12/12 chegaram à Ascensão (T35–T70) e à Convergência
(T104–T124); 12/12 TIMEOUT no T160 (o cap é anterior às vitórias típicas — não é baseline).

| Era | BASIC ataques / golpes em cidade | INTERMEDIATE | ADVANCED |
|---|---|---|---|
| Despertar | 382 / 521 | 41 / 0 | 6 / 0 |
| Ascensão | 78 / 0 | 126 / 109 | 13 / 0 |
| Convergência | 173 / 0 | 130 / 0 | 127 / 45 |

Leitura: BASIC domina o Despertar; INTERMEDIATE cresce claramente na Ascensão (e é o único com city-hunt); ADVANCED
cresce claramente na Convergência (único com city-hunt; per capita ~7 monstros contra ~40 BASIC). Os 173 ataques
BASIC da Convergência são oportunistas (exércitos passando no território local).

- População (mediana unidades/sítios): T30 BASIC 55/28,5 · INT 14/14 · ADV 7/7; T50/T75/T100 estáveis
  (BASIC 53–54); T150 BASIC 36,5/20 · INT 14/14 · ADV 7/7. Nem extinção nem explosão; o BASIC tardio fica abaixo do
  alvo porque a reposição exige tile fora de toda visão e o mapa da Convergência está muito explorado/ocupado.
- Reposições: 178 BASIC, 131 INTERMEDIATE, 38 ADVANCED; sítios esvaziados 267 / 146 / 43.
- Mortes de monstros ecológicos: 567 / 147 / 43. Unidades de civ mortas por monstros ecológicos: 54 / 50 / 22.
- Golpes em cidade por assento: 190 / 117 / 181 / 187 (assento 0 = humano formal); ataques a unidades
  279 / 284 / 234 / 279 — sem viés de identidade.
- Combate monstro × civ: 4.748 (2.215 iniciados por monstros, 2.533 por civs, 1.514 desses contra a ecologia).
- Primeiro contato (mín/mediana): BASIC T3/T3,5 · INT T5/T13 · ADV T9/T85,5. Primeira morte de monstro:
  BASIC T5 · INT T61 · ADV T63. Primeira unidade de civ morta: BASIC T4 · INT T7 · ADV T12.
- Cidades deixadas em 1 HP por golpe ecológico: 142 ocorrências (nenhuma captura — impossível por regra).
- Eliminações: 4 (T96, T115, T116, T152; assentos 2, 2, 0, 2); **0 antes do T30 e 0 antes do T60**. Baseline
  F33B: 18 primeiras eliminações em 48 partidas, mediana T108, mínimo T54.
- Cidades por civ (mediana): T30 1 · T50 1,5 · T75 2 · T100 3 · T150 4 (baseline F33B: 1 · 2 · 3 · 3 · 5).
- D2: ameaças regionais vivas (mediana) T30 4 · T50 4 · T75 3,5 · T100 2,5; limpas 31/48 (mediana T93,
  T46–T159), 17 nunca limpas até o T160; guerras por partida 1–6.

**Performance:** colocação inicial 128–162 ms por mundo (survey; uma vez no setup). Rodada global:
esvaziamento/contagem 0,13 ms, avaliação de reposição 2,6 ms p50 / 5,0 ms máx (visibilidade das 4 civs, só a
cada 2 rodadas). MonsterAI: ~0,3 ms por ação de monstro ecológico (~20–25 ms síncronos por rodada para ~80 monstros;
no jogo real a fila é escalonada em frames por `stagger_ai_turns`). Primeiro turno com/sem ecologia: ~65 / ~56 ms.
Save +0–2 ms, load +0–50 ms (ruído; o load é dominado pelo generate_map de ~3 s). Nada por frame, nenhum scan
do mapa por monstro, nenhum pathfinding novo (só `compute_reachable` local já usado pela MonsterAI).

**Testes:** suíte completa 3580/3580, 177 scripts, 375.373 asserts (baseline 3546 / 175 / 372.490). Novos:
`test/unit/test_v3_ecology_foundation.gd` (28) e `test/unit/test_v3_ecology_world.gd` (6). Ajustados: SAVE_VERSION 25
(test_settings, test_v2_race_bonuses), invariante "nenhuma regra lê a era" passa a aceitar os dois arquivos da
ecologia (test_phase33d1_world_phase), e três fluxos de conteúdo de mapa fixo desligam a ecologia pela flag de
fixture (test_v2_phase18/19/20_main_flow).

#### Observações para as próximas etapas

- A regra legada "monstros param e voltam para casa durante o evento do Dragão" também recolhe a ecologia (à
  própria âncora) — preservada; reduz a atividade da Ascensão durante o Dragão. Decidir na Etapa 5.
- A visão §14 prevê BASIC perto das regiões iniciais e INTERMEDIATE/ADVANCED em regiões remotas/valiosas: a zona de
  segurança por tier já produz esse gradiente perto das capitais; a preferência por região valiosa/remota é habitat
  (Etapas 2–4). Sem conflito.

---

### Etapa 2 — Monster Identity & Abilities + Opening Corrections

**Escopo:** (A) pesquisa só depois da primeira cidade; (B) UX do Colonizador; (C) identidade mecânica das 12 espécies
(habilidade + comportamento específico). Placeholders continuam; habitat, biomas, Colonizador/Construtor como economia,
opções de setup e tuning F33E ficam fora.

#### A — Pesquisa só depois da primeira cidade

- Regra única `V2ResearchAccess.start_blocked_reason(player)`: sem cidade (`player.cities`, fonte canônica de posse)
  nenhuma pesquisa pode ser **iniciada nem trocada**. Aplicada nos dois caminhos que escolhem pesquisa — Research Board
  (humano) e `V2StrategicAI._choose_research` (IA) — e nas superfícies que convidam a escolher (widget global e
  Attention). `V2ResearchState` continua um modelo puro por civilização (não sabe de cidades).
- Board: árvore visível; nós pesquisáveis mostram o estado semântico **"Requer uma cidade"**; botão desabilitado com o
  motivo "Funde sua primeira cidade para iniciar uma pesquisa." (não finge pré-requisito). Widget: **"Pesquisa
  indisponível / Funde sua primeira cidade."**, sem o badge de erro. Attention: nenhum REQUIRED de pesquisa antes da
  cidade; depois dela, o "Escolher Pesquisa" normal. A barra global atualiza no `EventBus.city_founded`. Nada é
  selecionado automaticamente.
- Perder todas as cidades: a pesquisa ativa **não** é cancelada (o Conhecimento só vem de cidades, então ela só para
  de progredir); iniciar/trocar fica bloqueado; pausar continua permitido. Conhecimento, custos, árvore, slot único e
  timings intactos. Laboratório (capitais no T1) inalterado; a telemetria marca `first_research_selected` por civ
  (gate: nunca antes de `first_city_founded`).

#### B — Colonizador

- `UnitPresenter.commands_for`: o Colonizador mostra só **Mover** e **Fundar Cidade** (Fortificar/Explorar saem da
  faixa dele, pela capacidade `can_found_city`; as APIs continuam para as outras unidades).
- Fundar Cidade sempre visível: desabilitada com o motivo real (`CitySite.reason_text`; embarcado: "Desembarque para
  fundar uma cidade.") ou, no tile válido, **ação primária** (`UnitAbilityViewData.is_primary` → `AECommandButton` com a
  variação `PrimaryButton` do tema). Atalho novo **F** (não havia; a câmera usa WASD/QE/setas, Espaço = fim de turno),
  rótulo "⌂ Fundar Cidade [F]". Sem pulse (nenhuma animação nova; Reduced Motion não se aplica).

#### C — Arquitetura das habilidades

| Peça | Arquivo | Papel |
|---|---|---|
| Dados | `scripts/data/MonsterAbilityData.gd` | 13 habilidades: nome, descrição, passiva/ativa, recarga, alcance, alvo, quando a IA usa, parâmetros |
| Espécie | `MonsterEcologyData.SPECIES[kind].abilities` / `.behavior_profile` | ids das habilidades e identidade de comportamento (city_hunt, improvement_hunt, prey, avoid_bad_fights, group_raid, chase_bonus) |
| Runtime | `scripts/core/MonsterAbilitySystem.gd` | disponibilidade/recarga, alvo legítimo, execução, passivas por evento, Verme subterrâneo, telemetria |
| Status | `scripts/core/UnitStatusEffects.gd` | Veneno, Em Chamas, Abalado, Petrificação Parcial, Enraizado, Silenciado |
| Perigos | `scripts/core/MonsterHazardSystem.gd` | Raízes, infecção micótica, telegraph do Verme, marcadores, custo/evasão da IA |
| Decisão | `MonsterAI._take_ecology_turn` | uma IA genérica: tier = intensidade (perfil da era), espécie = identidade |

- **Reuso:** recargas em `unit.magic_cooldowns` e estados em `unit.magic_status` (os MESMOS dicionários de
  feitiços/Técnicas, já salvos; `SaveManager._sanitize_magic_dict` passou a aceitar os ids de criatura). Dano físico
  sempre por `CombatResolver.predict/resolve/apply_direct_unit_damage`; a Investida usa o `strike_multiplier` existente.
  Zonas ambientais (têm dono conjurador) e modificações de terreno (permanentes) não servem semanticamente para
  raízes/infecção — por isso `MonsterHazardSystem`, pequeno e fixo.
- **Só a ecologia usa habilidades.** Ameaça regional e Guardião Troll mantêm as regras D2/D3
  (exceção documentada: nenhuma habilidade nesses papéis; Esqueleto de evento/regional nunca multiplica).
- **Duração justa (humano × IA):** a IA joga antes dos monstros e o humano depois do `_finish_turn`. Um estado com
  duração k cobre exatamente k turnos PRÓPRIOS da vítima (expiração N+k para o humano, N+k+1 para a IA); dano
  periódico no início de cada um desses turnos (k ticks para os dois). Efeitos de movimento valem já no turno em curso.
- **Barreira Arcana** absorve dano no setter de Vida da unidade (qualquer fonte); a **Regeneração** usa a marca
  `took_damage_since_regen` do mesmo setter (dano real, nunca o load).

#### Status

| Estado | Efeito | Origem |
|---|---|---|
| Envenenado | 4% da Vida máx./turno (1–4), 3 turnos, renova sem acumular | Aranha Gigante |
| Em Chamas | 3% da Vida máx./turno (1–4), 2 turnos | Wyvern |
| Abalado | −1 Movimento, −15% Defesa, 1 turno | Minotauro (empurrão bloqueado) |
| Petrificação Parcial | Movimento 0, −20% Defesa, ainda ataca, 1 turno | Basilisco |
| Enraizado | Movimento 0 (ataca/conjura), 1 turno | Ancião Arbóreo |
| Silenciado | não conjura feitiço (move e ataca), 1 turno | Devorador de Mana |
| Barreira Arcana | escudo até 15% da Vida máx. do Devorador | Devorador de Mana |

Nunca em cidade, estrutura ou monstro. O TileInspector lista estados com a duração em turnos da vítima, e cada criatura
da ecologia com as próprias habilidades (nome, descrição curta, recarga atual).

#### As 12 espécies

| Espécie | Mecânica | Regras principais |
|---|---|---|
| Goblin | Saque Rápido | raide de cidade só no Despertar, máx. 2 Goblins por cidade, golpe rouba até 8 Ouro (nunca negativo), recua e descansa 8; saque de melhoria segue o existente (sem pagar duas vezes) |
| Esqueleto | Horda Crescente | grupo de 3 por sítio, fica junto na âncora; raide só com bando de 3+ a ≤ 2; não inicia luta claramente perdida (recua para o bando); ao matar unidade de civ ergue 1 Esqueleto num vizinho livre (1/sítio/rodada, máx. 6 vivos/sítio, nunca em cidade/unidade, sem cadeia) |
| Worg | Faro de Sangue | nunca caça cidade nem melhoria; prioriza alvo isolado (sem aliado colado) ou ferido (< 50%); +1 Movimento na perseguição e golpe no mesmo turno; +25% no primeiro golpe contra isolado; perseguição +2 |
| Aranha Gigante | Picada Venenosa | territorial, sem cidade; golpe que causa dano envenena |
| Troll | Regeneração Monstruosa | +10% da Vida no início do turno sem dano real desde o anterior; territorial (perseguição −2), sem cidade |
| Wyvern | Sopro Incendiário | recarga 3, alcance 2, cone (alvo + 2 tiles atrás), 90%/60%, Em Chamas; usa com 2+ atingidos ou 1 de alto valor; nunca contra unidade dentro de cidade; única intermediária com raide de cidade (Ascensão) |
| Minotauro | Investida | recarga 3, alvo a 2–4 em linha reta livre (não atravessa unidade/cidade/covil/terreno impassável), termina colado, 150%, empurra 1 tile ou deixa Abalado; sem cidade |
| Basilisco | Olhar Petrificante | recarga 4, alcance 2, o alvo de maior Ataque, não repete em quem já está petrificado; sem cidade |
| Verme Colossal | Escavar | recarga 4 (após emergir), alvo a ≤ 6 preferindo grupos; subterrâneo: fora de `units_by_coord` (não bloqueia, não é alvo), destino = posição do alvo no mergulho, **Rastro Subterrâneo** visível ali; emerge na fase dos monstros do turno seguinte no destino (ou no tile livre mais próximo, raio ≤ 2) sem redirecionar; 120% no impacto, 80% nos colados, empurrão legal |
| Ancião Arbóreo | Raízes do Mundo | recarga 4, até 4 tiles a ≤ 2 (ocupados primeiro), 3 rodadas, +2 custo de movimento só para civ, ocupante Enraizado; nunca altera o terreno-base |
| Devorador de Mana | Fome Arcana + Ruptura Etérea | aura 3: o primeiro feitiço inimigo da rodada RESOLVE e depois drena até 6 Mana (nunca negativo) → Barreira; Ruptura (recarga 4, alcance 2) só contra conjurador: 80% do Ataque mágico + Silenciado |
| Colmeia Micótica | Contaminação Micótica | 0–1 tile da âncora; infecção = âncora + raio 1, +1 tile/rodada (raio ≤ 2, ≤ 12); entrar/começar o turno: 3% da Vida (1–3) uma vez por turno (entrar nunca mata na hora); cura −50%; sem DoT em cidade; morta, decai metade numa rodada e o resto na seguinte |

#### Era × espécie

TIER define quando a classe é mais ativa (perfis da Etapa 1); a ESPÉCIE define como. Raide de cidade só para
`city_hunt` (Goblin/Esqueleto no Despertar, Wyvern na Ascensão), e o raide vem antes da caça para essas espécies;
nenhum ADVANCED caça cidade — na Convergência o raio de interesse (12) vira caça a presas especiais: grupos (Verme,
Wyvern) e conjuradores (Devorador). BASIC não persegue nem ataca presa que claramente o mataria. Habilidades nunca
escolhem alvo fora da zona legítima da era (sem path global).

#### Dragão

O Dragão **não pausa mais o ecossistema**: só o selvagem legado (covil da seed sem papel, fora da ecologia — hoje só
nos continentes especiais) mantém o recolhimento antigo. Ecologia, ameaça regional, Guardião e guardiões de evento
seguem agindo. O Dragão em si (world_event_managed) não mudou.

#### IA de civilização (mínimo)

Só perigo visível/conhecido: infecção conhecida pesa +3 na avaliação de rota (`compute_path`, nunca muro nem custo
real); raízes são custo real de movimento para civ; `MonsterHazardSystem.ai_evade` tira a unidade de IA de
infecção/raiz conhecida ou do tile de IMPACTO de um telegraph visível (sem inimigo colado) — reação deliberadamente
imperfeita (os vizinhos do impacto ainda levam 80%). Sítios sem estrutura continuam fora do planejamento de covis da
IA (integração posterior).

#### Save (25 → 26)

Por monstro: `ability_state`, `arcane_barrier`, `regen_interrupted`; sítio: `raised_turn`; bloco `combat_ecology`:
`hazards` (raízes, infecções, último dano de infecção por unidade) e `burrowed` (Vermes subterrâneos, recriados fora
do mapa de unidades). Estados/recargas nos dicionários existentes. O load nunca lança habilidade, ergue Esqueleto,
expande Colmeia, faz Verme emergir nem avança estado. Save 25 carrega sem perigos nem Verme subterrâneo.

#### Telemetria

`combat_ecology` ganhou `abilities_by_species` (usos, alvos atingidos, dano, estados, abates), `abilities` (por
habilidade: usos + todo campo numérico — gold_stolen, raised, healed, mana_drained, barrier, zones,
isolated_hunted, hunt_bonus_attack, outcome_knockback/blocked, stage_burrow/emerge...), `status_ticks` (ticks, dano,
abates por estado), `infection` (dano, ticks, abates, pico de tiles), `max_site_population`, `ai_evades`; o agregado
traz `research_gate` (civs e violações).

#### Ajustes feitos durante as sondas (antes dos smokes)

- A primeira versão quase apagou a pressão BASIC (7 golpes em cidade em 2 partidas): Goblins/Esqueletos gastavam o turno
  perseguindo qualquer unidade e os Esqueletos se espalhavam rondando, então o bando nunca se formava. Correções: para
  espécies `city_hunt` o raide disponível vem antes da caça; espécies de bando ficam juntas na âncora quando ociosas;
  BASIC não persegue presa que claramente o mataria; depois de um raide o monstro recua para a âncora.
- O Verme registrava 0 acertos: a IA saía do raio 1 inteiro do telegraph visível. A evasão passou a cobrir só o tile
  de impacto (os vizinhos ainda levam 80%).

#### Resultados (12 smokes 4-IA até T160, `--run=v3e2 --tag=smoke`; não é baseline)

12/12 chegaram à Ascensão e à Convergência; 12/12 TIMEOUT no T160.

| Era | BASIC ataques / golpes em cidade | INTERMEDIATE | ADVANCED |
|---|---|---|---|
| Despertar | 281 / 191 | 13 / 0 | 1 / 0 |
| Ascensão | 333 / 0 | 237 / 47 | 21 / 0 |
| Convergência | 228 / 0 | 74 / 0 | 90 / 0 |

| Espécie | Golpes em cidade | Ataques | Unid. de civ mortas | Mortes | Habilidade (usos · resultado) |
|---|---|---|---|---|---|
| Goblin | 44 | 110 | 8 | 132 | Saque Rápido 44 · 352 Ouro roubado |
| Esqueleto | 147 | 202 | 23 | 275 | Horda Crescente 22 erguidos · maior sítio 6 |
| Worg | 0 | 399 | 88 | 154 | Faro de Sangue: 533 caças a isolado, 389 golpes com bônus |
| Aranha Gigante | 0 | 131 | 14 | 143 | 117 envenenamentos · 167 ticks, 173 dano, 8 abates |
| Troll | 0 | 60 | 9 | 28 | 34 regenerações · 93 Vida |
| Wyvern | 47 | 109 | 43 | 33 | 42 sopros · 43 atingidos (~1,0/sopro) · 209 dano · Chamas 67 ticks, 12 abates |
| Minotauro | 0 | 59 | 36 | 32 | 71 investidas · 544 dano · 49 empurrões, 4 bloqueados (Abalado), 18 abates |
| Basilisco | 0 | 96 | 19 | 38 | 93 petrificações |
| Verme Colossal | 0 | 47 | 37 | 12 | 72 mergulhos / 69 emersões · 73 atingidos · 526 dano · 17 abates |
| Ancião Arbóreo | 0 | 22 | 3 | 6 | 24 lançamentos · 96 tiles de raiz · 24 enraizados |
| Devorador de Mana | 0 | 31 | 9 | 13 | Fome Arcana 10 · 60 Mana drenada · 12 de Barreira; Ruptura 6 · 4 silêncios, 2 abates |
| Colmeia Micótica | 0 | 12 | 1 | 10 | pico 31 tiles infectados (todas as Colmeias) · 22 ticks, 22 dano |

- **Pressão urbana:** cidades deixadas em 1 HP **12** (Etapa 1: 142). Golpes em cidade só de Goblin, Esqueleto e Wyvern.
- Unidades de civilização mortas por monstros ecológicos: 290 (BASIC 133, INTERMEDIATE 107, ADVANCED 50; por era
  BASIC/INTERMEDIATE/ADVANCED: Despertar 54/7/2, Ascensão 63/90/13, Convergência 16/10/35).
- Alvo por assento (0 = humano formal): golpes em cidade 61/36/81/60, ataques 344/359/263/312, unidades mortas
  70/80/56/84 — sem viés de identidade.
- Esqueleto: maior população de sítio 6 em todas as partidas (gate ≤ 6), 22 erguidos no total — sem crescimento runaway.
- Perigos conhecidos: 67 evasões da IA; 22 ticks de infecção no total (a IA não entra repetidamente em perigo conhecido).
- Gate de pesquisa: 48 civs, 0 primeiras pesquisas antes da primeira cidade.
- Eliminações: 7, todas entre T120 e T160 (guerras da Convergência); **0 antes do T30 e 0 antes do T60**; assentos
  0:3, 1:1, 2:2, 3:1.
- Cidades por civ (mediana): T30 1 · T50 2 · T75 2 · T100 3 · T150 3 (Etapa 1: 1 · 1,5 · 2 · 3 · 4; F33B: 1 · 2 · 3 ·
  3 · 5).
- População (mediana de unidades ecológicas): BASIC 63 (T30) → 60 (T100) → 49 (T150); INTERMEDIATE 14 → 13;
  ADVANCED 7 → 6. Nem extinção nem explosão.
- Primeiro contato (mediana): BASIC T3, INTERMEDIATE T26, ADVANCED T91.

**Determinismo:** 4 seeds (0, 3, 6, 9) × 2 execuções até T110 → seção `combat_ecology` idêntica (63–114 usos de
habilidade por partida). RNG da ecologia é o único canal sorteado nas decisões de monstro.

**Performance (mapa padrão real, sem concorrência):** rodada da ecologia (esvaziamento + perigos + emersões)
0,39 ms p50 / 0,53 ms máx; status + infecção de início de turno 0,06 ms por rodada; ação de monstro ecológico na
MonsterAI 0,54–0,77 ms (Etapa 1 ~0,3 ms), dos quais a seleção de habilidade ativa ~0,06 ms. Coleções fixas (≤ 4 raízes
por lançamento, ≤ 12 tiles por Colmeia, Vermes subterrâneos numa lista própria); nenhum scan de mapa por monstro,
nenhum pathfinding novo, nada por frame.

**World survey (48 mundos, depois da Etapa 2):** worldgen/capitais 48/48, ameaça regional 192/192, cobertura das 12
espécies 48/48, 0 violações de segurança, 0 spawns inválidos, maior metade 65,6%; unidades iniciais 78–96 (mediana 87:
BASIC 65 — o Esqueleto agora nasce em grupo de 3 —, INTERMEDIATE 15, ADVANCED 7).

**Testes:** suíte completa 3620/3620, 179 scripts, 376.078 asserts (Etapa 1: 3580 / 177 / 375.373). Novos:
`test_v3_e2_opening.gd` (8) e `test_v3_e2_abilities.gd` (32). Ajustados para as decisões desta etapa: os testes
de era da Etapa 1 (a intermediária do cenário passa a ser a Wyvern; ADVANCED não caça cidade; Dragão não recolhe a
ecologia; inspector lista as habilidades), SAVE_VERSION 26, Attention de pesquisa com cidade (`test_ui_attention`) e
três fluxos de conteúdo de layout fixo com a flag de fixture (`test_v2_guardian_flow`, `phase15`, `phase22`).

---

## Etapa 3 — World Readability, Aggro & Ecology Clarity

**Escopo:** tornar o mundo legível (foco/transparência por tile, minimapa), fixar o mundo padrão 1.0 (só o continente
principal), dar à ecologia aggro/perseguição/leash/retorno por tier×era, tornar as habilidades legíveis (telegraph →
execução → consequência) e separar Covil real × território ecológico × repopulação. Economia do Colonizador,
Construtor, monstros novos, habitat final, dificuldade/velocidade, balanceamento F33E/F33F e arte final ficam fora.

### Foco visual / transparência (`scripts/world/VisualFocusSystem.gd`, render-only)

- **Regra padrão (foco na unidade):** em todo tile com unidade VISÍVEL (qualquer dono: própria, rival, monstro), a
  decoração do tile (árvores, prop de recurso, gelo flutuante, cavalos) fica com alpha ≈ 0,35 e as estruturas do tile
  (prédio, cidade, covil, marcador de melhoria, obra) com alpha ≈ 0,45; a unidade fica opaca. Unidade escondida pela
  névoa não dispara nada (a transparência nunca revela quem está oculto).
- **Foco do inspetor** (`ContextRouter._sync_visual_focus`): Unidade = regra padrão; Cidade/**Estrutura** (aba nova
  quando uma unidade divide o tile com prédio/covil/melhoria/obra) = estrutura opaca e unidade semitransparente;
  Terreno escolhido no seletor = tudo em cima do tile semitransparente. Fechar o contexto volta à regra padrão.
- **Aba lembrada por tile (2026-10-12):** a aba que o jogador escolhe no seletor de ocupantes (Cidade / Unidade /
  Estrutura / Terreno) fica guardada POR TILE em `ContextRouter._remembered_tabs`; clicar de novo naquele tile —
  no mesmo turno ou turnos depois, tendo clicado em outros tiles no meio — abre nessa aba. Antes a escolha morava
  num único espaço (`_preferred_mode`) que qualquer clique em outro tile apagava, então a tropa guarnecida numa
  cidade voltava a abrir na Cidade a cada turno. Precedência no roteamento: pedido explícito do roteamento em curso
  (deep link `open_city`/`open_unit`, unidade recém-selecionada — vale uma vez) > aba lembrada > padrão (Cidade,
  senão Unidade, senão Terreno). Só o clique no seletor grava; deep link não grava nem apaga. Aba que deixou de
  existir no tile (a unidade saiu) é esquecida. Estado de interface: não vai para o save e é descartado quando o
  mapa muda (`map_seed`) ou em `reset()`.
- **Sem tocar em material compartilhado:** nós usam `GeometryInstance3D.transparency` por instância (valor original
  guardado e devolvido; rótulos Label3D/Sprite3D nunca são afetados). Decoração em MultiMesh: as instâncias do tile
  são escondidas (escala zero, transform guardado) e copiadas para um `MultiMeshInstance3D` pequeno próprio do tile,
  com o MESMO mesh/material (sem modificar) e `transparency` própria; ao sair, a instância original volta.
  `_clear_tree_props_at`/`_clear_tile_decor_at` pedem `release_props` ANTES de limpar (a árvore limpa nunca
  "ressuscita"); `_rebuild_props`, `ResourcePropsManager.rebuild` e `_clear_entities` chamam `reset()`.
- **Dirigido a evento:** mover/teleportar/criar/remover unidade, fundar cidade, posicionar prédio, melhoria, obra,
  covil, névoa e Verme mergulhar/emergir marcam sujo; o recálculo roda uma vez no fim do frame (`call_deferred`),
  O(unidades), nunca em `_process`. Fade 0,15 s; Reduced Motion = instantâneo. Sem tela (laboratório/testes headless)
  o sistema fica inerte. Nada é salvo (o load só reconstrói a partir do estado).
- **Obra com tropa em cima (2026-10-12):** unidade não bloqueia mais a escolha do tile de um prédio
  (`City.is_valid_building_tile` — aliada, inimiga ou monstro; a trava só existia no clique, já que qualquer unidade
  sempre pôde andar para cima de uma obra em andamento). O canteiro nasce semitransparente sob a tropa pela regra
  padrão acima, e o prédio pronto também. A barra de progresso da obra (Sprite3D sem teste de profundidade) sobe
  para cima dos marcadores da unidade (`Unit.markers_top_height()` + folga) enquanto a unidade está em foco no tile, e
  volta à altura do canteiro quando ela sai ou quando o inspetor foca a Estrutura (`_refresh_construction_bars`).
  A IA (`V2StrategicAI._building_site`) só usa tile ocupado quando não sobra tile livre — com tile livre a escolha é
  idêntica à anterior, então o baseline do laboratório de balanceamento não muda.
- **Cura na evolução (2026-10-12):** evoluir uma unidade (`V2UnitUpgrade.perform_upgrade`) recupera 30% da Vida
  MÁXIMA da forma nova (`UPGRADE_HEAL_FRACTION`), somada ao percentual que a troca de forma já preservava e
  limitada ao máximo. Fração do máximo — e não número fixo nem % da vida que falta — porque dá a mesma quantidade
  com a tropa quase morta ou quase cheia, acompanha os tiers e é o modelo de toda cura do jogo (guarnição 25%/turno,
  Fortificar 10%/turno, promoção 20%, Cura Sagrada 30%). 30% porque evoluir custa Ouro e a ação da unidade: vale
  mais que um turno na guarnição, sem ser cura completa. Respeita a penalidade de cura do tile (infecção micótica).
  O botão Evoluir mostra quanto cura agora; a IA recebe a mesma cura. **Muda o baseline do laboratório** (tropas
  evoluídas saem mais inteiras). Antes: "nunca cura de graça" (9/18 virava 12/24 e só). Testes:
  `test/unit/test_v2_unit_upgrade.gd`.
- **Eliminação ao perder a última cidade (2026-10-12):** uma civilização cuja ÚLTIMA cidade é capturada sai da
  partida na hora — `HexGrid.capture_city` → `eliminate_civilization`: todas as unidades que restavam são removidas
  (pelo `remove_unit` de sempre), `Diplomacy.dissolve_relations` encerra guerras, tréguas, propostas de paz e
  campanhas dela dos dois lados (sem trégua: não é um acordo de paz) e sai `EventBus.civilization_eliminated`
  (evento estruturado no histórico/toast). Vale para rivais e para o jogador; só dispara na captura — quem ainda não
  fundou a primeira cidade (o Colono do turno 1) não está eliminado. Antes a eliminação exigia também matar a última
  unidade: um reino sem cidades seguia vivo com tropas soltas, a Dominação não fechava e o conquistador continuava em
  guerra (pagando manutenção) com um reino que não existia. `V2VictoryConditions.is_eliminated` (sem cidades e sem
  unidades) não mudou, então Dominação, Supremacia e a derrota do jogador seguem pela mesma checagem.
  `GameManager` pula civilização eliminada no planejamento da IA e não deixa agir, no mesmo lote, uma unidade já
  removida. **Muda o baseline do laboratório:** civilizações passam a cair antes. Testes:
  `test/unit/test_civilization_elimination.gd`.
  **A regra é de estado, não só um evento da captura (2026-10-12):** `V2VictoryConditions.has_fallen` (já teve cidade
  — existe no mapa uma com o `original_owner_index` dela — e não tem mais nenhuma) + `HexGrid.reconcile_eliminations`,
  que elimina pelo mesmo caminho toda civilização caída que ainda tenha unidades ou relações
  (`Diplomacy.has_relations`). Roda ao carregar um save (`SaveManager.load_game`) e no começo de cada virada de rodada
  (`GameManager._on_turn_changed`); idempotente, uma passada pelas cidades. Sem isso uma partida salva antes da regra
  seguia com a civilização conquistada em guerra e propondo paz todo turno (nenhuma captura futura passaria por ela).
  Depende de cidade nunca ser destruída, só capturada: quem um dia criar destruição de cidade precisa chamar
  `eliminate_civilization` quando a última sair.
- **Grandes Manifestações em jogo (2026-10-13):** as seis usam os modelos animados de
  `assets/generated/grand_manifestations/` — Serafim e Primordial dos Elementos já usavam; entraram Arquidemônio
  (`archdemon_blocky_v5_animated`), Lich Soberano (`elder_lich_blocky_v3_animated`), Avatar da Natureza
  (`nature_avatar_blocky_v5_animated`, no lugar do Ent procedural 1,7×) e Arconte do Véu
  (`veil_archon_blocky_v9_animated`, no lugar do conjurador arcano 1,45×). Fonte única:
  `UnitDatabase.MANIFESTATION_MODELS` + `_apply_manifestation_model` — o MESMO modelo para as quatro raças
  (`UnitArtCatalog` não tem entrada para elas, de propósito), escala nativa de 3 m (multiplicador 1,0, yaw 0), Idle e
  Walk em ciclo, Spell em todo feitiço (`Unit.play_cast_visual`), Attack ligado mas sem uso em jogo (nenhuma tem
  ataque básico). Só arte: nenhum número de regra mudou.
  - **Transições suaves:** `UnitData.pose_transition_time` (+ `pose_transition_walk_time` para entrar/sair do Andar)
    liga a transição por CAPTURA DE POSE (`scripts/units/PoseCaptureTransition.gd`, o antigo
    `ElementalSerpentTransition` generalizado): a troca parte da pose em que o esqueleto está naquele instante e
    chega ao clipe novo com curva seno, enquanto ele já corre — interromper um gesto ou conjurar duas vezes seguidas
    não dá salto. Substitui o crossfade linear (`animation_blend_time`, ignorado quando a captura está ligada; o
    Serafim usava 0,2 s, que lia como tranco num corpo de Idle de 24 s). Tempos: 0,5 s para as cinco, 0,6 s/0,9 s
    (andar) para o Primordial, os aprovados com o modelo dele. Vale porque os quatro clipes de cada modelo animam o
    mesmo conjunto de ossos (conferido em teste). Custo: as trilhas 3D viram trilhas de valor em cópias dos clipes,
    por unidade — aceitável para poucas unidades grandes, não ligar em tropa comum.
  - **Debug:** painel de Debug → "Invocar Grande Manifestação" (quantidade 1–50 + um botão por Manifestação): nascem
    para o jogador nos tiles livres mais próximos da unidade selecionada (ou da primeira cidade), sem custo, sem
    pesquisa e sem o limite de uma por Escola (`scripts/core/DebugSummon.gd`). "Animação da unidade selecionada"
    toca Parado/Andar/Atacar/Conjurar com a transição normal (`Unit.debug_play_state`) — é o único jeito de ver o
    Attack delas. O painel agora rola (`DebugScroll`) em vez de passar da altura da janela.
  - Testes: `test/unit/test_grand_manifestations_in_game.gd` — inclui a medida de "nenhum osso salta" (posição,
    ângulo e escala de todo osso um quadro depois de cada troca de estado, com um teste de controle provando que um
    corte seco reprovaria) — e `test_seraph_blocky_model.gd`.
- **Dragão modelado no lugar do procedural (2026-10-13):** o Dragão do evento usa
  `assets/generated/dragons/dark_red_dragon_v5_animated` (3 m, seis clipes: parado/andar/atacar no ar e em terra).
  Posturas `flying`/`ground` guiadas pelo `travel_mode` do `DragonEvent` (`Unit.set_posture`,
  `UnitData.posture_animations`, `MonsterDatabase.DRAGON_POSTURES`), sopro de fogo no osso `mouth_fire`
  (`Unit._build_fire_breath` / `play_fire_breath`, janela 0,75–2,0 s), tombo de morte (`Unit.play_death_topple`).
  O corpo de caixas montado em código (`Unit._build_dragon_body` + cinco clipes procedurais) foi removido. Só arte:
  as regras do evento não mudaram. Detalhes em `docs/DRAGON_EVENT_DESIGN.md` e `docs/ASSET_FACTORY_GUIDE.md`;
  testes em `test/unit/test_dragon_model.gd`.
- **Núcleos das Manifestações iluminam + opções de vídeo (2026-10-13):** o efeito dos cristais (`WorldGlow`) nos
  núcleos das seis Grandes Manifestações — luz sem sombra presa ao osso do núcleo (`WorldGlow.attach_light`,
  `Unit._build_core_glow`, `UnitData.glow_profile`/`glow_bone`, `UnitDatabase.MANIFESTATION_CORES`) e o mapa de
  emissão do modelo crescendo com a escuridão (`WorldGlow.track_emission`, `GlowProfiles.emission_factor`: de dia o
  modelo aprovado, à noite ×1,8–2,2). Duas opções novas em Configurações → Vídeo, ligadas por padrão: "Luzes do
  mapa" e "Luzes das criaturas" (`Settings.map_lighting_enabled` / `creature_lighting_enabled`, camadas
  `WorldGlow.LAYER_MAP` / `LAYER_CREATURES`); desligam só as luzes, o brilho do modelo continua. Detalhes em
  `docs/GRAPHICS_SETTINGS.md` (seção "Brilho do mundo"), medição em `docs/PERFORMANCE_GUIDE.md` 2.15. Testes:
  `test/unit/test_core_glow.gd`.
- **Ícones por tipo (2026-10-13, refeitos no mesmo dia):** o selo único de "espadas cruzadas" sobre toda unidade e
  os selos abstratos de recurso deram lugar a 39 pictogramas. `scripts/data/IconCatalog.gd` decide qual pictograma,
  qual cor e como o selo é desenhado: **tropa** = um pictograma por CLASSE (escudo/Guardião, espada/Guerreiro,
  arco/Patrulheiro, cavalo/Cavalaria, capuz/Ladino, catapulta/Cerco) com 1–3 pontos pela forma da linha e aro
  dourado na Lendária; **conjurador** = símbolo da Escola; **Grande Manifestação** = pictograma próprio com aro
  dourado; Colonizador = tenda, Construtor = martelo, Hostes = mão erguida; **monstro** = um pictograma por espécie
  (as 13 de `MonsterDatabase`). Por classe e não por unidade de propósito: 24 silhuetas de tropa não se distinguem
  num selo pequeno sobre o mapa.
  - **Arte:** a primeira versão (pixel art 16×16 desenhada à mão) foi rejeitada ("parece algo amador que eu abri o
    paint e fiz"). Os desenhos agora são ícones vetoriais de https://game-icons.net — **CC BY 3.0, crédito ao autor
    obrigatório em qualquer distribuição** (`assets/icons/CREDITS.txt`, gerado; falta levar o crédito a uma tela de
    créditos quando o jogo tiver uma). Fontes versionadas em `tools/art_pipeline/icon_sources/` (`manifest.json`: id
    → "autor/nome"; `svg/`; pasta com `.gdignore`). `fetch_icon_sources.py` baixa o que mudou no manifesto;
    `build_icon_glyphs.gd` rasteriza cada SVG numa MÁSCARA sem cor (`assets/icons/glyphs/<id>.png`, 128×128, branco
    + alfa suavizado, recortada e encaixada na mesma moldura) e reescreve o CREDITS. Pictograma novo ou trocado: uma
    linha no manifesto, os dois scripts, `--import`, mapear no catálogo.
  - **Cor é parâmetro, não arquivo** (preparado para a mecânica de escolher a cor do reino): o selo inteiro sai de
    UMA cor base — `IconCatalog.badge(pictograma, cor, pontos, elite, formato)`. Degradê, aro (a própria cor
    escurecida), fio de relevo e sombra são camadas sem cor (branco/preto translúcidos) por cima dela, e a tinta do
    desenho é escolhida pelo contraste (`ink_for`: clara se der ≥ 3:1, senão escura — amarelo e branco ganham
    desenho escuro). Nenhuma cor de reino exige arte nova: basta `CivilizationData.color` mudar
    (`color_for_owner`); unidades já no mapa pegam a cor nova com `Unit.refresh_troop_icon()` (só troca a
    textura). Composição quase toda em operações nativas de `Image` sobre camadas em cache, ~2–3
    ms por combinação nova, uma textura por combinação. Para ver/exportar variações:
    `godot --headless --path . -s tools/art_pipeline/export_icon_variations.gd -- --out=<pasta> [--colors=#rrggbb,...] [--files]`
    (folha de contato + opcionalmente um PNG por selo e cor).
  - **Formato = tipo de coisa:** placa quadrada (tropa de um reino, na cor dele — a mesma da borda/minimapa),
    hexágono (monstro neutro, sempre `MONSTER_COLOR`), medalhão redondo escuro com o desenho na cor do recurso
    (recurso de mapa). O formato existe porque a cor será livre: um reino vermelho-escuro não pode parecer monstro.
  - **Usos:** `Unit._build_troop_icon` (o emblema de duas letras da Escola sobre os magos saiu),
    `ResourceIconManager` e o retrato do card da unidade (`AEPortrait.set_icon`). Sprite3D com filtro linear +
    mipmaps e transparência por mistura (a arte tem borda suave e sombra; nada de `alpha_cut`). Ainda não usam o
    selo: minimapa e lista de produção (`IconCatalog.kind_badge` já existe para ela). Testes:
    `test/unit/test_icon_catalog.gd`.
- **Dragão: aviso, sem pergunta (2026-10-13):** o jogador não é mais perguntado se quer participar da caçada (o
  Dragão ataca os reinos por onde passa, queira ele ou não). Saíram da HUD o `WorldEventPanel` (cena e código),
  `format_world_event_title/prompt`, os botões Participar/Não participar, o item de Attention
  `world_event_decision` e `GameManager.respond_to_world_event`. O aviso da Preparação virou afirmação ("Prepare
  suas defesas: o Dragão ataca os reinos por onde passa") e o Tracker conta a chegada (`HUD.preparation_objective`).
  O modal de anúncio e o resto do evento não mudaram. Sem mudança de regra: a recompensa já dependia só do dano
  causado; a IA mantém a decisão interna de mandar ou não uma força à caçada. Testes: `test_hud.gd`,
  `test_phase33d3_events.gd`.
- **Duração dos efeitos de 1 turno — comunicação (2026-10-13):** relato do usuário: "eu ativo o efeito no meu turno,
  dou próximo, e o efeito já acabou". A regra (`V2OwnerTurnEffect`: Técnicas e feitiços de estado duram "até o início
  do próximo turno do dono") SEMPRE cobriu o turno dos inimigos — `test_buff_duration.gd` passa pela troca de turno
  de verdade e confere que Égide/Muralha de Escudos estão ativas no instante em que a IA ataca, e que o Silêncio
  cobre o turno do mago inimigo. O defeito era de comunicação, e foi isso que mudou (nenhuma regra/balanceamento):
  (1) textos numa fonte única (`DURATION_FOR_CASTER`, `DURATION_ON_UNIT`): "até o início do seu próximo turno — vale
  durante todo o turno dos inimigos"; o buff de Ataque diz que vale para os ataques deste turno e os revides;
  (2) o chip do card troca "· 1t" por "· até o próx. turno" (`AEStatusChip.set_status(..., duration_text)`); os
  estados de criatura (Veneno etc.), contados em turnos próprios, seguem com "2t"; (3) o aviso de combate diz o
  que protegeu: "Seu Guerreiro foi atacado e resistiu! Protegido por Égide Sagrada."
  (`CombatResolver.defense_effects_note`, inclusive a Muralha projetada por um aliado ao lado).
- **Escolher o alvo: tropa ou cidade (2026-10-13):** atacar um tile com uma tropa guarnecendo uma cidade não bate
  mais sempre na tropa (que servia de escudo). `SelectionManager.attack_targets_at` devolve os dois alvos atacáveis;
  havendo os dois, o clique emite `EventBus.attack_target_choice_requested` e o `AttackTargetChoicePresenter` abre o
  modal "Atacar quem?" com a previsão de cada golpe (`CombatResolver.predict` / `predict_city_attack` — a conta do
  dano à cidade virou `city_attack_damage`, usada também por `resolve_city_attack`). Cancelar/ESC não gasta nada;
  sem UI ligada ao sinal vale o alvo de sempre (a tropa). O hover mostra "ATACAR <tropa> ou <cidade>". A cidade
  não revida. **Guarnição de cidade capturada:** `HexGrid._withdraw_garrison` (em `capture_city`) faz a tropa do
  antigo dono recuar para o tile livre mais próximo; sem tile livre, ela cai com a cidade — o Bombardeio de Cerco
  já podia capturar uma cidade guarnecida e deixava a tropa inimiga dentro dela. **IA** (`RivalAI._engage`): toma a
  cidade se o golpe a captura; senão luta com a guarnição quando é favorável; senão bate na cidade (antes desistia
  do ataque — uma guarnição forte protegia a cidade contra a IA). **Muda o baseline do laboratório.** Testes:
  `test/unit/test_attack_target_choice.gd`, `test_ui_strategy.gd`.
- **Rota de marcha visível (2026-10-13):** toda unidade do jogador com ordem de marcha pendente
  (`Unit.move_order_target`) tem a rota desenhada no mapa até chegar — `MarchRouteOverlay` (`HexGrid.march_routes`):
  uma marca por tile do caminho e um anel no destino, na cor do reino, mais forte na tropa selecionada. Só para o
  dono: apenas unidades de `GameManager.human_player`, e só com uma pessoa no assento (`is_human_controlled`).
  A rota é `HexGrid.unit_path` (a mesma de `continue_move_order`), replanejada quando a unidade anda, o destino muda
  ou o turno vira; sem caminho no momento, o destino continua marcado. Sem estado próprio nem save: é o reflexo de
  `move_order_target`, que virou propriedade com setter e emite `EventBus.unit_move_order_changed`. Orientada a
  evento (ordem mudou, unidade removida, névoa recalculada, seleção), uma reconstrução adiada por quadro, A* em
  cache por (posição, destino, turno), duas MultiMesh. Marcas em tile nunca visto ficam sobre a camada de névoa.
  Medido em partida real com 2 marchas: reconstrução de ~72 µs com o cache, ~770 µs replanejando as rotas.
  Testes: `test/unit/test_march_route_overlay.gd`.
- **Fronteiras abertas — acordo diplomático (2026-10-13):** `Diplomacy.request_open_borders(proposer, receiver)` cria
  um acordo SIMÉTRICO (`PlayerData.open_borders`) que suspende, entre os dois, as fronteiras fechadas mesmo em paz
  (`HexGrid.closed_tiles_for` consulta o acordo). Quem responde: a IA, na hora, por regra pública
  (`open_borders_refusal_reason`: recusa com trégua em vigor ou quando o exército de quem pede é o dobro do dela e
  tem 4+ unidades a mais); o jogador, no modal `OpenBordersOfferPresenter` (Aceitar/Recusar, não cancelável, mesmo
  desenho do modal de paz; pedido sem resposta caduca na troca de turno). Recusa = espera de
  `OPEN_BORDERS_COOLDOWN_TURNS` (5) quando a IA recusa, `OPEN_BORDERS_PLAYER_REFUSAL_TURNS` (30) quando o jogador
  recusa (a IA não volta a incomodar tão cedo). A IA também pede (`RivalAI.decide_open_borders`): cadência fixa por par a cada
  12 turnos, sem RNG, só a quem já tem cidade de fronteira fechada e só o que ela mesma concederia. O acordo não
  tem prazo; acaba por `end_open_borders` (qualquer lado, na Diplomacia) ou por guerra — `declare_war` encerra o
  acordo e retira as tropas ANTES de a guerra começar (o acordo nunca serve para estacionar um exército dentro do
  reino alheio e atacar). Em qualquer fim, `enforce_closed_borders` retira quem ficou dentro. Save: chaves
  opcionais `open_borders`/`open_border_offers`/`open_border_refusals` em `relations` (sem bump de versão).
  Interface: botões "Solicitar/Encerrar Fronteiras Abertas" na Diplomacia com a previsão da resposta no tooltip,
  fato "Fronteiras" e chip "Fronteiras abertas" na lista, eventos no histórico, e o inspetor de tile diz
  "Fronteiras abertas por acordo". **Muda o baseline do laboratório** (IAs fecham acordos entre si). Testes:
  `test/unit/test_open_borders.gd`, `test_ui_strategy.gd`, `test_save_manager.gd`.
- **Fronteiras fechadas (2026-10-13):** o território (`City.owned_tiles`) de uma cidade que já evoluiu ao menos uma
  vez (City Level >= `HexGrid.CLOSED_BORDERS_FROM_LEVEL` = 2) é fechado a toda civilização que não seja a dona e não
  esteja em guerra com ela: as unidades dela não andam para dentro, não atravessam, não pousam (voo tático
  sobrevoa) e não terminam uma infiltração ali. Em guerra a fronteira não existe para os dois lados; monstros nunca
  são barrados. A regra é POR CIDADE (uma colônia nível I continua aberta) e vale igual para jogador e IA, porque
  mora nas funções de passagem comuns: `compute_reachable`, `flight_reachable`, `infiltrate_reachable`,
  `_find_route` (destino fechado é rejeitado antes da busca; o A* contorna). Nada é salvo — deriva de nível,
  território e guerras (`closed_tiles_for(owner)`, mapa por civilização remontado só quando o carimbo de cidades/
  tiles muda). **Retirada:** quem fica dentro quando a fronteira fecha (cidade evoluiu, paz, anexação por cima da
  unidade, captura, save antigo) vai para o tile livre mais próximo fora dela — `enforce_closed_borders`, chamado na
  virada de rodada, depois das cidades, no fim da fase da IA, em `Diplomacy.make_peace`, na anexação do jogador, em
  `capture_city` e no load. Interface: o alcance não destaca tiles fechados, o hover diz "FRONTEIRA FECHADA —
  <reino>", mandar marchar para dentro avisa o motivo, o inspetor de tile/cidade mostra o estado da fronteira, a
  Diplomacia explica a consequência de guerra/paz e a cidade do jogador avisa quando fecha. **Muda o baseline do
  laboratório** (rotas da IA em paz contornam reinos evoluídos). Testes: `test/unit/test_closed_borders.gd`.
- **Conhecimento guardado à vista (2026-10-13):** o Conhecimento que entra sem projeto ativo (ou sobra de uma
  pesquisa concluída) fica em `V2ResearchState.research_overflow` e entra INTEIRO, na hora, na próxima pesquisa
  escolhida — podendo concluí-la no clique. A regra não mudou; a interface passou a mostrar isso antes da escolha.
  `V2ResearchState.banked_preview(id)` é a conta (só leitura, a mesma de `_advance`). No `V2ResearchBoard`: chip
  "Guardado: N · +X por turno" no cabeçalho (antes o valor só existia no fim da linha de status, cortada com
  reticências), prévia em cada nó que pode ser escolhido (barra azul + "Com guardado: 8 / 16" ou "Com guardado:
  conclui") e uma frase no rodapé/tooltip do nó selecionado (até onde vai, quanto falta e ≈ turnos, ou "conclui
  na hora e sobram N"). `ResearchStatusWidget` e o item de Attention explicam o mesmo. Na barra superior
  (`GlobalBarPresenter`) o chip de Conhecimento passou de só "+2" para "8  +2" (guardado + por turno, o formato do
  Ouro e da Mana), com tooltip dizendo para onde a renda vai; a barra escuta o estado de pesquisa do jogador
  (`_bind_research`), então guardado e progresso atualizam na hora da escolha, não só na virada de turno. Testes:
  `test_v2_research_state.gd`, `test_v2_research_board.gd`, `test_ui_foundation.gd`.
- **Relicário Desperto removido (2026-10-12, "apague o evento relicário do game"):** saíram `ReliquaryEvent`, o
  agendador (`maybe_start_reliquary`, `reliquary_schedule`), a escolha de recompensa no painel de evento, o item de
  Attention, o chip de objetivo, os avisos do Event Center, o plano da IA (`V2StrategicAI.reliquary_plan`,
  `StrategicAI.respond_to_reliquary`), o campo `Unit.source_event_id` (só o Relicário gerava monstros de evento), o
  marcador `WORLD_EVENT_MARKER_GROUP` e a seção `reliquary` da telemetria do laboratório. O único grande evento da
  Ascensão passa a ser o Dragão. **Saves:** `WorldEventManager.RETIRED_EVENT_TYPES = ["reliquary"]` — um save com o
  Relicário ativo carrega sem o evento e sem os guardiões dele (`SaveManager._deserialize_neutral_units` não restaura
  monstro com `source_event`); uma recompensa que estivesse aguardando escolha é perdida. `SAVE_VERSION` não mudou.
  **Muda o baseline do laboratório:** some a recompensa única de 90 Ouro/60 Mana e o deslocamento de tropas da IA
  até o local. Testes: `test_phase33d3_events.gd` (Dragão + save com o evento removido), `test_phase33d_review.gd`.
- **Rivais nunca repetem a raça do jogador (2026-10-12):** `GameManager.AI_CIVS` tem uma civilização de IA por
  raça (a humana, Reino de Valmere, é nova) e `rival_races_for(raça do jogador)` devolve as outras, na ordem canônica
  `RACES` (humano, elfo, anão, orc) — jogador humano continua com elfo/anão/orc; jogador elfo recebe humano/anão/orc;
  com menos de 3 rivais entram as primeiras da lista. Antes a lista era fixa (elfo, anão, orc por índice) e nunca
  havia IA humana. O save grava `rival_races` (chave opcional) e `setup_players(grid, rival_races)` recria o elenco
  salvo; save sem a chave carrega com o elenco fixo antigo (`LEGACY_RIVAL_RACES`), exatamente como foi jogado. O
  laboratório 4-IA não muda (ele sobrescreve raça/nome por assento). Testes: `test_game_manager.gd`,
  `test_save_manager.gd`.
- **Conclusão de obra atômica (2026-10-12):** o canteiro (modelo animado + barra) existe exatamente enquanto alguma
  cidade tem `pending_building_coord` e ainda não há prédio no tile. Quem cria o prédio retira o canteiro:
  `HexGrid.place_building` → `_retire_construction_marker` — some do jogo naquele instante (foco visual, inspetor e
  névoa não o veem mais) e sobra um aceno de <1 s (barra em 100% que sobe e some; nada com Reduced Motion ou fora da
  visão). `refresh_construction_markers()` virou reconciliação pura, sem parâmetro: nunca cria canteiro onde há
  prédio, remove obra cancelada na hora, só refaz a textura de uma barra cujo valor mudou e já aplica a névoa ao
  criar. `GameManager` chama logo depois da produção das cidades (a barra anda no Encerrar Turno, não depois da
  fase da IA) e de novo no fim da rodada (cidade capturada pode ter perdido a obra). Antes o prédio nascia na hora
  mas o canteiro só era avisado depois, por uma lista de coordenadas passada do `GameManager` ao `HexGrid`, em duas
  etapas: fim da fase da IA (até lá, prédio + canteiro + barra do turno anterior no mesmo tile) e um turno inteiro
  depois (barra parada em 100% sobre o prédio pronto). Testes: `test/unit/test_construction_completion.gd` (turno
  real, com a fila de IA escalonada).
- **Obra sobre recurso de mapa (2026-10-12):** construir um prédio num tile com recurso DESTRÓI o recurso — e, com
  ele, a melhoria do Construtor (rendimento, marcador, pilhagem pendente), o prop 3D e o ícone. Antes o prédio só
  escondia o prop/ícone e `HexTileData.resource` continuava nos dados, inaproveitável (Construtor não melhora tile com
  prédio) e ainda listado no inspetor.
  - **Regra, um ponto só:** `HexGrid.destroy_resource_at(coord)` (idempotente, devolve o id destruído). É chamado por
    `City.start_building` — a entrada única de "iniciar obra" do jogador e da IA; o recurso some quando a obra
    COMEÇA e não volta se ela for cancelada — e por `place_building` (rede de segurança: prédio de pé nunca tem
    recurso embaixo; também saneia save antigo com prédio sobre recurso).
  - **Jogador:** no posicionamento, o hover do tile mostra "CONSTRUIR X — destrói Y". O clique não inicia nada:
    `SelectionManager` guarda `placement_confirmation_coord` e emite
    `EventBus.building_placement_confirmation_requested`; `BuildingSiteConfirmPresenter` (UIShell) abre o modal com o
    recurso e a melhoria perdida/possível (rendimento pelo dono). "Construir e destruir" →
    `confirm_building_placement()`; "Escolher outro tile", fechar ou ESC → `decline_building_placement()`: nada é
    gasto nem destruído e o posicionamento continua ativo. Sem interface escutando (testes headless) o clique vale
    como a confirmação.
  - **IA:** `_building_site` prefere tile SEM recurso (depois desocupado, depois coordenada); só constrói sobre um
    recurso quando não sobra outro tile, e aí vale a mesma regra. **Isto muda o baseline do laboratório:** antes a IA
    escolhia o tile de menor coordenada mesmo com recurso (e o deixava inaproveitável).
  - **Save:** `destroyed_resources` (lista esparsa `[x, y, id]`, campo opcional, sem bump de versão). O mapa é
    recriado do seed no load; a lista é reaplicada logo depois de `terrain_changes`/`terrain_resources`.

### Minimapa (`scripts/ui/Minimap.gd`)

- **Geografia contínua:** cada tile pinta o seu "tijolo" inteiro (largura √3·size, altura 1,5·size, centrado no
  hex). No layout pointy-top com linhas deslocadas meio hex esses tijolos tesselam o plano sem buracos nem
  sobreposição — lê como mapa em qualquer zoom do quadro adaptativo. Imagem persistente (cache); delta da névoa
  repinta só os tiles que mudaram.
- **Indicador de câmera:** os 4 cantos da tela por `project_ray_*` contra o chão; raio que não acerta (ou acerta além
  de 60 unidades, perto do horizonte) é limitado a 60 na direção do raio; nenhum ponto não-finito passa; o polígono é
  recortado ao retângulo útil (`Geometry2D.intersect_polygons`). Câmera fora do quadro adaptativo = nada desenhado.

### Mundo padrão 1.0 e continentes especiais

`WorldProfile` (`scripts/world/WorldProfile.gd`): `STANDARD_1_0` (144×76, só o continente principal) é o perfil de
toda partida nova e do laboratório; `SPECIAL_CONTINENTS` (320×84) liga os continentes Vulcânico e Cristalino. O perfil
é derivado das dimensões (o mundo é regenerado por seed+dimensões no load): save antigo 320×84 continua com os
continentes especiais, save novo continua só com o principal — sem campo novo no save. `HexGrid._zone_for` só
classifica VULCÂNICA/CRISTAL com a flag do perfil. O conteúdo especial **existe em código, está desligado no 1.0 e
fica reservado para conteúdo futuro opcional** — detalhes em `docs/SPECIAL_CONTINENTS.md`. Covil legado de Dragão
que o fallback antigo pudesse pôr no continente principal é removido na preparação da ecologia.

### Aggro / perseguição / leash / retorno

Dados em `MonsterActivityProfile` (por tier×era) + refinamento por espécie (`MonsterEcologyData.behavior_profile`:
`aggro_bonus`, `pursuit_bonus`, `chase_bonus`, `local_raid`); raios efetivos numa fonte única
`MonsterAI.ecology_ranges` (IA e telemetria).

| Era | BASIC aggro/perseg./leash | INTERMEDIATE | ADVANCED |
|---|---|---|---|
| Despertar | 4 / 6 / 8 | 2 / 4 / 5 | 1 / 3 / 4 |
| Ascensão | 3 / 5 / 5 | 4 / 7 / 9 | 2 / 4 / 6 |
| Convergência | 2 / 4 / 4 | 4 / 6 / 6 | 4 / 7 / 9 |

Espécie: Worg aggro +1, perseguição +2, leash +2; Troll perseguição −1, leash −2; Devorador aggro +1; Wyvern raide
só dentro do próprio leash (`local_raid`); quem caça presa especial (grupo: Wyvern/Verme; conjurador: Devorador)
usa o raio de interesse da era como zona.

- **Aquisição** (`_ecology_aggro_target`): busca LIMITADA aos tiles a `aggro` do monstro (`HexMetrics.coords_within`,
  nunca o mapa), ignora alvo fora do leash/zona da âncora, prioridade da espécie (isolado/ferido, grupo, conjurador),
  BASIC não escolhe luta claramente perdida. Alvo guardado em `ability_state.aggro_target` (serial) +
  `aggro_coord`.
- **Perseguição:** mantém o alvo enquanto ele estiver a `pursuit` do monstro e a até zona+1 da âncora.
- **Leash:** fora disso, desiste (`leash_disengage`), limpa o alvo e entra em **RETORNO** (`ability_state.returning`):
  volta à âncora sem readquirir alvo distante (só se defende de quem encostar); a ≤ 1 da âncora, `return_home` e o
  aggro normal volta. Sem ping-pong (testado: distância à âncora nunca cresce durante o retorno).
- **Habilidades respeitam o aggro:** `MonsterAbilitySystem.engage_reach` (definido pela IA antes de `try_active`) —
  uma habilidade ofensiva só mira até o raio de aggro (ou o interesse da era para presa especial) ou o alvo já
  perseguido. Achado corrigido: a Investida (alcance 2–4) furava o aggro 2 do Despertar.
- **Raides preservados:** Goblin/Esqueleto como na Etapa 2 (Despertar, descanso, bando de 3). **Wyvern (auditoria):**
  o raide da Ascensão continua, mas só contra cidade dentro do próprio leash (antes podia partir de 12 tiles).
- Estado transitório já viajava em `ability_state` (salvo desde a Etapa 2) — sem campo novo.

### Legibilidade das habilidades (`scripts/world/MonsterAbilityFeedback.gd`)

Camada de apresentação desacoplada: só escuta `EventBus.combat_ecology_event` (a lógica agora emite coordenadas:
`source`, `target_coord`, `tiles`, `landing`, `victim_from/to`, `dest`) e desenha efeitos provisórios auto-liberados
(texto flutuante empilhado por tile, aro, explosão, feixe, tiles do cone). Nada é condição de gameplay: a lógica
resolve tudo antes (headless igual). Só desenha em tile VISÍVEL agora (feixe só com as duas pontas visíveis); sem RNG
(o popup antigo usava `randf`); Reduced Motion = marcas estáticas; inerte sem tela.

| Habilidade | Telegraph → execução → consequência |
|---|---|
| Saque Rápido | aro dourado na cidade + "Saque: −8 Ouro" |
| Horda Crescente | explosão de ossos no tile + "Horda Crescente: ergueu-se!" |
| Faro de Sangue | linha de caça vermelha Worg → alvo isolado + "Faro de Sangue" |
| Picada Venenosa | explosão verde + "Envenenado" + anel/rótulo de estado; tick "Veneno −N" |
| Regeneração | aro verde + "Regeneração +N (sem dano no turno)" |
| Sopro Incendiário | feixe na direção + tiles do cone destacados + "Sopro Incendiário"; "Chamas −N" no tick |
| Investida | aro de preparação na origem, linha até a vítima, "Investida!", deslize do Minotauro (0,25 s de wind-up), impacto, empurrão visual da vítima até o tile final; Reduced Motion mantém linha e marcas |
| Olhar Petrificante | feixe cinza + "Petrificação Parcial" + anel cinza "Petrificado" |
| Escavar | aro de poeira na origem + "Escavou — foge sob a terra"; marcador com buraco na origem, trilha de montinhos e aro no destino; "Emergiu" sem dano |
| Raízes do Mundo | linhas Ancião → tiles + "Raízes do Mundo"; tiles com toras + cipós erguidos |
| Fome Arcana | feixe roxo conjurador → Devorador, "−X Mana", "Barreira Arcana +N", casca translúcida enquanto houver barreira |
| Ruptura Etérea | feixe + explosão roxa + "Ruptura Etérea — Silenciado" + anel "Silenciado" |
| Contaminação Micótica | tiles com cogumelos rosados; entrar mostra "Área Micótica" (sem dano); no início do turno, explosão de esporos + "Esporos −N" |

**Estado na unidade** (`Unit.refresh_status_overlay`): anel colorido + rótulo do estado mais importante
(Petrificado > Enraizado > Silenciado > Em Chamas > Envenenado > Abalado) e casca da Barreira Arcana; nós próprios
(não usa `material_overlay`, que o flash de dano limpa), idempotente, refeito no load. Inspector: estados com
duração, "Área Micótica" enquanto a unidade está num tile infectado, estado de aggro ("perseguindo um intruso" /
"retornando ao território").

### Verme Colossal — revisão

Escavar virou **reposicionamento defensivo / fuga**: o Verme luta normalmente na superfície; com ≤ 35% da Vida e
inimigo a ≤ 3, mergulha para um destino a 2–3 tiles que maximiza a distância ao inimigo mais próximo dentro da
zona (desempate: mais perto de casa, coordenada). Subterrâneo: fora do mapa de unidades, sem atacar, sem dano de
contato/habilidade, intocável. Emerge na fase dos monstros do turno seguinte no destino anunciado (ou fallback legal
≤ 2) **sem dano**. Rastro com origem → trilha → destino (salvo como antes; origem nova em `ability_state.origin`).
Não é mais perigo para a IA de civilização. Corpo VISUAL longo (dorsos semienterrados passando do hex); lógica 1 hex.

### Colmeia e Ancião — causalidade

Entrar num tile infectado **não** causa dano (evento `infection_entered`, aviso "Área Micótica"); o dano (3%, 1–3)
é só no início do turno de quem ainda está no tile, uma vez por turno. Inspector do tile: "Contaminação Micótica"
(dano no início do turno, cura −50%, entrar não machuca, origem). Raízes: "Raízes do Mundo" (movimento +2, quem
estava em cima ficou Enraizado, **não causam dano**).

### Covil × território × repopulação

- **Covil** só para estrutura real (`LairStructure`). Sítio ecológico sem estrutura = **Território/Habitat** com nome
  por espécie (`MonsterAbilityFeedback.HABITAT_NAMES`: Acampamento Goblin, Ossário, Território de Worgs, Ninho de
  Aranhas, Território de Troll, Poleiro de Wyvern, Território do Minotauro, Toca do Basilisco, Território do Verme,
  Bosque Ancestral, Fenda Arcana, Colônia Micótica).
- **Marcador discreto** (estaca + bandeira na cor do tier + nome) na âncora de todo território que o humano já
  descobriu (tile explorado); não bloqueia, não é atacável, não dá recompensa; derivado do estado (nunca salvo);
  some quando o sítio se esvazia, com "Área limpa" se o tile estiver à vista.
- **Inspector:** território com o texto de repopulação; área limpa recente (cooldown de 20 rodadas) como "Área
  limpa". Painel de unidade de criatura ecológica: tier, comportamento real da era, território, estado de aggro e
  habilidades (antes caía no rótulo legado "Guardião (defende o território do covil)").
- **Repopulação:** regras da Etapa 1 intactas (1 sítio a cada 2 rodadas, fora da visão de todas as civs, ≥ 2 de
  unidades/cidades, nunca a ≤ 8 de um sítio esvaziado nas últimas 20 rodadas, pesos por era). Texto ao jogador:
  "Criaturas podem repovoar regiões distantes ao longo da partida. Áreas recentemente limpas permanecem seguras por
  algum tempo." A IA continua sem caçar território sem estrutura (decisão registrada para revisão futura).

### Multi-tile — viabilidade (só auditoria)

Ocupação é 1 coord por unidade em todo o código: `units_by_coord` (30 referências em 6 arquivos), `get_unit_at` (109
chamadas), ~550 usos de `unit.coord`; A*/alcance (`compute_path`, `unit_reachable`) sem noção de pegada; corpo a
corpo/adjacência, AoE, névoa, empurrão (`teleport_unit`), seleção por clique e save assumem um tile. Classificação:
**visual multi-segmento = A** (feito: Verme); **pegada lógica 2×2/4-hex = C** (reescrita transversal, alto risco).
Um meio-termo de "ocupação sombra" (tiles extras bloqueados apontando para a raiz) seria **B**, mas toca a semântica
das 109 chamadas de `get_unit_at`. Basilisco e Verme continuam 1 hex lógico.

### Validação visual não-headless (uma execução, mundo padrão real com HUD)

Screenshots de desenvolvimento em `user://dev_artifacts/v3_e3_visual/` (fora do repositório e do build; a cena
temporária foi apagada logo depois).

| # | Item | Resultado |
|---|---|---|
| 1 | Unidade + floresta | PASS — guerreiro inteiro; copas do próprio tile translúcidas, florestas vizinhas opacas |
| 2 | Foco na estrutura | PASS — padrão: unidade opaca, casas da cidade translúcidas; aba Cidade: casas opacas, unidade translúcida |
| 3 | Foco no terreno | PASS — cidade e unidade translúcidas, chão legível |
| 4 | Geografia do minimapa | PASS — manchas contínuas de terreno/água, sem grade de pontos |
| 5 | Indicador de câmera | PASS — trapézio real, recortado na moldura; câmera fora do quadro adaptativo não desenha nada (sem lixo) |
| 6 | Investida | PASS — aro de preparação, linha, "Investida!", deslize, impacto, empurrão (o flash de dano aparece no instante lógico, antes do deslize terminar) |
| 7 | Veneno | PASS — explosão verde, anel/rótulo "Envenenado"; tick "Veneno −2" (sobreposição de rótulos vista aqui → corrigida com empilhamento) |
| 8 | Petrificação | PASS — feixe cinza, "Petrificação Parcial", anel cinza |
| 9 | Verme | PASS — aro de poeira + "Escavou — foge sob a terra", trilha até o destino; "Emergiu" no destino com o corpo segmentado longo, sem dano |
| 10 | Raízes | PASS — linhas do Ancião aos tiles, toras + cipós, unidade Enraizada; inspector "Raízes do Mundo … não causam dano" |
| 11 | Mana drenada / Barreira | PASS — feixe roxo, "−6 Mana", "Barreira Arcana +4", casca visível (o silêncio da Ruptura não apareceu: o "Mago" legado não é conjurador V2 — coberto só por teste headless) |
| 12 | Infecção / tick | PASS — tiles rosados com cogumelos; entrar: "Área Micótica", Vida 60 → 60; início do turno: esporos + "Esporos −2" (60 → 58,2); inspector "Contaminação Micótica" |

Também visto: marcador "Ninho de Aranhas" no mapa; painel de unidade de criatura ecológica caía no rótulo legado
"Guardião (defende o território do covil)" → corrigido.

### Resultados (12 smokes 4-IA até T160, `--run=v3e3 --tag=smoke`, mundo padrão 144×76; não é baseline)

**Atenção à comparação:** a Etapa 2 rodou no canvas 320×84 (continente principal + especiais vazios de civs); a Etapa
3 roda no perfil padrão. O continente principal usa a mesma pegada fixa, mas os números não são 1:1.

12/12 chegaram à Ascensão e à Convergência; 12/12 TIMEOUT no T160.

| Era | BASIC ataques / golpes em cidade | INTERMEDIATE | ADVANCED |
|---|---|---|---|
| Despertar | 269 / 144 | 11 / 0 | 1 / 0 |
| Ascensão | 339 / 0 | 118 / 19 | 19 / 0 |
| Convergência | 221 / 0 | 110 / 0 | 83 / 0 |

| Espécie | Golpes em cidade | Ataques | Unid. de civ mortas | Mortes | Habilidade |
|---|---|---|---|---|---|
| Goblin | 28 | 107 | 3 | 139 | Saque 28 · 224 Ouro |
| Esqueleto | 116 | 193 | 20 | 243 | 20 erguidos · maior sítio 6 |
| Worg | 0 | 359 | 57 | 157 | 631 caças, 274 a isolado, 357 golpes com bônus |
| Aranha Gigante | 0 | 170 | 23 | 142 | 147 envenenamentos · 226 ticks, 234 dano, 8 abates |
| Troll | 0 | 52 | 6 | 26 | 44 regenerações · 129 Vida |
| Wyvern | 19 | 59 | 24 | 26 | 23 sopros · 28 atingidos (~1,2/sopro) · Chamas 44 ticks, 3 abates |
| Minotauro | 0 | 88 | 65 | 32 | 116 investidas · 892 dano · 58 empurrões, 17 bloqueados, 40 abates |
| Basilisco | 0 | 40 | 4 | 29 | 41 petrificações |
| Verme Colossal | 0 | 27 | 2 | 9 | 15 fugas subterrâneas / 15 emersões · 0 dano |
| Ancião Arbóreo | 0 | 37 | 5 | 7 | 29 lançamentos · 116 tiles · 30 enraizados |
| Devorador de Mana | 0 | 15 | 6 | 6 | Fome Arcana 1 · 6 Mana / 4 Barreira; Ruptura 0 |
| Colmeia Micótica | 0 | 24 | 2 | 14 | pico 36 tiles · 43 ticks, 43 dano, 1 abate |

**Aggro / leash (novo):**

| Tier | Aquisições | Desistências (leash) | Retornos completos | Distância da âncora na perseguição (média / máx.) | Passos além da zona |
|---|---|---|---|---|---|
| BASIC | 741 | 361 | 356 | 3,26 / 10 | 0 |
| INTERMEDIATE | 191 | 99 | 98 | 4,52 / 12 | 0 |
| ADVANCED | 64 | 26 | 25 | 4,19 / 12 | 0 |

O máximo 12 é a zona de interesse de quem caça presa especial (Wyvern na Ascensão, Verme/Devorador na Convergência);
gate de leash: **0** passos de perseguição além da zona da espécie (+1).

- Cidades deixadas em 1 HP: **0** (Etapa 2: 12). Golpes em cidade: 163 (BASIC 144 no Despertar, Wyvern 19).
- Unidades de civ mortas por monstros ecológicos: 217. Alvo por assento: golpes em cidade 43/36/49/35, ataques
  313/294/301/263, mortes 44/58/46/69 — sem viés.
- Cidades por civ (mediana): T30 1 · T50 2 · T75 2 · T100 3 · T150 **4** (Etapa 2: 3).
- População (mediana): BASIC 66 (T30) → 63 (T100) → **55** (T150); INTERMEDIATE 15 → 14; ADVANCED 7.
- Eliminações: 4, nenhuma antes do T30/T60. Gate de pesquisa: 48 civs, 0 violações. Evasões da IA: 21.
- Primeiro contato (mediana): BASIC T3, INTERMEDIATE T49, ADVANCED T93.

**Watchpoints:** Worg 57 mortes (Etapa 2: 88); expansão T150 = 4 (Etapa 2: 3); Wyvern ~1,2 alvo/sopro (~1,0);
BASIC T150 = 55 (~49); cidade em 1 HP = 0 (12). **Minotauro 65 mortes (Etapa 2: 36), 116 investidas (71)** — o
aggro de Ascensão 4 dá mais alvos legítimos à Investida; registrado, sem tuning. Devorador quase não encontra
conjurador (Fome Arcana 1, Ruptura 0) — amostra baixa no mundo padrão.

**World survey (48 mundos, padrão 1.0):** perfil `standard_1_0` 48/48, 10.944 tiles, **0** tiles de zona
Vulcânica/Cristalina, **0** terreno especial, **0** terra fora do continente principal; 4 capitais em 48/48, 0
violações de distância (menor par 12), ameaça regional 192/192, cobertura das 12 espécies 48/48, 0 violações de
segurança, 0 spawns inválidos, maior metade 62,8%; unidades iniciais 81–96 (mediana 90).

**Determinismo:** 4 seeds (0, 3, 6, 9) × 2 execuções até T110 → seção `combat_ecology` idêntica (47–67 usos de
habilidade, 29–58 aquisições de aggro por partida); só `placement_ms` (relógio) difere.

**Performance (mapa padrão real):** foco visual — primeiro cálculo 3,8 ms com 150 unidades (94 tiles focados),
recálculo por evento 1,6 ms p50 / 2,0 ms máx, no máximo uma vez por frame e só quando algo muda; minimapa —
reconstrução completa 37 ms (só mapa novo/load/resize/mudança de quadro), delta de 60 tiles 0,23 ms, polígono da
câmera 13 µs; aquisição de aggro limitada ao raio (≤ 61 tiles); turno p95 do laboratório 215–481 ms. Nada novo por
frame.

**Testes:** suíte completa **3644/3644**, 180 scripts, 485.920 asserts (Etapa 2: 3620 / 179 / 376.078 — o salto de asserts vem dos testes de terreno, que agora geram também o mundo padrão). Novo `test_v3_e3_readability.gd` (21). Ajustados às decisões desta etapa: Escavar/infecção/
evasão da Etapa 2 (`test_v3_e2_abilities`), Wyvern dentro do leash (`test_v3_ecology_foundation`), geradores
especiais pelo perfil `SPECIAL_WORLD` + 2 testes de perfil (`test_terrain_generation`), seed set 144×76
(`test_balance_lab_phase33b`).

**Save:** SAVE_VERSION continua **26** — aggro/retorno vivem em `ability_state` (já salvo), origem do Verme idem,
foco/marcadores/feedback são derivados; perfil de mundo derivado das dimensões.

---

## Etapa 4 — Ecology Habitats, Minimap Closure & Graphics Foundation

**Escopo:** fechar problemas concretos do playtest humano (minimapa, leitura de estados, raide do Goblin, iluminação
"tropical") e continuar a Combat Ecology com habitat data-driven. Fora: economia do Colonizador, Construtor, monstros
novos, worldgen, macrobiomas, multi-tile real, continentes especiais no padrão, tuning F33E/F33F.

> **Tamanho do mundo — DECIDIDO em 2026-10-10** (ver "Tamanhos de mapa" no fim deste doc): Pequeno 96×56, Médio
> 112×64 e **Grande 128×72 (padrão)**. `STANDARD_1_0` (144×76) virou perfil legado, só para saves antigos.
> Números de laboratório 144×76 (Etapa 3 em diante) **não se comparam** 1:1 com F33B/Etapa 2 (320×84).

### Minimapa (`scripts/ui/Minimap.gd`) — playtest humano sobrepõe o PASS da Etapa 3

**Causa do bug:** o "quadro adaptativo" da Etapa 3 seguia as cidades/unidades do humano (com histerese por turno e
expansão ao fundar cidade). No playtest isso parecia um minimapa congelado numa região que de repente voltava a
mostrar o continente inteiro, e a câmera fora do quadro fazia o indicador sumir. O painel era 4,6:1 com escala não
uniforme — os "tijolos" viravam faixas achatadas, lidas como grade quadrada.

**Modelo canônico agora: MAPA fixo, só o INDICADOR se move.**
- **Limites fixos:** retângulo XZ de toda a terra do mapa + meia largura do hex + 1,5 hex de margem
  (`compute_world_bounds`), calculado UMA vez por mapa (identidade = grade + seed + dimensões + nº de tiles). A
  transformação mundo → minimapa usa escala **uniforme**, centrada na área útil (letterbox). Só muda com mapa
  novo/load/reinício ou com o painel realmente redimensionado. Câmera, turnos, cidades e névoa nunca a recalculam
  (o código adaptativo foi removido inteiro).
- **Raster hexagonal:** cada pixel cai no hex de centro mais próximo (a mesma conta de `HexMetrics.world_to_axial`,
  embutida) — massa contínua de terreno, mas a costa e as transições têm o recorte hexagonal (fileiras deslocadas meio
  hex, pontas). Contorno sutil (pixel de fronteira × 0,84) só quando o hex tem ≥ 3 px; no compacto não há contorno
  (seria ruído).
- **Tamanho:** o host antigo (224×144) dava hex de ~2 px. Compacto agora **368×186** no breakpoint largo (216×116 no
  médio), proporção ~2:1 do mundo, sem tocar a faixa de atenção; botão **"+" / "−"** no canto amplia ~2,2× (hex de ~6
  px, grade hexagonal nítida) — mesmo mundo, só em escala maior (`UIShell.minimap_size_for`).
- **Cache:** mapa pixel → tile calculado por enquadramento; imagem RGBA persistente; delta da névoa repinta só os
  pixels dos tiles que mudaram. Camera move = só redraw das formas (unidades/cidades/indicador).
- **Indicador:** 4 cantos da tela por raio real da câmera contra o chão (limite de 60 perto do horizonte), na
  transformação fixa, recortado ao retângulo do mapa. Câmera inteira fora do mundo: triângulo na borda mais próxima
  apontando para ela (nunca recentraliza, nunca some, nunca geometria inválida).
- Clique/arraste: pixel → mundo pela mesma transformação, limitado ao retângulo do mapa.

### Chips de estado no card da unidade

`UnitPresenter.ecology_status_chips` alimenta a linha de chips já existente (`AEStatusChip`, design system atual):
- Estados da Combat Ecology na ordem de importância (Petrificação Parcial > Enraizado > Silenciado > Em Chamas >
  Envenenado > Abalado), tom de debuff, rótulo `Envenenado · 2t` (duração em turnos da vítima; sem duração, sem
  contador). Tooltip com o efeito mecânico REAL montado de `UnitStatusEffects.DEFS` (`effect_text`: dano do tick
  calculado para a unidade, Movimento, Defesa, silêncio) + turnos restantes + espécie de origem.
- **Barreira Arcana** (buff, sem duração: "absorve os próximos N de dano") e **Área Micótica** (debuff enquanto a
  unidade estiver no tile; números de `MonsterAbilityData`/`MonsterHazardSystem.infection_damage`).
- Buffs/debuffs V2 (Técnica, Égide, Silêncio, feitiços, Fortificada, zona ambiental, Tensão Logística) continuam na
  mesma linha.
- Mais de 6 chips: 5 visíveis + chip `+N` com os demais no tooltip; a linha quebra (flow) — o card não cresce sem
  limite.
- **Atualização por evento:** `EventBus.unit_status_changed` sai de `Unit.refresh_status_overlay` (aplicado,
  renovado, expirou, Barreira mudou, load) e do tick de dano; o `ContextRouter` reconstrói o card só se a unidade em
  foco mudou. Sem polling.
- Achado corrigido de passagem: `UnitPresenter._statuses` quebrava (`Array` → `Array[String]`) para unidade em tile não
  visível.

### Raide do Goblin

- **Saque Rápido:** todo golpe válido em cidade rouba `min(2, Ouro da vítima)` (antes até 8) — sem sorteio, nunca
  negativo; o Ouro some. Esqueleto continua sem roubo; Wyvern sem mudança.
- **Bug "Goblin parado na cidade" — reproduzido** (lab, 3 partidas até T40): o Goblin chegava ao tile de ataque
  (dentro do território, colado na cidade) gastando a ação do turno e só golpeava na fase dos monstros SEGUINTE —
  ficava um turno humano inteiro parado na cidade; o recuo depois era de 1 passo por turno. Não era ocupação do centro
  (monstro nunca entra em cidade: `compute_reachable` bloqueia).
- **Laço novo** (`MonsterAI._ecology_press_city` / `_ecology_strike_city` / `_ecology_raid_retreat`): adquire → aproxima
  → **ao chegar à posição de ataque golpeia na mesma ação** → rouba até 2 → feedback → **recua no mesmo turno** (até 2
  tiles com o Movimento base, sempre para longe da cidade e, no empate, para casa) → descanso (8) → volta à âncora.
  Posições de ataque inalcançáveis por 2 turnos seguidos → `raid_abandoned` e descanso (nunca ronda parado). Golpe
  na guarnição também encerra o raide com recuo. Regras de captura intocadas.
- **Feedback:** aro + estouro dourado na cidade, linha dourada cidade → Goblin e texto flutuante `−2 Ouro` (valor real
  se restava menos; "Saque: tesouro vazio" com 0). Em cidade de rival/IA só "Saque!" (o tesouro alheio é privado). O
  HUD de Ouro atualiza na hora (o aviso do jogador dispara o refresh da barra global).
- **Telemetria** (`combat_ecology.goblin_raids`): `city_hits`, `gold_stolen`, `hits_with_no_gold`, `retreats`,
  `abandoned` e `ended_adjacent_to_city` (Goblins da ecologia que terminaram a rodada colados numa cidade — gate do bug).

### Iluminação (WorldEnvironment + sol, `scenes/main/Main.tscn`)

Auditoria do pipeline real: o "sol tropical" vinha da soma de sol quente (1,00; 0,92; 0,78) com energia 1,1,
**saturação global 1,3** (também a principal causa do ciano extremo da água), contraste 1,12 e bloom 0,1 que lavava
areia/neve. Ambiente do céu já era baixo (0,22). Mudanças (tabela completa em `docs/GRAPHICS_SETTINGS.md`): sol quase
neutro (1,00; 0,97; 0,93) a 0,95 e −42°, ambiente 0,20, Filmic com exposição 0,95, saturação 1,08, contraste 1,06,
glow 0,4/bloom 0,02, céu temperado um pouco mais claro e menos saturado. Sem filtro azul, sem mexer na arte nem na
água. Exploração (uma execução): AgX ficou cinza/lavado, ACES ainda estourava a areia — descartados.

### Opções gráficas (`scripts/world/GraphicsQuality.gd`, detalhes em `docs/GRAPHICS_SETTINGS.md`)

Godot 4.7.1, Forward+. **Anti-aliasing:** Desativado / FXAA / **MSAA 2x (padrão)** / MSAA 4x — FXAA e MSAA
mutuamente exclusivos, TAA sempre desligado. **Sombras:** Desativadas (sol sem sombra) / Baixa (atlas 2048, filtro
duro, 2 cascatas, 60) / **Média (padrão;** 4096, PCF muito baixo, 4 cascatas, 80) / Alta (8192, PCF médio, 4
cascatas, 100). Tudo ao vivo, sem reiniciar. Persistência em `user://settings.cfg` `[graphics]` (preferência do
jogador, nunca o save de partida); inválido → padrão; botão "Restaurar padrões gráficos" na página Vídeo (não havia
fluxo de reset antes).

### Habitat ecológico (`scripts/data/MonsterHabitatProfile.gd`)

**Sinais auditados e usados** (só o que existe no mapa): tipo de terreno, recurso do tile (`mana_node` = Nódulo
Arcano; demais = valor), água em volta (Oceano/Costa/Mar Gelado), Colinas/Montanhas, distância às capitais. **Não
existem** (nada inventado): ruínas, rios, umidade/temperatura por tile, elevação contínua.

- Composição LOCAL em raio 2 (19 tiles, o central em dobro): frações `forest` (Floresta/Selva/Taiga), `open`,
  `fertile` (Pradaria/Planície), `arid` (Deserto 1, Savana 0,45), `cold`, `rugged`, `water`; derivados `edge`
  (mistura floresta/aberto), `variety` (transições), `resource`, `mana` (Nódulo a ≤ 4) e `remote` (longe das capitais).
- Perfil por espécie (`MonsterEcologyData.habitat_profile` → `PROFILES`): pesos positivos somam ~1, negativos afastam;
  score 0..1. Nenhuma regra rígida "só no terreno X".
- **Colocação:** a ordem de tiers, cotas e round-robin continuam; para cada vaga o planner junta uma janela de 24
  âncoras VÁLIDAS (todas as regras de antes: legalidade, zona das capitais, espaçamento, folga de covil, grupo) e
  sorteia uma com peso `max(score, 0,03)^3` (RNG da ecologia → determinístico). Sem nenhuma ≥ 0,4, a janela dobra até
  96 (**fallback progressivo**); escolha < 0,25 conta como fallback. Reposição: junta até 12 âncoras válidas e sorteia
  igual. Sem macro-habitat. Ameaça regional (D2), Guardiões e eventos intocados.
- Custo só no setup/reposição (sinais em cache por mapa); nada por frame ou por turno de monstro.

| Espécie | Prefere (pesos +) | Evita (pesos −) |
|---|---|---|
| Goblin | borda de floresta, terra fértil, floresta, água | frio, árido |
| Esqueleto | árido, frio, aberto, relevo | floresta, fértil |
| Worg | floresta, borda, aberto | árido, água |
| Aranha Gigante | floresta densa, água, borda | aberto, árido, frio |
| Troll | relevo, floresta, água, recurso por perto | árido |
| Wyvern | relevo/alto, aberto, frio | floresta, água |
| Minotauro | aberto, transições, fértil | floresta, relevo |
| Basilisco | árido, relevo, aberto | floresta, água, fértil |
| Verme Colossal | árido (deserto), aberto | floresta, água, relevo, frio |
| Ancião Arbóreo | floresta densa, fértil | aberto, árido, frio |
| Devorador de Mana | Nódulo Arcano por perto; fallback: região remota | — |
| Colmeia Micótica | fértil, floresta, água | árido, frio |

### Achados do laboratório sobre o "Goblin parado na cidade" (além do raide)

Telemetria nova (`ended_adjacent_to_city`) mostrou que o raide não era a única causa: (1) o aggro perseguia a
**guarnição** dentro da cidade — o BASIC não ataca luta perdida, então ficava parado ao lado; (2) perseguição de alvo
**inalcançável** (atrás da cidade, ilha) sem desistir; (3) o passo guloso de volta para casa travava em **mínimo local**
(cidade/água no meio) — Goblin "retornando" 9 turnos no mesmo tile; (4) ronda ociosa podia parar colada na cidade.
Correções (genéricas da ecologia, `MonsterAI`): `_ecology_unpursuable` (aggro nunca persegue unidade dentro de cidade;
BASIC larga alvo que virou luta claramente perdida), perseguição sem progresso por 2 turnos → `aggro_drop` + retorno,
`_ecology_detour_step` (A* do HexGrid só quando o passo guloso não acha tile mais perto, limitado a 4 destinos) e a ronda
nunca escolhe/para em tile colado numa cidade. O ataque a quem já está ao alcance não mudou (golpear a guarnição
adjacente continua sendo combate visível).

### Validação visual não-headless (duas execuções: exploração + validação final; tela 1920×1080, mundo padrão real)

Screenshots em `user://dev_artifacts/v3_e4_visual/` (`explore/` e `final/`, fora do repositório); as cenas temporárias
foram apagadas.

| # | Item | Resultado |
|---|---|---|
| 1–3 | Minimapa oeste / leste / norte / sul | PASS — continente e enquadramento idênticos em todas; só o trapézio se move, recortado na borda; câmera além do mundo mostra o marcador de borda |
| 4 | Zoom mín./máx. | PASS — trapézio pequeno/grande, mapa intacto |
| — | Fluxo (3 travessias, 75 frames) | PASS — 0 frames com mudança de limites/enquadramento/terreno |
| 5 | Aparência hex | PASS — ampliado (hex 6,45 px): grade hexagonal nítida; compacto (2,8 px): costa com recorte hexagonal/deslocado, sem escada quadrada |
| 6 | Chips de estado | PASS — `Petrificação Parcial · 1t`, `Em Chamas · 1t`, `Envenenado · 2t`; 7 estados → 5 + `+2`, quebra de linha; tooltips reais ("Perde 1 de Vida no início de cada turno (4% da Vida máxima, 1–4)." + turnos + origem) |
| 7 | Golpe do Goblin | PASS — chega e golpeia na mesma ação, Ouro 10 → 8, aro + linha dourada, "−2 Ouro" e aviso "Goblins saquearam 2 Ouro", recua 2 tiles no mesmo turno. Visto: o rótulo encostava na placa de nome da cidade → elevado (`PLUNDER_LABEL_LIFT`, não re-fotografado) |
| 8–10 | Iluminação floresta / deserto / neve / costa / unidade (antes × depois) | PASS — some o tom amarelo-alaranjado e o ciano extremo da água; areia e neve sem estourar; sombras visíveis; cores vivas (nada de cinza/dark) |
| 11–12 | AA Desativado / FXAA / MSAA 2x / 4x | PASS — `msaa_3d`/`screen_space_aa` reais trocam (0/0, 0/1, 1/0, 2/0); serrilhado da lança some com MSAA |
| 13–14 | Sombras Desativadas / Alta | PASS — sem sombra nenhuma vs. sombras nítidas; Baixa com borda dura |
| — | Página Vídeo | PASS — AA e sombras com "(padrão)", aviso de exclusividade e "Restaurar padrões gráficos" cabem no painel |

**Gate humano da iluminação** ("ainda parece continente tropical sob sol fortíssimo?"): no julgamento desta etapa,
**não** — mas a paleta base do terreno (Planície/Pradaria amareladas) é arte e não foi tocada; a palavra final é do
product owner.

### Opções gráficas — desempenho aproximado (floresta, 1920×1080, V-Sync desligado, 240 frames)

| Configuração | ms/frame | FPS |
|---|---|---|
| AA Desativado · sombras Médias | 5,39 | 185 |
| FXAA · Médias | 5,33 | 188 |
| **MSAA 2x · Médias (padrão)** | 5,32 | 188 |
| MSAA 4x · Médias | 5,33 | 188 |
| MSAA 2x · sombras Desativadas | 3,65 | 274 |
| MSAA 2x · Baixa | 4,18 | 239 |
| MSAA 2x · Média | 5,23 | 191 |
| MSAA 2x · Alta | 7,29 | 137 |

Nesta máquina o AA é praticamente gratuito; as sombras são o custo real (Alta ≈ +2 ms sobre Média). Com V-Sync ligado
o teto é o do monitor.

### Habitat — world survey (48 mundos, padrão 1.0, `--run=v3e4 --world-survey`; A/B `--no-habitat` nas mesmas seeds)

Gates: perfil `standard_1_0` 48/48, capitais OK 48/48, ameaça regional 192/192, **cobertura das 12 espécies 48/48**,
**0** violações de distância de capital (menor ADVANCED = 14), **0** spawns inválidos, 0 falta de sítios, maior metade
65,6% (uniforme: 72,2%), sítios 47–56 (média 52,8). Ecologia mais próxima da capital: mín. 7 (igual ao uniforme).

| Espécie | Sítios | Score (hab./unif.) | Sinal preferido | Sítios no sinal (hab./unif.) | Terra com o sinal | Lift (hab./unif.) | Fallback | Mesma espécie mais perto | Maior quadrante | Dist. capital mín./média | Terrenos mais comuns |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Goblin | 358 | 0,36 / 0,22 | borda de floresta | 0,54 / 0,31 | 0,32 | 1,66 / 0,96 | 11 | 14,1 | 0,46 | 7 / 16,4 | Floresta, Selva, Planície |
| Esqueleto | 363 | 0,34 / 0,15 | árido | 0,26 / 0,19 | 0,09 | 2,85 / 2,02 | 39 | 14,2 | 0,50 | 7 / 18,5 | Deserto, Neve, Gelo Eterno |
| Worg | 366 | 0,43 / 0,26 | floresta | 0,59 / 0,34 | 0,32 | 1,86 / 1,08 | 20 | 15,0 | 0,49 | 7 / 15,4 | Taiga, Selva, Floresta |
| Aranha Gigante | 361 | 0,57 / 0,23 | floresta | 0,89 / 0,35 | 0,32 | 2,78 / 1,09 | 2 | 12,9 | 0,49 | 7 / 15,6 | Selva, Taiga, Floresta |
| Troll | 185 | 0,24 / 0,17 | relevo | 0,17 / 0,07 | 0,12 | 1,47 / 0,60 | 12 | 24,6 | 0,52 | 10 / 17,7 | Taiga, Colinas, Selva |
| Wyvern | 178 | 0,39 / 0,15 | relevo | 0,49 / 0,13 | 0,12 | 4,19 / 1,10 | 43 | 23,5 | 0,56 | 10 / 17,3 | Colinas, Neve, Tundra |
| Minotauro | 180 | 0,54 / 0,22 | aberto | 0,89 / 0,31 | 0,45 | 1,99 / 0,68 | 8 | 28,0 | 0,54 | 10 / 19,3 | Planície, Neve, Estepe |
| Basilisco | 179 | 0,40 / 0,09 | árido | 0,54 / 0,10 | 0,09 | 5,79 / 1,02 | 29 | 17,1 | 0,56 | 10 / 15,1 | Deserto, Savana, Colinas |
| Verme Colossal | 92 | 0,62 / 0,10 | árido | 0,70 / 0,07 | 0,09 | 7,51 / 0,70 | 7 | 31,0 | — | 14 / 17,8 | Deserto, Savana, Estepe |
| Ancião Arbóreo | 90 | 0,73 / 0,20 | floresta | 0,98 / 0,27 | 0,32 | 3,07 / 0,84 | 0 | 45,3 | — | 14 / 20,2 | Floresta, Selva, Taiga |
| Devorador de Mana | 87 | 0,63 / 0,21 | Nódulo Arcano | 0,79 / 0,15 | 0,21 | 3,84 / 0,72 | 4 | 42,3 | — | 14 / 21,2 | Floresta, Colinas, Taiga |
| Colmeia Micótica | 93 | 0,41 / 0,18 | fértil | 0,34 / 0,12 | 0,17 | 2,00 / 0,69 | 8 | 34,9 | — | 14 / 19,3 | Floresta, Selva, Planície |

Lift = fração dos sítios na região do sinal preferido ÷ fração da terra elegível com esse sinal (1 = sorteio uniforme).
Todas as espécies ficam acima de 1,4× (uniforme: 0,6–1,1×) — agrupamento perceptível sem concentração artificial (maior
quadrante 0,46–0,56, igual ao uniforme). Troll é o mais fraco (relevo é só 12% da terra; muitos sítios em Taiga/Selva,
coerente com o perfil úmido/florestal). Fallback mais usado: Wyvern (24%, relevo raro) e Esqueleto (11%). "Neve" no
Minotauro = Neve/Tundra abertas (sinal "aberto"). Colocação: **519 ms** em média por mundo (uniforme: 373 ms), só no
setup.

### Resultados (12 smokes 4-IA até T160, `--run=v3e4 --tag=smoke`, mundo padrão 144×76; não é baseline)

12/12 chegaram à Ascensão e à Convergência; 12/12 TIMEOUT no T160. Mesmo tamanho de mapa que a Etapa 3, mas o habitat
muda onde as espécies nascem — comparação qualitativa.

| Era | BASIC ataques / golpes em cidade | INTERMEDIATE | ADVANCED |
|---|---|---|---|
| Despertar | 300 / 172 | 19 / 0 | 2 / 0 |
| Ascensão | 251 / 0 | 125 / 19 | 29 / 0 |
| Convergência | 185 / 0 | 126 / 0 | 106 / 0 |

| Espécie | Golpes em cidade | Ataques | Unid. de civ mortas | Mortes | Habilidade |
|---|---|---|---|---|---|
| Goblin | 67 | 136 | 5 | 143 | Saque 67 · 134 Ouro (2/golpe) · 0 golpes sem Ouro |
| Esqueleto | 105 | 139 | 20 | 171 | 14 erguidos |
| Worg | 0 | 302 | 38 | 157 | 533 caças, 234 a isolado |
| Aranha Gigante | 0 | 159 | 15 | 161 | 144 envenenamentos · 236 ticks, 8 abates |
| Troll | 0 | 81 | 7 | 31 | 49 regenerações · 91 Vida |
| Wyvern | 19 | 63 | 31 | 31 | 38 sopros · 44 atingidos (~1,16/sopro) · Chamas 69 ticks |
| Minotauro | 0 | 52 | 27 | 24 | 54 investidas · 417 dano · 32 empurrões, 11 bloqueados, 11 abates |
| Basilisco | 0 | 74 | 10 | 28 | 66 petrificações |
| Verme Colossal | 0 | 42 | 10 | 11 | 17 fugas / 17 emersões · 0 dano |
| Ancião Arbóreo | 0 | 25 | 1 | 7 | 23 lançamentos · 92 tiles · 24 enraizados |
| Devorador de Mana | 0 | 46 | 16 | 10 | Fome Arcana 5 · 30 Mana / 4 Barreira; Ruptura 1 |
| Colmeia Micótica | 0 | 24 | 2 | 7 | pico 36 tiles · 21 ticks |

**Raide do Goblin:** 67 golpes em cidade (Etapa 3: 28), **67 recuos no mesmo turno**, 134 Ouro roubados (Etapa 3: 224
com até 8/golpe), 0 golpes com tesouro vazio, 75 raides abandonados (Goblin sem posição de ataque alcançável — antes
ficava parado com o alvo), rodadas terminadas com Goblin colado numa cidade **99 → 34** (maioria lutando contra unidade
adjacente ou contornando a cidade em movimento), **4** delas em estado de raide.

**Watchpoints:** Minotauro 27 abates / 54 investidas (Etapa 3: 65 / 116 — com o habitat ele nasce em terra aberta;
sem tuning). Devorador de Mana: Fome Arcana 5 (Etapa 3: 1), Ruptura 1 (0) — habitat perto de Nódulo Arcano aproxima
conjuradores, como previsto; habilidade sem buff. Worg 38 abates (57). Cidades em 1 HP: **1** (Etapa 3: 0). Wyvern
~1,16 alvo/sopro (~1,2).

- Expansão (mediana de cidades): T30 1 · T50 2 · T75 2 · T100 3 · T150 4 (igual à Etapa 3).
- População BASIC (mediana): 65 (T30) → 62 (T100) → 55 (T150); INTERMEDIATE 15 → 14; ADVANCED 7.
- Gate de pesquisa: 48 civs, 0 violações. Evasões da IA: 7. Leash: 0 passos além da zona em todos os tiers.
- **Eliminações: 6, duas antes do T30 (F33B-003 T25, F33B-011 T19)** — ambas por **captura da capital por IA rival**
  (PvP), não por monstros (a ecologia fez 1 e 6 ataques nessas civs). A/B `--no-habitat` nas duas seeds: a 011 ainda
  perde uma civ no T32 e a 003 não — trajetória caótica da IA, não causada pela ecologia. Achado para o product owner;
  nenhum tuning de IA nesta etapa.

### Determinismo

Seeds 0 e 3, duas execuções até T110 → seção `combat_ecology` idêntica (57–70 usos de habilidade, 68–75 aquisições de
aggro por partida). Teste: mesma seed/config → mesma distribuição ecológica (e habitat > uniforme no score médio).

### Desempenho

- Minimapa (mapa padrão real, headless): raster do compacto 352×170 ≈ 97 ms e do ampliado 793×393 ≈ 378 ms **uma vez por
  mapa** (cache por tamanho; alternar o botão depois: 19–38 ms, só repintura); delta da névoa de 60 tiles 0,06 ms;
  indicador 15–20 µs. A câmera nunca refaz terreno nem enquadramento. O primeiro "ampliar" de cada mapa custa ~0,4 s —
  candidato a pré-cálculo no carregamento se incomodar no playtest.
- Habitat: +146 ms no setup (519 vs 373 ms); reposição junta 12 amostras por tentativa; nada por frame/turno.
- Chips: por evento (`unit_status_changed`), sem polling. Turno p95 do laboratório: 189–486 ms (Etapa 3: 215–481).

### Testes

Suíte completa **3666/3666**, 181 scripts, 488.262 asserts (Etapa 3: 3644 / 180 / 485.920). Novo `test_v3_e4_habitats_minimap_graphics.gd` (22 testes): Saque de exatamente até 2 (10→8→6, 1→0, nunca negativo,
sem sorteio), Esqueleto sem roubo, laço aproxima-golpeia-recua sem terminar colado, desistência sem posição de ataque,
aggro não persegue guarnição e ocioso não para colado na cidade, perseguição inalcançável abandonada, texto do feedback
(valor só na cidade do humano), telemetria do raide, chip de cada estado (nome, duração, tooltip canônico, expiração),
números canônicos, Barreira/Área Micótica, sinal de atualização, formato `· 2t` e `+N`, minimapa fixo na varredura da
câmera, marcador de borda, raster hexagonal (pontas estreitas, fileira deslocada meio hex), delta da névoa sem refazer
layout, persistência/reset/fallback gráfico, AA real e exclusivo, sombras com parâmetros distintos, scores de habitat
por terreno sintético, determinismo e habitat > uniforme. Ajustados às decisões: Saque 2 (`test_v3_e2_abilities`),
feedback sem valor para cidade não humana e API do minimapa fixo (`test_v3_e3_readability`, `test_minimap`), formato do
chip (`test_ui_foundation`). Achado de isolamento corrigido no próprio teste novo do minimapa (emitia
`TurnManager.turn_changed` global e contaminava `test_selection_manager`/`test_v2_ai_strategy`).

### Save / migração

**SAVE_VERSION continua 26.** Opções gráficas são preferência em `user://settings.cfg` (nunca no save de partida).
Habitat só decide ONDE os sítios nascem (sítios/unidades já salvos). `raid_stuck`/`pursuit_stuck` viajam em
`ability_state` (já salvo); minimapa/chips/feedback são derivados.

### Herói Corrompido substitui a Colmeia Micótica (2026-10-04)

A pedido do usuário, a Colmeia ("só fica parada existindo") saiu do bestiário, e os assets
dela foram apagados. O `corrupted_hero` ocupa a mesma vaga ADVANCED:
- mesmos stats de combate (ataque 8, defesa 6, vida 34) e movimento 2;
- sem o `patrol_radius_cap` 1, então segue o perfil ADVANCED padrão por era (territorial no
  Despertar e na Ascensão, ativo na Convergência; aggro em quem encosta);
- habilidade **Bloqueio com Escudo** (`shield_block`, passiva): 20% de chance de negar todo o
  dano de um ataque comum recebido, com rolagem determinística por hash (não consome o RNG da
  ecologia). O revide segue normal, e o bloqueio toca o clipe `Hero_Block` e mostra
  "Bloqueou!";
- 1,95 m em jogo (`_ROOT` 0,73), menor que o Troll;
- modelo `assets/generated/corrupted_heroes/corrupted_hero_v1` (Hero_Idle/Walk/Attack);
- habitat herdado da Colmeia (provisório);
- save antigo: `MonsterDatabase.LEGACY_KINDS` (`mycotic_hive` → `corrupted_hero`).

A Contaminação Micótica (`MonsterHazardSystem`, `MYCOTIC_CONTAMINATION`) ficou **dormente**:
nenhuma espécie a tem. O código e os testes de infecção (que passam a âncora direto) foram
mantidos para reuso. As tabelas de telemetria e balanceamento acima ainda citam a Colmeia;
elas são histórico e só mudam quando o laboratório rodar de novo.

## Tamanhos de mapa (2026-10-10)

Proposta do product owner, aplicada: o oceano grande existia para aventuras navais e outros continentes, que não
existem; cada tamanho é "uma versão menor do mesmo continente" na lógica de biomas. Código: `scripts/world/WorldProfile.gd`
(perfis), `HexGrid.generate_map` / `_main_half_extents` (área reservada e escala do ruído), seletor em
`GameSetupScreen`. Testes: `test/unit/test_map_sizes.gd`.

| Tamanho | Grade | Área reservada | Terra (média 4 seeds) | Água | Geração |
|---|---|---|---|---|---|
| Pequeno | 96 × 56 | 72 × 44 | 1.698 | 68,4% | 1,0 s |
| Médio | 112 × 64 | 84 × 52 | 2.352 | 67,2% | 1,4 s |
| **Grande (padrão)** | 128 × 72 | 96 × 60 | 3.113 | 66,2% | 1,9 s |
| legado 144 × 76 | 144 × 76 | 96 × 60 | 3.113 | 71,5% | 2,0 s |

- **Área reservada por tamanho** (`WorldProfile.main_frame`): substitui a pegada fixa 96×60 (`TitleScreen.MAIN_ZONE_SIZE`
  e `HexGrid.MAIN_ZONE_HALF_*`, removidas) no falloff da borda, na zona principal, na latitude (clima), na distância
  mínima dos covis ao centro e na elipse de origem dos rivais (fixtures de teste continuam como antes).
- **Mesmo continente em escala:** `noise_scale = 96 / largura da área` multiplica as frequências de todo o ruído da
  geração e divide `warp_strength`. Mesma seed = mesmo desenho e mesma mistura de biomas (medido: cada bioma fica a
  ±2 pontos percentuais do Grande; o esqueleto terra/água em pontos normalizados coincide > 85%).
- **O Grande novo é o MESMO continente do 144×76** (escala 1, mesma área): mesma terra e mesmos biomas, só com 16 em
  vez de 24 colunas de oceano em volta e menos Mar Gelado.
- **Saves antigos:** 144×76 e 320×84 continuam registrados (perfis legados) e regeneram o mundo idêntico — teste com
  hash do terreno capturado antes da mudança. Dimensões desconhecidas seguem a regra antiga (fixture abaixo de 144×76).
- **Já escalam sozinhos:** covis (por terra elegível), recursos, distância entre capitais (12). Rivais: 1–3 em todos.
- **Pendência registrada (fora deste escopo):** a Costa cobre ~43% do mapa, inclusive longe da terra — a reclassificação
  Oceano→Costa parece se espalhar demais; investigar à parte.


## Embarque automático: a tropa vira barquinho (2026-10-10)

Pedido do product owner: "quando uma tropa entra na água, ela vira o barquinho e quando sai da água vira a tropa de
novo", com transições suaves. Decisões dele: **automático**, **desde o início** (sem tecnologia), **custo normal** da
água, **IA também**. Testes: `test/unit/test_embark_boats.gd`.

**Regras**
- **Quem embarca** (`Unit.can_embark()`): toda unidade de civilização que anda pelo chão — tropas, colonos,
  construtores, magos, retinue, invocações, o Mestre das Sombras e o Cavaleiro de Grifo (que não voa mais). Monstros
  neutros não embarcam; quem voa (perfil `FLYING` ou voo legado) sobrevoa.
- **Movimento:** Oceano, Mar Gelado e Costa (`HexTileData.can_be_embarked_on()`) viram terreno atravessável ao custo
  do tile (1). Lava e montanha continuam bloqueando. Um mesmo trajeto pode ir terra → água → terra (a antiga regra
  "terra só como último passo" do embarque manual saiu).
- **Estado derivado do tile:** `Unit.embarked` é true sempre que uma unidade que embarca está na água. Um único ponto
  liga e desliga: `HexGrid.move_unit` / `HexGrid.sync_embarked` (andar, teleporte, spawn, load do save, terreno
  transformado embaixo da unidade). O campo continua no save, mas o load re-deriva.
- **Na água:** não ataca (central em `CombatResolver.can_attack_unit` / `can_attack_city` / `resolve` /
  `resolve_city_attack`, vale para a IA), não fortifica (entrar na água desfaz), não funda cidade, não conjura nem usa
  técnica que consome ação, não constrói, não evolui. Pode ser atacada normalmente. Explorar continua ligado: a rota
  pode cruzar água, o alvo é sempre terra.
- **Técnicas de deslocamento** (Carga, Retirada) e Portal/teleporte continuam só por terra
  (`unit_reachable(..., allow_water = false)`).

**API de rota** (`HexGrid`): `compute_reachable` / `compute_path` têm o parâmetro `amphibious` (antes `embarked`).
`unit_path(unit, dest)` e `unit_reachable(unit)` usam as regras da unidade e são o caminho padrão para seleção, marcha,
sítio de cidade e IA. `unit_landing_reachable(unit)` é para as escolhas "gulosas" da IA (melhor tile por pontuação): a
rota pode passar pela água, mas o destino é terra (exceto para quem já está no mar). Para se aproximar de um alvo, a IA
prefere a casa vizinha em terra (`RivalAI.move_unit_toward`) e, embarcada, não tenta atacar.

**Visual** (`Unit.gd`, seção "EMBARQUE AUTOMÁTICO: o barquinho"; arte em `UnitArtCatalog.boat_scene_path`):
- Um barco por raça (`assets/generated/<raça>/<raça>_embark_boat_v1/*.tscn`, manifesto
  `assets/generated/embark_boats_manifest.json`). A cena já aplica a escala de mapa 0,52; a origem é a linha d'água;
  o modelo gira 180° (frente −Z → +Z). Montado sob demanda na primeira vez que a unidade entra na água.
- Na água a unidade fica no plano d'água visível (`HexGrid.LIQUID_LEVEL_Y`), via `world_surface_for_coord`.
- A troca acontece **no meio do passo** que cruza a margem (`walk_path` recebe a flag de água de cada waypoint):
  escala cruzada de 0,25 s com curva `TRANS_BACK` (a tropa encolhe, o barco cresce), sem transparência. No fim, o lado
  escondido sai da renderização e o `AnimationPlayer` dele para. Spawn, load e unidade fora da visão trocam na hora.
- Animação do barco: `idle` e `walk` em loop, crossfade de 0,2 s, guiados pelo estado de andar da unidade. A barra de
  vida e o ícone sobem acima do mastro enquanto a unidade está de barco, se o barco for mais alto que a tropa. O
  emblema de Escola dos magos continua visível.

**IA com barco — A/B no laboratório 4-IA** (12 partidas, `--matches=0-11`, mapa Grande 128×72, mesmas seeds; "sem barco"
= `can_embark()` forçado a false só para a medição; dados em `user://balance/embark/{noembark,smoke}`; não é baseline):

| | Sem barco | Com barco |
|---|---|---|
| Fins | 8 timeout, 3 Transcendência, 1 Supremacia | 7 timeout, 5 Transcendência |
| Turno final médio | 230,8 | 227,8 |
| Cidades no fim (soma das 4 civs) | 15,3 | 16,7 |
| Cidades capturadas | 7,3 | 6,7 |
| Unidades mortas | 63,5 | 64,1 |
| Turno p95 (mediana das partidas) | 485 ms | 503 ms |
| Pior turno | 1,49 s | 1,13 s |

Nenhuma partida travou, nenhum laço de IA; a IA usa a água como atalho e funda um pouco mais de cidades. Custo de CPU
dentro do ruído (+4% no p95).
