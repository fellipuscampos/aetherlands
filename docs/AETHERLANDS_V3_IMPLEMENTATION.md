# Aetherlands V3 — Implementação

Documento técnico do que foi de fato construído na V3. A direção canônica (o **porquê**) fica em
`docs/# Aetherlands V3 — Visão e Direção.md`; aqui só o **o quê** e o **como**. Documento vivo: cada
etapa acrescenta sua seção. Baseline anterior à V3: F33D + F33D-R (3546/3546 testes, SAVE_VERSION 24);
F33E/F33F adiadas porque a V3 altera gameplay o bastante para invalidar uma baseline final agora.

---

## V3 — Combat Ecology

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

**Tier ≠ papel.** Covis regionais, Guardiões Troll e guardiões do Relicário mantêm o papel e o
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
- **Só a ecologia usa habilidades.** Ameaça regional, Guardião Troll e guardiões do Relicário mantêm as regras D2/D3
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
