extends GutTest

var _owned_players: Array[PlayerData] = []

func _track_player(civ: CivilizationData) -> PlayerData:
	var player := PlayerData.new(civ)
	_owned_players.append(player)
	return player

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

	human = _track_player(CivilizationData.new())
	rival = _track_player(CivilizationData.new())
	Diplomacy.declare_war(human, rival) # _choose_target agora exige guerra pra mirar em alguem
	GameManager.hex_grid = hex_grid
	GameManager.human_player = human

func after_each():
	for player in _owned_players:
		player.release_relations()
	_owned_players.clear()
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
	var dwarf_player := _track_player(dwarf_civ)

	assert_true("dwarf_axeguard" in RivalAI._military_kinds_for(dwarf_player))

func test_military_kinds_for_does_not_leak_other_races_unique_unit():
	var dwarf_civ := CivilizationData.new()
	dwarf_civ.race = "dwarf"
	var dwarf_player := _track_player(dwarf_civ)

	var kinds = RivalAI._military_kinds_for(dwarf_player)
	assert_false("orc_berserker" in kinds)
	assert_false("elf_ranger" in kinds)

func test_military_kinds_for_has_no_racial_unit_without_a_race():
	var human_civ := CivilizationData.new() # race = "" (padrao)
	var human_without_race := _track_player(human_civ)

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
	var orc_player := _track_player(orc_civ)
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
	rival.researched_techs["arqueiro"] = true # libera has_unlocked("archer")
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
## Task 22 -- a regra virou estrutural (CitySite.rejection_reason, vale pra
## jogador e IA); esta regressao continua valendo: cidade de OUTRO dono
## tambem conta.
func test_city_site_is_rejected_near_a_human_city():
	hex_grid.found_city(Vector2i(0, 0), human, "Capital Humana")
	assert_eq(CitySite.rejection_reason(hex_grid, Vector2i(1, 0), rival), CitySite.REASON_TOO_CLOSE, "distancia 1 < min_city_distance, deveria ser recusado mesmo sendo cidade do humano")

func test_city_site_is_accepted_far_from_every_city():
	hex_grid.found_city(Vector2i(0, 0), human, "Capital Humana")
	assert_eq(CitySite.rejection_reason(hex_grid, Vector2i(6, 0), rival), "", "distancia 6 >= min_city_distance, deveria ser aceito")

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
	var third_party := _track_player(CivilizationData.new())
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
	var third := _track_player(CivilizationData.new())
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
	var third := _track_player(CivilizationData.new())
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

## Roadmap "Parte C" C4 — _campaign_attack_target: mesma base de
## _choose_campaign_target, mais a checagem de frescor (o coord ainda
## corresponde a uma cidade de verdade do oponente agora).

func test_campaign_attack_target_null_without_campaign():
	assert_null(RivalAI._campaign_attack_target(rival, hex_grid, human))

func test_campaign_attack_target_null_with_terminal_status():
	var target := hex_grid.found_city(Vector2i(5, 0), human, "Alvo")
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": target.coord,
		"status": RivalAI.CAMPAIGN_STATUS_ABANDONED,
	}

	assert_null(RivalAI._campaign_attack_target(rival, hex_grid, human))

func test_campaign_attack_target_null_when_target_coord_no_longer_opponent_city():
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": Vector2i(99, 99), # sem cidade nenhuma nesse coord
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}

	assert_null(RivalAI._campaign_attack_target(rival, hex_grid, human))

func test_campaign_attack_target_returns_coord_when_active_and_still_opponent_city():
	var target := hex_grid.found_city(Vector2i(5, 0), human, "Alvo")
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": target.coord,
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}

	assert_eq(RivalAI._campaign_attack_target(rival, hex_grid, human), target.coord)

## Roadmap "Parte C" C4 — integracao em _handle_attacker. As duas cidades
## indefesas conhecidas (city_b inserida PRIMEIRO em known_enemy_cities,
## city_a depois) exploram o fato de _choose_target nao ter criterio de
## "mais perto" -- ele devolve a PRIMEIRA que bater o criterio na ordem de
## insercao do Dictionary, entao sem campanha ele pegaria city_b. So a
## integracao de C4 faz a escolha mudar pra city_a quando ela e o alvo da
## campanha.

func test_handle_attacker_prioritizes_campaign_target_over_choose_target():
	var attacker = _make_unit("warrior", rival, Vector2i(0, 0))
	var city_b := hex_grid.found_city(Vector2i(1, 0), human, "Cidade Normal") # _choose_target pegaria esta
	var city_a := hex_grid.found_city(Vector2i(1, -1), human, "Alvo da Campanha")
	rival.known_enemy_cities[city_b.coord] = true
	rival.known_enemy_cities[city_a.coord] = true
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": city_a.coord,
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}
	var city_a_hp_before := city_a.hp
	var city_b_hp_before := city_b.hp

	RivalAI._handle_attacker(attacker, hex_grid, rival, human, {})

	assert_lt(city_a.hp, city_a_hp_before, "campanha deveria redirecionar o ataque pro alvo estrategico")
	assert_eq(city_b.hp, city_b_hp_before, "cidade que _choose_target normalmente escolheria nao deveria ser atacada")

func test_handle_attacker_advances_toward_campaign_target_when_out_of_range():
	var attacker = _make_unit("warrior", rival, Vector2i(0, 0))
	var target_city := hex_grid.found_city(Vector2i(5, 0), human, "Alvo Distante") # fora do attack_range=1, dentro de PERCEPTION_RANGE=5
	rival.known_enemy_cities[target_city.coord] = true
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": target_city.coord,
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}

	RivalAI._handle_attacker(attacker, hex_grid, rival, human, {})

	assert_ne(attacker.coord, Vector2i(0, 0), "deveria avancar em direcao ao alvo da campanha")

func test_handle_attacker_uses_choose_target_when_no_campaign():
	var attacker = _make_unit("warrior", rival, Vector2i(0, 0))
	var enemy = _make_unit("warrior", human, Vector2i(1, 0))

	RivalAI._handle_attacker(attacker, hex_grid, rival, human, {enemy.coord: true})

	assert_lt(enemy.hp, enemy.unit_data.max_hp, "sem campanha, deveria continuar usando _choose_target normalmente")

func test_handle_attacker_ignores_terminal_campaign():
	var attacker = _make_unit("warrior", rival, Vector2i(0, 0))
	var city_b := hex_grid.found_city(Vector2i(1, 0), human, "Cidade Normal") # _choose_target deveria escolher esta
	var city_a := hex_grid.found_city(Vector2i(1, -1), human, "Alvo Antigo da Campanha")
	rival.known_enemy_cities[city_b.coord] = true
	rival.known_enemy_cities[city_a.coord] = true
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": city_a.coord,
		"status": RivalAI.CAMPAIGN_STATUS_ABANDONED,
	}
	var city_a_hp_before := city_a.hp
	var city_b_hp_before := city_b.hp

	RivalAI._handle_attacker(attacker, hex_grid, rival, human, {})

	assert_eq(city_a.hp, city_a_hp_before, "campanha abandonada nao deveria mais direcionar ataques")
	assert_lt(city_b.hp, city_b_hp_before, "deveria cair pro comportamento normal de _choose_target")

func test_handle_attacker_falls_back_when_campaign_target_invalidated():
	var attacker = _make_unit("warrior", rival, Vector2i(0, 0))
	var enemy = _make_unit("warrior", human, Vector2i(1, 0))
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": Vector2i(99, 99), # sem cidade nenhuma do oponente ali
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}

	RivalAI._handle_attacker(attacker, hex_grid, rival, human, {enemy.coord: true})

	assert_lt(enemy.hp, enemy.unit_data.max_hp, "alvo invalido deveria cair pro comportamento tatico existente, sem crash")

## Roadmap "Parte D" D1 — decide_peace: encerramento autonomo de guerra por
## desgaste (war_weariness). before_each ja deixa human/rival em guerra.
## Os testes de "aceita"/"recusa" dao ao rival 2 unidades contra 0 do
## humano (ou o inverso) pra isolar exatamente o que _accepts_peace ja
## decide hoje (contagem de unidade) — decide_peace nao reimplementa essa
## heuristica, so decide SE tenta.

func test_decide_peace_does_nothing_at_peace():
	human.enemies.erase(rival)
	rival.enemies.erase(human)
	rival.war_weariness = 100.0 # mesmo com desgaste maximo

	var result = RivalAI.decide_peace(rival, human)

	assert_eq(result, RivalAI.PEACE_DECISION_NOT_AT_WAR)
	assert_false(rival.is_at_war_with(human))

func test_decide_peace_does_not_propose_below_offer_threshold():
	_make_unit("warrior", rival, Vector2i(0, 0))
	_make_unit("warrior", rival, Vector2i(1, 0)) # rival mais forte -- humano aceitaria SE a proposta chegasse
	rival.war_weariness = RivalAI.WAR_WEARINESS_OFFER_PEACE_THRESHOLD - 1.0

	var result = RivalAI.decide_peace(rival, human)

	assert_eq(result, RivalAI.PEACE_DECISION_BELOW_THRESHOLD)
	assert_true(rival.is_at_war_with(human), "abaixo do limiar de oferta, nao deveria nem tentar propor (mesmo que a proposta fosse aceita)")

func test_decide_peace_proposes_at_offer_threshold_and_ends_war_when_accepted():
	_make_unit("warrior", rival, Vector2i(0, 0))
	_make_unit("warrior", rival, Vector2i(1, 0)) # rival mais forte -- humano aceita
	rival.war_weariness = RivalAI.WAR_WEARINESS_OFFER_PEACE_THRESHOLD

	var result = RivalAI.decide_peace(rival, human)

	assert_eq(result, RivalAI.PEACE_DECISION_ACCEPTED)
	assert_false(rival.is_at_war_with(human))
	assert_false(human.is_at_war_with(rival), "paz precisa ser simetrica nos dois lados")

func test_decide_peace_leaves_war_active_when_refused():
	_make_unit("warrior", human, Vector2i(0, 0))
	_make_unit("warrior", human, Vector2i(1, 0)) # humano mais forte -- recusa
	rival.war_weariness = RivalAI.WAR_WEARINESS_OFFER_PEACE_THRESHOLD

	var result = RivalAI.decide_peace(rival, human)

	assert_eq(result, RivalAI.PEACE_DECISION_REFUSED)
	assert_true(rival.is_at_war_with(human), "humano em vantagem numerica deveria recusar -- guerra continua, sem erro nem estado novo")

## Roadmap "Parte E" E1 -- ANTES desta fatia, uma campanha ACTIVE
## sobrevivia intacta a uma paz aceita (era o comportamento documentado e
## aceito desde C3/D1, ver git blame). Desde E1, decide_peace herda de
## Diplomacy.propose_peace() o encerramento automatico da campanha -- este
## teste agora exercita e trava o contrato NOVO. Cobertura mais central
## (via Diplomacy.propose_peace diretamente, nas duas direcoes) fica em
## test_diplomacy.gd.
func test_decide_peace_abandons_active_war_campaign_on_acceptance():
	_make_unit("warrior", rival, Vector2i(0, 0))
	_make_unit("warrior", rival, Vector2i(1, 0))
	rival.war_weariness = RivalAI.WAR_WEARINESS_OFFER_PEACE_THRESHOLD
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": Vector2i(5, 0),
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}

	var result = RivalAI.decide_peace(rival, human)

	assert_eq(result, RivalAI.PEACE_DECISION_ACCEPTED, "pre-condicao: paz deveria ter sido aceita")
	assert_eq(rival.war_campaigns[human].status, RivalAI.CAMPAIGN_STATUS_ABANDONED, "paz aceita deveria abandonar a campanha ACTIVE contra o novo parceiro de paz (E1)")

func test_decide_peace_ignores_terminal_campaign_status():
	_make_unit("warrior", rival, Vector2i(0, 0))
	_make_unit("warrior", rival, Vector2i(1, 0))
	rival.war_weariness = RivalAI.WAR_WEARINESS_OFFER_PEACE_THRESHOLD
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": Vector2i(5, 0),
		"status": RivalAI.CAMPAIGN_STATUS_ABANDONED,
	}

	var result = RivalAI.decide_peace(rival, human)

	assert_eq(result, RivalAI.PEACE_DECISION_ACCEPTED, "campanha abandonada nao deveria impedir a decisao de paz")

## Documenta a escolha de ordem em GameManager.gd (decide_peace roda ANTES
## de Diplomacy.process_war_weariness_and_upkeep no mesmo turno) em vez de
## deixar a defasagem parecer acidental: desgaste ganho MAIS TARDE no mesmo
## turno so afeta a decisao do turno SEGUINTE.
func test_decide_peace_does_not_react_to_weariness_gained_later_same_turn():
	_make_unit("warrior", rival, Vector2i(0, 0))
	_make_unit("warrior", rival, Vector2i(1, 0))
	rival.war_weariness = RivalAI.WAR_WEARINESS_OFFER_PEACE_THRESHOLD - 0.5 # abaixo do limiar quando decide_peace roda

	var result = RivalAI.decide_peace(rival, human) # fase de decisao do turno T

	assert_eq(result, RivalAI.PEACE_DECISION_BELOW_THRESHOLD)
	assert_true(rival.is_at_war_with(human))

	Diplomacy.process_war_weariness_and_upkeep(rival) # fase economica do MESMO turno T

	assert_true(rival.war_weariness >= RivalAI.WAR_WEARINESS_OFFER_PEACE_THRESHOLD, "pre-condicao: agora deveria estar acima do limiar")
	assert_true(rival.is_at_war_with(human), "atualizar war_weariness sozinho nao decide nada -- so a PROXIMA chamada de decide_peace (turno seguinte) reagiria a isso")

## Roadmap "Parte D" D2 — feedback de UI puramente aditivo (EventBus.notify)
## nos pontos de mutacao de guerra/campanha/paz. watch_signals(EventBus) e
## assert_signal_emit_count e o padrao ja estabelecido neste projeto (ver
## test_game_manager.gd/test_settings.gd).

func test_decide_war_notifies_human_when_rival_declares_war():
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival") # sem isso, proximidade fica 0 e o score nunca cruza WAR_SCORE_THRESHOLD
	var target := hex_grid.found_city(Vector2i(5, 0), human, "Alvo")
	rival.known_enemy_cities[target.coord] = true
	human.enemies.erase(rival)
	rival.enemies.erase(human) # comeca em paz -- decide_war precisa decidir declarar

	watch_signals(EventBus) # DEPOIS do found_city (que ja emite "Cidade fundada" pro dono humano) -- so queremos contar o notify de decide_war
	for i in range(300):
		RivalAI.decide_war(rival, hex_grid, human)
		if rival.is_at_war_with(human):
			break

	assert_true(rival.is_at_war_with(human), "pre-condicao: guerra deveria ter sido declarada")
	assert_signal_emit_count(EventBus, "notify", 1)

func test_decide_war_does_not_notify_when_opponent_is_not_the_human():
	var third := _track_player(CivilizationData.new())
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	var target := hex_grid.found_city(Vector2i(5, 0), third, "Alvo")
	rival.known_enemy_cities[target.coord] = true

	watch_signals(EventBus)
	for i in range(300):
		RivalAI.decide_war(rival, hex_grid, third)
		if rival.is_at_war_with(third):
			break

	assert_true(rival.is_at_war_with(third), "pre-condicao: guerra deveria ter sido declarada")
	assert_signal_emit_count(EventBus, "notify", 0)

func test_decide_campaign_notifies_human_on_start():
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	var target := hex_grid.found_city(Vector2i(5, 0), human, "Alvo")
	rival.known_enemy_cities[target.coord] = true

	watch_signals(EventBus) # DEPOIS do found_city, mesmo motivo do teste de decide_war acima
	RivalAI.decide_campaign(rival, hex_grid, human)

	assert_signal_emit_count(EventBus, "notify", 1)

func test_decide_campaign_notifies_human_on_completion():
	var target := hex_grid.found_city(Vector2i(5, 0), human, "Alvo")
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": target.coord,
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}
	hex_grid.capture_city(target, rival)

	watch_signals(EventBus) # DEPOIS de found_city/capture_city (HexGrid.gd tambem emite notify quando o humano funda/perde uma cidade)
	RivalAI.decide_campaign(rival, hex_grid, human)

	assert_signal_emit_count(EventBus, "notify", 1)

func test_decide_campaign_notifies_human_on_abandon_invalid_target():
	var target := hex_grid.found_city(Vector2i(5, 0), human, "Alvo")
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": target.coord,
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}
	var third := _track_player(CivilizationData.new())
	hex_grid.capture_city(target, third) # invalidado, sem substituto conhecido

	watch_signals(EventBus)
	RivalAI.decide_campaign(rival, hex_grid, human)

	assert_eq(rival.war_campaigns[human].status, RivalAI.CAMPAIGN_STATUS_ABANDONED, "pre-condicao")
	assert_signal_emit_count(EventBus, "notify", 1)

func test_decide_campaign_notifies_human_on_abandon_no_longer_viable():
	var target := hex_grid.found_city(Vector2i(5, 0), human, "Alvo")
	target.buildings["walls"] = true
	_make_unit("warrior", human, Vector2i(0, 0))
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": target.coord,
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}

	watch_signals(EventBus)
	RivalAI.decide_campaign(rival, hex_grid, human)

	assert_eq(rival.war_campaigns[human].status, RivalAI.CAMPAIGN_STATUS_ABANDONED, "pre-condicao")
	assert_signal_emit_count(EventBus, "notify", 1)

func test_decide_campaign_does_not_notify_when_still_active():
	var target := hex_grid.found_city(Vector2i(5, 0), human, "Alvo")
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": target.coord,
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}

	watch_signals(EventBus)
	RivalAI.decide_campaign(rival, hex_grid, human)

	assert_eq(rival.war_campaigns[human].status, RivalAI.CAMPAIGN_STATUS_ACTIVE, "pre-condicao: alvo ainda valido e viavel, nada deveria mudar")
	assert_signal_emit_count(EventBus, "notify", 0)

func test_decide_campaign_does_not_notify_for_non_human_opponent():
	watch_signals(EventBus)
	var third := _track_player(CivilizationData.new())
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	var target := hex_grid.found_city(Vector2i(5, 0), third, "Alvo")
	rival.known_enemy_cities[target.coord] = true
	Diplomacy.declare_war(rival, third)

	RivalAI.decide_campaign(rival, hex_grid, third)

	assert_true(rival.war_campaigns.has(third), "pre-condicao: campanha deveria ter sido criada")
	assert_signal_emit_count(EventBus, "notify", 0)

func test_decide_peace_notifies_human_on_acceptance():
	watch_signals(EventBus)
	_make_unit("warrior", rival, Vector2i(0, 0))
	_make_unit("warrior", rival, Vector2i(1, 0)) # rival mais forte -- humano aceita
	rival.war_weariness = RivalAI.WAR_WEARINESS_OFFER_PEACE_THRESHOLD

	RivalAI.decide_peace(rival, human)

	assert_signal_emit_count(EventBus, "notify", 1)

func test_decide_peace_notifies_human_on_refusal():
	watch_signals(EventBus)
	_make_unit("warrior", human, Vector2i(0, 0))
	_make_unit("warrior", human, Vector2i(1, 0)) # humano mais forte -- recusa
	rival.war_weariness = RivalAI.WAR_WEARINESS_OFFER_PEACE_THRESHOLD

	RivalAI.decide_peace(rival, human)

	assert_signal_emit_count(EventBus, "notify", 1)

## Roadmap "Parte E" E1 -- paz aceita com uma campanha ACTIVE do rival
## contra o humano deveria gerar DOIS toasts distintos (paz + abandono),
## nunca um so combinado nem o abandono duplicado. A campanha do lado do
## humano (se existisse) NAO gera toast -- mesma regra de sempre em
## _notify_human, ja coberta por outros testes deste arquivo.
func test_decide_peace_also_notifies_campaign_abandoned_when_active():
	watch_signals(EventBus)
	_make_unit("warrior", rival, Vector2i(0, 0))
	_make_unit("warrior", rival, Vector2i(1, 0)) # rival mais forte -- humano aceita
	rival.war_weariness = RivalAI.WAR_WEARINESS_OFFER_PEACE_THRESHOLD
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": Vector2i(5, 0),
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}

	RivalAI.decide_peace(rival, human)

	assert_eq(rival.war_campaigns[human].status, RivalAI.CAMPAIGN_STATUS_ABANDONED, "pre-condicao")
	assert_signal_emit_count(EventBus, "notify", 2, "paz aceita + campanha abandonada -- dois eventos distintos, um toast cada")

func test_decide_peace_does_not_notify_below_threshold():
	watch_signals(EventBus)
	rival.war_weariness = RivalAI.WAR_WEARINESS_OFFER_PEACE_THRESHOLD - 1.0

	RivalAI.decide_peace(rival, human)

	assert_signal_emit_count(EventBus, "notify", 0)

func test_decide_peace_does_not_notify_when_already_at_peace():
	watch_signals(EventBus)
	human.enemies.erase(rival)
	rival.enemies.erase(human)
	rival.war_weariness = 100.0

	RivalAI.decide_peace(rival, human)

	assert_signal_emit_count(EventBus, "notify", 0)

## Roadmap 2.0 Parte 1 (B2) — pontuacao de guerra soma riqueza de recursos
## do alvo. Muralha na cidade-alvo zera o termo de vulnerabilidade de
## proposito, pra isolar o efeito do termo de recursos (sem isso, o score
## ja cruzaria o limiar so por vulnerabilidade+proximidade, mascarando o
## que estamos testando).
func test_decide_war_eventually_declares_only_once_target_city_is_resource_rich():
	var attacker := _track_player(CivilizationData.new())
	var opponent := _track_player(CivilizationData.new())
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

## Task 22 -- avaliacao de local (CitySite.evaluate) no lugar do antigo
## _score_settle_candidate: mesmas propriedades (recurso vizinho recompensa;
## pressao rival e covil ativo penalizam, nunca bloqueiam), agora em "partes".
func _site_score(coord: Vector2i) -> Dictionary:
	return CitySite.evaluate(hex_grid, coord, CitySite.build_context(hex_grid, rival))

func test_site_score_rewards_neighboring_resources():
	var coord := Vector2i(3, 0)
	var without: Dictionary = _site_score(coord)
	var resource_neighbor: Vector2i = coord + HexGrid.NEIGHBOR_DIRS[0]
	var tile = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	tile.resource = "iron"
	hex_grid.tiles[resource_neighbor] = tile

	var with_resource: Dictionary = _site_score(coord)

	assert_gt(with_resource.parts.resources, 0.0, "candidato com vizinho de recurso deveria pontuar em recursos")
	assert_gt(with_resource.total, without.total)

## Roadmap 2.0 Parte 1 (B3) — _score_settle_candidate penaliza (nunca
## bloqueia) tile sob pressao de cidade rival (A2).
func test_site_score_penalizes_tile_under_rival_pressure():
	hex_grid.found_city(Vector2i(0, 0), human, "Capital Humana")
	var pressured_coord := Vector2i(HexGrid.RIVAL_PRESSURE_RADIUS, 0)

	var result: Dictionary = _site_score(pressured_coord)

	assert_lt(result.parts.security, 0.0, "tile sob pressao de cidade rival (do jogador humano) deveria ser penalizado em seguranca")

## Roadmap 2.0 (fecha Parte A) — mesma penalizacao, agora por covil de
## monstro perigoso ativo em vez de cidade rival.
func test_site_score_penalizes_tile_near_active_lair():
	var lair_coord := Vector2i(0, 0)
	hex_grid.lair_coords.append(lair_coord)
	hex_grid.lair_kind_by_coord[lair_coord] = "dragon"
	hex_grid.spawn_monster_at(lair_coord, "dragon", true)
	var candidate := Vector2i(HexGrid.LAIR_DANGER_RADIUS, 0)

	var result: Dictionary = _site_score(candidate)

	assert_lt(result.parts.security, 0.0, "tile perto de covil de Dragao ativo deveria ser penalizado em seguranca")

## Leva a exclusao do guardiao morto (HexGrid.get_lair_danger_at) ate a
## formula de assentamento da IA, nao so a consulta crua do HexGrid.
func test_site_score_ignores_lair_with_dead_defender():
	var lair_coord := Vector2i(0, 0)
	hex_grid.lair_coords.append(lair_coord)
	hex_grid.lair_kind_by_coord[lair_coord] = "dragon" # sem spawn_monster_at -- guardiao "morto"
	var candidate := Vector2i(HexGrid.LAIR_DANGER_RADIUS, 0)

	var result: Dictionary = _site_score(candidate)

	assert_eq(result.parts.security, 0.0, "covil sem defensor vivo nao deveria penalizar o candidato")

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
	assert_eq(RivalAI._tech_identity_axis(TechDatabase.get_tech("arqueiro")), CityIdentity.AXIS_MILITAR)
	assert_eq(RivalAI._tech_identity_axis(TechDatabase.get_tech("estabulo")), CityIdentity.AXIS_MILITAR)
	assert_eq(RivalAI._tech_identity_axis(MagicDatabase.get_tech("constructos_de_guerra")), CityIdentity.AXIS_MILITAR)
	assert_eq(RivalAI._tech_identity_axis(MagicDatabase.get_tech("invocacao_espiritos")), CityIdentity.AXIS_ARCANA)
	assert_eq(RivalAI._tech_identity_axis(MagicDatabase.get_tech("pacto_florestal")), CityIdentity.AXIS_ARCANA)
	assert_eq(RivalAI._tech_identity_axis(MagicDatabase.get_tech("forja_runica")), CityIdentity.AXIS_ARCANA)
	assert_eq(RivalAI._tech_identity_axis(MagicDatabase.get_tech("lordes_dos_ventos")), CityIdentity.AXIS_ARCANA)
	assert_eq(RivalAI._tech_identity_axis(MagicDatabase.get_tech("necromancia_pratica")), CityIdentity.AXIS_ARCANA)

func test_tech_identity_axis_resolves_batedor_montado_via_stable_fallback():
	assert_eq(RivalAI._tech_identity_axis(TechDatabase.get_tech("batedor_montado")), CityIdentity.AXIS_MILITAR, "batedor_montado treina no Estabulo (fallback de BuildingDatabase.UNIT_TRAINER_FALLBACK), deveria herdar o eixo militar")

func test_tech_identity_axis_is_empty_for_techs_without_building_or_unit_unlock():
	assert_eq(RivalAI._tech_identity_axis(TechDatabase.get_tech("navegacao")), "", "navegacao nao desbloqueia predio nem unidade, nao deveria ter eixo de identidade")
	for id in ["canalizacao_base", "cataclismo_elemental", "transcendencia_florestal", "alquimia_botanica", "transmutacao_rocha", "geomancia"]:
		assert_eq(RivalAI._tech_identity_axis(MagicDatabase.get_tech(id)), "", "%s nao desbloqueia predio nem unidade, nao deveria ter eixo de identidade" % id)

## Protege a propriedade "sem predio/unidade, identidade nao inventa
## preferencia" — pontuacao de uma tech sem eixo e EXATAMENTE igual com a
## civ sem identidade nenhuma e com a civ no auge de qualquer eixo.
## Especialmente relevante com 7 das 21 techs caindo nesse caso.
func test_score_research_candidate_identity_has_no_effect_for_unmapped_tech():
	var navegacao: TechData = TechDatabase.get_tech("navegacao")
	var player_no_identity := _track_player(CivilizationData.new())

	var player_max_identity := _track_player(CivilizationData.new())
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
	var player_no_personality := _track_player(CivilizationData.new())

	var player_max_personality := _track_player(CivilizationData.new())
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
	var quartel: TechData = TechDatabase.get_tech("quartel") # unlocks_building "barracks" -> militar
	var player := _track_player(CivilizationData.new())
	player.personality[CityIdentity.AXIS_MILITAR] = 1.0

	var score := RivalAI._score_research_candidate(quartel, player)

	assert_almost_eq(score, RivalAI.RESEARCH_WEIGHT_PERSONALITY * 1.0, 0.001)

## Identidade (B3, retrospectiva) e personalidade (B4, prospectiva) sao
## independentes e ADITIVAS — nenhuma anula a outra, os dois termos aparecem
## juntos no score (mandato do usuario: "as duas convivem").
func test_score_research_candidate_personality_and_identity_are_independent_and_additive():
	var invocacao: TechData = MagicDatabase.get_tech("invocacao_espiritos") # unlocks_unit "mage" -> arcane_tower -> arcana
	var player := _track_player(CivilizationData.new())
	var city := City.new()
	city.buildings["sages_tower"] = true # arcana 1/7, identidade > 0
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
## Roadmap "arvore de 10 niveis": o Nivel 2 so abre com 2 techs do Nivel 1
## pesquisadas — celeiro + batedor (nenhuma delas militar) abre o Nivel 2
## sem tocar em "quartel", entao SO "oficina" (ancora cosmetica em
## "celeiro") continua uma cadeia; homem_de_armas/campo_de_tiro/arqueiro
## (todas ancoradas em "quartel", nao pesquisada) ficam sem continuidade,
## mesmo com identidade+personalidade militar no maximo.
func test_decide_research_personality_never_overrides_stronger_continuation():
	var player := _track_player(CivilizationData.new())
	player.researched_techs["celeiro"] = true
	player.researched_techs["batedor"] = true # 2 techs do Nivel 1 -> abre o Nivel 2, so "oficina" continua cadeia

	var city := City.new()
	for id in ["walls", "barracks", "archery_range", "stable", "siege_workshop"]:
		city.buildings[id] = true # militar 1.0, identidade perfeita
	player.cities.append(city)
	player.personality[CityIdentity.AXIS_MILITAR] = 1.0 # personalidade tambem no maximo

	RivalAI.decide_research(player)

	assert_eq(player.current_research, "oficina", "continuacao de cadeia deve vencer mesmo com identidade E personalidade militar no maximo simultaneo, ambas noutra tech sem continuidade")
	city.queue_free()

## --- Roadmap "Fase F"/G: decisao minima de IA pra Ascensao Arcana --------

func _grant_arcane_ritual_prerequisites(city: City) -> void:
	var node_coords: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	for coord in node_coords:
		hex_grid.tiles[coord].resource = "mana_node"
	city.owned_tiles = node_coords
	for tech_id in ["canalizacao_base", "alquimia_botanica", "transmutacao_rocha", "geomancia"]:
		rival.researched_magic[tech_id] = true

## Decisao explicita do usuario: nao e um novo peso de balanceamento, e um
## filtro de candidato obviamente prematuro — a IA nao deveria gastar
## producao numa infraestrutura cujo beneficio de vitoria esta muito
## distante, so pelo +2 mana modesto.
func test_production_candidates_excludes_sanctuary_without_arcane_prerequisites():
	var city = hex_grid.found_city(Vector2i(0, 0), rival, "Cidade A")
	var candidates = RivalAI._production_candidates(rival, city, hex_grid)
	assert_false("arcane_sanctuary" in candidates, "sem os pre-requisitos do ritual, o Santuario nao deveria competir na producao")

func test_production_candidates_includes_sanctuary_once_arcane_prerequisites_are_met():
	var city = hex_grid.found_city(Vector2i(0, 0), rival, "Cidade A")
	_grant_arcane_ritual_prerequisites(city)
	var candidates = RivalAI._production_candidates(rival, city, hex_grid)
	assert_true("arcane_sanctuary" in candidates, "com os pre-requisitos do ritual cumpridos, o Santuario deveria poder competir na producao")

## Especificacao fechada pelo usuario: "tenho condicoes de tentar?", nunca
## "e seguro tentar?" — pre-requisitos + Santuario construido + mana pra
## ativacao MAIS uma manutencao inteira (pra nao comecar um ritual que seria
## interrompido no proprio primeiro processamento de turno por falta de
## mana).
func test_decide_arcane_ritual_activates_once_prerequisites_sanctuary_and_mana_are_met():
	var city = hex_grid.found_city(Vector2i(0, 0), rival, "Cidade A")
	city.buildings[VictoryConditions.SANCTUARY_BUILDING_ID] = true
	_grant_arcane_ritual_prerequisites(city)
	rival.mana = VictoryConditions.ARCANE_RITUAL_ACTIVATION_COST + VictoryConditions.ARCANE_RITUAL_UPKEEP_COST_PER_TURN

	RivalAI.decide_arcane_ritual(rival, hex_grid)

	assert_true(rival.arcane_ritual_active, "com pre-requisitos + Santuario + mana suficiente pra ativacao e uma manutencao, a IA deveria ativar o ritual")

func test_decide_arcane_ritual_does_not_activate_without_the_sanctuary():
	var city = hex_grid.found_city(Vector2i(0, 0), rival, "Cidade A")
	_grant_arcane_ritual_prerequisites(city)
	rival.mana = VictoryConditions.ARCANE_RITUAL_ACTIVATION_COST + VictoryConditions.ARCANE_RITUAL_UPKEEP_COST_PER_TURN

	RivalAI.decide_arcane_ritual(rival, hex_grid)

	assert_false(rival.arcane_ritual_active, "sem o Santuario construido, meets_arcane_ritual_prerequisites nao cobre isso, mas activate_arcane_ritual ainda deveria recusar")

## Falta exatamente a manutencao de UM turno em cima do custo de ativacao —
## a IA nao deveria comecar conscientemente um ritual que ja seria
## interrompido no primeiro processamento de turno por falta de mana.
func test_decide_arcane_ritual_does_not_activate_without_mana_for_one_full_upkeep():
	var city = hex_grid.found_city(Vector2i(0, 0), rival, "Cidade A")
	city.buildings[VictoryConditions.SANCTUARY_BUILDING_ID] = true
	_grant_arcane_ritual_prerequisites(city)
	rival.mana = VictoryConditions.ARCANE_RITUAL_ACTIVATION_COST # falta a manutencao

	RivalAI.decide_arcane_ritual(rival, hex_grid)

	assert_false(rival.arcane_ritual_active, "mana so pra ativacao, sem sobra pra uma manutencao, nao deveria ativar")

func test_decide_arcane_ritual_does_nothing_when_already_active():
	rival.arcane_ritual_active = true
	rival.mana = 1000.0

	RivalAI.decide_arcane_ritual(rival, hex_grid)

	assert_almost_eq(rival.mana, 1000.0, 0.01, "ritual ja ativo: decide_arcane_ritual nao deveria descontar mana nem mexer em mais nada")

## Decisao explicita do usuario: SEM peso de guerra — a Ascensao Arcana
## responde so "tenho condicoes de tentar?", nunca "e seguro tentar?". O
## proprio ritual ja tem mecanismo de risco embutido (GameManager.
## _update_arcane_ritual interrompe sozinho se a cidade cair ou os nodulos
## carem abaixo de 3); before_each ja coloca human x rival em guerra
## (Diplomacy.declare_war), entao este teste confirma a premissa antes de
## provar que ela nao bloqueia a ativacao.
func test_decide_arcane_ritual_activates_even_while_at_war():
	assert_true(rival.is_at_war_with(human), "premissa do before_each: human e rival ja deveriam estar em guerra")
	var city = hex_grid.found_city(Vector2i(0, 0), rival, "Cidade A")
	city.buildings[VictoryConditions.SANCTUARY_BUILDING_ID] = true
	_grant_arcane_ritual_prerequisites(city)
	rival.mana = VictoryConditions.ARCANE_RITUAL_ACTIVATION_COST + VictoryConditions.ARCANE_RITUAL_UPKEEP_COST_PER_TURN

	RivalAI.decide_arcane_ritual(rival, hex_grid)

	assert_true(rival.arcane_ritual_active, "estar em guerra nao deveria impedir a IA de ativar o ritual — sem peso de guerra nesta decisao, por design")

## --- Roadmap "Fase Macro" 5B.2: decisao minima de participacao em
## eventos mundiais -------------------------------------------------------

func test_decide_world_event_participation_participates_during_preparation():
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_PREPARATION

	RivalAI.decide_world_event_participation(rival, 1, event)

	assert_eq(event.participants.get(1), {"decision": true})

func test_decide_world_event_participation_does_nothing_outside_preparation():
	for phase in [WorldEvent.PHASE_DORMANT, WorldEvent.PHASE_ANNOUNCED, WorldEvent.PHASE_ACTIVE, WorldEvent.PHASE_RESOLUTION, WorldEvent.PHASE_COMPLETED]:
		var event := DragonEvent.new()
		event.phase = phase
		RivalAI.decide_world_event_participation(rival, 1, event)
		assert_false(event.participants.has(1), "fase %s nao deveria coletar decisao nenhuma" % phase)

func test_decide_world_event_participation_only_decides_once():
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_PREPARATION
	event.participants[1] = {"decision": false} # decisao ja registrada por outro caminho

	RivalAI.decide_world_event_participation(rival, 1, event)

	assert_eq(event.participants[1], {"decision": false}, "nao deveria sobrescrever uma decisao ja tomada")

## --- Roadmap "Fase Macro" 5B.3-G: IA reage ao Dragao ----------------------
## "Preparation = tempo de preparacao militar" + "IA precisa reagir ao
## Dragao" -- reusa move_unit_toward/CombatResolver.resolve existentes,
## NADA de arvore de decisao nova. v2 (pedido explicito apos playtest):
## prepare_for_world_event() restringe os candidatos a SO' tropa/predio de
## treino (_troop_only_candidates) -- Muralhas/economia nunca competem.

func test_prepare_for_world_event_restricts_production_to_troops_only():
	var city = hex_grid.found_city(Vector2i(0, 0), rival, "Cidade")
	hex_grid.found_city(Vector2i(5, 0), rival, "Cidade B") # 2 cidades: sai do ramo "sempre colonizador"

	RivalAI.prepare_for_world_event(rival, hex_grid, human)

	var building := BuildingDatabase.get_building(city.production_item)
	assert_true(building == null or building.trains_unit != "", "durante o evento, a cidade so' deveria produzir tropa ou o predio de treino que falta -- nunca economia pura")
	assert_ne(city.production_item, "walls", "muralhas nao e' uma tropa -- pedido explicito do usuario e' 'tropas apenas'")

func test_prepare_for_world_event_never_falls_back_to_settler_even_with_a_single_city():
	var city = hex_grid.found_city(Vector2i(0, 0), rival, "Unica")
	city.production_item = "granary" # o que estava produzindo antes do evento

	RivalAI.prepare_for_world_event(rival, hex_grid, human)

	assert_ne(city.production_item, "settler", "colonizador e' economia disfarcada, nao uma tropa -- o atalho de 'cidade unica' de decide_production nao deveria se aplicar aqui")


func test_react_to_dragon_moves_a_military_unit_toward_a_distant_dragon():
	var soldier := _make_unit("warrior", rival, Vector2i(0, 0))
	var dragon := hex_grid.spawn_monster_at(Vector2i(5, 0), "dragon")

	RivalAI.react_to_dragon(soldier, hex_grid, dragon)

	assert_ne(soldier.coord, Vector2i(0, 0), "a unidade deveria ter avancado em direcao ao Dragao")
	assert_lt(HexMetrics.axial_distance(soldier.coord, dragon.coord), HexMetrics.axial_distance(Vector2i(0, 0), dragon.coord), "deveria ter reduzido a distancia ate o Dragao")

func test_react_to_dragon_attacks_via_combat_resolver_when_in_range():
	var soldier := _make_unit("warrior", rival, Vector2i(0, 0))
	soldier.unit_data.attack = 60.0
	var dragon := hex_grid.spawn_monster_at(Vector2i(1, 0), "dragon")
	dragon.hp = 200.0 # bem acima do dano de um golpe -- sobrevive, distinto do teste de "pode matar"
	var dragon_hp_before := dragon.hp

	RivalAI.react_to_dragon(soldier, hex_grid, dragon)

	assert_lt(dragon.hp, dragon_hp_before, "o ataque precisa ter passado por CombatResolver de verdade, causando dano real ao Dragao")

## Roadmap "Dragon Event v1 fechado" -- pedido explicito do usuario:
## "ranking de dano... dano real causado ao Dragao". react_to_dragon
## precisa registrar o dano no DragonEvent ativo (nao so' aplicar via
## CombatResolver) pra' civ do atacante aparecer no ranking.
func test_react_to_dragon_records_damage_on_the_active_dragon_event():
	var _original_players: Array[PlayerData] = GameManager.players
	GameManager.players = [human, rival]
	var soldier := _make_unit("warrior", rival, Vector2i(0, 0))
	soldier.unit_data.attack = 60.0
	var dragon := hex_grid.spawn_monster_at(Vector2i(1, 0), "dragon")
	dragon.hp = 200.0
	var event := DragonEvent.new()
	event.dragon_unit = dragon
	WorldEventManager.active_events.append(event)

	RivalAI.react_to_dragon(soldier, hex_grid, dragon)

	var rival_index: int = GameManager.players.find(rival)
	assert_gt(event.damage_by_civ.get(rival_index, 0.0), 0.0, "o dano causado pelo rival deveria ter sido registrado no ranking do evento")
	WorldEventManager.active_events.clear()
	GameManager.players = _original_players

## Roadmap 5B.3-G v3 -- pedido explicito do usuario apos playtest: "as
## tropas nao conseguem causar dano... ficam ao redor do dragao mas nao
## atacam". Causa real: is_favorable_attack SEMPRE reprovava um Guarda
## padrao (attack 4/defense 3) contra o Dragao (attack 16/defense 8) --
## perde ~25% do proprio HP de contra-ataque contra so' ~2% de dano
## causado -- entao react_to_dragon chegava ao alcance e nunca atacava de
## verdade. Removido: uma guarnicao defendendo a propria cidade precisa
## lutar mesmo em desvantagem (o ponto de "forcar reacao militar").
func test_react_to_dragon_attacks_even_when_the_trade_is_unfavorable():
	var soldier := _make_unit("warrior", rival, Vector2i(0, 0)) # stats padrao, SEM buff nenhum
	var dragon := hex_grid.spawn_monster_at(Vector2i(1, 0), "dragon")
	var dragon_hp_before := dragon.hp

	RivalAI.react_to_dragon(soldier, hex_grid, dragon)

	assert_lt(dragon.hp, dragon_hp_before, "mesmo um Guarda basico (desvantagem clara) precisa causar dano real ao Dragao, nunca so' ficar parado no alcance")

func test_react_to_dragon_can_kill_the_dragon():
	var soldier := _make_unit("warrior", rival, Vector2i(0, 0))
	soldier.unit_data.attack = 999.0
	var dragon := hex_grid.spawn_monster_at(Vector2i(1, 0), "dragon")

	RivalAI.react_to_dragon(soldier, hex_grid, dragon)

	assert_lte(dragon.hp, 0.0, "a IA precisa conseguir matar o Dragao de verdade (Unit -> CombatResolver -> Dragon Unit, sem combate especial)")

func test_react_to_dragon_does_nothing_for_a_retreating_unit():
	var soldier := _make_unit("warrior", rival, Vector2i(0, 0))
	soldier.hp = soldier.unit_data.max_hp * 0.1 # bem abaixo de RETREAT_HP_FRACTION
	var dragon := hex_grid.spawn_monster_at(Vector2i(1, 0), "dragon")
	var dragon_hp_before := dragon.hp

	RivalAI.react_to_dragon(soldier, hex_grid, dragon)

	assert_eq(soldier.coord, Vector2i(0, 0), "unidade em retirada nao deveria avancar pro combate")
	assert_eq(dragon.hp, dragon_hp_before, "unidade em retirada nao deveria atacar")

## 5B.3-G v2 -- pedido explicito do usuario apos playtest: "as tropas ficam
## apenas paradas, no maximo uma que tiver do lado do dragao ataca, mas as
## outras ficam paradas tomando de longe... direcione TODAS as tropas pro
## dragao". Substitui a v1 (so' a unidade GLOBAL mais proxima reagia).
func test_defend_against_dragon_sends_every_troop_near_a_threatened_city_toward_the_dragon():
	var city := hex_grid.found_city(Vector2i(0, 0), rival, "Capital")
	var soldier_a := _make_unit("warrior", rival, Vector2i(1, 0))
	var soldier_b := _make_unit("warrior", rival, Vector2i(-1, 0))
	# Dragao dentro de DRAGON_CITY_AGGRO_RADIUS (5) da cidade -- "sob ataque".
	var dragon := hex_grid.spawn_monster_at(Vector2i(4, 0), "dragon")

	RivalAI.defend_against_dragon(rival, hex_grid, dragon)

	assert_ne(soldier_a.coord, Vector2i(1, 0), "TODA tropa perto da cidade ameacada deveria avancar, nao so' a mais proxima")
	assert_ne(soldier_b.coord, Vector2i(-1, 0), "TODA tropa perto da cidade ameacada deveria avancar, nao so' a mais proxima")
	city.queue_free()

## Pedido explicito do usuario: "quando o dragao sai do agro da cidade as
## tropas retornam para ficar ao redor da cidade pra proteger ela no
## proximo ataque".
func test_defend_against_dragon_recalls_a_wandering_troop_back_to_garrison_when_the_dragon_is_far():
	var city := hex_grid.found_city(Vector2i(0, 0), rival, "Capital")
	var wandering_soldier := _make_unit("warrior", rival, Vector2i(6, 0)) # longe da propria cidade
	# Dragao MUITO longe da cidade -- fora de DRAGON_CITY_AGGRO_RADIUS (5).
	var dragon := hex_grid.spawn_monster_at(Vector2i(0, -9), "dragon")

	RivalAI.defend_against_dragon(rival, hex_grid, dragon)

	var distance_to_city_after: float = HexMetrics.axial_distance(wandering_soldier.coord, city.coord)
	assert_lt(distance_to_city_after, 6.0, "sem o Dragao por perto, a tropa deveria voltar em direcao a propria cidade (garrison)")
	city.queue_free()

func test_defend_against_dragon_leaves_an_already_garrisoned_troop_in_place_when_the_dragon_is_far():
	var city := hex_grid.found_city(Vector2i(0, 0), rival, "Capital")
	var garrisoned_soldier := _make_unit("warrior", rival, Vector2i(1, 0)) # ja perto (GARRISON_RETURN_RADIUS)
	var dragon := hex_grid.spawn_monster_at(Vector2i(0, -9), "dragon") # bem longe

	RivalAI.defend_against_dragon(rival, hex_grid, dragon)

	assert_eq(garrisoned_soldier.coord, Vector2i(1, 0), "tropa ja guarnecendo a cidade nao deveria vagar a toa sem motivo")
	city.queue_free()

func test_defend_against_dragon_does_nothing_without_any_military_unit():
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital") # sem unidade nenhuma
	var dragon := hex_grid.spawn_monster_at(Vector2i(5, 0), "dragon")

	RivalAI.defend_against_dragon(rival, hex_grid, dragon) # nao deveria crashar

	assert_eq(dragon.coord, Vector2i(5, 0))

func test_defend_against_dragon_does_nothing_when_the_dragon_is_null():
	var soldier := _make_unit("warrior", rival, Vector2i(0, 0))

	RivalAI.defend_against_dragon(rival, hex_grid, null) # nao deveria crashar

	assert_eq(soldier.coord, Vector2i(0, 0), "sem Dragao nenhum, nenhuma unidade deveria se mover")
