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
