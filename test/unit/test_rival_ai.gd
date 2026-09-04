extends GutTest

## Cobre a melhoria da IA rival: avaliar risco antes de atacar
## (CombatResolver.predict() + RivalAI.is_favorable_attack), a cura por
## guarnicao que da sentido a recuar (GameManager._heal_if_garrisoned), a
## regeneracao passiva do Ent em qualquer lugar (GameManager._apply_regen),
## a fog of war propria (so mira em unidades inimigas VISIVEIS agora, mas
## lembra de cidades inimigas ja escoutadas) e a coordenacao tatica basica
## (unidade a distancia sozinha nao avanca sem escolta corpo-a-corpo).

var hex_grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _created_units: Array[Unit] = []
var _original_hex_grid: HexGrid
var _original_human_player: PlayerData

func before_each():
	_original_hex_grid = GameManager.hex_grid
	_original_human_player = GameManager.human_player
	_created_units = []

	hex_grid = HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	for dir in HexGrid.NEIGHBOR_DIRS:
		hex_grid.tiles[center + dir] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	# Linha extra de tiles pra dar espaco a testes de fog of war/escolta que
	# precisam de distancias maiores que 1 (o anel de vizinhos acima so
	# alcanca ate 1 tile do centro).
	for i in range(2, 7):
		hex_grid.tiles[Vector2i(i, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	human = PlayerData.new(CivilizationData.new())
	rival = PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(human, rival) # _choose_target agora exige guerra pra mirar em alguem
	GameManager.hex_grid = hex_grid
	GameManager.human_player = human

func after_each():
	GameManager.hex_grid = _original_hex_grid
	GameManager.human_player = _original_human_player
	for unit in _created_units:
		if is_instance_valid(unit):
			unit.queue_free()
	hex_grid.queue_free()

func _make_unit(kind: String, player: PlayerData, coord: Vector2i) -> Unit:
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit(kind), player, coord)
	player.units.append(unit)
	hex_grid.units_by_coord[coord] = unit
	_created_units.append(unit)
	return unit

func test_predict_matches_actual_resolve_damage():
	var attacker = _make_unit("warrior", rival, Vector2i(0, 0))
	var defender = _make_unit("warrior", human, Vector2i(1, 0))
	var predicted = CombatResolver.predict(attacker, defender, hex_grid)
	var hp_before = defender.hp

	CombatResolver.resolve(attacker, defender, hex_grid)

	assert_almost_eq(hp_before - defender.hp, predicted.damage_to_defender, 0.01)

## RivalAI.begin_turn()/act_for_unit() sao a MESMA logica de take_turn(), so
## separada em duas partes pra GameManager poder espalhar por frames (ver
## GameManager.stagger_ai_turns, pedido do usuario: "Civilization... em
## pequenos grupos... diminui o lag na passada de turnos") — confirma que a
## dupla continua produzindo o mesmo resultado de antes: ataque letal
## favoravel executa normalmente atraves delas.
func test_begin_turn_and_act_for_unit_together_match_take_turn_behavior():
	var attacker = _make_unit("warrior", rival, Vector2i(0, 0))
	var defender = _make_unit("warrior", human, Vector2i(1, 0))
	defender.hp = 0.5 # qualquer golpe mata

	var visible = RivalAI.begin_turn(rival, hex_grid, human)
	RivalAI.act_for_unit(attacker, hex_grid, rival, human, visible)

	assert_ne(hex_grid.get_unit_at(Vector2i(1, 0)), defender, "ataque letal deveria ter derrotado o defensor")

func test_favorable_attack_is_true_for_lethal_hit():
	var attacker = _make_unit("warrior", rival, Vector2i(0, 0))
	var defender = _make_unit("warrior", human, Vector2i(1, 0))
	defender.hp = 0.5 # qualquer golpe mata

	assert_true(RivalAI.is_favorable_attack(attacker, defender, hex_grid))

func test_favorable_attack_is_false_when_attacker_would_die_to_counter():
	var attacker = _make_unit("settler", rival, Vector2i(0, 0)) # sem ataque de verdade
	var defender = _make_unit("warrior", human, Vector2i(1, 0))
	attacker.hp = 0.5 # qualquer contra-ataque mata

	assert_false(RivalAI.is_favorable_attack(attacker, defender, hex_grid))

func test_garrisoned_unit_heals_up_to_max_hp():
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	var warrior = _make_unit("warrior", rival, Vector2i(0, 0))
	warrior.hp = 1.0
	var expected = min(1.0 + warrior.unit_data.max_hp * GameManager.GARRISON_HEAL_FRACTION, warrior.unit_data.max_hp)

	GameManager._heal_if_garrisoned(warrior)

	assert_almost_eq(warrior.hp, expected, 0.01)

func test_unit_outside_own_city_does_not_heal():
	var warrior = _make_unit("warrior", rival, Vector2i(0, 0))
	warrior.hp = 1.0

	GameManager._heal_if_garrisoned(warrior)

	assert_eq(warrior.hp, 1.0)

## Fortificar (Unit.fortified, pedido do usuario: "se você tiver ferido,
## você fica se curando um pouco todo turno") — cura passiva fora de
## cidade, mais fraca que guarnicao de proposito (GameManager.
## FORTIFY_HEAL_FRACTION < GARRISON_HEAL_FRACTION).
func test_fortified_unit_outside_city_heals_passively():
	var warrior = _make_unit("warrior", rival, Vector2i(0, 0))
	warrior.hp = 1.0
	warrior.fortified = true
	var expected = min(1.0 + warrior.unit_data.max_hp * GameManager.FORTIFY_HEAL_FRACTION, warrior.unit_data.max_hp)

	GameManager._heal_if_garrisoned(warrior)

	assert_almost_eq(warrior.hp, expected, 0.01)

## Guarnicao numa cidade PROPRIA cura mais forte que so fortificar — nao
## deveria somar os dois (double-heal), so a maior das duas vale.
func test_garrisoned_and_fortified_unit_heals_only_via_garrison_amount():
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	var warrior = _make_unit("warrior", rival, Vector2i(0, 0))
	warrior.hp = 1.0
	warrior.fortified = true
	var expected = min(1.0 + warrior.unit_data.max_hp * GameManager.GARRISON_HEAL_FRACTION, warrior.unit_data.max_hp)

	GameManager._heal_if_garrisoned(warrior)

	assert_almost_eq(warrior.hp, expected, 0.01, "guarnicao deveria valer, nao somar com a cura de fortificar por cima")

## Ent (UnitData.regen_fraction, GameManager._apply_regen): diferente da
## cura por guarnicao, regenera em QUALQUER lugar — nao precisa estar
## dentro da propria cidade nem perto de nenhuma.
func test_regenerating_unit_heals_anywhere_without_a_city():
	var treant = _make_unit("treant", rival, Vector2i(0, 0))
	treant.hp = 1.0
	var expected = min(1.0 + treant.unit_data.max_hp * treant.unit_data.regen_fraction, treant.unit_data.max_hp)

	GameManager._apply_regen(treant)

	assert_almost_eq(treant.hp, expected, 0.01)

func test_regen_never_exceeds_max_hp():
	var treant = _make_unit("treant", rival, Vector2i(0, 0))
	treant.hp = treant.unit_data.max_hp - 0.1

	GameManager._apply_regen(treant)

	assert_almost_eq(treant.hp, treant.unit_data.max_hp, 0.01)

func test_unit_without_regen_fraction_does_not_heal_passively():
	var warrior = _make_unit("warrior", rival, Vector2i(0, 0))
	warrior.hp = 1.0

	GameManager._apply_regen(warrior)

	assert_eq(warrior.hp, 1.0, "so o Ent (regen_fraction > 0) deveria curar sozinho fora de uma cidade")

func test_unit_in_enemy_city_does_not_heal():
	hex_grid.found_city(Vector2i(0, 0), human, "Capital Humana")
	var warrior = _make_unit("warrior", rival, Vector2i(0, 0))
	warrior.hp = 1.0

	GameManager._heal_if_garrisoned(warrior)

	assert_eq(warrior.hp, 1.0)

func test_choose_target_ignores_units_outside_vision():
	var scout = _make_unit("warrior", rival, Vector2i(0, 0))
	_make_unit("warrior", human, Vector2i(3, 0)) # existe, mas fora da "visao" simulada
	var empty_visible := {}

	var target = RivalAI._choose_target(scout, hex_grid, rival, human, empty_visible)

	assert_null(target, "sem visao nem cidade conhecida, nao deveria haver alvo")

func test_choose_target_finds_visible_unit():
	var scout = _make_unit("warrior", rival, Vector2i(0, 0))
	var enemy = _make_unit("warrior", human, Vector2i(3, 0))
	var visible := {Vector2i(3, 0): true}

	var target = RivalAI._choose_target(scout, hex_grid, rival, human, visible)

	assert_eq(target, enemy.coord)

## Diplomacia (Diplomacy.gd): em paz, a IA nunca mira no jogador com quem
## fez as pazes, mesmo com um alvo perfeitamente visivel no alcance.
func test_choose_target_returns_null_when_at_peace():
	var scout = _make_unit("warrior", rival, Vector2i(0, 0))
	_make_unit("warrior", human, Vector2i(3, 0))
	var visible := {Vector2i(3, 0): true}
	var accepted = Diplomacy.propose_peace(human, rival) # 1 unidade cada lado, empate aceita
	assert_true(accepted, "pre-condicao do teste: paz devia ser aceita")

	var target = RivalAI._choose_target(scout, hex_grid, rival, human, visible)

	assert_null(target, "em paz, a IA nao deveria mirar no jogador humano")

func test_known_enemy_city_remains_target_after_leaving_vision():
	var scout = _make_unit("warrior", rival, Vector2i(0, 0))
	hex_grid.found_city(Vector2i(3, 0), human, "Cidade Inimiga")
	rival.known_enemy_cities[Vector2i(3, 0)] = true
	var empty_visible := {} # cidade fora de visao agora, mas ja escoutada antes

	var target = RivalAI._choose_target(scout, hex_grid, rival, human, empty_visible)

	assert_eq(target, Vector2i(3, 0), "cidade ja escoutada continua sendo alvo mesmo fora de visao")

func test_scout_enemy_cities_records_visible_city():
	hex_grid.found_city(Vector2i(3, 0), human, "Cidade Inimiga")
	var visible := {Vector2i(3, 0): true}

	RivalAI._scout_enemy_cities(rival, human, visible)

	assert_true(rival.known_enemy_cities.has(Vector2i(3, 0)))

func test_has_melee_escort_nearby_true_when_ally_close():
	var archer = _make_unit("archer", rival, Vector2i(0, 0))
	_make_unit("warrior", rival, Vector2i(1, -1)) # a 1 tile, dentro do ESCORT_RANGE

	assert_true(RivalAI._has_melee_escort_nearby(archer, rival))

func test_has_melee_escort_nearby_false_when_alone():
	var archer = _make_unit("archer", rival, Vector2i(0, 0))

	assert_false(RivalAI._has_melee_escort_nearby(archer, rival))

func test_has_melee_escort_nearby_false_when_ally_too_far():
	var archer = _make_unit("archer", rival, Vector2i(0, 0))
	_make_unit("warrior", rival, Vector2i(6, 0)) # bem longe, fora do ESCORT_RANGE

	assert_false(RivalAI._has_melee_escort_nearby(archer, rival))

func test_lone_ranged_unit_holds_position_without_escort():
	var archer = _make_unit("archer", rival, Vector2i(0, 0))
	_make_unit("warrior", human, Vector2i(5, 0))
	var visible := {Vector2i(5, 0): true}

	RivalAI._handle_attacker(archer, hex_grid, rival, human, visible)

	assert_eq(archer.coord, Vector2i(0, 0), "arqueiro sozinho nao deveria avancar sem escolta")

func test_ranged_unit_advances_with_melee_escort_nearby():
	var archer = _make_unit("archer", rival, Vector2i(0, 0))
	_make_unit("warrior", rival, Vector2i(1, -1)) # escolta por perto, fora do caminho ate o alvo
	_make_unit("warrior", human, Vector2i(5, 0))
	var visible := {Vector2i(5, 0): true}

	RivalAI._handle_attacker(archer, hex_grid, rival, human, visible)

	assert_ne(archer.coord, Vector2i(0, 0), "com escolta por perto, arqueiro deveria avancar normalmente")

## Civilizacoes de fantasia (CivilizationData.race, ver GameManager.
## RIVAL_CIVS): cada raca com tropa propria (UnitDatabase.RACE_UNIQUE_KIND)
## ve essa tropa no proprio pool de producao, mas so a sua — um anao nunca
## sorteia Berserker da Horda, e uma civ sem raca reconhecida nenhuma (um rival
## hipotetico sem `race`) nunca sorteia tropa racial nenhuma.
func test_military_kinds_for_includes_the_racial_unique_unit():
	var dwarf_civ := CivilizationData.new()
	dwarf_civ.race = "dwarf"
	var dwarf_player := PlayerData.new(dwarf_civ)

	assert_true("dwarf_axeguard" in RivalAI._military_kinds_for(dwarf_player))

func test_military_kinds_for_does_not_leak_other_races_unique_unit():
	var dwarf_civ := CivilizationData.new()
	dwarf_civ.race = "dwarf"
	var dwarf_player := PlayerData.new(dwarf_civ)

	var kinds = RivalAI._military_kinds_for(dwarf_player)
	assert_false("orc_berserker" in kinds)
	assert_false("elf_ranger" in kinds)

func test_military_kinds_for_has_no_racial_unit_without_a_race():
	var human_civ := CivilizationData.new() # race = "" (padrao)
	var human_without_race := PlayerData.new(human_civ)

	var kinds = RivalAI._military_kinds_for(human_without_race)
	assert_false("dwarf_axeguard" in kinds)
	assert_false("orc_berserker" in kinds)
	assert_false("elf_ranger" in kinds)

## Regressao de integracao: com 2+ cidades e o predio de treino ja pronto,
## um rival orc escolhe Berserker da Horda via decide_production (nao so a
## lista de candidatos em si, o fluxo completo ate city.production_item).
## Desde a Fase 1 (decide_production pontuado, deterministico — nao mais
## um sorteio aleatorio), NAO faz mais sentido rodar em loop esperando a
## sorte favorecer a tropa racial: mesmo estado sempre da a mesma
## pontuacao. Berserker da Horda exige o Quartel construido (fallback de
## treino pra tropa racial sem predio proprio, ver BuildingDatabase.
## building_that_trains) — sem ele nunca vira candidato, entao a cidade
## precisa ja "ter" o predio pronto pra este teste fazer sentido (simular
## turnos de producao de verdade ate completar o Quartel esta fora do
## escopo deste teste).
func test_decide_production_can_pick_the_racial_unit_for_that_race():
	var orc_civ := CivilizationData.new()
	orc_civ.race = "orc"
	var orc_player := PlayerData.new(orc_civ)
	var city_a = hex_grid.found_city(Vector2i(0, 0), orc_player, "Cidade A")
	hex_grid.found_city(Vector2i(5, 0), orc_player, "Cidade B") # 2 cidades: sai do ramo "sempre colonizador"
	city_a.buildings["barracks"] = true

	RivalAI.decide_production(orc_player, hex_grid, human)

	assert_eq(city_a.production_item, "orc_berserker", "com o Quartel pronto e nenhuma outra tropa em vantagem, o rival orc deveria preferir a propria tropa exclusiva (empate quebrado por SCORE_RACIAL_UNIT_TIE_BREAK)")

## Roadmap "Parte C" (composicao de exercito), C1 — _role_counts/
## _role_gap_bonus/hierarquia de pesos em _score_production_candidate.
## Papeis vem de ArmyComposition.roles_for_kind (ver test_army_composition.
## gd pra cobertura da derivacao em si); aqui so o uso dentro de RivalAI.

func test_role_counts_is_zero_for_every_role_with_no_units():
	var counts := RivalAI._role_counts(rival)
	for role in ArmyComposition.ROLES:
		assert_eq(counts[role], 0, role)

func test_role_counts_multi_role_unit_counts_toward_every_role_it_has():
	_make_unit("cavalry", rival, Vector2i(0, 0)) # ArmyComposition: [melee, cavalry]
	var counts := RivalAI._role_counts(rival)
	assert_eq(counts[ArmyComposition.ROLE_MELEE], 1)
	assert_eq(counts[ArmyComposition.ROLE_CAVALRY], 1)
	assert_eq(counts[ArmyComposition.ROLE_RANGED], 0)
	assert_eq(counts[ArmyComposition.ROLE_SIEGE], 0)

func test_role_gap_bonus_is_zero_for_candidate_with_no_role():
	var counts := RivalAI._role_counts(rival)
	assert_eq(RivalAI._role_gap_bonus("walls", counts), 0.0)
	assert_eq(RivalAI._role_gap_bonus("barracks", counts), 0.0)

func test_role_gap_bonus_decreases_monotonically_as_role_count_grows():
	var counts := {ArmyComposition.ROLE_MELEE: 0, ArmyComposition.ROLE_RANGED: 0, ArmyComposition.ROLE_CAVALRY: 0, ArmyComposition.ROLE_SIEGE: 0}
	assert_almost_eq(RivalAI._role_gap_bonus("warrior", counts), 1.0, 0.001)
	counts[ArmyComposition.ROLE_MELEE] = 1
	assert_almost_eq(RivalAI._role_gap_bonus("warrior", counts), 0.5, 0.001)
	counts[ArmyComposition.ROLE_MELEE] = 2
	assert_almost_eq(RivalAI._role_gap_bonus("warrior", counts), 1.0 / 3.0, 0.001)
	counts[ArmyComposition.ROLE_MELEE] = 3
	assert_almost_eq(RivalAI._role_gap_bonus("warrior", counts), 0.25, 0.001)

func test_role_gap_bonus_takes_max_across_roles_not_sum():
	# cavalry = [melee, cavalry]: exercito cheio de melee mas zero cavalaria
	# deveria pontuar pela lacuna de CAVALARIA (maior), nao a soma das duas.
	var counts := {ArmyComposition.ROLE_MELEE: 10, ArmyComposition.ROLE_RANGED: 0, ArmyComposition.ROLE_CAVALRY: 0, ArmyComposition.ROLE_SIEGE: 0}
	assert_almost_eq(RivalAI._role_gap_bonus("cavalry", counts), 1.0, 0.001, "lacuna de cavalaria (0 unidades) deveria dominar, nao a soma com a lacuna de melee (ja cheia)")

## Hierarquia de pesos (ver comentario de SCORE_WEIGHT_ROLE_GAP em RivalAI.
## gd): deficit militar maximo sozinho (score 2.0) vence ameaca maxima +
## role gap maximo combinados sem deficit (score 1.5) — valores exatos, nao
## so a desigualdade em prosa. "barracks" (predio de TREINO, sem papel
## proprio — roles_for_kind so cobre kinds de UNIDADE) isola o termo de
## deficit sem contribuicao de role gap nenhuma, exatamente como o proprio
## _production_candidates mistura predio de treino e unidade no mesmo ramo
## militar do score.
func test_score_production_candidate_military_deficit_alone_beats_threat_plus_role_gap_combined():
	var empty_counts := {ArmyComposition.ROLE_MELEE: 0, ArmyComposition.ROLE_RANGED: 0, ArmyComposition.ROLE_CAVALRY: 0, ArmyComposition.ROLE_SIEGE: 0}
	var deficit_alone := RivalAI._score_production_candidate("barracks", 0.0, 0.0, 1.0, empty_counts)
	var threat_and_role_gap := RivalAI._score_production_candidate("warrior", 0.0, 1.0, 0.0, empty_counts)
	assert_almost_eq(deficit_alone, 2.0, 0.001)
	assert_almost_eq(threat_and_role_gap, 1.5, 0.001)
	assert_gt(deficit_alone, threat_and_role_gap, "deficit militar real deveria sempre vencer ameaca+composicao combinados no maximo")

## Integracao: exercito so com corpo-a-corpo (warrior) deveria preferir
## treinar algo a distancia (papel ausente) em vez de mais um warrior,
## quando os outros termos do score empatam entre os candidatos. Torre dos
## Sabios (unico predio SEM gate de tecnologia, ver comentario de City.
## _tech_unlocked_for_building) e construida de proposito pra remover o
## unico concorrente de ECONOMY_GAP (1.5) que dominaria os dois candidatos
## militares nesse cenario sem ameaca/deficit — sobra so warrior vs archer,
## decidido pelo role gap.
func test_decide_production_prefers_missing_role_when_otherwise_tied():
	var city_a = hex_grid.found_city(Vector2i(0, 0), rival, "Cidade A")
	hex_grid.found_city(Vector2i(5, 0), rival, "Cidade B") # 2 cidades: sai do ramo "sempre colonizador"
	city_a.buildings["sages_tower"] = true
	city_a.buildings["archery_range"] = true
	rival.researched_techs["arquearia"] = true # libera has_unlocked("archer")
	_make_unit("warrior", rival, Vector2i(1, 0))
	_make_unit("warrior", rival, Vector2i(2, 0))

	RivalAI.decide_production(rival, hex_grid, human)

	assert_eq(city_a.production_item, "archer", "exercito so com corpo-a-corpo deveria preferir treinar arqueiro (papel ausente) sobre mais um warrior")

## Roadmap de gameplay Fase 4A — pequeno acrescimo ao escopo do plano
## original: sem isto, TradeManager.propose_route nunca teria como
## comecar sozinho (so existe UI humana pra guerra/paz, nenhuma pra
## comercio ainda). Chance baixa por turno (RivalAI.
## TRADE_PROPOSE_CHANCE_PER_TURN), entao roda em loop confirmando que
## EVENTUALMENTE propoe — nao que propoe sempre.
func test_decide_trade_eventually_proposes_a_route_to_a_known_city_at_peace():
	var city_a := hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	city_a.buildings["market"] = true
	var city_b := hex_grid.found_city(Vector2i(5, 0), human, "Capital Humana")
	city_b.buildings["market"] = true
	rival.known_enemy_cities[Vector2i(5, 0)] = true
	assert_true(Diplomacy.propose_peace(human, rival), "pre-condicao: paz devia ser aceita (0 unidades dos dois lados)")

	var proposed := false
	for i in range(200):
		RivalAI.decide_trade(rival, hex_grid, human)
		if rival.trade_routes.size() > 0:
			proposed = true
			break

	assert_true(proposed, "com cidade conhecida em paz e Mercado nos dois lados, deveria eventualmente propor uma rota")

func test_decide_trade_never_proposes_while_at_war():
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival").buildings["market"] = true
	hex_grid.found_city(Vector2i(5, 0), human, "Capital Humana").buildings["market"] = true
	rival.known_enemy_cities[Vector2i(5, 0)] = true
	# before_each ja deixa human/rival em guerra (Diplomacy.declare_war)

	for i in range(200):
		RivalAI.decide_trade(rival, hex_grid, human)

	assert_eq(rival.trade_routes.size(), 0, "em guerra, nunca deveria propor rota de comercio")

## Roadmap 2.0 Parte 1 (A3) — regressao: antes _far_enough_from_cities so
## olhava as cidades do PROPRIO player, entao uma cidade RIVAL (inclusive
## do jogador humano) nunca impedia um assentador de fundar colado nela.
func test_far_enough_from_cities_is_false_near_a_human_city():
	hex_grid.found_city(Vector2i(0, 0), human, "Capital Humana")
	assert_false(RivalAI._far_enough_from_cities(Vector2i(1, 0), hex_grid), "distancia 1 < SETTLE_MIN_DISTANCE (3), deveria ser recusado mesmo sendo cidade do humano")

func test_far_enough_from_cities_is_true_far_from_every_city():
	hex_grid.found_city(Vector2i(0, 0), human, "Capital Humana")
	assert_true(RivalAI._far_enough_from_cities(Vector2i(6, 0), hex_grid), "distancia 6 >= SETTLE_MIN_DISTANCE (3), deveria ser aceito")

## Integracao: um assentador de IA parado ao lado de uma cidade HUMANA nao
## deveria fundar ali — so anda (compute_reachable/move_unit), nunca chama
## WorldSetup.found_city_from_settler.
func test_handle_settler_does_not_found_next_to_a_human_city():
	hex_grid.found_city(Vector2i(0, 0), human, "Capital Humana")
	var settler = _make_unit("settler", rival, Vector2i(1, 0))

	RivalAI._handle_settler(settler, hex_grid, rival)

	assert_null(hex_grid.get_city_at(Vector2i(1, 0)), "assentador nao deveria ter fundado colado na cidade humana")

## Roadmap "Parte C" C2 — _known_enemy_cities_of/_role_fit_bonus. Cobre so
## as funcoes puras aqui; _best_war_objective/decide_war ficam nas proximas
## etapas (ver plano), depois de validar esta base isoladamente.

func test_known_enemy_cities_of_returns_all_known_cities_belonging_to_opponent():
	var third_party := PlayerData.new(CivilizationData.new())
	var city_a := hex_grid.found_city(Vector2i(0, 0), human, "Alvo A")
	var city_b := hex_grid.found_city(Vector2i(5, 0), human, "Alvo B")
	var other_city := hex_grid.found_city(Vector2i(10, 0), third_party, "Terceiro")
	rival.known_enemy_cities[city_a.coord] = true
	rival.known_enemy_cities[city_b.coord] = true
	rival.known_enemy_cities[other_city.coord] = true

	var result := RivalAI._known_enemy_cities_of(rival, human, hex_grid)

	assert_eq(result.size(), 2)
	assert_true(city_a in result)
	assert_true(city_b in result)
	assert_false(other_city in result)

func test_known_enemy_cities_of_excludes_recaptured_city():
	var city := hex_grid.found_city(Vector2i(0, 0), human, "Cidade")
	rival.known_enemy_cities[city.coord] = true
	city.owner_player = rival # recapturada: nao pertence mais ao "opponent" human

	var result := RivalAI._known_enemy_cities_of(rival, human, hex_grid)

	assert_true(result.is_empty(), "cidade recapturada nao deveria contar como alvo conhecido do antigo dono")

func test_role_fit_bonus_rewards_siege_for_walled_target():
	var city := hex_grid.found_city(Vector2i(0, 0), human, "Cidade Muralhada")
	city.buildings["walls"] = true
	var counts := {ArmyComposition.ROLE_SIEGE: 0}
	assert_almost_eq(RivalAI._role_fit_bonus(city, counts), 0.0, 0.001)
	counts[ArmyComposition.ROLE_SIEGE] = 1
	assert_almost_eq(RivalAI._role_fit_bonus(city, counts), 0.5, 0.001)
	counts[ArmyComposition.ROLE_SIEGE] = 2
	assert_almost_eq(RivalAI._role_fit_bonus(city, counts), 1.0, 0.001)

func test_role_fit_bonus_rewards_cavalry_for_undefended_target():
	var city := hex_grid.found_city(Vector2i(0, 0), human, "Cidade Aberta")
	var counts := {ArmyComposition.ROLE_CAVALRY: 2}
	assert_almost_eq(RivalAI._role_fit_bonus(city, counts), 1.0, 0.001)

func test_role_fit_bonus_is_role_specific_not_general_military_presence():
	var city := hex_grid.found_city(Vector2i(0, 0), human, "Cidade Muralhada")
	city.buildings["walls"] = true
	var counts := {ArmyComposition.ROLE_CAVALRY: 5, ArmyComposition.ROLE_SIEGE: 0}
	assert_almost_eq(RivalAI._role_fit_bonus(city, counts), 0.0, 0.001, "muralha exige cerco, nao importa quanta cavalaria o atacante tenha")

## Roadmap "Parte C" C2 — _best_war_objective: selecao do melhor par
## (cidade, objetivo) entre MULTIPLAS cidades conhecidas (nao so a mais
## perto, ver plano). decide_war ainda nao foi reescrito pra usar isto —
## fica isolado ate a proxima etapa, mesma disciplina de C1.

func test_best_war_objective_returns_null_with_no_known_enemy_cities():
	assert_null(RivalAI._best_war_objective(rival, hex_grid, human))

func test_best_war_objective_picks_best_scoring_city_among_multiple_known():
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	var good_target := hex_grid.found_city(Vector2i(5, 0), human, "Alvo Bom") # perto, indefeso
	var resource_coords = [Vector2i(50, 0), Vector2i(51, 0), Vector2i(52, 0), Vector2i(53, 0)]
	for coord in resource_coords:
		var tile = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
		tile.resource = "iron"
		hex_grid.tiles[coord] = tile
	good_target.owned_tiles.append_array(resource_coords)

	var far_tile = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	hex_grid.tiles[Vector2i(12, 0)] = far_tile
	var bad_target := hex_grid.found_city(Vector2i(12, 0), human, "Alvo Ruim") # longe, muralhado, sem recurso
	bad_target.buildings["walls"] = true

	rival.known_enemy_cities[good_target.coord] = true
	rival.known_enemy_cities[bad_target.coord] = true

	var best = RivalAI._best_war_objective(rival, hex_grid, human)

	assert_eq(best.coord, good_target.coord, "cidade perto+indefesa+rica em recurso deveria vencer a longe+muralhada+sem recurso")

func test_best_war_objective_prefers_secure_resources_when_target_is_resource_rich():
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	var target := hex_grid.found_city(Vector2i(5, 0), human, "Alvo")
	target.buildings["walls"] = true # isola vulnerabilidade=0, mesmo truque do teste de B2 abaixo
	var resource_coords = [Vector2i(50, 0), Vector2i(51, 0), Vector2i(52, 0), Vector2i(53, 0)]
	for coord in resource_coords:
		var tile = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
		tile.resource = "iron"
		hex_grid.tiles[coord] = tile
	target.owned_tiles.append_array(resource_coords)
	rival.known_enemy_cities[target.coord] = true

	var best = RivalAI._best_war_objective(rival, hex_grid, human)

	assert_eq(best.objective, RivalAI.WAR_OBJECTIVE_SECURE_RESOURCES)

func test_best_war_objective_prefers_conquer_when_target_has_no_resources():
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	var target := hex_grid.found_city(Vector2i(5, 0), human, "Alvo")
	target.buildings["walls"] = true
	rival.known_enemy_cities[target.coord] = true

	var best = RivalAI._best_war_objective(rival, hex_grid, human)

	assert_eq(best.objective, RivalAI.WAR_OBJECTIVE_CONQUER, "sem recurso nenhum, os dois objetivos empatam e o desempate deterministico cai pra CONQUER")

## Hierarquia numerica (ver plano, Invariantes 1 e 2) — valores exatos, nao
## so a desigualdade em prosa, mesmo padrao do teste equivalente de C1
## (test_score_production_candidate_military_deficit_alone_beats_threat_
## plus_role_gap_combined).

func test_role_fit_alone_never_crosses_war_threshold_from_zero_baseline():
	# strength_advantage=0 (2 catapultas de cada lado, mesma forca total),
	# sem cidade propria pro rival -> proximidade=0 (distancia vira 999999),
	# alvo muralhado -> vulnerabilidade=0, sem recurso -> resources=0,
	# 2 catapultas do rival -> role_fit=1.0 (papel de cerco maximo).
	_make_unit("catapult", rival, Vector2i(0, 0))
	_make_unit("catapult", rival, Vector2i(1, 0))
	_make_unit("catapult", human, Vector2i(-1, 0))
	_make_unit("catapult", human, Vector2i(0, -1))
	var target := hex_grid.found_city(Vector2i(1, -1), human, "Alvo")
	target.buildings["walls"] = true
	rival.known_enemy_cities[target.coord] = true

	var best = RivalAI._best_war_objective(rival, hex_grid, human)

	assert_almost_eq(best.score, 0.3, 0.001)
	assert_lt(best.score, RivalAI.WAR_SCORE_THRESHOLD, "role_fit maximizado sozinho nao deveria chegar perto do limiar de guerra")

func test_close_undefended_target_beats_far_defended_target_with_maxed_role_fit():
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	var close_undefended := hex_grid.found_city(Vector2i(5, 0), human, "Candidato A") # perto, indefeso, sem role certo
	var far_tile = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	hex_grid.tiles[Vector2i(12, 0)] = far_tile
	var far_defended := hex_grid.found_city(Vector2i(12, 0), human, "Candidato B") # longe, muralhado
	far_defended.buildings["walls"] = true
	_make_unit("catapult", rival, Vector2i(1, 0))
	_make_unit("catapult", rival, Vector2i(1, -1)) # 2 catapultas -> role_fit maximo (1.0) especificamente pro alvo B (muralhado)

	rival.known_enemy_cities[close_undefended.coord] = true
	rival.known_enemy_cities[far_defended.coord] = true

	var best = RivalAI._best_war_objective(rival, hex_grid, human)

	assert_eq(best.coord, close_undefended.coord, "vantagem binaria real (proximidade+vulnerabilidade) nao deveria perder pra role_fit maximo isolado")

func test_conquer_zero_resource_zero_role_fit_preserves_base_score():
	# Vale so quando resource_richness == 0 -- com recurso > 0 o termo ja
	# existia na formula antiga tambem, nao e uma equivalencia nova.
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	var target := hex_grid.found_city(Vector2i(5, 0), human, "Alvo") # sem muralha, sem recurso
	rival.known_enemy_cities[target.coord] = true

	var best = RivalAI._best_war_objective(rival, hex_grid, human)

	assert_eq(best.objective, RivalAI.WAR_OBJECTIVE_CONQUER)
	assert_almost_eq(best.score, 2.0, 0.001) # strength_advantage(0) + proximity(1.0) + vulnerability(1.0), formula pre-C2 exata

## Roadmap "Parte C" C3 — campanhas de guerra: memoria PERSISTENTE do
## objetivo (PlayerData.war_campaigns), ao contrario de _best_war_objective
## (C2, sempre transiente). before_each ja deixa human/rival em guerra.

func test_campaign_still_viable_true_at_boundary_score():
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	var target := hex_grid.found_city(Vector2i(5, 0), human, "Alvo") # sem muralha, sem recurso, dentro do alcance de proximidade
	var role_counts := RivalAI._role_counts(rival) # sem unidades -> todos os papeis em 0

	var viable := RivalAI._campaign_still_viable(rival, hex_grid, human, target, RivalAI.WAR_OBJECTIVE_CONQUER)

	assert_true(viable, "strength_advantage(0)+proximity(1.0)+vulnerability(1.0) = 1.0 >= 0.75, deveria continuar viavel")

func test_campaign_still_viable_false_below_threshold():
	_make_unit("warrior", human, Vector2i(0, 0)) # enemy_strength > 0, rival sem unidade nenhuma -> strength_advantage = -1.0
	var far_tile = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	hex_grid.tiles[Vector2i(12, 0)] = far_tile
	var target := hex_grid.found_city(Vector2i(12, 0), human, "Alvo") # sem cidade propria do rival -> proximidade=0; muralhado -> vulnerabilidade=0
	target.buildings["walls"] = true

	var viable := RivalAI._campaign_still_viable(rival, hex_grid, human, target, RivalAI.WAR_OBJECTIVE_CONQUER)

	assert_false(viable, "strength_advantage(-1.0) sozinho ja fica abaixo de 0.75")

func test_decide_campaign_creates_campaign_when_war_declared_and_objective_exists():
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	var target := hex_grid.found_city(Vector2i(5, 0), human, "Alvo") # sem muralha -> score 2.0 >= WAR_SCORE_THRESHOLD
	rival.known_enemy_cities[target.coord] = true

	RivalAI.decide_campaign(rival, hex_grid, human)

	assert_true(rival.war_campaigns.has(human))
	var campaign: Dictionary = rival.war_campaigns[human]
	assert_eq(campaign.status, RivalAI.CAMPAIGN_STATUS_ACTIVE)
	assert_eq(campaign.target_coord, target.coord)
	assert_eq(campaign.objective, RivalAI.WAR_OBJECTIVE_CONQUER)

func test_decide_campaign_does_nothing_at_peace_with_no_existing_campaign():
	human.enemies.erase(rival)
	rival.enemies.erase(human)
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	var target := hex_grid.found_city(Vector2i(5, 0), human, "Alvo")
	rival.known_enemy_cities[target.coord] = true

	RivalAI.decide_campaign(rival, hex_grid, human)

	assert_true(rival.war_campaigns.is_empty(), "em paz e sem campanha existente, nao deveria criar nenhuma")

func test_decide_campaign_does_not_create_campaign_below_war_score_threshold():
	# sem cidade propria do rival (proximidade=0), alvo muralhado (vulnerabilidade=0),
	# sem recurso, sem unidade nenhuma dos dois lados -> score = 0.0 < 1.5
	var target := hex_grid.found_city(Vector2i(5, 0), human, "Alvo")
	target.buildings["walls"] = true
	rival.known_enemy_cities[target.coord] = true

	RivalAI.decide_campaign(rival, hex_grid, human)

	assert_true(rival.war_campaigns.is_empty())

func test_advance_campaign_marks_completed_when_target_captured_by_player():
	var target := hex_grid.found_city(Vector2i(5, 0), human, "Alvo")
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": target.coord,
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}
	hex_grid.capture_city(target, rival)

	RivalAI.decide_campaign(rival, hex_grid, human)

	assert_eq(rival.war_campaigns[human].status, RivalAI.CAMPAIGN_STATUS_COMPLETED)

func test_advance_campaign_retargets_when_invalidated_by_third_party_capture():
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival") # sem isso, proximidade fica 0 pra qualquer alvo (rival.cities vazio) e o substituto nao bateria o limiar
	var target_a := hex_grid.found_city(Vector2i(5, 0), human, "Alvo A")
	var target_b := hex_grid.found_city(Vector2i(1, -1), human, "Alvo B") # sem muralha, perto -> substituto viavel
	rival.known_enemy_cities[target_a.coord] = true
	rival.known_enemy_cities[target_b.coord] = true
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": target_a.coord,
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}
	var third := PlayerData.new(CivilizationData.new())
	hex_grid.capture_city(target_a, third) # nem player nem opponent -> invalidado, nao concluido

	RivalAI.decide_campaign(rival, hex_grid, human)

	var campaign: Dictionary = rival.war_campaigns[human]
	assert_eq(campaign.status, RivalAI.CAMPAIGN_STATUS_ACTIVE)
	assert_eq(campaign.target_coord, target_b.coord, "deveria reavaliar e trocar pro unico alvo restante ainda do oponente")

func test_advance_campaign_abandons_when_invalidated_with_no_replacement():
	var target := hex_grid.found_city(Vector2i(5, 0), human, "Alvo")
	rival.known_enemy_cities[target.coord] = true
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": target.coord,
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}
	var third := PlayerData.new(CivilizationData.new())
	hex_grid.capture_city(target, third)

	RivalAI.decide_campaign(rival, hex_grid, human)

	assert_eq(rival.war_campaigns[human].status, RivalAI.CAMPAIGN_STATUS_ABANDONED, "sem nenhum outro alvo conhecido do oponente, deveria abandonar")

func test_advance_campaign_abandons_when_no_longer_viable():
	var target := hex_grid.found_city(Vector2i(5, 0), human, "Alvo") # ainda do oponente, so deixou de ser viavel
	target.buildings["walls"] = true
	_make_unit("warrior", human, Vector2i(0, 0)) # rival sem unidade nenhuma -> strength_advantage = -1.0
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": target.coord,
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}

	RivalAI.decide_campaign(rival, hex_grid, human)

	assert_eq(rival.war_campaigns[human].status, RivalAI.CAMPAIGN_STATUS_ABANDONED)

## Prova da regra "persistencia e o padrao, nunca troca oportunista" (C3,
## ponto #6 do usuario): campanha continua no alvo original mesmo depois de
## uma cidade objetivamente MELHOR ser escoutada, desde que o alvo original
## continue do oponente e ainda viavel.
func test_advance_campaign_persists_target_when_better_target_appears():
	var target_a := hex_grid.found_city(Vector2i(5, 0), human, "Alvo Original") # sem muralha, perto -> score 2.0, viavel
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": target_a.coord,
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}
	var target_b := hex_grid.found_city(Vector2i(1, -1), human, "Alvo Melhor")
	var resource_coords = [Vector2i(50, 0), Vector2i(51, 0), Vector2i(52, 0), Vector2i(53, 0)]
	for coord in resource_coords:
		var tile = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
		tile.resource = "iron"
		hex_grid.tiles[coord] = tile
	target_b.owned_tiles.append_array(resource_coords)
	rival.known_enemy_cities[target_a.coord] = true
	rival.known_enemy_cities[target_b.coord] = true

	RivalAI.decide_campaign(rival, hex_grid, human)

	var campaign: Dictionary = rival.war_campaigns[human]
	assert_eq(campaign.target_coord, target_a.coord, "alvo original ainda do oponente e viavel -- nao deveria trocar so porque um alvo melhor apareceu")
	assert_eq(campaign.objective, RivalAI.WAR_OBJECTIVE_CONQUER)
	assert_eq(campaign.status, RivalAI.CAMPAIGN_STATUS_ACTIVE)

func test_decide_campaign_starts_fresh_campaign_after_previous_one_terminal_while_still_at_war():
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	var target := hex_grid.found_city(Vector2i(5, 0), human, "Alvo")
	rival.known_enemy_cities[target.coord] = true
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": Vector2i(99, 99), # alvo antigo, ja nao importa
		"status": RivalAI.CAMPAIGN_STATUS_ABANDONED,
	}

	RivalAI.decide_campaign(rival, hex_grid, human)

	var campaign: Dictionary = rival.war_campaigns[human]
	assert_eq(campaign.status, RivalAI.CAMPAIGN_STATUS_ACTIVE, "guerra continua e ha objetivo valido -- deveria nascer uma NOVA instancia de campanha")
	assert_eq(campaign.target_coord, target.coord)

func test_choose_campaign_target_returns_null_without_active_campaign():
	assert_null(RivalAI._choose_campaign_target(rival, human))

func test_choose_campaign_target_returns_active_target_coord():
	var target := hex_grid.found_city(Vector2i(5, 0), human, "Alvo")
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": target.coord,
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}

	assert_eq(RivalAI._choose_campaign_target(rival, human), target.coord)

## Roadmap 2.0 Parte 1 (B2) — pontuacao de guerra soma riqueza de recursos
## do alvo. Muralha na cidade-alvo zera o termo de vulnerabilidade de
## proposito, pra isolar o efeito do termo de recursos (sem isso, o score
## ja cruzaria o limiar so por vulnerabilidade+proximidade, mascarando o
## que estamos testando).
func test_decide_war_eventually_declares_only_once_target_city_is_resource_rich():
	var attacker := PlayerData.new(CivilizationData.new())
	var opponent := PlayerData.new(CivilizationData.new())
	hex_grid.found_city(Vector2i(0, 0), attacker, "Capital Atacante")
	var target_coord := Vector2i(5, 0)
	var target_city := hex_grid.found_city(target_coord, opponent, "Capital Alvo")
	target_city.buildings["walls"] = true # vulnerabilidade 0, isola o termo de recursos
	attacker.known_enemy_cities[target_coord] = true

	var declared_without_resources := false
	for i in range(300):
		RivalAI.decide_war(attacker, hex_grid, opponent)
		if attacker.is_at_war_with(opponent):
			declared_without_resources = true
			break
	assert_false(declared_without_resources, "sem recursos e com muralha, o score deveria ficar abaixo do limiar de guerra")

	var resource_coords = [Vector2i(50, 0), Vector2i(51, 0), Vector2i(52, 0), Vector2i(53, 0)]
	for coord in resource_coords:
		var tile = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
		tile.resource = "iron"
		hex_grid.tiles[coord] = tile
	target_city.owned_tiles.append_array(resource_coords)

	var declared_with_resources := false
	for i in range(300):
		RivalAI.decide_war(attacker, hex_grid, opponent)
		if attacker.is_at_war_with(opponent):
			declared_with_resources = true
			break
	assert_true(declared_with_resources, "com 4 recursos controlados pelo alvo, o termo de riqueza deveria empurrar o score acima do limiar")

## Roadmap 2.0 Parte 1 (B3) — _score_settle_candidate soma 1 por vizinho
## com recurso.
func test_score_settle_candidate_rewards_neighboring_resources():
	var coord := Vector2i(3, 0)
	var resource_neighbor: Vector2i = coord + HexGrid.NEIGHBOR_DIRS[0]
	var tile = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	tile.resource = "iron"
	hex_grid.tiles[resource_neighbor] = tile

	var score = RivalAI._score_settle_candidate(coord, hex_grid, rival)

	assert_gt(score, 0.0, "candidato com vizinho de recurso deveria pontuar acima de zero")

## Roadmap 2.0 Parte 1 (B3) — _score_settle_candidate penaliza (nunca
## bloqueia) tile sob pressao de cidade rival (A2).
func test_score_settle_candidate_penalizes_tile_under_rival_pressure():
	hex_grid.found_city(Vector2i(0, 0), human, "Capital Humana")
	var pressured_coord := Vector2i(HexGrid.RIVAL_PRESSURE_RADIUS, 0)

	var score = RivalAI._score_settle_candidate(pressured_coord, hex_grid, rival)

	assert_lt(score, 0.0, "tile sob pressao de cidade rival (do jogador humano) deveria pontuar abaixo de zero")

## Roadmap 2.0 (fecha Parte A) — mesma penalizacao, agora por covil de
## monstro perigoso ativo em vez de cidade rival.
func test_score_settle_candidate_penalizes_tile_near_active_lair():
	var lair_coord := Vector2i(0, 0)
	hex_grid.lair_coords.append(lair_coord)
	hex_grid.lair_kind_by_coord[lair_coord] = "dragon"
	hex_grid.spawn_monster_at(lair_coord, "dragon", true)
	var candidate := Vector2i(HexGrid.LAIR_DANGER_RADIUS, 0)

	var score = RivalAI._score_settle_candidate(candidate, hex_grid, rival)

	assert_lt(score, 0.0, "tile perto de covil de Dragao ativo deveria pontuar abaixo de zero")

## Leva a exclusao do guardiao morto (HexGrid.get_lair_danger_at) ate a
## formula de assentamento da IA, nao so a consulta crua do HexGrid.
func test_score_settle_candidate_ignores_lair_with_dead_defender():
	var lair_coord := Vector2i(0, 0)
	hex_grid.lair_coords.append(lair_coord)
	hex_grid.lair_kind_by_coord[lair_coord] = "dragon" # sem spawn_monster_at -- guardiao "morto"
	var candidate := Vector2i(HexGrid.LAIR_DANGER_RADIUS, 0)

	var score = RivalAI._score_settle_candidate(candidate, hex_grid, rival)

	assert_eq(score, 0.0, "covil sem defensor vivo nao deveria penalizar o candidato")

## Roadmap "Parte B" (B3) — RivalAI._tech_identity_axis: eixo DERIVADO de
## unlocks_building/unlocks_unit (via BuildingDatabase.building_that_trains),
## nunca uma tabela nova. Nao depende de hex_grid/human/rival do fixture,
## so de TechDatabase/BuildingDatabase/CityIdentity.
func test_tech_identity_axis_derives_from_unlocks_building():
	assert_eq(RivalAI._tech_identity_axis(TechDatabase.get_tech("celeiro")), CityIdentity.AXIS_AGRICOLA)
	assert_eq(RivalAI._tech_identity_axis(TechDatabase.get_tech("oficina")), CityIdentity.AXIS_INDUSTRIAL)
	assert_eq(RivalAI._tech_identity_axis(TechDatabase.get_tech("mercado")), CityIdentity.AXIS_COMERCIAL)
	assert_eq(RivalAI._tech_identity_axis(TechDatabase.get_tech("muralhas")), CityIdentity.AXIS_MILITAR)

func test_tech_identity_axis_derives_from_unlocks_unit_via_trainer_building():
	assert_eq(RivalAI._tech_identity_axis(TechDatabase.get_tech("quartel")), CityIdentity.AXIS_MILITAR)
	assert_eq(RivalAI._tech_identity_axis(TechDatabase.get_tech("arquearia")), CityIdentity.AXIS_MILITAR)
	assert_eq(RivalAI._tech_identity_axis(TechDatabase.get_tech("estabulo")), CityIdentity.AXIS_MILITAR)
	assert_eq(RivalAI._tech_identity_axis(TechDatabase.get_tech("constructos_de_guerra")), CityIdentity.AXIS_MILITAR)
	assert_eq(RivalAI._tech_identity_axis(TechDatabase.get_tech("invocacao_espiritos")), CityIdentity.AXIS_ARCANA)
	assert_eq(RivalAI._tech_identity_axis(TechDatabase.get_tech("pacto_florestal")), CityIdentity.AXIS_ARCANA)
	assert_eq(RivalAI._tech_identity_axis(TechDatabase.get_tech("forja_runica")), CityIdentity.AXIS_ARCANA)
	assert_eq(RivalAI._tech_identity_axis(TechDatabase.get_tech("lordes_dos_ventos")), CityIdentity.AXIS_ARCANA)
	assert_eq(RivalAI._tech_identity_axis(TechDatabase.get_tech("necromancia_pratica")), CityIdentity.AXIS_ARCANA)

func test_tech_identity_axis_resolves_batedor_montado_via_stable_fallback():
	assert_eq(RivalAI._tech_identity_axis(TechDatabase.get_tech("batedor_montado")), CityIdentity.AXIS_MILITAR, "scout treina no Estabulo (fallback de BuildingDatabase.building_that_trains, mesmo de B2), deveria herdar o eixo militar")

func test_tech_identity_axis_is_empty_for_techs_without_building_or_unit_unlock():
	for id in ["canalizacao_base", "navegacao", "cataclismo_elemental", "transcendencia_florestal", "alquimia_botanica", "transmutacao_rocha", "geomancia"]:
		assert_eq(RivalAI._tech_identity_axis(TechDatabase.get_tech(id)), "", "%s nao desbloqueia predio nem unidade, nao deveria ter eixo de identidade" % id)

## Protege a propriedade "sem predio/unidade, identidade nao inventa
## preferencia" — pontuacao de uma tech sem eixo e EXATAMENTE igual com a
## civ sem identidade nenhuma e com a civ no auge de qualquer eixo.
## Especialmente relevante com 7 das 21 techs caindo nesse caso.
func test_score_research_candidate_identity_has_no_effect_for_unmapped_tech():
	var navegacao: TechData = TechDatabase.get_tech("navegacao")
	var player_no_identity := PlayerData.new(CivilizationData.new())

	var player_max_identity := PlayerData.new(CivilizationData.new())
	var city := City.new()
	for id in ["walls", "barracks", "archery_range", "stable", "siege_workshop"]:
		city.buildings[id] = true
	player_max_identity.cities.append(city)

	assert_eq(
		RivalAI._score_research_candidate(navegacao, player_no_identity),
		RivalAI._score_research_candidate(navegacao, player_max_identity),
		"tech sem eixo de identidade nao deveria pontuar diferente so por causa da identidade da civ"
	)
	city.queue_free()

## Roadmap "Parte B" B4.2 — mesmo padrao do teste equivalente de identidade
## (B3): tech sem eixo pontua igual com personalidade vazia e personalidade
## no maximo em qualquer eixo.
func test_score_research_candidate_personality_has_no_effect_for_unmapped_tech():
	var navegacao: TechData = TechDatabase.get_tech("navegacao")
	var player_no_personality := PlayerData.new(CivilizationData.new())

	var player_max_personality := PlayerData.new(CivilizationData.new())
	player_max_personality.personality[CityIdentity.AXIS_MILITAR] = 1.0

	assert_eq(
		RivalAI._score_research_candidate(navegacao, player_no_personality),
		RivalAI._score_research_candidate(navegacao, player_max_personality),
		"tech sem eixo de identidade nao deveria pontuar diferente so por causa da personalidade da civ"
	)

## Tech com eixo soma exatamente RESEARCH_WEIGHT_PERSONALITY * personality[axis]
## quando identidade e continuacao estao zeradas (civ sem cidade, sem
## pesquisa em andamento).
func test_score_research_candidate_adds_personality_term_for_mapped_tech():
	var quartel: TechData = TechDatabase.get_tech("quartel") # unlocks_unit "men_at_arms" -> barracks -> militar
	var player := PlayerData.new(CivilizationData.new())
	player.personality[CityIdentity.AXIS_MILITAR] = 1.0

	var score := RivalAI._score_research_candidate(quartel, player)

	assert_almost_eq(score, RivalAI.RESEARCH_WEIGHT_PERSONALITY * 1.0, 0.001)

## Identidade (B3, retrospectiva) e personalidade (B4, prospectiva) sao
## independentes e ADITIVAS — nenhuma anula a outra, os dois termos aparecem
## juntos no score (mandato do usuario: "as duas convivem").
func test_score_research_candidate_personality_and_identity_are_independent_and_additive():
	var invocacao: TechData = TechDatabase.get_tech("invocacao_espiritos") # unlocks_unit "mage" -> arcane_tower -> arcana
	var player := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.buildings["sages_tower"] = true # arcana 1/6, identidade > 0
	player.cities.append(city)
	player.personality[CityIdentity.AXIS_ARCANA] = 0.5

	var identity_strength := CityIdentity.civilization_axis_strength(player, CityIdentity.AXIS_ARCANA)
	var expected := RivalAI.RESEARCH_WEIGHT_IDENTITY * identity_strength + RivalAI.RESEARCH_WEIGHT_PERSONALITY * 0.5
	var score := RivalAI._score_research_candidate(invocacao, player)

	assert_almost_eq(score, expected, 0.001, "identidade e personalidade deveriam somar juntas, nenhuma zerando a outra")
	city.queue_free()

## Espelha o "nunca sobrepoe" de B3: mesmo com identidade E personalidade
## no maximo simultaneo (0.2+0.15=0.35), uma continuacao de cadeia real
## (score 1.0) ainda vence.
func test_decide_research_personality_never_overrides_stronger_continuation():
	var player := PlayerData.new(CivilizationData.new())
	player.researched_techs["celeiro"] = true # abre "oficina" (industrial), unica continuacao disponivel

	var city := City.new()
	for id in ["walls", "barracks", "archery_range", "stable", "siege_workshop"]:
		city.buildings[id] = true # militar 1.0, identidade perfeita
	player.cities.append(city)
	player.personality[CityIdentity.AXIS_MILITAR] = 1.0 # personalidade tambem no maximo

	RivalAI.decide_research(player)

	assert_eq(player.current_research, "oficina", "continuacao de cadeia deve vencer mesmo com identidade E personalidade militar no maximo simultaneo, ambas noutra tech de raiz")
	city.queue_free()
