extends GutTest

## Aetherlands V2, Fase 15 — o Construtor (V2ConstructorRuntime): cargas fixadas no nascimento pelo
## tier de Indústria do dono (nunca recarregado por pesquisa posterior), consumo da última carga sem
## semântica de morte, gate de desbloqueio GENÉRICO (UnitData.required_v2_unlock_id, sem nenhum
## `if kind == "v2_unit_builder"` em City/PlayerData) e a matriz de elegibilidade de melhoria (§58).

const BUILDER := "v2_unit_builder"
const WORKSHOP := "v2_building_workshop"

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
	_players.append(player)
	_grids.append(grid)
	var city := grid.found_city(Vector2i(0, 0), player, "Capital", true)
	player.gold = 1000.0
	return {"grid": grid, "player": player, "city": city}

func _unlock_builder(player: PlayerData) -> void:
	player.v2_research.complete_research(V2ResearchDatabase.node_for_unlock_id(WORKSHOP).id)

# --- Gate de desbloqueio GENÉRICO -----------------------------------------------------------------

func test_the_builder_is_locked_before_researching_the_workshop_unlock():
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	assert_false(player.has_unlocked(BUILDER))

func test_researching_the_workshop_alone_unlocks_the_builder():
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	_unlock_builder(player)
	assert_true(player.has_unlocked(BUILDER), "a mesma pesquisa que libera a Oficina libera o Construtor")

func test_the_workshop_trains_the_builder_and_nothing_else_needs_a_new_unlock():
	var s := _grid_with_city()
	_unlock_builder(s.player)
	s.city.buildings[WORKSHOP] = true
	assert_true(s.city.can_train(BUILDER))

func test_is_unit_unlocked_redirects_via_required_v2_unlock_id_generically():
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	assert_eq(UnitDatabase.create_unit(BUILDER).required_v2_unlock_id, WORKSHOP)
	_unlock_builder(player)
	assert_true(V2UnlockSystem.is_unit_unlocked(player, BUILDER))

## Anti-hardcode (§53 do pedido): nenhuma classe de runtime resolve o gate do Construtor citando o
## próprio kind — só o dado (UnitData.required_v2_unlock_id) via V2UnlockSystem.is_unit_unlocked.
func test_no_source_file_special_cases_the_builder_kind_in_the_generic_unlock_path():
	for path in ["res://scripts/city/City.gd", "res://scripts/core/PlayerData.gd", "res://scripts/core/V2UnlockSystem.gd"]:
		var text := FileAccess.get_file_as_string(path)
		assert_false(text.contains("\"v2_unit_builder\""), "%s não deveria citar o kind do Construtor" % path)

# --- Cargas: fixadas no nascimento pelo tier ATUAL de Indústria -----------------------------------

func test_charges_for_a_new_builder_match_the_owners_current_industry_tier():
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	assert_eq(V2ConstructorRuntime.charges_for_new_builder(player), 1, "sem pesquisa nenhuma -- tier 1")
	_research_tier(player, "industry", 2)
	assert_eq(V2ConstructorRuntime.charges_for_new_builder(player), 2)
	_research_tier(player, "industry", 3)
	assert_eq(V2ConstructorRuntime.charges_for_new_builder(player), 3)

## A atribuição de cargas (GameManager, no spawn de produção) roda UMA vez, no instante do
## nascimento — simulado aqui exatamente como o hook real faz: work_charges_remaining =
## charges_for_new_builder(player) uma única vez, logo após o spawn.
func test_a_builder_born_at_tier_one_keeps_its_charge_even_after_later_research():
	var s := _grid_with_city()
	var unit: Unit = s.grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit(BUILDER), s.player)
	unit.work_charges_remaining = V2ConstructorRuntime.charges_for_new_builder(s.player)
	assert_eq(unit.work_charges_remaining, 1, "nasceu no tier 1 -- 1 carga")
	# Pesquisa POSTERIOR nunca recarrega um Construtor já vivo (a atribuição não é reexecutada).
	_research_tier(s.player, "industry", 2)
	_research_tier(s.player, "industry", 3)
	assert_eq(V2ConstructorRuntime.charges_for_new_builder(s.player), 3, "um construtor NOVO agora nasceria com 3...")
	assert_eq(unit.work_charges_remaining, 1, "...mas o já existente continua com 1")

# --- Melhoria: instantânea, consome carga + ação, sem custo ----------------------------------------

func _place_builder(s: Dictionary, coord: Vector2i, charges: int = 2) -> Unit:
	var unit: Unit = s.grid.spawn_unit(coord, UnitDatabase.create_unit(BUILDER), s.player)
	unit.work_charges_remaining = charges
	unit.movement_left = unit.unit_data.movement_points
	return unit

func _resource_tile(s: Dictionary, coord: Vector2i, resource_id: String) -> void:
	var tile := TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	tile.resource = resource_id
	s.grid.tiles[coord] = tile

func test_improving_a_resource_is_instant_never_touches_production_gold_mana_or_supply():
	var s := _grid_with_city()
	_resource_tile(s, Vector2i(1, 0), "iron")
	s.city.owned_tiles.assign([Vector2i(1, 0)])
	var unit := _place_builder(s, Vector2i(1, 0))
	var gold_before: float = s.player.gold
	var mana_before: float = s.player.mana
	assert_eq(s.city.production_item, "")
	assert_true(V2ConstructorRuntime.improve_resource(unit, s.grid))
	assert_eq(s.city.production_item, "", "instantâneo -- nunca entra na fila de produção")
	assert_eq(s.player.gold, gold_before)
	assert_eq(s.player.mana, mana_before)
	assert_eq(s.city.resource_improvements[Vector2i(1, 0)], "v2_improvement_iron_mine")
	var marker: Node3D = s.grid.improvement_markers_by_coord.get(Vector2i(1, 0))
	assert_not_null(marker, "indicação visual no mapa")
	assert_eq(marker.get_child_count(), 2, "modelo KayKit existente (mina) + selo dourado -- nenhum asset novo")

func test_improving_consumes_the_charge_and_the_units_action():
	var s := _grid_with_city()
	_resource_tile(s, Vector2i(1, 0), "iron")
	s.city.owned_tiles.assign([Vector2i(1, 0)])
	var unit := _place_builder(s, Vector2i(1, 0), 2)
	V2ConstructorRuntime.improve_resource(unit, s.grid)
	assert_eq(unit.work_charges_remaining, 1)
	assert_eq(unit.movement_left, 0.0)

func test_using_the_last_charge_removes_the_unit_without_death_or_kill_semantics():
	var s := _grid_with_city()
	_resource_tile(s, Vector2i(1, 0), "iron")
	s.city.owned_tiles.assign([Vector2i(1, 0)])
	var unit := _place_builder(s, Vector2i(1, 0), 1)
	var before_units: int = s.player.units.size()
	assert_true(V2ConstructorRuntime.improve_resource(unit, s.grid))
	assert_true(unit.is_queued_for_deletion(), "consumido -- removido do mapa (queue_free, sem morte)")
	assert_null(s.grid.get_unit_at(Vector2i(1, 0)), "o tile ficou livre")
	assert_false(unit in s.player.units)
	assert_eq(s.player.units.size(), before_units - 1)

func test_a_charge_above_one_never_removes_the_unit():
	var s := _grid_with_city()
	_resource_tile(s, Vector2i(1, 0), "iron")
	s.city.owned_tiles.assign([Vector2i(1, 0)])
	var unit := _place_builder(s, Vector2i(1, 0), 2)
	V2ConstructorRuntime.improve_resource(unit, s.grid)
	assert_false(unit.is_queued_for_deletion())
	assert_true(unit in s.player.units)

# --- Elegibilidade (§58, em ordem) ------------------------------------------------------------------

func test_only_the_builder_kind_can_improve():
	var s := _grid_with_city()
	_resource_tile(s, Vector2i(1, 0), "iron")
	s.city.owned_tiles.assign([Vector2i(1, 0)])
	var other: Unit = s.grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit("warrior"), s.player)
	assert_eq(V2ConstructorRuntime.unavailable_reason(other, s.grid), "Só o Construtor pode melhorar recursos.")

func test_a_builder_with_no_charges_left_cannot_improve():
	var s := _grid_with_city()
	_resource_tile(s, Vector2i(1, 0), "iron")
	s.city.owned_tiles.assign([Vector2i(1, 0)])
	var unit := _place_builder(s, Vector2i(1, 0), 0)
	assert_eq(V2ConstructorRuntime.unavailable_reason(unit, s.grid), "Sem cargas restantes.")

func test_a_builder_that_already_acted_this_turn_cannot_improve():
	var s := _grid_with_city()
	_resource_tile(s, Vector2i(1, 0), "iron")
	s.city.owned_tiles.assign([Vector2i(1, 0)])
	var unit := _place_builder(s, Vector2i(1, 0), 2)
	unit.movement_left = 0.0
	assert_eq(V2ConstructorRuntime.unavailable_reason(unit, s.grid), "A unidade já agiu neste turno.")

func test_a_tile_without_a_recognized_resource_cannot_be_improved():
	var s := _grid_with_city()
	s.city.owned_tiles.assign([Vector2i(1, 0)]) # grama comum, sem recurso
	var unit := _place_builder(s, Vector2i(1, 0))
	assert_eq(V2ConstructorRuntime.unavailable_reason(unit, s.grid), "Não há recurso neste tile.")

func test_a_tile_with_a_building_on_it_cannot_be_improved():
	var s := _grid_with_city()
	_resource_tile(s, Vector2i(1, 0), "iron")
	s.city.owned_tiles.assign([Vector2i(1, 0)])
	var unit := _place_builder(s, Vector2i(1, 0))
	var fake_building := Building.new()
	s.grid.buildings_by_coord[Vector2i(1, 0)] = fake_building
	assert_eq(V2ConstructorRuntime.unavailable_reason(unit, s.grid), "Este tile já tem uma construção.")
	s.grid.buildings_by_coord.erase(Vector2i(1, 0))
	fake_building.free()

func test_a_resource_outside_any_owned_city_territory_cannot_be_improved():
	var s := _grid_with_city()
	# Fundar a cidade já reivindica o raio 1 -- (3, 0) fica fora de qualquer território.
	_resource_tile(s, Vector2i(3, 0), "iron")
	assert_null(s.grid.city_owning_tile(Vector2i(3, 0)), "pré-condição: fora de território")
	var unit := _place_builder(s, Vector2i(3, 0))
	assert_eq(V2ConstructorRuntime.unavailable_reason(unit, s.grid), "O recurso precisa estar no território de uma cidade própria.")

func test_a_resource_owned_by_a_rival_city_cannot_be_improved():
	var s := _grid_with_city()
	var rival := PlayerData.new(CivilizationData.new())
	_players.append(rival)
	var rival_city: City = s.grid.found_city(Vector2i(-3, 0), rival, "Rival", true)
	_resource_tile(s, Vector2i(-2, 0), "iron")
	if not Vector2i(-2, 0) in rival_city.owned_tiles:
		rival_city.owned_tiles.append(Vector2i(-2, 0))
	assert_eq(s.grid.city_owning_tile(Vector2i(-2, 0)), rival_city, "pré-condição: território rival")
	var unit := _place_builder(s, Vector2i(-2, 0))
	assert_eq(V2ConstructorRuntime.unavailable_reason(unit, s.grid), "O recurso precisa estar no território de uma cidade própria.")

func test_an_already_improved_resource_cannot_be_improved_again():
	var s := _grid_with_city()
	_resource_tile(s, Vector2i(1, 0), "iron")
	s.city.owned_tiles.assign([Vector2i(1, 0)])
	s.city.resource_improvements[Vector2i(1, 0)] = "v2_improvement_iron_mine"
	var unit := _place_builder(s, Vector2i(1, 0))
	assert_eq(V2ConstructorRuntime.unavailable_reason(unit, s.grid), "Este recurso já está sendo explorado.")

func test_a_fully_eligible_tile_returns_no_reason():
	var s := _grid_with_city()
	_resource_tile(s, Vector2i(1, 0), "iron")
	s.city.owned_tiles.assign([Vector2i(1, 0)])
	var unit := _place_builder(s, Vector2i(1, 0))
	assert_eq(V2ConstructorRuntime.unavailable_reason(unit, s.grid), "")
	assert_true(V2ConstructorRuntime.can_improve(unit, s.grid))

## Completa, EM ORDEM, os nós N1..`tier` da linha econômica `branch` (a pesquisa exige o anterior).
func _research_tier(player: PlayerData, branch: String, tier: int) -> void:
	var ids: Array = V2InfrastructureEconomyData.unlock_ids_for_branch(branch)
	for i in tier:
		var node := V2ResearchDatabase.node_for_unlock_id(ids[i])
		if not player.v2_research.is_completed(node.id):
			assert_true(player.v2_research.complete_research(node.id), "pesquisa %s" % node.id)
