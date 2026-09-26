extends GutTest

## Aetherlands V2, Fase 15 — Tensão Logística (V2LogisticsRuntime.is_logistically_strained/
## combat_multiplier): condição DERIVADA (usar mais Suprimentos que a capacidade permite), nunca
## salva. -15% em Ataque E Defesa via uma função GENÉRICA (nunca `if unit.unit_data.visual_kind ==`),
## só pra unidade com supply_cost > 0; nunca afeta movimento, cidade, civil ou conteúdo V1 (supply_cost
## 0 por padrão). predict()==resolve() sob Tensão e composição multiplicativa com outros fatores
## (veterania) já existentes.

const SHIELD := "v2_unit_shieldbearer" # N3, custo 1
const SENTINEL := "v2_unit_sentinel" # N7, custo 3
const HALL := "v2_building_guardian_hall"

var _grids: Array[HexGrid] = []
var _players: Array[PlayerData] = []

func after_each():
	for player in _players:
		player.release_relations()
	_players.clear()
	for grid in _grids:
		if is_instance_valid(grid):
			grid.queue_free()
	_grids.clear()

func _grid_with_city() -> Dictionary:
	var grid := HexGrid.new()
	grid._ready()
	for q in range(-3, 4):
		for r in range(-3, 4):
			if absi(q + r) <= 3:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var player := PlayerData.new(CivilizationData.new())
	for n in range(1, 4):
		player.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	_players.append(player)
	_grids.append(grid)
	var city := grid.found_city(Vector2i(0, 0), player, "Capital", true)
	city.buildings[HALL] = true
	player.gold = 1000.0
	return {"grid": grid, "player": player, "city": city}

## Estoura a capacidade base (4) de propósito: 4 Escudeiros vivos (1 cada) já saturam; o 5º ainda é
## permitido nascer (Tensão NUNCA destrói nada, só penaliza combate — §12 do pedido), só ativa a
## condição.
func _strained_player() -> Dictionary:
	var s := _grid_with_city()
	var coords := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, -1)]
	for coord in coords:
		s.grid.spawn_unit(coord, UnitDatabase.create_unit(SHIELD), s.player)
	return s

func test_is_logistically_strained_false_when_used_is_at_or_below_capacity():
	var s := _grid_with_city()
	s.grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit(SHIELD), s.player)
	s.grid.spawn_unit(Vector2i(-1, 0), UnitDatabase.create_unit(SENTINEL), s.player) # 1 + 3 == 4, no limite, não excede
	assert_false(V2LogisticsRuntime.is_logistically_strained(s.player))

func test_is_logistically_strained_true_once_used_exceeds_capacity():
	var s := _strained_player()
	assert_eq(V2LogisticsRuntime.player_supply_used(s.player), 5)
	assert_true(V2LogisticsRuntime.is_logistically_strained(s.player), "5 usados > 4 de capacidade")

func test_strain_never_destroys_or_blocks_units_already_alive():
	var s := _strained_player()
	for unit in s.player.units:
		assert_true(is_instance_valid(unit), "Tensão nunca remove/mata unidade — só penaliza combate")

# --- combat_multiplier: função pura e GENÉRICA -----------------------------------------------------

func test_combat_multiplier_is_one_when_the_owner_is_not_strained():
	var s := _grid_with_city()
	var unit: Unit = s.grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit(SHIELD), s.player)
	assert_almost_eq(V2LogisticsRuntime.combat_multiplier(unit), 1.0, 0.0001)

func test_combat_multiplier_is_the_tension_penalty_when_strained_and_the_unit_has_supply_cost():
	var s := _strained_player()
	var strained_unit: Unit = s.player.units[0]
	assert_almost_eq(V2LogisticsRuntime.combat_multiplier(strained_unit), V2LogisticsRuntime.TENSION_MULTIPLIER, 0.0001)
	assert_almost_eq(V2LogisticsRuntime.TENSION_MULTIPLIER, 0.85, 0.0001)

func test_combat_multiplier_never_penalizes_a_zero_supply_cost_unit_even_while_the_owner_is_strained():
	var s := _strained_player()
	var v1_unit: Unit = s.grid.spawn_unit(Vector2i(-1, 1), UnitDatabase.create_unit("warrior"), s.player)
	var builder: Unit = s.grid.spawn_unit(Vector2i(1, -2), UnitDatabase.create_unit("v2_unit_builder"), s.player)
	var settler: Unit = s.grid.spawn_unit(Vector2i(-2, 1), UnitDatabase.create_unit("settler"), s.player)
	for civilian in [v1_unit, builder, settler]:
		assert_almost_eq(V2LogisticsRuntime.combat_multiplier(civilian), 1.0, 0.0001, civilian.unit_data.visual_kind)

func test_combat_multiplier_never_affects_movement_points():
	var s := _strained_player()
	var unit: Unit = s.player.units[0]
	var before := unit.unit_data.movement_points
	V2LogisticsRuntime.combat_multiplier(unit) # consulta pura, não deveria nem existir efeito colateral
	assert_eq(unit.unit_data.movement_points, before)

func test_combat_multiplier_handles_null_gracefully():
	assert_almost_eq(V2LogisticsRuntime.combat_multiplier(null), 1.0, 0.0001)

## Anti-hardcode (§20 do pedido): NENHUM id/kind concreto de unidade aparece na decisão — só o dado
## (supply_cost) e o estado derivado do dono.
func test_combat_multiplier_has_no_unit_specific_conditional():
	var code := _code_without_comments("res://scripts/core/V2LogisticsRuntime.gd")
	# (ler o PRÓPRIO kind da unidade pra calcular o delta de upgrade é legítimo — o proibido é
	# decidir comparando com um kind concreto.)
	assert_false(code.contains("visual_kind =="), "nenhum `if unit.unit_data.visual_kind == ...` na Logística")
	assert_false(code.contains("\"v2_unit_") or code.contains("\"v2_legendary_"), "nenhum id de unidade concreto")

func _code_without_comments(path: String) -> String:
	var lines: PackedStringArray = []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var cut := line.find("#")
		lines.append(line if cut == -1 else line.substr(0, cut))
	return "\n".join(lines)

## A MESMA função serve os dois lados de CombatResolver.predict — nunca um par
## attack_multiplier/defense_multiplier separado (§18 do pedido).
func test_a_single_function_serves_both_attack_and_defense_sides_in_predict():
	var text := FileAccess.get_file_as_string("res://scripts/core/CombatResolver.gd")
	var atk_count := text.count("V2LogisticsRuntime.combat_multiplier(attacker)")
	var def_count := text.count("V2LogisticsRuntime.combat_multiplier(defender)")
	assert_eq(atk_count, 1)
	assert_eq(def_count, 1)
	assert_false(text.contains("V2LogisticsRuntime.attack_multiplier") or text.contains("V2LogisticsRuntime.defense_multiplier"), "nunca um par separado")

# --- Integração real: predict()/resolve() sob Tensão -------------------------------------------------

func _place_strained_pair(s: Dictionary) -> Dictionary:
	# A cidade de `s` já está saturada (5 Escudeiros vivos, capacidade 4, todos a 1 tile da
	# capital). Usa um DELES como atacante real (supply_cost > 0) contra um defensor rival em
	# guerra, longe o bastante (3,0) pra nenhum outro Escudeiro do próprio atacante contar como
	# aliado flanqueando. Defesa 0 e HP alto: o dano nunca bate no piso de 1.0 da fórmula, então a
	# penalidade aparece inteira na razão tensionado/aliviado.
	var attacker: Unit = s.player.units[0]
	var rival := PlayerData.new(CivilizationData.new())
	_players.append(rival)
	Diplomacy.declare_war(s.player, rival)
	var defender: Unit = s.grid.spawn_unit(Vector2i(3, 0), UnitDatabase.create_unit(SHIELD), rival)
	defender.unit_data.defense = 0.0
	defender.hp = 1000.0
	return {"attacker": attacker, "defender": defender}

## Alivia a Tensão do jogador de `s` (uma Fazenda: capacidade 4 -> 8) sem mexer em nada do combate.
func _relieve(s: Dictionary) -> void:
	s.city.buildings["v2_building_farm"] = true
	assert_false(V2LogisticsRuntime.is_logistically_strained(s.player), "pré-condição: aliviado")

func test_predict_applies_the_penalty_to_the_strained_attacker():
	var s := _strained_player()
	var pair := _place_strained_pair(s)
	var strained: float = CombatResolver.predict(pair.attacker, pair.defender, s.grid).damage_to_defender
	_relieve(s)
	var relieved: float = CombatResolver.predict(pair.attacker, pair.defender, s.grid).damage_to_defender
	assert_almost_eq(strained, relieved * V2LogisticsRuntime.TENSION_MULTIPLIER, 0.0001, "Ataque x0,85 sob Tensão")

func test_predict_applies_the_penalty_to_the_strained_defender():
	var s := _strained_player()
	var rival := PlayerData.new(CivilizationData.new())
	_players.append(rival)
	Diplomacy.declare_war(s.player, rival)
	var defender: Unit = s.player.units[0]
	defender.hp = 1000.0
	var data := UnitDatabase.create_unit("warrior")
	data.attack = 50.0 # ataque alto: o dano nunca bate no piso de 1.0
	var attacker: Unit = s.grid.spawn_unit(Vector2i(3, 0), data, rival)
	# Ataque efetivo puro (todos os multiplicadores do atacante), medido com a Defesa zerada.
	var real_defense: float = defender.unit_data.defense
	defender.unit_data.defense = 0.0
	var effective_attack: float = CombatResolver.predict(attacker, defender, s.grid).damage_to_defender
	defender.unit_data.defense = real_defense
	var strained: float = CombatResolver.predict(attacker, defender, s.grid).damage_to_defender
	_relieve(s)
	var relieved: float = CombatResolver.predict(attacker, defender, s.grid).damage_to_defender
	var relieved_mitigation := effective_attack - relieved
	assert_gt(relieved_mitigation, 0.0, "pré-condição: a Defesa mitiga algo")
	assert_almost_eq(effective_attack - strained, relieved_mitigation * V2LogisticsRuntime.TENSION_MULTIPLIER, 0.0001, "Defesa x0,85 sob Tensão")

func test_predict_equals_resolve_under_tension():
	var s := _strained_player()
	var pair := _place_strained_pair(s)
	var predicted: float = CombatResolver.predict(pair.attacker, pair.defender, s.grid).damage_to_defender
	var hp_before: float = pair.defender.hp
	CombatResolver.resolve(pair.attacker, pair.defender, s.grid)
	assert_almost_eq(hp_before - pair.defender.hp, predicted, 0.0001, "previsão == resolução também sob Tensão")

func test_strain_composes_multiplicatively_with_veterancy_never_replacing_it():
	var s := _strained_player()
	var pair := _place_strained_pair(s)
	var green: float = CombatResolver.predict(pair.attacker, pair.defender, s.grid).damage_to_defender
	pair.attacker.veterancy_level = 2
	var veteran: float = CombatResolver.predict(pair.attacker, pair.defender, s.grid).damage_to_defender
	assert_almost_eq(veteran / green, pair.attacker.veterancy_multiplier(), 0.0001, "a veterania continua valendo inteira sob Tensão")
	_relieve(s)
	var veteran_relieved: float = CombatResolver.predict(pair.attacker, pair.defender, s.grid).damage_to_defender
	assert_almost_eq(veteran, veteran_relieved * V2LogisticsRuntime.TENSION_MULTIPLIER, 0.0001, "e a Tensão multiplica por cima, sem substituir")

func test_a_civilian_unit_never_takes_the_tension_penalty_even_in_real_combat():
	var s := _strained_player()
	var rival := PlayerData.new(CivilizationData.new())
	_players.append(rival)
	Diplomacy.declare_war(s.player, rival)
	var builder: Unit = s.grid.spawn_unit(Vector2i(2, 0), UnitDatabase.create_unit("v2_unit_builder"), s.player)
	var attacker: Unit = s.grid.spawn_unit(Vector2i(3, 0), UnitDatabase.create_unit("warrior"), rival)
	var predicted: float = CombatResolver.predict(attacker, builder, s.grid).damage_to_defender
	var expected_def: float = builder.unit_data.defense * builder.veterancy_multiplier() # sem 0.85 -- Construtor tem supply_cost 0
	var expected: float = max(1.0, attacker.unit_data.attack * attacker.veterancy_multiplier() - expected_def * CombatResolver.DEFENSE_MITIGATION_FACTOR)
	assert_almost_eq(predicted, expected, 0.001)
