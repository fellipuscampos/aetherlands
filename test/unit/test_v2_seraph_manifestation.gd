extends GutTest

## Aetherlands V2, Fase 17 — Serafim (Grande Manifestação Sagrada), Presença Sagrada (aura), V2ManifestationSystem
## (1 por Escola, derivado, fail-closed), custo de Mana de produção (cobrado na conclusão, espera sem perder PP) e a
## independência dos slots Lendário x Manifestação. A vitória exige o Ritual Final da Fase 23.

const TEMPLE := "v2_building_sacred_temple"
const RITUAL := "v2_building_sacred_ritual"
const SERAPH := "v2_manifestation_seraph"
const CLERIC := "v2_unit_sacred_cleric"
const CHAMPION := "v2_legendary_guardian_champion"
const G_MASTERY := "v2_building_guardian_mastery"
const G_HALL := "v2_building_guardian_hall"

var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _players: Array[PlayerData] = []
var _original_players: Array[PlayerData]
var _original_human: PlayerData
var _original_rivals: Array[PlayerData]
var _original_grid: HexGrid
var _original_turn: int
var _original_state
var _injected: Array[String] = []

func before_each():
	_original_players = GameManager.players
	_original_human = GameManager.human_player
	_original_rivals = GameManager.rival_players
	_original_grid = GameManager.hex_grid
	_original_turn = TurnManager.turn_number
	_original_state = GameManager.state
	grid = HexGrid.new()
	grid._ready()
	for q in range(-9, 10):
		for r in range(-9, 10):
			if absi(q + r) <= 9:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Reino Humano")
	rival = _player("Reino Rival")
	var majors: Array[PlayerData] = [human, rival]
	GameManager.players = majors
	GameManager.human_player = human
	var rivals: Array[PlayerData] = [rival]
	GameManager.rival_players = rivals
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	Diplomacy.declare_war(human, rival)
	TurnManager.turn_number = 30
	human.gold = 500.0
	human.mana = 200.0

func after_each():
	SelectionManager.reset()
	GameManager.players = _original_players
	GameManager.human_player = _original_human
	GameManager.rival_players = _original_rivals
	GameManager.hex_grid = _original_grid
	TurnManager.turn_number = _original_turn
	GameManager.state = _original_state
	for player in _players:
		player.release_relations()
	_players.clear()
	grid.queue_free()

func _player(civ_name: String) -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	player.civ.civ_name = civ_name
	_players.append(player)
	return player

func _learn(player: PlayerData, tier: int = 9) -> void:
	for i in range(1, tier + 1):
		if not player.v2_research.is_completed("v2_magic_sacred_%d" % i):
			assert_true(player.v2_research.complete_research("v2_magic_sacred_%d" % i))

func _ritual_city(owner: PlayerData, coord: Vector2i) -> City:
	var city := grid.found_city(coord, owner, "Cidade %s" % str(coord), true)
	city.city_level = 3
	city.buildings[TEMPLE] = true
	city.buildings[RITUAL] = true
	return city

func _unit(kind: String, owner: PlayerData, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	assert_not_null(unit, "%s em %s" % [kind, str(coord)])
	unit.movement_left = unit.unit_data.movement_points
	return unit

## Roda o turno de produção de UMA cidade pelo mesmo caminho do GameManager (process_turn + nascimento).
func _complete(city: City) -> void:
	TurnManager.turn_number += 0
	city.stored_production = max(city.stored_production, city.production_cost())
	var result := city.process_turn(grid)
	if result.spawn_unit_kind != "":
		_spawn_like_game_manager(city, result.spawn_unit_kind)

func _spawn_like_game_manager(city: City, kind: String) -> void:
	var player := city.owner_player
	var cost := UnitDatabase.create_unit(kind).production_mana_cost
	if not V2ManifestationSystem.spawn_allowed(player, kind):
		V2ManifestationSystem.refuse_spawn(city, kind, false)
	elif cost > 0.0 and player.mana < cost:
		city.production_item = kind
		city.stored_production += city.production_cost()
	else:
		player.mana -= cost
		grid.spawn_unit(WorldSetup.find_spawn_tile(grid, city.coord), UnitDatabase.create_unit(kind), player)

# --- Dados --------------------------------------------------------------------------------------------

func test_seraph_data_and_traits():
	var data := UnitDatabase.create_unit(SERAPH)
	assert_eq([data.unit_name, data.max_hp, data.attack, data.defense, data.movement_points, data.vision_range], ["Serafim", 38.0, 0.0, 7.0, 3.0, 4])
	assert_eq([data.production_cost, data.production_mana_cost, data.supply_cost], [100.0, 60.0, 0])
	assert_false(data.can_basic_attack)
	assert_eq(data.v2_magic_school, "sacred")
	assert_eq(data.movement_profile, UnitData.MovementProfile.FLYING)
	assert_eq(data.ranged_damage_taken_bonus, 0.0, "voar não implica a vulnerabilidade do Grifo")
	for trait_id in [UnitData.TRAIT_CASTER, UnitData.TRAIT_FLYING, UnitData.TRAIT_GRAND_MANIFESTATION]:
		assert_true(data.has_trait(trait_id), trait_id)
	assert_false(data.has_trait(UnitData.TRAIT_LEGENDARY), "NÃO é Lendária")
	assert_false(V2LegendarySystem.is_legendary_kind(SERAPH))
	assert_true(V2ManifestationSystem.is_manifestation_kind(SERAPH))

func test_production_mana_cost_default_is_zero_for_existing_units():
	for kind in ["warrior", CLERIC, CHAMPION, "v2_legendary_griffon_rider", "settler"]:
		assert_eq(UnitDatabase.create_unit(kind).production_mana_cost, 0.0, kind)

func test_seraph_needs_n9_and_the_cathedral():
	var city := _ritual_city(human, Vector2i.ZERO)
	_learn(human, 8)
	assert_false(city.can_train(SERAPH), "sem N9")
	_learn(human, 9)
	assert_true(city.can_train(SERAPH))
	city.buildings.erase(RITUAL)
	assert_false(city.can_train(SERAPH))

func test_seraph_flies_and_lands_only_on_legal_tiles():
	_learn(human)
	var seraph := _unit(SERAPH, human, Vector2i.ZERO)
	grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var reach := grid.unit_reachable(seraph)
	assert_false(reach.has(Vector2i(1, 0)), "nunca pousa na água")
	assert_true(reach.has(Vector2i(2, 0)), "voa por cima")

func test_seraph_knows_the_sacred_repertoire_and_never_attacks():
	_learn(human)
	var seraph := _unit(SERAPH, human, Vector2i.ZERO)
	assert_eq(V2MagicRuntime.spells_for_unit(seraph).size(), 4)
	var enemy := _unit("warrior", rival, Vector2i(1, 0))
	assert_false(CombatResolver.can_attack_unit(seraph, enemy, grid))
	var hp := enemy.hp
	CombatResolver.resolve(seraph, enemy, grid)
	assert_eq(enemy.hp, hp)

func test_seraph_uses_no_supply_and_ignores_logistic_tension():
	_learn(human)
	var before := V2LogisticsRuntime.player_supply_used(human)
	var seraph := _unit(SERAPH, human, Vector2i.ZERO)
	assert_eq(V2LogisticsRuntime.player_supply_used(human), before)
	for coord in [Vector2i(-4, 0), Vector2i(-4, 1)]:
		_unit("v2_unit_sentinel", human, coord)
	assert_true(V2LogisticsRuntime.is_logistically_strained(human))
	assert_eq(V2LogisticsRuntime.combat_multiplier(seraph), 1.0)

func test_counters_dismantle_yes_legend_hunt_no_city_attack_plain():
	for i in range(1, 7):
		rival.v2_research.complete_research("v2_doctrine_rogue_%d" % i)
	for i in range(1, 10):
		rival.v2_research.complete_research("v2_doctrine_ranger_%d" % i)
	_learn(human)
	var seraph := _unit(SERAPH, human, Vector2i.ZERO)
	var assassin := _unit("v2_unit_assassin", rival, Vector2i(1, 0))
	var hunter := _unit("v2_legendary_legend_hunter", rival, Vector2i(0, 1))
	assert_eq(V2TechniqueRuntime.attack_multiplier(assassin, seraph), 1.5, "Desmantelar: caster")
	assert_eq(UnitAbilities.trait_attack_multiplier(hunter, seraph), 1.0, "Caçada Lendária: Manifestação não é Lendária")
	var city := grid.found_city(Vector2i(0, -2), rival, "Fortaleza", true)
	city.city_level = 2
	city.fortification_level = 1
	rival.gold = 500.0
	var hp := seraph.hp
	assert_true(CityDefense.resolve_city_defense_attack(city, seraph, grid))
	assert_eq(hp - seraph.hp, 3.0, "sem +25% de voador")

# --- Presença Sagrada ------------------------------------------------------------------------------------

func test_sacred_presence_radius_two_not_self_not_enemies():
	_learn(human)
	var seraph := _unit(SERAPH, human, Vector2i.ZERO)
	var near := _unit("warrior", human, Vector2i(2, 0))
	var far := _unit("warrior", human, Vector2i(3, 0))
	var enemy := _unit("warrior", rival, Vector2i(0, 2))
	assert_almost_eq(V2UnitAuras.defense_multiplier(near), 1.15, 0.0001)
	assert_eq(V2UnitAuras.defense_multiplier(far), 1.0)
	assert_eq(V2UnitAuras.defense_multiplier(seraph), 1.0, "não afeta o emissor")
	assert_eq(V2UnitAuras.defense_multiplier(enemy), 1.0)
	grid.teleport_unit(far, Vector2i(1, 1))
	assert_almost_eq(V2UnitAuras.defense_multiplier(far), 1.15, 0.0001, "posição atual")
	grid.remove_unit(seraph)
	assert_eq(V2UnitAuras.defense_multiplier(near), 1.0, "sem emissor, sem aura")

func test_two_presences_never_stack_and_the_champion_wins():
	var ally := _unit("warrior", human, Vector2i(0, 0))
	_unit(SERAPH, human, Vector2i(1, 0))
	_unit(SERAPH, human, Vector2i(-1, 0))
	assert_almost_eq(V2UnitAuras.defense_multiplier(ally), 1.15, 0.0001, "mesma aura: não soma")
	_unit(CHAMPION, human, Vector2i(0, 1))
	assert_almost_eq(V2UnitAuras.defense_multiplier(ally), 1.20, 0.0001, "Campeão +20 vence o Serafim +15; nunca +38 nem +35")

func test_presence_lines():
	var seraph := _unit(SERAPH, human, Vector2i.ZERO)
	assert_eq(V2UnitAuras.lines(seraph), ["Passiva da Manifestação — Presença Sagrada", "Aliados em raio 2 recebem +15% de Defesa."] as Array[String])

# --- V2ManifestationSystem -----------------------------------------------------------------------------------

func test_slot_free_then_taken_by_active_then_freed_by_death():
	var city := _ritual_city(human, Vector2i.ZERO)
	_learn(human)
	assert_true(V2ManifestationSystem.slot_available(human, "sacred", city))
	var seraph := _unit(SERAPH, human, Vector2i(3, 0))
	assert_false(V2ManifestationSystem.slot_available(human, "sacred", city))
	assert_false(city.can_train(SERAPH))
	assert_eq(V2ManifestationSystem.training_soft_reason(human, city, SERAPH), V2ManifestationSystem.SLOT_TAKEN_REASON)
	grid.remove_unit(seraph)
	assert_true(city.can_train(SERAPH), "morte/remoção libera; sem cooldown")

func test_production_reserves_the_slot_and_cancelling_frees_it():
	var a := _ritual_city(human, Vector2i(-4, 0))
	var b := _ritual_city(human, Vector2i(4, 0))
	_learn(human)
	a.set_production(SERAPH)
	assert_false(b.can_train(SERAPH), "outra Catedral bloqueada")
	assert_true(a.can_train(SERAPH), "a cidade que produz não se bloqueia")
	a.set_production("warrior")
	assert_true(b.can_train(SERAPH), "trocar a produção libera")

func test_rival_manifestation_never_takes_the_player_slot():
	var city := _ritual_city(human, Vector2i.ZERO)
	_learn(human)
	_unit(SERAPH, rival, Vector2i(5, 0))
	assert_true(city.can_train(SERAPH))

func test_research_reset_keeps_the_seraph_and_its_slot():
	_learn(human)
	var seraph := _unit(SERAPH, human, Vector2i.ZERO)
	human.v2_research.reset()
	assert_true(is_instance_valid(seraph) and seraph.hp > 0.0)
	assert_false(V2ManifestationSystem.slot_available(human, "sacred"))

func test_slot_is_per_school_not_global():
	# Fixture de uma Manifestação de OUTRA Escola: mesmo traço, v2_magic_school diferente. Fixa "1 por Escola".
	_learn(human)
	var other := UnitDatabase.create_unit("warrior")
	other.v2_magic_school = "infernal"
	other.traits.append(UnitData.TRAIT_GRAND_MANIFESTATION)
	grid.spawn_unit(Vector2i(3, 0), other, human)
	assert_eq(V2ManifestationSystem.active_units(human, "infernal").size(), 1)
	assert_true(V2ManifestationSystem.slot_available(human, "sacred"), "a Infernal ocupada não bloqueia a Sagrada")
	_unit(SERAPH, human, Vector2i(-3, 0))
	assert_false(V2ManifestationSystem.slot_available(human, "sacred"))
	assert_false(V2ManifestationSystem.slot_available(human, "infernal"))

func test_legendary_and_manifestation_slots_are_independent():
	for i in range(1, 10):
		human.v2_research.complete_research("v2_doctrine_guardian_%d" % i)
	_learn(human)
	var city := _ritual_city(human, Vector2i(-4, 0))
	city.buildings[G_HALL] = true
	city.buildings[G_MASTERY] = true
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 1
	_unit(CHAMPION, human, Vector2i(4, 0))
	assert_true(city.can_train(SERAPH), "Lendária ativa não bloqueia a Manifestação")
	_unit(SERAPH, human, Vector2i(4, 2))
	assert_true(V2LegendarySystem.has_active_legendary(human))
	assert_eq(V2ManifestationSystem.active_units(human, "sacred").size(), 1, "os dois coexistem")

# --- Mana de produção ------------------------------------------------------------------------------------------

func test_starting_needs_the_mana_but_never_charges_it():
	var city := _ritual_city(human, Vector2i.ZERO)
	_learn(human)
	human.mana = 59.0
	assert_false(city.can_train(SERAPH))
	assert_eq(V2ManifestationSystem.training_soft_reason(human, city, SERAPH), "Requer 60 Mana.")
	human.mana = 60.0
	assert_true(city.can_train(SERAPH), "exatamente 60 pode iniciar")
	city.set_production(SERAPH)
	assert_eq(human.mana, 60.0, "nada reservado nem descontado")
	human.mana = 5.0
	assert_true(city.can_train(SERAPH), "gastar Mana durante a produção não cancela a ordem")

func test_completion_waits_for_mana_without_losing_production_and_pays_once():
	var city := _ritual_city(human, Vector2i.ZERO)
	_learn(human)
	city.set_production(SERAPH)
	human.mana = 10.0
	_complete(city)
	assert_eq(V2ManifestationSystem.active_units(human, "sacred").size(), 0, "não nasce sem Mana")
	assert_eq(city.production_item, SERAPH)
	assert_eq(city.stored_production, 100.0, "PP completos, sem perda")
	assert_eq(city.production_waiting_for_mana(), 60)
	assert_eq(human.mana, 10.0)
	assert_false(V2ManifestationSystem.slot_available(human, "sacred", null), "o slot continua reservado")
	human.mana = 70.0
	_complete(city)
	assert_eq(V2ManifestationSystem.active_units(human, "sacred").size(), 1, "nasce UMA vez")
	assert_eq(human.mana, 10.0, "60 cobrados uma vez")
	assert_eq(city.production_item, "")
	_complete(city)
	assert_eq(V2ManifestationSystem.active_units(human, "sacred").size(), 1, "sem conclusão dupla")

func test_cancelling_needs_no_refund():
	var city := _ritual_city(human, Vector2i.ZERO)
	_learn(human)
	city.set_production(SERAPH)
	city.stored_production = 50.0
	city.set_production("warrior")
	assert_eq(human.mana, 200.0)

func test_two_cities_completing_the_same_cycle_never_create_two_seraphs():
	var a := _ritual_city(human, Vector2i(-4, 0))
	var b := _ritual_city(human, Vector2i(4, 0))
	_learn(human)
	a.production_item = SERAPH
	b.production_item = SERAPH # estado inconsistente (save editado): as duas concluem no mesmo ciclo
	human.mana = 200.0
	_complete(a)
	_complete(b)
	assert_push_error("V2ManifestationSystem")
	assert_eq(V2ManifestationSystem.active_units(human, "sacred").size(), 1, "fail-closed")
	assert_eq(human.mana, 140.0, "só uma cobrança")
	assert_gte(b.stored_production, 100.0, "os PP voltam à cidade recusada (mais a renda do turno)")

func test_the_real_game_manager_turn_spawns_and_charges_once():
	var city := _ritual_city(human, Vector2i.ZERO)
	_learn(human)
	city.set_production(SERAPH)
	city.stored_production = 100.0
	human.mana = 80.0
	TurnManager.end_turn()
	assert_eq(V2ManifestationSystem.active_units(human, "sacred").size(), 1)
	assert_true(human.mana <= 80.0 - 60.0 + V2EconomyRuntime.player_mana_income(human) + 0.001, "60 cobrados (mais a renda do turno)")

# --- Transcendência sem Ritual Final --------------------------------------------------------------------------

func test_transcendence_research_without_final_ritual_never_grants_victory():
	_learn(human)
	_unit(SERAPH, human, Vector2i.ZERO)
	human.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MAGIC_SCHOOL, "infernal")
	assert_true(human.v2_research.complete_research(V2ResearchDatabase.TRANSCENDENCE_ID), "pesquisável estruturalmente")
	_unit("warrior", rival, Vector2i(5, 0))
	grid.found_city(Vector2i(6, -3), rival, "Rival", true)
	GameManager.check_victories()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "nenhuma Transcendência nesta fase")
	assert_false("arcane_ritual_active" in human, "Fase 25: estado V1 removido")
