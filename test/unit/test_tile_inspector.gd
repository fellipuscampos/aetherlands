extends GutTest

## Task 23 -- TileInspector: "o que existe neste tile?" (modelo unico de
## inspecao, sem cena). Cobre cada tipo de entidade, prioridade, terreno como
## secao separada, multiplas entidades, e as regras de segredo/nevoa.

var hex_grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _created_units: Array[Unit] = []
var _original_hex_grid: HexGrid
var _original_human_player: PlayerData
var _original_players: Array[PlayerData]
var _original_turn: int

func before_each():
	_original_hex_grid = GameManager.hex_grid
	_original_human_player = GameManager.human_player
	_original_players = GameManager.players
	_original_turn = TurnManager.turn_number
	_created_units = []
	hex_grid = HexGrid.new()
	hex_grid._ready()
	for q in range(-6, 7):
		for r in range(-6, 7):
			var coord := Vector2i(q, r)
			if HexMetrics.axial_distance(coord, Vector2i.ZERO) <= 6:
				hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.JUNGLE)
				hex_grid.visibility[coord] = HexGrid.Visibility.VISIBLE
	human = _player("Humanos", "human")
	rival = _player("Elfos", "elf")
	human.enemies[rival] = true
	rival.enemies[human] = true
	GameManager.hex_grid = hex_grid
	GameManager.human_player = human
	GameManager.players = [human, rival]
	TurnManager.turn_number = 10

func after_each():
	hex_grid.free()
	GameManager.hex_grid = _original_hex_grid
	GameManager.human_player = _original_human_player
	GameManager.players = _original_players
	TurnManager.turn_number = _original_turn
	human.enemies.clear()
	rival.enemies.clear()
	for unit in _created_units:
		if is_instance_valid(unit):
			unit.free()

func _player(civ_name: String, race: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = civ_name
	civ.race = race
	return PlayerData.new(civ)

func _unit(kind: String, owner_player: PlayerData, coord: Vector2i) -> Unit:
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit(kind), owner_player, coord)
	unit.reset_movement()
	owner_player.units.append(unit)
	hex_grid.units_by_coord[coord] = unit
	_created_units.append(unit)
	return unit

func _inspect(coord: Vector2i) -> Dictionary:
	return TileInspector.inspect(hex_grid, coord, human)

func _kinds(inspection: Dictionary) -> Array:
	return inspection.entries.map(func(e): return e.kind)

func _text(inspection: Dictionary, key: String = "") -> String:
	return TileInspector.render(inspection, key)

# --- Unidades ---------------------------------------------------------------

func test_own_unit_is_the_main_entry_and_terrain_stays_as_a_section():
	_unit("warrior", human, Vector2i(1, 0))
	var inspection := _inspect(Vector2i(1, 0))
	assert_eq(inspection.entries[0].kind, TileInspector.KIND_UNIT)
	var text := _text(inspection)
	assert_string_contains(text, "Guarda")
	assert_string_contains(text, "HP 12/12")
	assert_string_contains(text, "Movimento 2.0/2.0")
	assert_string_contains(text, "(sua)")
	assert_string_contains(text, "Terreno: Selva (1, 0)")
	assert_true(text.find("Guarda") < text.find("Terreno"), "a entidade vem antes do terreno")

func test_enemy_unit_is_identifiable_with_faction_and_stats():
	_unit("warrior", rival, Vector2i(2, 0))
	var inspection := _inspect(Vector2i(2, 0))
	assert_eq(inspection.entries[0].kind, TileInspector.KIND_UNIT)
	var text := _text(inspection)
	assert_string_contains(text, "Facção: Elfos (em guerra)")
	assert_string_contains(text, "HP 12/12")
	assert_string_contains(text, "Ataque 4.0")
	assert_false("Movimento 2.0/2.0" in text, "movimento restante e' segredo de quem comanda")

func test_enemy_unit_in_peace_is_marked_as_peace():
	human.enemies.clear()
	rival.enemies.clear()
	_unit("warrior", rival, Vector2i(2, 0))
	assert_string_contains(_text(_inspect(Vector2i(2, 0))), "(em paz)")

func test_own_caster_shows_school_action_and_cooldowns():
	var mage := _unit("elementalist", human, Vector2i(1, 1))
	mage.magic_cooldowns["Bola de Fogo"] = TurnManager.turn_number + 3
	var text := _text(_inspect(Vector2i(1, 1)))
	assert_string_contains(text, "Conjurador — Elementalismo")
	assert_string_contains(text, "Ação: pronto para conjurar")
	assert_string_contains(text, "Recarga: Bola de Fogo (3)")

func test_enemy_caster_shows_school_but_not_cooldowns_or_actions():
	var mage := _unit("elementalist", rival, Vector2i(1, 1))
	mage.magic_cooldowns["Bola de Fogo"] = TurnManager.turn_number + 3
	var text := _text(_inspect(Vector2i(1, 1)))
	assert_string_contains(text, "Conjurador — Elementalismo")
	assert_false("Recarga" in text, "recarga de magia inimiga e' segredo")
	assert_false("Ação:" in text)

func test_silence_and_other_visible_status_effects_are_listed():
	var mage := _unit("elementalist", rival, Vector2i(1, 1))
	mage.magic_status["silence"] = TurnManager.turn_number + 2
	assert_string_contains(_text(_inspect(Vector2i(1, 1))), "Silenciado (2 turno(s))")
	var own := _unit("elementalist", human, Vector2i(2, 1))
	own.magic_status["silence"] = TurnManager.turn_number + 2
	assert_string_contains(_text(_inspect(Vector2i(2, 1))), "Ação: silenciado")

# --- Monstros ----------------------------------------------------------------

func test_roaming_monster_is_identified_as_a_monster_not_as_a_lair():
	hex_grid.spawn_monster_at(Vector2i(2, 2), "skeleton", false)
	var inspection := _inspect(Vector2i(2, 2))
	assert_eq(inspection.entries[0].kind, TileInspector.KIND_MONSTER)
	var text := _text(inspection)
	assert_string_contains(text, "Esqueleto")
	assert_string_contains(text, "Monstros (hostis a todos)")
	assert_string_contains(text, "Comportamento: Invasor")
	assert_false("Covil de Monstro" in text, "esqueleto andando nao e' um covil")

func test_camp_boss_is_identified_as_a_boss():
	hex_grid.spawn_monster_at(Vector2i(2, 2), "troll", true)
	var inspection := _inspect(Vector2i(2, 2))
	assert_eq(inspection.entries[0].kind, TileInspector.KIND_BOSS)
	var text := _text(inspection)
	assert_string_contains(text, "Troll")
	assert_string_contains(text, "Chefe")
	assert_string_contains(text, "HP 50/50")

# --- Cidades -----------------------------------------------------------------

func test_own_city_shows_management_facts_and_life():
	var city := hex_grid.found_city(Vector2i(0, 0), human, "Alvorada")
	var text := _text(_inspect(Vector2i(0, 0)))
	assert_string_contains(text, "Alvorada")
	assert_string_contains(text, "População: 1")
	assert_string_contains(text, "Comida: ")
	assert_string_contains(text, "Predios: ")
	assert_string_contains(text, "Vida: %d/%d" % [int(city.hp), int(city.max_hp())])

func test_rival_city_shows_public_facts_only():
	var city := hex_grid.found_city(Vector2i(3, 0), rival, "Silvana")
	city.set_production("warrior")
	city.stored_food = 7.0
	city.buildings["granary"] = true
	var text := _text(_inspect(Vector2i(3, 0)))
	assert_string_contains(text, "Silvana")
	assert_string_contains(text, "Elfos (em guerra)")
	assert_string_contains(text, "Vida: ")
	assert_false("Comida:" in text, "estoque de comida rival e' segredo")
	assert_false("Predios:" in text, "lista de predios rival e' segredo")
	assert_false("Guarda" in text, "producao rival e' segredo")

func test_rival_city_is_hidden_outside_the_vision_but_own_city_is_not():
	hex_grid.found_city(Vector2i(3, 0), rival, "Silvana")
	hex_grid.found_city(Vector2i(-3, 0), human, "Alvorada")
	hex_grid.visibility[Vector2i(3, 0)] = HexGrid.Visibility.EXPLORED
	hex_grid.visibility[Vector2i(-3, 0)] = HexGrid.Visibility.EXPLORED
	assert_eq(_kinds(_inspect(Vector2i(3, 0))), [], "cidade rival fora da visao nao aparece")
	assert_eq(_kinds(_inspect(Vector2i(-3, 0))), [TileInspector.KIND_CITY])

# --- Covil, construcao, magia, recurso ----------------------------------------

func _add_lair(coord: Vector2i, kind: String) -> LairStructure:
	hex_grid.lair_coords.append(coord)
	hex_grid.lair_kind_by_coord[coord] = kind
	var structure := LairStructure.new()
	structure.build(kind, hex_grid)
	hex_grid.add_child(structure)
	hex_grid.lairs_by_coord[coord] = structure
	return structure

func test_defended_lair_shows_type_hp_faction_state_and_reward():
	var lair := _add_lair(Vector2i(2, -2), "goblin")
	hex_grid.spawn_monster_at(Vector2i(2, -2) + HexGrid.NEIGHBOR_DIRS[0], "goblin", true)
	var inspection := _inspect(Vector2i(2, -2))
	assert_eq(inspection.entries[0].kind, TileInspector.KIND_LAIR)
	var text := _text(inspection)
	assert_string_contains(text, "Covil de Goblin")
	assert_string_contains(text, "Estrutura: %d/%d HP" % [int(lair.hp), int(lair.max_hp)])
	assert_string_contains(text, "Monstros")
	assert_string_contains(text, "defendido por 1 monstro")
	assert_string_contains(text, "Recompensa ao destruir")

func test_undefended_lair_says_it_can_be_destroyed():
	_add_lair(Vector2i(2, -2), "goblin")
	assert_string_contains(_text(_inspect(Vector2i(2, -2))), "sem defensores à vista")

func test_lair_defenders_are_not_counted_outside_the_vision():
	_add_lair(Vector2i(2, -2), "goblin")
	hex_grid.spawn_monster_at(Vector2i(2, -2) + HexGrid.NEIGHBOR_DIRS[0], "goblin", true)
	hex_grid.visibility[Vector2i(2, -2) + HexGrid.NEIGHBOR_DIRS[0]] = HexGrid.Visibility.EXPLORED
	var text := _text(_inspect(Vector2i(2, -2)))
	assert_false("defendido por" in text, "defensor fora da visao nao pode ser contado")

func test_lair_out_of_vision_shows_only_remembered_facts():
	_add_lair(Vector2i(2, -2), "goblin")
	hex_grid.visibility[Vector2i(2, -2)] = HexGrid.Visibility.EXPLORED
	var text := _text(_inspect(Vector2i(2, -2)))
	assert_string_contains(text, "Estado atual desconhecido")
	assert_false("Estrutura:" in text)

func test_building_shows_owner_city_and_function():
	var city := hex_grid.found_city(Vector2i(0, 0), human, "Alvorada")
	city.buildings["granary"] = true
	city.building_coords["granary"] = Vector2i(1, 0)
	hex_grid.place_building(Vector2i(1, 0), "granary", human)
	var inspection := _inspect(Vector2i(1, 0))
	assert_eq(inspection.entries[0].kind, TileInspector.KIND_BUILDING)
	var text := _text(inspection)
	assert_string_contains(text, "Cidade: Alvorada")
	assert_string_contains(text, "Efeitos:")
	assert_string_contains(text, "operacional")

func test_rival_building_is_visible_only_with_the_tile_in_view():
	hex_grid.place_building(Vector2i(2, 1), "granary", rival)
	assert_eq(_kinds(_inspect(Vector2i(2, 1))), [TileInspector.KIND_BUILDING])
	hex_grid.visibility[Vector2i(2, 1)] = HexGrid.Visibility.EXPLORED
	assert_eq(_kinds(_inspect(Vector2i(2, 1))), [])

func test_magic_structure_is_labeled_with_its_school():
	hex_grid.place_building(Vector2i(1, 0), "arcane_tower", human)
	var text := _text(_inspect(Vector2i(1, 0)))
	assert_string_contains(text, "Estrutura mágica — Arcanismo")

func test_own_construction_site_shows_progress_and_rival_site_hides_what_is_built():
	var city := hex_grid.found_city(Vector2i(0, 0), human, "Alvorada")
	city.set_production("granary")
	city.pending_building_coord = Vector2i(1, 0)
	city.stored_production = city.production_cost() / 2.0
	var own_text := _text(_inspect(Vector2i(1, 0)))
	assert_string_contains(own_text, "Obra: ")
	assert_string_contains(own_text, "Progresso: 50%")
	var rival_city := hex_grid.found_city(Vector2i(4, 0), rival, "Silvana")
	rival_city.set_production("walls")
	rival_city.pending_building_coord = Vector2i(5, 0)
	var rival_text := _text(_inspect(Vector2i(5, 0)))
	assert_string_contains(rival_text, "Obra em andamento")
	assert_false("Muralha" in rival_text, "o que o rival constroi e' segredo")

func test_magic_region_and_ritual_are_listed_for_visible_tiles():
	rival.magic_effects.append({"effect": "aurora", "center": [1, 1], "origin": [1, 1], "radius": 2, "expires": TurnManager.turn_number + 4, "changes": []})
	var inspection := _inspect(Vector2i(1, 1))
	assert_true(TileInspector.KIND_MAGIC in _kinds(inspection))
	assert_string_contains(_text(inspection), "Duração restante: 4 turno(s)")
	hex_grid.visibility[Vector2i(1, 1)] = HexGrid.Visibility.EXPLORED
	assert_false(TileInspector.KIND_MAGIC in _kinds(_inspect(Vector2i(1, 1))), "area mágica inimiga fora da visão continua oculta")
	human.magic_effects.append({"effect": "aurora", "center": [1, 1], "origin": [1, 1], "radius": 2, "expires": TurnManager.turn_number + 4, "changes": []})
	assert_true(TileInspector.KIND_MAGIC in _kinds(_inspect(Vector2i(1, 1))), "area propria sempre visivel")

func test_resource_is_the_main_entry_when_nothing_else_is_there():
	hex_grid.tiles[Vector2i(2, 0)].resource = "iron"
	var inspection := _inspect(Vector2i(2, 0))
	assert_eq(inspection.entries[0].kind, TileInspector.KIND_RESOURCE)
	var text := _text(inspection)
	assert_string_contains(text, "Recurso: Ferro")
	assert_string_contains(text, "+2 produção")
	assert_string_contains(text, "Terreno: Selva")

# --- Tile vazio, multiplas entidades, segredo ---------------------------------

func test_empty_tile_shows_only_terrain():
	var inspection := _inspect(Vector2i(2, 0))
	assert_eq(inspection.entries.size(), 0)
	var text := _text(inspection)
	assert_string_contains(text, "Terreno: Selva (2, 0)")
	assert_string_contains(text, "Comida 2 | Produção 1 | Ouro 0")

func test_multiple_entities_keep_priority_order_and_are_all_reachable():
	hex_grid.tiles[Vector2i(1, 0)].resource = "horses"
	hex_grid.place_building(Vector2i(1, 0), "granary", human)
	_unit("warrior", human, Vector2i(1, 0))
	var inspection := _inspect(Vector2i(1, 0))
	assert_eq(_kinds(inspection), [TileInspector.KIND_UNIT, TileInspector.KIND_BUILDING, TileInspector.KIND_RESOURCE])
	assert_string_contains(_text(inspection, "building"), "Efeitos")
	assert_string_contains(_text(inspection, "resource"), "Recurso: Cavalos")
	assert_string_contains(_text(inspection, "no-such-key"), "Guarda", "chave desconhecida cai na entidade principal")
	assert_string_contains(TileInspector.summary_line(inspection), "também aqui: ")

func test_city_outranks_a_garrisoned_unit_and_both_are_listed():
	hex_grid.found_city(Vector2i(0, 0), human, "Alvorada")
	_unit("warrior", human, Vector2i(0, 0))
	assert_eq(_kinds(_inspect(Vector2i(0, 0))), [TileInspector.KIND_CITY, TileInspector.KIND_UNIT])

func test_unseen_tile_reveals_nothing():
	hex_grid.tiles[Vector2i(2, 0)].resource = "iron"
	hex_grid.spawn_monster_at(Vector2i(2, 0), "skeleton", false)
	hex_grid.visibility[Vector2i(2, 0)] = HexGrid.Visibility.UNSEEN
	var inspection := _inspect(Vector2i(2, 0))
	assert_eq(inspection.entries.size(), 0)
	assert_string_contains(_text(inspection), "Região inexplorada")
	assert_false("Selva" in _text(inspection), "terreno de tile nunca visto e' segredo")

func test_unit_outside_the_vision_is_hidden_but_own_units_never_are():
	_unit("warrior", rival, Vector2i(2, 0))
	_unit("warrior", human, Vector2i(-2, 0))
	hex_grid.visibility[Vector2i(2, 0)] = HexGrid.Visibility.EXPLORED
	hex_grid.visibility[Vector2i(-2, 0)] = HexGrid.Visibility.EXPLORED
	assert_eq(_kinds(_inspect(Vector2i(2, 0))), [])
	assert_eq(_kinds(_inspect(Vector2i(-2, 0))), [TileInspector.KIND_UNIT])
	assert_string_contains(_text(_inspect(Vector2i(2, 0))), "fora da visão")

func test_veiled_enemy_unit_is_not_inspectable():
	_unit("warrior", rival, Vector2i(2, 0))
	rival.magic_effects.append({"effect": "veil", "center": [2, 0], "origin": [2, 0], "radius": 1, "expires": TurnManager.turn_number + 5, "changes": []})
	assert_true(MagicRuntime.concealed(hex_grid.get_unit_at(Vector2i(2, 0)), human, hex_grid), "pre-condicao: unidade velada")
	assert_false(TileInspector.KIND_UNIT in _kinds(_inspect(Vector2i(2, 0))))

func test_destroyed_entities_leave_no_stale_entry():
	var unit := _unit("warrior", rival, Vector2i(2, 0))
	assert_eq(_kinds(_inspect(Vector2i(2, 0))), [TileInspector.KIND_UNIT])
	hex_grid.remove_unit(unit)
	assert_eq(_kinds(_inspect(Vector2i(2, 0))), [])
	var monster := hex_grid.spawn_monster_at(Vector2i(3, 3), "goblin", false)
	assert_eq(_kinds(_inspect(Vector2i(3, 3))), [TileInspector.KIND_MONSTER])
	hex_grid.remove_unit(monster)
	assert_eq(_kinds(_inspect(Vector2i(3, 3))), [])

func test_out_of_map_coordinate_is_safe():
	var inspection := _inspect(Vector2i(99, 99))
	assert_eq(inspection.entries.size(), 0)
	assert_string_contains(_text(inspection), "Região inexplorada")
