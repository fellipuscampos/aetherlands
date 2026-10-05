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

> **Tamanho do mundo padrão — decisão de produto pendente.** `STANDARD_1_0` = **144×76** (definido na Etapa 3) **não
> é decisão final**: o product owner pode manter, aumentar ou restaurar outro tamanho. Esta etapa não mexeu no tamanho.
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
