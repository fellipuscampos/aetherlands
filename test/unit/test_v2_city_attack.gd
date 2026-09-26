extends GutTest

## Aetherlands V2, Fase 16 — Ataque da Cidade: ação EXPLÍCITA de uma cidade fortificada, uma vez
## por turno do dono, contra uma unidade hostil válida dentro do alcance. Dano fixo (semântica da
## milícia V1: sem Defesa do alvo), sem revide, sem +25% contra voadores, Tensão Logística não
## entra, Déficit reduz só o poder (×0,5). Mira pela SelectionManager (ESC/clique inválido não
## gastam). IA: paridade tática mínima (menor HP%, empate menor serial_id). A milícia AUTOMÁTICA
## foi removida. Save/load de last_city_attack_turn vive em test_save_manager.gd.

const G_HALL := "v2_building_guardian_hall"
const G_MASTERY := "v2_building_guardian_mastery"
const GRIFFON := "v2_legendary_griffon_rider"

var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var neutral_peace: PlayerData
var _players: Array[PlayerData] = []
var _original_players: Array[PlayerData]
var _original_human: PlayerData
var _original_rivals: Array[PlayerData]
var _original_grid: HexGrid
var _original_turn: int

func before_each():
	_original_players = GameManager.players
	_original_human = GameManager.human_player
	_original_rivals = GameManager.rival_players
	_original_grid = GameManager.hex_grid
	_original_turn = TurnManager.turn_number
	grid = HexGrid.new()
	grid._ready()
	for q in range(-8, 9):
		for r in range(-8, 9):
			if absi(q + r) <= 8:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Reino Humano")
	rival = _player("Reino Rival")
	neutral_peace = _player("Reino em Paz")
	var majors: Array[PlayerData] = [human, rival, neutral_peace]
	GameManager.players = majors
	GameManager.human_player = human
	var rivals: Array[PlayerData] = [rival, neutral_peace]
	GameManager.rival_players = rivals
	GameManager.hex_grid = grid
	Diplomacy.declare_war(human, rival)
	TurnManager.turn_number = 20
	human.gold = 500.0 # caixa positivo: sem Déficit acidental (a Fortaleza sozinha custa 3 > renda base 2)
	rival.gold = 500.0

func after_each():
	SelectionManager.reset()
	GameManager.players = _original_players
	GameManager.human_player = _original_human
	GameManager.rival_players = _original_rivals
	GameManager.hex_grid = _original_grid
	TurnManager.turn_number = _original_turn
	for player in _players:
		player.release_relations()
	_players.clear()
	grid.queue_free()

func _player(civ_name: String) -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	player.civ.civ_name = civ_name
	_players.append(player)
	return player

func _fortified(owner: PlayerData, level: int = 1, coord: Vector2i = Vector2i.ZERO) -> City:
	var city := grid.found_city(coord, owner, "Cidade %s" % str(coord), true)
	city.city_level = level + 1
	city.fortification_level = level
	city.hp = city.max_hp()
	city.shield = city.max_shield()
	return city

func _unit(kind: String, owner: PlayerData, coord: Vector2i, defense: float = -1.0) -> Unit:
	var data := UnitDatabase.create_unit(kind)
	data.max_hp = 40.0
	if defense >= 0.0:
		data.defense = defense
	var unit := grid.spawn_unit(coord, data, owner)
	assert_not_null(unit, "%s em %s" % [kind, str(coord)])
	return unit

func _monster(coord: Vector2i) -> Unit:
	var unit := grid.spawn_monster_at(coord, "skeleton", false)
	assert_not_null(unit, "monstro em %s" % str(coord))
	unit.unit_data.max_hp = 40.0
	unit.hp = 40.0
	return unit

# --- Requisito: fortificação ---------------------------------------------------------------------

func test_an_unfortified_city_has_no_city_attack():
	var city := grid.found_city(Vector2i.ZERO, human, "Aberta", true)
	_unit("warrior", rival, Vector2i(1, 0))
	assert_eq(CityDefense.city_attack_unavailable_reason(city), "Requer fortificação (Muralhas I ou superior).")
	assert_true(CityDefense.city_attack_targets(city, grid).is_empty())
	assert_eq(CityDefense.city_attack_power(city), 0.0)

func test_power_and_range_by_level():
	var city := _fortified(human, 1)
	assert_eq([CityDefense.city_attack_power(city), CityDefense.city_attack_range(city)], [3.0, 2])
	city.fortification_level = 2
	assert_eq([CityDefense.city_attack_power(city), CityDefense.city_attack_range(city)], [5.0, 2])
	city.fortification_level = 3
	assert_eq([CityDefense.city_attack_power(city), CityDefense.city_attack_range(city)], [7.0, 3])

# --- Alvos -------------------------------------------------------------------------------------------

func test_only_hostile_units_within_range_are_targets():
	var city := _fortified(human, 1)
	var enemy_in := _unit("warrior", rival, Vector2i(2, 0))
	var enemy_out := _unit("warrior", rival, Vector2i(3, 0))
	var own := _unit("warrior", human, Vector2i(1, 0))
	var at_peace := _unit("warrior", neutral_peace, Vector2i(0, 1))
	var monster := _monster(Vector2i(-1, 0))
	var targets := CityDefense.city_attack_targets(city, grid)
	assert_true(enemy_in in targets, "inimigo em guerra a 2")
	assert_true(monster in targets, "monstro neutro é hostil a todos")
	assert_false(enemy_out in targets, "fora do alcance 2")
	assert_false(own in targets)
	assert_false(at_peace in targets, "sem guerra, sem alvo")

func test_fortress_range_three_reaches_further():
	var city := _fortified(human, 3)
	var far := _unit("warrior", rival, Vector2i(3, 0))
	assert_true(far in CityDefense.city_attack_targets(city, grid))

func test_event_managed_monsters_are_never_targets():
	var city := _fortified(human, 1)
	var dragon_like := _monster(Vector2i(1, 0))
	dragon_like.world_event_managed = true
	assert_true(CityDefense.city_attack_targets(city, grid).is_empty())

func test_human_city_needs_visibility_and_the_ai_does_not():
	var human_city := _fortified(human, 1)
	var rival_city := _fortified(rival, 1, Vector2i(4, -2))
	var enemy := _unit("warrior", rival, Vector2i(2, 0))
	var own_near_rival := _unit("warrior", human, Vector2i(5, -2))
	grid.recompute_fog(human)
	assert_true(enemy in CityDefense.city_attack_targets(human_city, grid), "visível: mira")
	grid.visibility[Vector2i(2, 0)] = HexGrid.Visibility.EXPLORED # sob neblina
	assert_false(enemy in CityDefense.city_attack_targets(human_city, grid), "humano não mira através da neblina")
	grid.visibility[Vector2i(5, -2)] = HexGrid.Visibility.UNSEEN
	assert_true(own_near_rival in CityDefense.city_attack_targets(rival_city, grid), "IA: sem restrição de neblina (mesmo padrão das técnicas)")
	assert_false(enemy in CityDefense.city_attack_targets(human_city, grid, {}), "filtro explícito extra continua valendo")

# --- Dano ---------------------------------------------------------------------------------------------

func test_damage_is_flat_ignores_defense_and_has_no_counter():
	var city := _fortified(human, 2)
	var tank := _unit("warrior", rival, Vector2i(1, 0), 50.0)
	var city_hp := city.hp
	var city_shield := city.shield
	assert_eq(CityDefense.predict_city_defense_attack(city, tank), 5.0)
	assert_true(CityDefense.resolve_city_defense_attack(city, tank, grid))
	assert_eq(tank.hp, 35.0, "5 fixo, Defesa 50 não reduz")
	assert_eq([city.hp, city.shield], [city_hp, city_shield], "sem revide")

func test_attack_power_is_3_5_7_in_practice():
	for level in [1, 2, 3]:
		TurnManager.turn_number += 1
		var city := _fortified(human, level, Vector2i(-6 + level * 4, 0))
		var target := _unit("warrior", rival, city.coord + Vector2i(1, 0))
		assert_true(CityDefense.resolve_city_defense_attack(city, target, grid))
		assert_eq(target.hp, 40.0 - V2FortificationData.city_attack_power(level))

func test_flyers_take_the_plain_power_without_the_unit_vulnerability_bonus():
	var city := _fortified(human, 1)
	var griffon := grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit(GRIFFON), rival)
	assert_true(griffon.unit_data.is_flying(), "pré-condição: voador")
	var hp_before := griffon.hp
	assert_true(CityDefense.resolve_city_defense_attack(city, griffon, grid))
	assert_eq(hp_before - griffon.hp, 3.0, "sem os +25% de vulnerabilidade de voador")

func test_deficit_halves_the_power_only():
	var city := _fortified(human, 1)
	city.buildings[G_HALL] = true
	city.buildings[G_MASTERY] = true
	human.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(human), "pré-condição: Déficit")
	var target := _unit("warrior", rival, Vector2i(1, 0))
	assert_eq(CityDefense.predict_city_defense_attack(city, target), 1.5)
	CityDefense.resolve_city_defense_attack(city, target, grid)
	assert_eq(target.hp, 38.5)
	assert_eq(city.max_shield(), 8.0)
	assert_almost_eq(city.defense_bonus(), 0.10, 0.0001)

func test_logistic_tension_never_changes_the_city_attack():
	var city := _fortified(human, 1)
	var placed := 0
	for coord in HexMetrics.coords_within(Vector2i(-5, 3), 2):
		if placed >= 6:
			break
		if grid.tiles.has(coord) and grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null:
			grid.spawn_unit(coord, UnitDatabase.create_unit("v2_unit_shieldbearer"), human)
			placed += 1
	assert_true(V2LogisticsRuntime.is_logistically_strained(human), "pré-condição: Tensão")
	assert_eq(CityDefense.city_attack_power(city), 3.0)

func test_killing_blow_removes_the_target_and_grants_no_reward():
	var city := _fortified(human, 3)
	var weak := _unit("warrior", rival, Vector2i(1, 0))
	weak.hp = 2.0
	human.gold = 10.0
	assert_true(CityDefense.resolve_city_defense_attack(city, weak, grid))
	assert_null(grid.get_unit_at(Vector2i(1, 0)))
	assert_eq(human.gold, 10.0)

# --- Uma vez por turno --------------------------------------------------------------------------------

func test_once_per_owner_turn():
	var city := _fortified(human, 1)
	var a := _unit("warrior", rival, Vector2i(1, 0))
	var b := _unit("warrior", rival, Vector2i(0, 1))
	assert_true(CityDefense.resolve_city_defense_attack(city, a, grid))
	assert_eq(city.last_city_attack_turn, TurnManager.turn_number)
	assert_eq(CityDefense.city_attack_unavailable_reason(city), "Ataque da Cidade já usado neste turno.")
	assert_false(CityDefense.resolve_city_defense_attack(city, b, grid), "segundo disparo recusado")
	assert_eq(b.hp, 40.0)
	TurnManager.turn_number += 1
	assert_eq(CityDefense.city_attack_unavailable_reason(city), "")
	assert_true(CityDefense.resolve_city_defense_attack(city, b, grid), "turno seguinte: disponível de novo")

func test_capture_marks_the_attack_as_spent_for_the_new_owner():
	var city := _fortified(rival, 1, Vector2i(3, 0))
	_unit("warrior", rival, Vector2i(5, 0))
	grid.capture_city(city, human)
	assert_eq(CityDefense.city_attack_unavailable_reason(city), "Ataque da Cidade já usado neste turno.", "sem disparo grátis na troca de dono")

func test_an_invalid_target_never_consumes_the_attack():
	var city := _fortified(human, 1)
	var far := _unit("warrior", rival, Vector2i(5, 0))
	assert_false(CityDefense.resolve_city_defense_attack(city, far, grid))
	assert_eq(city.last_city_attack_turn, -1)

# --- Mira (SelectionManager) ----------------------------------------------------------------------------

func test_targeting_mode_highlights_targets_and_esc_cancels_without_spending():
	var city := _fortified(human, 1)
	var enemy := _unit("warrior", rival, Vector2i(1, 0))
	grid.recompute_fog(human)
	watch_signals(EventBus)
	SelectionManager.start_city_attack_targeting(city)
	assert_same(SelectionManager.city_attack_city, city)
	assert_true(enemy.coord in SelectionManager.city_attack_coords)
	assert_signal_emitted_with_parameters(EventBus, "notify", [SelectionManager.CITY_ATTACK_HINT, ""])
	assert_eq(SelectionManager.CITY_ATTACK_HINT, "Escolha o alvo do Ataque da Cidade (ESC cancela)")
	assert_true(SelectionManager.cancel_city_attack_targeting(), "ESC")
	assert_null(SelectionManager.city_attack_city)
	assert_eq(city.last_city_attack_turn, -1, "cancelar não gasta")
	assert_eq(enemy.hp, 40.0)

func test_clicking_an_invalid_tile_keeps_targeting_and_a_valid_one_fires_once():
	var city := _fortified(human, 1)
	var enemy := _unit("warrior", rival, Vector2i(1, 0))
	grid.recompute_fog(human)
	SelectionManager.start_city_attack_targeting(city)
	SelectionManager._handle_city_attack_click(Vector2i(4, 0))
	assert_same(SelectionManager.city_attack_city, city, "clique inválido: continua mirando")
	assert_eq(city.last_city_attack_turn, -1)
	SelectionManager._handle_city_attack_click(enemy.coord)
	assert_eq(enemy.hp, 37.0)
	assert_null(SelectionManager.city_attack_city, "disparou e saiu da mira")
	SelectionManager.start_city_attack_targeting(city)
	assert_null(SelectionManager.city_attack_city, "já usado: não entra de novo")

func test_the_city_attack_is_not_a_doctrine_technique():
	for technique in V2DoctrineTechniqueDatabase.all_techniques():
		assert_false(String(technique.id).contains("city_attack"), "nenhuma Técnica de Doutrina: %s" % technique.id)
	var city := _fortified(human, 1)
	assert_false("magic_cooldowns" in city, "nenhuma recarga/estado de Técnica na cidade")

# --- IA: paridade tática mínima ----------------------------------------------------------------------------

func test_ai_fires_once_at_the_lowest_hp_fraction():
	var city := _fortified(rival, 1)
	var healthy := _unit("warrior", human, Vector2i(1, 0))
	var hurt := _unit("warrior", human, Vector2i(0, 1))
	hurt.hp = 10.0
	Diplomacy.declare_war(rival, human)
	assert_same(CityDefense.ai_city_defense_turn(city, grid), hurt)
	assert_eq(hurt.hp, 7.0)
	assert_eq(healthy.hp, 40.0)
	assert_null(CityDefense.ai_city_defense_turn(city, grid), "uma vez por turno")

func test_ai_tie_breaks_by_lowest_serial_id():
	var city := _fortified(rival, 1)
	var first := _unit("warrior", human, Vector2i(0, 1))
	var second := _unit("warrior", human, Vector2i(1, 0))
	assert_lt(first.serial_id, second.serial_id)
	assert_same(CityDefense.ai_city_defense_turn(city, grid), first)

func test_ai_only_scans_its_range():
	var city := _fortified(rival, 1)
	_unit("warrior", human, Vector2i(4, 0))
	assert_null(CityDefense.ai_city_defense_turn(city, grid))

func test_an_unfortified_ai_city_never_fires():
	var city := grid.found_city(Vector2i.ZERO, rival, "Aberta", true)
	_unit("warrior", human, Vector2i(1, 0))
	assert_null(CityDefense.ai_city_defense_turn(city, grid))
