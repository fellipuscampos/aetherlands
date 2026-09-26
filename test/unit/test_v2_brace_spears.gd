extends GutTest

## Técnicas PASSIVAS (V2DoctrineTechniqueData.ActivationMode.PASSIVE) e Preparar Lanças
## (v2_technique_brace_spears, Aetherlands V2 Fase 5), mais a classificação genérica
## "montada" (UnitData.traits / UnitAbilities.is_mounted). Números (+50%) = BALANCE
## PLACEHOLDER: os testes leem o valor do dado.

const BRACE := "v2_technique_brace_spears"
const WALL := "v2_technique_shield_wall"
const SHIELD := "v2_unit_shieldbearer"
const GUARDIAN := "v2_unit_guardian"
const SENTINEL := "v2_unit_sentinel"

var _grids: Array[HexGrid] = []
var _players: Array[PlayerData] = []
var _cities: Array[City] = []
var _supply_granted: Dictionary = {}
var _original_turn: int
var _original_human: PlayerData

func before_each():
	_original_turn = TurnManager.turn_number
	_original_human = GameManager.human_player
	TurnManager.turn_number = 5

func after_each():
	TurnManager.turn_number = _original_turn
	GameManager.human_player = _original_human
	for grid in _grids:
		if is_instance_valid(grid):
			grid.queue_free()
	_grids.clear()
	for city in _cities:
		if is_instance_valid(city):
			city.free()
	_cities.clear()
	_supply_granted.clear()
	for player in _players:
		player.release_relations()
	_players.clear()

# --- Helpers -------------------------------------------------------------------------------------

func _world() -> HexGrid:
	var grid := HexGrid.new()
	grid._ready()
	for q in range(-4, 5):
		for r in range(-4, 5):
			if absi(q + r) <= 4:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	_grids.append(grid)
	return grid

func _player(through: int) -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	for n in range(1, through + 1):
		player.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	return player

func _unit(grid: HexGrid, player: PlayerData, kind: String, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), player)
	assert_not_null(unit, "spawn %s em %s" % [kind, str(coord)])
	# Aetherlands V2, Fase 15 — este arquivo é sobre a fórmula da passiva, não sobre Suprimentos:
	# sem cidade nenhuma, a capacidade seria 0 e QUALQUER unidade com supply_cost > 0 entraria em
	# Tensão Logística sozinha, poluindo o multiplicador que os testes verificam pela fórmula.
	if unit != null and unit.unit_data.supply_cost > 0 and not _supply_granted.has(player):
		var city := City.new()
		city.owner_player = player
		city.buildings["v2_building_farm"] = true
		city.repeatable_building_counts["v2_building_farm"] = 50
		player.cities.append(city)
		_cities.append(city)
		_supply_granted[player] = true
		if player.gold <= 0.0:
			player.gold = 1000.0
	return unit

## Alvo de teste: defesa baixa e vida alta (o dano nunca cai no piso de 1 nem mata),
## com ou sem o traço "montada" e com um id QUALQUER (a classificação não pode depender dele).
func _target(grid: HexGrid, owner: PlayerData, coord: Vector2i, mounted: bool, fake_id: String = "fixture_target") -> Unit:
	var data := UnitDatabase.create_unit("warrior")
	data.visual_kind = fake_id
	data.unit_name = "Alvo de teste"
	data.defense = 1.0
	data.max_hp = 60.0
	if mounted:
		data.traits.append(UnitData.TRAIT_MOUNTED)
	var unit := grid.spawn_unit(coord, data, owner)
	assert_not_null(unit)
	return unit

func _damage(grid: HexGrid, attacker: Unit, defender: Unit) -> float:
	return CombatResolver.predict(attacker, defender, grid).damage_to_defender

func _expected(grid: HexGrid, attacker: Unit, defender: Unit, attack_mult: float) -> float:
	var terrain := 1.0 + grid.get_tile(defender.coord).defense_bonus
	return maxf(1.0, attacker.unit_data.attack * attack_mult - defender.unit_data.defense * terrain * CombatResolver.DEFENSE_MITIGATION_FACTOR)

func _bonus() -> float:
	return V2DoctrineTechniqueDatabase.get_technique(BRACE).basic_attack_bonus

# --- Framework ACTIVE / PASSIVE ----------------------------------------------------------------------

func test_a_technique_declares_its_activation_mode_in_data():
	assert_eq(V2DoctrineTechniqueDatabase.get_technique(WALL).activation_mode, V2DoctrineTechniqueData.ActivationMode.ACTIVE)
	assert_false(V2DoctrineTechniqueDatabase.get_technique(WALL).is_passive())
	assert_eq(V2DoctrineTechniqueDatabase.get_technique(BRACE).activation_mode, V2DoctrineTechniqueData.ActivationMode.PASSIVE)
	assert_true(V2DoctrineTechniqueDatabase.get_technique(BRACE).is_passive())
	assert_eq(V2DoctrineTechniqueData.new().activation_mode, V2DoctrineTechniqueData.ActivationMode.ACTIVE, "o padrão é ativa")

func test_brace_spears_is_a_passive_with_no_cost_no_cooldown_no_action():
	var technique := V2DoctrineTechniqueDatabase.get_technique(BRACE)
	assert_eq(technique.display_name, "Preparar Lanças")
	assert_eq(technique.display_name, V2ResearchDatabase.node_for_unlock_id(BRACE).display_name)
	assert_eq(technique.doctrine_branch, "guardian")
	assert_eq(technique.cooldown_turns, 0)
	assert_false(technique.consumes_action)
	assert_almost_eq(technique.basic_attack_bonus, 0.5, 0.0001, "+50% (placeholder)")
	assert_eq(technique.basic_attack_target_traits, [UnitData.TRAIT_MOUNTED])
	assert_false(technique.has_defense_effect())
	assert_true(technique.has_attack_effect())

func test_the_description_is_built_from_the_data_and_is_not_a_placeholder_notice():
	var text := V2DoctrineTechniqueDatabase.get_technique(BRACE).description
	assert_true(text.begins_with("Passiva:"), text)
	assert_true(text.contains("+50% de dano de ataque básico contra unidades montadas"), text)
	assert_false(text.contains("Gameplay V2"))
	assert_eq(V2DoctrineTechniqueDatabase.passive_effect_text(V2DoctrineTechniqueDatabase.get_technique(BRACE)), "+50% de dano de ataque básico contra unidades montadas")

func test_the_registry_partitions_active_and_passive_by_data():
	var branch := V2DoctrineTechniqueDatabase.for_branch("guardian")
	assert_eq(branch.filter(func(t): return t.is_passive()).size(), 1)
	assert_eq(branch.filter(func(t): return not t.is_passive()).size(), 1)
	assert_eq(V2DoctrineTechniqueDatabase.attack_bonus_techniques().size(), 2, "Preparar Lanças (Fase 5) e Desmantelar (Fase 10), no registro GLOBAL")
	assert_true(V2DoctrineTechniqueDatabase.defensive_techniques().all(func(t): return not t.is_passive()), "as defensivas são as ativas")

func test_after_n6_the_unit_lists_the_wall_as_an_action_and_brace_spears_as_a_passive():
	var grid := _world()
	var unit := _unit(grid, _player(6), GUARDIAN, Vector2i(0, 0))
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit).size(), 2)
	assert_eq(V2TechniqueRuntime.active_techniques_for_unit(unit).map(func(t): return t.id), [WALL], "só a Muralha ganha botão")
	assert_eq(V2TechniqueRuntime.passive_techniques_for_unit(unit).map(func(t): return t.id), [BRACE])

func test_before_n6_nothing_passive_is_listed():
	var grid := _world()
	var unit := _unit(grid, _player(5), GUARDIAN, Vector2i(0, 0))
	assert_eq(V2TechniqueRuntime.passive_techniques_for_unit(unit), [])
	assert_eq(V2TechniqueRuntime.passive_lines(unit), [])

func test_a_passive_cannot_be_activated_and_says_why():
	var grid := _world()
	var unit := _unit(grid, _player(6), GUARDIAN, Vector2i(0, 0))
	assert_false(V2TechniqueRuntime.can_use(unit, BRACE))
	assert_true(V2TechniqueRuntime.unavailable_reason(unit, BRACE).contains("passiva"))
	assert_false(V2TechniqueRuntime.activate(unit, BRACE))

func test_a_passive_uses_no_action_no_movement_no_mana_and_stores_no_state():
	var grid := _world()
	var player := _player(6)
	player.mana = 9.0
	player.gold = 40.0
	var unit := _unit(grid, player, GUARDIAN, Vector2i(0, 0))
	var target := _target(grid, _player(0), Vector2i(1, 0), true)
	var movement := unit.movement_left
	_damage(grid, unit, target)
	CombatResolver.resolve(unit, target, grid) # o efeito age no combate real...
	assert_eq(unit.magic_status.get(BRACE, null), null, "...sem gravar estado ativo")
	assert_false(unit.magic_cooldowns.has(BRACE), "...nem recarga")
	assert_false(V2TechniqueRuntime.is_active(unit, BRACE))
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, BRACE), 0)
	assert_eq(player.mana, 9.0)
	assert_eq(player.gold, 40.0)
	assert_eq(V2TechniqueRuntime.active_technique_name(unit), "", "não bloqueia upgrade")
	assert_ne(movement, 0.0)

func test_expiry_and_ui_lines_ignore_passives():
	var grid := _world()
	var player := _player(6)
	var unit := _unit(grid, player, GUARDIAN, Vector2i(0, 0))
	TurnManager.turn_number = 9
	assert_eq(V2TechniqueRuntime.expire_finished(player), 0)
	assert_eq(V2TechniqueRuntime.status_lines(unit), [])
	assert_eq(V2TechniqueRuntime.cooldown_lines(unit), [])

func test_the_passive_line_is_the_specified_text_and_only_after_n6():
	var grid := _world()
	var unit := _unit(grid, _player(6), GUARDIAN, Vector2i(0, 0))
	assert_eq(V2TechniqueRuntime.passive_lines(unit), ["Passiva — Preparar Lanças", "+50% de dano de ataque básico contra unidades montadas."])
	assert_true(TileInspector.own_unit_lines(unit).any(func(l): return l.begins_with("Passiva — Preparar Lanças")), "inspetor do dono")

func test_the_public_inspector_facts_never_reveal_the_owner_passive():
	var grid := _world()
	var unit := _unit(grid, _player(6), GUARDIAN, Vector2i(0, 0))
	# Só own_unit_lines (dono) tem a passiva; o que qualquer observador vê não a revela.
	assert_false(TileInspector.status_effect_lines(unit).any(func(l): return l.contains("Passiva")))
	assert_false(TileInspector.unit_traits(unit).any(func(t): return t.contains("Passiva") or t.contains("Lanças")))

# --- Preparar Lanças: efeito no combate ---------------------------------------------------------------

func test_before_n6_there_is_no_bonus_against_a_mounted_target():
	var grid := _world()
	var mine := _player(5)
	var attacker := _unit(grid, mine, GUARDIAN, Vector2i(0, 0))
	var target := _target(grid, _player(0), Vector2i(1, 0), true)
	assert_eq(UnitAbilities.attack_multiplier(attacker, target), 1.0)
	assert_almost_eq(_damage(grid, attacker, target), _expected(grid, attacker, target, 1.0), 0.0001)

func test_after_n6_every_form_of_the_line_gets_the_bonus_against_a_mounted_target():
	var grid := _world()
	var mine := _player(7)
	var rival := _player(0)
	var forms := [SHIELD, GUARDIAN, SENTINEL]
	for i in forms.size():
		var attacker := _unit(grid, mine, forms[i], Vector2i(-3 + i * 3, 0))
		var target := _target(grid, rival, attacker.coord + Vector2i(0, 1), true, "fixture_%d" % i)
		assert_almost_eq(UnitAbilities.attack_multiplier(attacker, target), 1.0 + _bonus(), 0.0001, forms[i])
		assert_almost_eq(_damage(grid, attacker, target), _expected(grid, attacker, target, 1.0 + _bonus()), 0.0001, forms[i])

func test_a_non_mounted_target_takes_normal_damage():
	var grid := _world()
	var attacker := _unit(grid, _player(6), GUARDIAN, Vector2i(0, 0))
	var target := _target(grid, _player(0), Vector2i(1, 0), false)
	assert_eq(UnitAbilities.attack_multiplier(attacker, target), 1.0)
	assert_almost_eq(_damage(grid, attacker, target), _expected(grid, attacker, target, 1.0), 0.0001)

func test_the_bonus_is_exactly_the_data_multiplier_on_the_attack_component():
	var grid := _world()
	var attacker := _unit(grid, _player(6), GUARDIAN, Vector2i(0, 0))
	var mounted := _target(grid, _player(0), Vector2i(1, 0), true)
	var plain := _target(grid, _player(0), Vector2i(0, 1), false)
	var with_bonus := _damage(grid, attacker, mounted)
	var without := _damage(grid, attacker, plain)
	assert_almost_eq(with_bonus - without, attacker.unit_data.attack * _bonus(), 0.0001, "+50% do ATAQUE (4,0 -> 6,0), não da vida nem da defesa")

func test_prediction_and_real_resolution_agree_against_mounted_and_not_mounted():
	var grid := _world()
	var mine := _player(6)
	var rival := _player(0)
	var attacker_a := _unit(grid, mine, GUARDIAN, Vector2i(0, 0))
	var attacker_b := _unit(grid, mine, GUARDIAN, Vector2i(0, 3))
	var mounted := _target(grid, rival, Vector2i(1, 0), true)
	var plain := _target(grid, rival, Vector2i(1, 3), false)
	var predicted_mounted := _damage(grid, attacker_a, mounted)
	var predicted_plain := _damage(grid, attacker_b, plain)

	var mounted_hp := mounted.hp
	var plain_hp := plain.hp
	CombatResolver.resolve(attacker_a, mounted, grid)
	CombatResolver.resolve(attacker_b, plain, grid)

	assert_almost_eq(mounted_hp - mounted.hp, predicted_mounted, 0.0001, "vs montado: perda real == previsão")
	assert_almost_eq(plain_hp - plain.hp, predicted_plain, 0.0001, "vs não montado: perda real == previsão")
	assert_gt(mounted_hp - mounted.hp, plain_hp - plain.hp, "e o montado apanhou mais")

func test_a_real_v1_mounted_unit_is_countered():
	var grid := _world()
	var attacker := _unit(grid, _player(6), GUARDIAN, Vector2i(0, 0))
	var cavalry := _unit(grid, _player(0), "cavalry", Vector2i(1, 0))
	var infantry := _unit(grid, _player(0), "warrior", Vector2i(0, 1))
	assert_almost_eq(UnitAbilities.attack_multiplier(attacker, cavalry), 1.0 + _bonus(), 0.0001, "cavalaria V1 (traço herdado de MOUNTED)")
	assert_eq(UnitAbilities.attack_multiplier(attacker, infantry), 1.0)

func test_a_rival_without_n6_gets_no_bonus_and_research_does_not_leak_between_civilizations():
	var grid := _world()
	var researcher := _player(6)
	var other := _player(5) # também da linha, mas sem N6
	var a := _unit(grid, researcher, GUARDIAN, Vector2i(0, 0))
	var b := _unit(grid, other, GUARDIAN, Vector2i(0, 3))
	var target_a := _target(grid, _player(0), Vector2i(1, 0), true, "fixture_a")
	var target_b := _target(grid, _player(0), Vector2i(1, 3), true, "fixture_b")
	assert_gt(UnitAbilities.attack_multiplier(a, target_a), 1.0)
	assert_eq(UnitAbilities.attack_multiplier(b, target_b), 1.0)

func test_units_outside_the_guardian_line_get_nothing():
	var grid := _world()
	var mine := _player(7)
	var archer := _unit(grid, mine, "archer", Vector2i(0, 0))
	var v1_lancer := _unit(grid, mine, "warrior", Vector2i(0, 3))
	var t1 := _target(grid, _player(0), Vector2i(1, 0), true, "fixture_a")
	var t2 := _target(grid, _player(0), Vector2i(1, 3), true, "fixture_b")
	assert_eq(UnitAbilities.attack_multiplier(archer, t1), 1.0)
	assert_eq(UnitAbilities.attack_multiplier(v1_lancer, t2), 1.0)

func test_the_effect_is_derived_so_a_reloaded_research_state_keeps_it_and_a_reset_removes_it():
	var grid := _world()
	var original := _player(6)
	var restored := _player(0)
	restored.v2_research.load_dict(original.v2_research.to_dict()) # o que o save/load faz
	var attacker := _unit(grid, restored, GUARDIAN, Vector2i(0, 0))
	var target := _target(grid, _player(0), Vector2i(1, 0), true)
	assert_gt(UnitAbilities.attack_multiplier(attacker, target), 1.0, "sem nenhum estado extra salvo")
	restored.v2_research.reset()
	assert_eq(UnitAbilities.attack_multiplier(attacker, target), 1.0, "resetar a pesquisa remove o efeito")
	assert_true(restored.v2_research.completed_ids.is_empty())

func test_city_and_spell_paths_do_not_get_the_basic_attack_bonus():
	var grid := _world()
	var attacker := _unit(grid, _player(7), SENTINEL, Vector2i(0, 0))
	assert_eq(UnitAbilities.city_attack_multiplier(attacker), 1.0, "dano de cidade não é ataque básico contra montado")

func test_v1_lancer_bonus_is_unchanged_and_not_doubled():
	var grid := _world()
	var lancer := _unit(grid, _player(0), "lanceiro", Vector2i(0, 0))
	var cavalry := _unit(grid, _player(0), "cavalry", Vector2i(1, 0))
	assert_eq(UnitAbilities.attack_multiplier(lancer, cavalry), 1.5, "o +50% V1 do Lanceiro segue igual (não é da linha V2)")
	var halberdier := _unit(grid, _player(0), "halberdier", Vector2i(0, 2))
	assert_eq(UnitAbilities.attack_multiplier(halberdier, cavalry), 1.5)

func test_a_second_application_of_the_same_technique_never_happens():
	# Uma técnica = um fator, mesmo com várias unidades da linha por perto.
	var grid := _world()
	var mine := _player(6)
	var attacker := _unit(grid, mine, GUARDIAN, Vector2i(0, 0))
	_unit(grid, mine, SENTINEL, Vector2i(-1, 1))
	_unit(grid, mine, SHIELD, Vector2i(0, 1))
	var target := _target(grid, _player(0), Vector2i(1, 0), true)
	assert_almost_eq(UnitAbilities.attack_multiplier(attacker, target), 1.0 + _bonus(), 0.0001)

# --- Classificação "montada" (genérica) ---------------------------------------------------------------------

func test_a_unit_marked_mounted_is_recognized_and_an_unmarked_one_is_not():
	var data := UnitDatabase.create_unit("warrior")
	assert_false(UnitAbilities.is_mounted(data))
	data.traits.append(UnitData.TRAIT_MOUNTED)
	assert_true(UnitAbilities.is_mounted(data))
	assert_false(UnitAbilities.is_mounted(null))

func test_the_classification_does_not_depend_on_name_or_id():
	var data := UnitDatabase.create_unit("warrior")
	data.visual_kind = "cavalry" # id de cavalaria V1, mas SEM o traço
	data.unit_name = "Cavaleiro"
	assert_false(UnitAbilities.is_mounted(data), "nome/id não classificam")
	var horse := UnitDatabase.create_unit("archer")
	horse.visual_kind = "qualquer_coisa_x"
	horse.traits.append(UnitData.TRAIT_MOUNTED)
	assert_true(UnitAbilities.is_mounted(horse), "o traço basta")

func test_every_v1_mounted_kind_gets_the_trait_and_no_other_trainable_kind_does_except_the_v2_cavalry_line():
	for kind in UnitAbilities.MOUNTED:
		assert_true(UnitAbilities.is_mounted(UnitDatabase.create_unit(kind)), kind)
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		if not (kind in UnitAbilities.MOUNTED):
			# A Doutrina da Cavalaria V2 (Fase 9) declara o traço no dado das suas quatro formas; nenhuma outra unidade o tem.
			var expected := V2UnitLine.doctrine_branch_of(kind) == "cavalry"
			assert_eq(UnitAbilities.is_mounted(UnitDatabase.create_unit(kind)), expected, kind)

func test_a_test_unit_with_the_trait_and_the_cavalry_ids_only_needs_the_trait():
	# Uma unidade de teste com o traço (mesmo com o id do Cavaleiro V2 da Fase 9) é contrariada; a Cavalaria real é coberta em test_v2_cavalry_hall.
	var grid := _world()
	var attacker := _unit(grid, _player(6), GUARDIAN, Vector2i(0, 0))
	var future := _target(grid, _player(0), Vector2i(1, 0), true, "v2_unit_cavalier")
	assert_gt(UnitAbilities.attack_multiplier(attacker, future), 1.0)

func test_the_mounted_trait_is_shown_to_the_player_as_a_public_fact():
	var grid := _world()
	var cavalry := _unit(grid, _player(0), "cavalry", Vector2i(0, 0))
	assert_true(TileInspector.unit_traits(cavalry).has("Montada"))
	assert_false(TileInspector.unit_traits(_unit(grid, _player(0), "warrior", Vector2i(1, 0))).has("Montada"))

# --- Nada de id concreto na lógica ----------------------------------------------------------------------------

func _code_of(path: String) -> String:
	var lines: Array[String] = []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not line.strip_edges().begins_with("#"):
			lines.append(line)
	return "\n".join(lines)

func test_no_combat_or_technique_logic_lists_concrete_ids():
	# Nenhuma lógica decide por id de cavalaria (o traço `mounted` é o dado)...
	for path in ["res://scripts/core/CombatResolver.gd", "res://scripts/core/V2TechniqueRuntime.gd", "res://scripts/core/V2UnitLine.gd", "res://scripts/core/V2UnitUpgrade.gd", "res://scripts/data/V2DoctrineTechniqueDatabase.gd"]:
		var source := _code_of(path)
		if path.ends_with("V2DoctrineTechniqueDatabase.gd"):
			source = source.replace("\"cavalry\"", "") # o registro de técnicas declara o RAMO da Doutrina ("cavalry"), como "warrior"/"ranger"; nenhum id de unidade
		for forbidden in ["cavalry", "cavaleiro", "human_knight", "batedor_montado"]:
			assert_false(source.contains(forbidden), "%s não pode hardcodar %s" % [path, forbidden])
	# ...nem por id de técnica/unidade V2 (o registro de técnicas é o único lugar dos ids de técnica).
	for path in ["res://scripts/core/V2TechniqueRuntime.gd", "res://scripts/core/V2UnitLine.gd", "res://scripts/core/V2UnitUpgrade.gd"]:
		var source := _code_of(path)
		for forbidden in ["brace_spears", "shield_wall", "sentinel", "shieldbearer", "v2_unit_", "v2_technique_"]:
			assert_false(source.contains(forbidden), "%s não pode hardcodar %s" % [path, forbidden])
