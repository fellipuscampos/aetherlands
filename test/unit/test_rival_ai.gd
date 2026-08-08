extends GutTest

## Cobre a melhoria da IA rival: avaliar risco antes de atacar
## (CombatResolver.predict() + RivalAI._is_favorable_attack), a cura por
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

func test_favorable_attack_is_true_for_lethal_hit():
	var attacker = _make_unit("warrior", rival, Vector2i(0, 0))
	var defender = _make_unit("warrior", human, Vector2i(1, 0))
	defender.hp = 0.5 # qualquer golpe mata

	assert_true(RivalAI._is_favorable_attack(attacker, defender, hex_grid))

func test_favorable_attack_is_false_when_attacker_would_die_to_counter():
	var attacker = _make_unit("settler", rival, Vector2i(0, 0)) # sem ataque de verdade
	var defender = _make_unit("warrior", human, Vector2i(1, 0))
	attacker.hp = 0.5 # qualquer contra-ataque mata

	assert_false(RivalAI._is_favorable_attack(attacker, defender, hex_grid))

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
