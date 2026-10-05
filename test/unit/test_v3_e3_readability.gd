extends GutTest

## V3 / Etapa 3 — World Readability, Aggro & Ecology Clarity: perfil de mundo padrão 1.0 (só continente principal),
## foco visual/transparência por tile (sem material compartilhado), aggro/perseguição/leash/retorno por tier×era,
## camada de feedback de habilidades segura em headless e na névoa, marcadores de território, inspetor de tile e
## minimapa contínuo com indicador de câmera finito.

var _original := {}
var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _events: Array = []
var _connections: Array = []
var _reduced_motion := false

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "ai_controls_human_seat"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	_original.events = WorldEventManager.to_save_dict()
	_reduced_motion = Settings.reduced_motion
	Settings.reduced_motion = true # efeitos/fades instantâneos: o teste lê o estado final na hora
	GameManager.stagger_ai_turns = false
	_events.clear()
	var callable := func(action: String, info: Dictionary): _events.append([action, info.duplicate()])
	EventBus.combat_ecology_event.connect(callable)
	_connections.append([EventBus.combat_ecology_event, callable])

func after_each():
	for entry in _connections:
		if (entry[0] as Signal).is_connected(entry[1]):
			(entry[0] as Signal).disconnect(entry[1])
	_connections.clear()
	VisualFocusSystem.enabled_in_headless = false
	MonsterAbilityFeedback.enabled_in_headless = false
	Settings.reduced_motion = _reduced_motion
	for player in GameManager.players:
		player.release_relations()
	if grid != null and is_instance_valid(grid):
		grid.queue_free()
	grid = null
	for key in _original:
		if key not in ["turn", "events"]:
			GameManager.set(key, _original[key])
	TurnManager.turn_number = _original.turn
	WorldEventManager.reset_for_new_match()
	WorldEventManager.from_save_dict(_original.events)
	MonsterAbilitySystem.reset()
	MonsterHazardSystem.reset()

# --- Fixture ------------------------------------------------------------------------------------

func _player(name: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = name
	civ.race = "human"
	return PlayerData.new(civ)

func _world(radius: int = 16, terrain: int = HexTileData.TerrainType.GRASSLAND) -> void:
	grid = HexGrid.new()
	add_child(grid)
	grid.map_seed = 99
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			if absi(q + r) <= radius:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(terrain)
	human = _player("Assento 0")
	rival = _player("Assento 1")
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.ai_controls_human_seat = false
	TurnManager.turn_number = 20
	WorldEventManager.reset_for_new_match(1)
	MonsterEcologySystem.enabled = true

func _monster(kind: String, coord: Vector2i, anchor: Vector2i = HexGrid.NO_LAIR) -> Unit:
	var site_anchor := coord if anchor == HexGrid.NO_LAIR else anchor
	MonsterEcologySystem._create_site(grid, kind, site_anchor, HexGrid.NO_LAIR, MonsterEcologySystem.SOURCE_INITIAL, TurnManager.turn_number, [coord] as Array[Vector2i])
	return grid.get_unit_at(coord)

func _soldier(coord: Vector2i, owner: PlayerData = null, kind: String = "warrior") -> Unit:
	return grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner if owner != null else human)

func _act(unit: Unit, turn: int) -> void:
	if not is_instance_valid(unit):
		return
	TurnManager.turn_number = turn
	unit.reset_movement()
	MonsterAI.act_for_unit(unit, grid, turn)

func _count(action: String) -> int:
	return _events.filter(func(e): return e[0] == action).size()

## Mapa só de floresta com árvores reais no MultiMesh compartilhado do grid.
func _forest_world() -> Array:
	_world(6, HexTileData.TerrainType.FOREST)
	grid._rebuild_props()
	var coords: Array = grid._tree_coord_to_index.keys()
	coords.sort()
	return coords

## Põe uma unidade num tile COM decoração: nasce num tile vizinho sem árvore (spawn limpa a decoração do próprio
## tile de propósito) e entra por teleporte, como entraria andando.
func _enter(unit_owner: PlayerData, coord: Vector2i) -> Unit:
	var start := HexGrid.NO_LAIR
	for other in MonsterEcologyPlanner.sorted_coords(grid.tiles.keys()):
		if grid.get_unit_at(other) == null and not grid._tree_coord_to_index.has(other):
			start = other
			break
	if start == HexGrid.NO_LAIR:
		start = MonsterEcologyPlanner.sorted_coords(grid.tiles.keys())[0]
	var unit := _soldier(start, unit_owner)
	grid.teleport_unit(unit, coord)
	return unit

func _overlay(coord: Vector2i) -> MultiMeshInstance3D:
	var node := grid.visual_focus.get_node_or_null("FocusProps_%d_%d" % [coord.x, coord.y]) as MultiMeshInstance3D
	return node if node != null and not node.is_queued_for_deletion() else null

# --- Perfil de mundo -----------------------------------------------------------------------------

func test_standard_world_profile_is_main_continent_only_and_special_profile_is_preserved():
	var standard := WorldProfile.for_dimensions(TitleScreen.MAP_SIZES.large.width, TitleScreen.MAP_SIZES.large.height)
	assert_eq(String(standard.id), "standard_1_0", "novo jogo usa o padrão 1.0")
	assert_false(bool(standard.volcanic_continent))
	assert_false(bool(standard.crystal_continent))
	var special := WorldProfile.for_dimensions(WorldProfile.SPECIAL_CONTINENTS.width, WorldProfile.SPECIAL_CONTINENTS.height)
	assert_eq(String(special.id), "special_continents", "save antigo 320x84 continua com os continentes especiais")
	assert_true(bool(special.volcanic_continent) and bool(special.crystal_continent))
	assert_eq(String(WorldProfile.for_dimensions(41, 41).id), "small")
	assert_eq(BalanceSeedSet.MAP_WIDTH, WorldProfile.STANDARD_1_0.width, "laboratório mede o mundo padrão")
	assert_eq(BalanceSeedSet.MAP_HEIGHT, WorldProfile.STANDARD_1_0.height)

# --- Foco visual ---------------------------------------------------------------------------------

## Obs.: o RenderingServer headless não guarda transforms de MultiMesh (devolve identidade) — o teste confere o que o
## sistema registrou (índices escondidos, overlay, material) em vez de ler a instância de volta.
func test_focus_hides_trees_only_on_the_unit_tile_with_an_own_overlay_and_never_touches_the_shared_material():
	VisualFocusSystem.enabled_in_headless = true
	var coords := _forest_world()
	assert_gt(coords.size(), 2, "precisa de tiles com árvore")
	var target: Vector2i = coords[0]
	var other: Vector2i = coords[coords.size() - 1]
	var shared := grid._props_tree_instance.material_override as StandardMaterial3D
	var shared_transparency := shared.transparency
	var shared_alpha := shared.albedo_color.a
	var shared_scissor := shared.alpha_scissor_threshold
	var unit := _enter(human, target)
	grid.visual_focus.refresh()
	assert_true(grid.visual_focus.is_focused(target))
	var entry: Dictionary = grid.visual_focus._applied[target]
	assert_eq(entry.props.size(), 1, "uma fonte de decoração (árvores) escondida neste tile")
	assert_eq(entry.props[0].source, grid._props_tree_instance)
	assert_eq(entry.props[0].indices, grid._tree_coord_to_index[target], "exatamente as árvores deste tile")
	var overlay := _overlay(target)
	assert_not_null(overlay, "overlay próprio do tile")
	assert_eq(overlay.multimesh.instance_count, (grid._tree_coord_to_index[target] as Array).size())
	assert_eq(overlay.material_override, shared, "mesmo material, reaproveitado sem cópia")
	assert_between(1.0 - overlay.transparency, 0.3, 0.5, "alpha entre 0.30 e 0.50")
	assert_eq(shared.transparency, shared_transparency, "material compartilhado intacto")
	assert_eq(shared.albedo_color.a, shared_alpha)
	assert_eq(shared.alpha_scissor_threshold, shared_scissor)
	assert_eq(grid._props_tree_instance.transparency, 0.0, "o MultiMesh do mapa inteiro continua opaco")
	assert_false(grid.visual_focus.is_focused(other), "outros tiles de floresta intocados")
	assert_null(_overlay(other))
	grid.remove_unit(unit)
	grid.visual_focus.refresh()
	assert_false(grid.visual_focus.is_focused(target), "unidade saiu: árvores voltam")
	assert_null(_overlay(target), "overlay descartado")

func test_focus_applies_to_any_owner_but_never_to_a_unit_hidden_by_fog():
	VisualFocusSystem.enabled_in_headless = true
	var coords := _forest_world()
	var a: Vector2i = coords[0]
	var rival_unit := _enter(rival, a)
	rival_unit.visible = true
	grid.visual_focus.refresh()
	assert_true(grid.visual_focus.is_focused(a), "unidade rival visível também ganha foco (independe de dono)")
	rival_unit.visible = false # névoa
	grid.visual_focus.refresh()
	assert_false(grid.visual_focus.is_focused(a), "unidade escondida pela névoa não revela nada pela transparência")

func test_clearing_decor_under_a_focused_tile_releases_first_and_never_resurrects_trees():
	VisualFocusSystem.enabled_in_headless = true
	var coords := _forest_world()
	var target: Vector2i = coords[0]
	_enter(human, target)
	grid.visual_focus.refresh()
	assert_true(grid.visual_focus.is_focused(target))
	grid._clear_tree_props_at(target) # cidade/estrada/spawn limpando a decoração
	assert_null(_overlay(target), "o foco devolve a instância ANTES da limpeza zerar")
	assert_false(grid._tree_coord_to_index.has(target))
	grid.visual_focus.refresh()
	assert_false(grid.visual_focus.is_focused(target), "sem decoração nem estrutura: nada a focar")
	assert_true(grid.visual_focus._pending_restore.is_empty())

func test_resource_prop_fades_only_on_the_occupied_tile():
	VisualFocusSystem.enabled_in_headless = true
	_world(5)
	for coord in [Vector2i(2, 0), Vector2i(-2, 0)]:
		grid.tiles[coord].resource = "iron"
	grid._resource_props_manager.rebuild(grid.tiles)
	var iron := grid._resource_props_manager._instances["iron"] as MultiMeshInstance3D
	assert_not_null(iron)
	var unit := _soldier(Vector2i(0, 0))
	grid.teleport_unit(unit, Vector2i(2, 0))
	grid.visual_focus.refresh()
	assert_true(grid.visual_focus.is_focused(Vector2i(2, 0)))
	var entry: Dictionary = grid.visual_focus._applied[Vector2i(2, 0)]
	assert_eq(entry.props.size(), 1)
	assert_eq(entry.props[0].source, iron, "o prop do recurso é que fica translúcido")
	assert_false(grid.visual_focus.is_focused(Vector2i(-2, 0)), "o outro Ferro do mapa fica intacto")
	assert_eq(iron.transparency, 0.0)

func test_neutral_monster_gets_the_same_focus_rule():
	VisualFocusSystem.enabled_in_headless = true
	var coords := _forest_world()
	var monster := grid.spawn_monster_detached(Vector2i(0, 0), "goblin")
	assert_not_null(monster)
	grid.teleport_unit(monster, coords[0])
	monster.visible = true
	grid.visual_focus.refresh()
	assert_true(grid.visual_focus.is_focused(coords[0]), "monstro neutro: mesma lógica visual")

func _mesh_transparency(node: Node) -> Array:
	var meshes: Array = []
	VisualFocusSystem._collect_meshes(node, meshes)
	return meshes.map(func(m): return (m as GeometryInstance3D).transparency)

func test_structure_and_terrain_focus_modes_swap_who_is_transparent():
	VisualFocusSystem.enabled_in_headless = true
	_world(8)
	var city := grid.found_city(Vector2i.ZERO, human, "Capital", true)
	var unit := _soldier(Vector2i(1, 0))
	grid.move_unit(unit, Vector2i.ZERO, 0.0)
	grid.visual_focus.refresh()
	assert_true(_mesh_transparency(city).all(func(t): return t > 0.3), "foco na unidade: a cidade fica semitransparente")
	assert_true(_mesh_transparency(unit._visual_root).all(func(t): return t == 0.0), "a unidade fica opaca")
	grid.visual_focus.set_focus(Vector2i.ZERO, VisualFocusSystem.MODE_STRUCTURE)
	grid.visual_focus.refresh()
	assert_true(_mesh_transparency(city).all(func(t): return t == 0.0), "foco na estrutura: cidade opaca")
	assert_true(_mesh_transparency(unit._visual_root).all(func(t): return t > 0.3), "unidade semitransparente")
	grid.visual_focus.set_focus(Vector2i.ZERO, VisualFocusSystem.MODE_TERRAIN)
	grid.visual_focus.refresh()
	assert_true(_mesh_transparency(city).all(func(t): return t > 0.3), "foco no terreno: tudo semitransparente")
	assert_true(_mesh_transparency(unit._visual_root).all(func(t): return t > 0.3))
	grid.visual_focus.clear_focus()
	grid.move_unit(unit, Vector2i(1, 0), 0.0)
	grid.visual_focus.refresh()
	assert_true(_mesh_transparency(city).all(func(t): return t == 0.0), "sem unidade: tudo volta ao original")
	assert_true(_mesh_transparency(unit._visual_root).all(func(t): return t == 0.0))

func test_focus_is_inert_in_headless_simulation():
	_world(4)
	assert_false(grid.visual_focus.active(), "lab/headless: zero custo")
	grid.mark_visual_focus_dirty()
	assert_false(grid.visual_focus._dirty)

# --- Aggro por tier × era --------------------------------------------------------------------------

func test_aggro_radii_follow_tier_and_era():
	var F := WorldPhaseRules.Phase.FOUNDATION
	var A := WorldPhaseRules.Phase.ASCENSION
	var C := WorldPhaseRules.Phase.CONVERGENCE
	var B := MonsterEcologyData.TIER_BASIC
	var I := MonsterEcologyData.TIER_INTERMEDIATE
	var V := MonsterEcologyData.TIER_ADVANCED
	assert_eq(int(MonsterActivityProfile.for_tier(I, F).aggro_radius), 2, "Despertar: INT reage a 1–2")
	assert_eq(int(MonsterActivityProfile.for_tier(V, F).aggro_radius), 1, "Despertar: ADV só a 1")
	assert_eq(int(MonsterActivityProfile.for_tier(I, A).aggro_radius), 4, "Ascensão: INT ~4")
	assert_eq(int(MonsterActivityProfile.for_tier(V, A).aggro_radius), 2, "Ascensão: ADV ~2")
	assert_eq(int(MonsterActivityProfile.for_tier(V, C).aggro_radius), 4, "Convergência: ADV ~4")
	assert_eq(int(MonsterActivityProfile.for_tier(I, C).aggro_radius), 4)
	assert_gte(int(MonsterActivityProfile.for_tier(B, F).aggro_radius), 3, "BASIC ativo no Despertar")
	for phase in [F, A, C]:
		for tier in [B, I, V]:
			var profile := MonsterActivityProfile.for_tier(tier, phase)
			assert_lte(int(profile.aggro_radius), int(profile.pursuit_radius), "perseguição ≥ aggro")
			assert_lte(int(profile.pursuit_radius), int(profile.chase_radius) + 1, "perseguição dentro do leash")

func test_intermediate_ignores_intruders_beyond_its_foundation_aggro_radius():
	_world()
	WorldEventManager.world_phase = WorldPhaseRules.Phase.FOUNDATION
	var troll := _monster("troll", Vector2i(0, 0))
	var far := _soldier(Vector2i(3, 0))
	_act(troll, 21)
	assert_eq(_count("aggro_acquire"), 0, "a 3 tiles no Despertar: não reage")
	assert_eq(far.hp, far.unit_data.max_hp)
	grid.teleport_unit(far, Vector2i(2, 0))
	_act(troll, 22)
	assert_eq(_count("aggro_acquire"), 1, "a 2 tiles: adquire o alvo")

## Itens 99–102 do pedido: reage ao intruso dentro do raio da Era/tier e fica territorial fora dele.
func _reacts(kind: String, phase: int, distance: int) -> bool:
	_events.clear()
	_world()
	WorldEventManager.world_phase = phase
	var monster := _monster(kind, Vector2i(0, 0))
	var intruder := _soldier(Vector2i(distance, 0))
	intruder.unit_data.max_hp = 500.0
	intruder.hp = 500.0
	_act(monster, 21)
	# adjacente: ataca direto (defesa) ou usa a habilidade (Olhar, Raízes) — tudo conta como reação ao intruso
	var reacted := _count("aggro_acquire") > 0 or _count("attack") > 0 or _count("ability") > 0
	grid.queue_free()
	grid = null
	MonsterAbilitySystem.reset()
	MonsterHazardSystem.reset()
	return reacted

func test_era_aggro_reactions_for_intermediate_and_advanced():
	var F := WorldPhaseRules.Phase.FOUNDATION
	var A := WorldPhaseRules.Phase.ASCENSION
	var C := WorldPhaseRules.Phase.CONVERGENCE
	for kind in ["troll", "basilisk", "minotaur"]:
		assert_true(_reacts(kind, F, 1), "%s reage a 1 tile no Despertar" % kind)
		assert_false(_reacts(kind, F, 4), "%s fica territorial a 4 tiles no Despertar" % kind)
	assert_true(_reacts("basilisk", A, 4), "INTERMEDIATE adquire a ~4 tiles na Ascensão")
	assert_true(_reacts("arboreal_ancient", F, 1), "ADVANCED reage a intrusão adjacente no Despertar")
	assert_false(_reacts("arboreal_ancient", F, 3), "ADVANCED fica territorial a distância moderada no Despertar")
	assert_true(_reacts("arboreal_ancient", C, 4), "ADVANCED adquire a ~4 tiles na Convergência")

func test_leash_disengages_and_returns_home_without_ping_pong():
	_world()
	WorldEventManager.world_phase = WorldPhaseRules.Phase.ASCENSION
	var troll := _monster("troll", Vector2i(0, 0))
	var prey := _soldier(Vector2i(3, 0))
	prey.unit_data.max_hp = 500.0
	prey.hp = 500.0
	_act(troll, 21)
	assert_eq(_count("aggro_acquire"), 1)
	grid.teleport_unit(troll, Vector2i(6, 0)) # perseguiu até longe de casa
	grid.teleport_unit(prey, Vector2i(15, 0)) # e a presa fugiu para muito além do leash
	_act(troll, 22)
	assert_eq(_count("leash_disengage"), 1, "desiste do alvo fora do leash")
	assert_true(bool(troll.ability_state.get("returning", false)), "entra em RETORNO")
	var distances: Array[int] = [HexMetrics.axial_distance(troll.coord, Vector2i.ZERO)]
	for turn in range(23, 33):
		_act(troll, turn)
		distances.append(HexMetrics.axial_distance(troll.coord, Vector2i.ZERO))
		if _count("return_home") > 0:
			break
	for i in range(1, distances.size()):
		assert_lte(distances[i], distances[i - 1], "nunca se afasta de casa enquanto volta (sem ping-pong)")
	assert_eq(_count("return_home"), 1, "retorno completo registrado uma vez")
	assert_lte(HexMetrics.axial_distance(troll.coord, Vector2i.ZERO), MonsterAI.RETURN_HOME_RADIUS)
	assert_false(bool(troll.ability_state.get("returning", false)))

func test_monster_never_chases_beyond_its_leash():
	_world()
	WorldEventManager.world_phase = WorldPhaseRules.Phase.CONVERGENCE
	var worg := _monster("worg", Vector2i(0, 0))
	var prey := _soldier(Vector2i(2, 0))
	prey.unit_data.max_hp = 500.0
	prey.hp = 500.0
	var leash := int(MonsterActivityProfile.for_species("worg", WorldPhaseRules.Phase.CONVERGENCE).chase_radius) + int(MonsterEcologyData.behavior("worg").chase_bonus)
	var max_distance := 0
	for turn in range(21, 40):
		if is_instance_valid(prey) and prey.coord.x < 15:
			grid.teleport_unit(prey, prey.coord + Vector2i(1, 0)) # presa recuando sempre
		_act(worg, turn)
		max_distance = maxi(max_distance, HexMetrics.axial_distance(worg.coord, Vector2i.ZERO))
	assert_lte(max_distance, leash + 1, "perseguição nunca infinita")

# --- Feedback de habilidades ------------------------------------------------------------------------

func test_ability_feedback_is_inert_headless_and_respects_fog_when_enabled():
	_world(6)
	var feedback := grid.ability_feedback
	assert_not_null(feedback)
	EventBus.combat_ecology_event.emit("ability", {"ability": MonsterAbilityData.QUICK_PLUNDER, "gold_stolen": 8.0, "target_coord": [0, 0], "source": [1, 0]})
	assert_eq(feedback.effects_spawned, 0, "headless: nenhum nó criado")
	MonsterAbilityFeedback.enabled_in_headless = true
	EventBus.combat_ecology_event.emit("ability", {"ability": MonsterAbilityData.QUICK_PLUNDER, "gold_stolen": 8.0, "target_coord": [0, 0], "source": [1, 0]})
	assert_gt(feedback.effects_spawned, 0, "com tela: aro + rótulo do saque")
	var labels := feedback.get_children().filter(func(n): return n is Label3D and String(n.text) == "Saque!") # Etapa 4: cidade sem dono humano não mostra valor
	assert_eq(labels.size(), 1)
	var before := feedback.effects_spawned
	grid.visibility[Vector2i(3, 0)] = HexGrid.Visibility.EXPLORED
	EventBus.combat_ecology_event.emit("ability", {"ability": MonsterAbilityData.VENOMOUS_BITE, "target_coord": [3, 0], "source": [4, 0]})
	assert_eq(feedback.effects_spawned, before, "fora da visão: nada (não revela alvo oculto)")

func test_worm_burrow_feedback_shows_origin_trail_and_destination_markers():
	_world()
	var worm := _monster("colossal_worm", Vector2i(0, 0))
	worm.set_hp_silent(worm.unit_data.max_hp * 0.3)
	_soldier(Vector2i(1, 0))
	TurnManager.turn_number = 30
	assert_true(MonsterAbilitySystem.try_active(worm, grid, Vector2i(0, 0), 9))
	var dest: Vector2i = MonsterAbilitySystem.telegraph_coords()[0]
	var hazards := grid.get_node_or_null("MonsterHazards")
	assert_not_null(hazards)
	var marker := hazards.get_node_or_null("Hazard_telegraph_%d_%d" % [dest.x, dest.y])
	assert_not_null(marker, "marcador no destino")
	assert_gt(marker.get_child_count(), 3, "buraco na origem + trilha de montinhos")

func test_unit_status_overlay_and_barrier_shell_are_render_only_and_idempotent():
	_world(4)
	var unit := _soldier(Vector2i(0, 0))
	UnitStatusEffects.apply(unit, UnitStatusEffects.POISON, 3)
	assert_not_null(unit.get_node_or_null(Unit.STATUS_MARKER_NAME), "anel/rótulo de estado")
	unit.refresh_status_overlay()
	assert_eq(unit.get_children().filter(func(n): return n.name == Unit.STATUS_MARKER_NAME).size(), 1, "idempotente")
	unit.magic_status.erase(UnitStatusEffects.POISON)
	unit.refresh_status_overlay()
	assert_true(unit.get_node_or_null(Unit.STATUS_MARKER_NAME) == null or unit.get_node(Unit.STATUS_MARKER_NAME).is_queued_for_deletion())
	unit.arcane_barrier = 5.0
	unit.refresh_status_overlay()
	assert_not_null(unit.get_node_or_null(Unit.BARRIER_MARKER_NAME), "casca da Barreira Arcana")

# --- Território / inspetor ----------------------------------------------------------------------------

func test_territory_marker_only_for_discovered_anchor_only_sites_and_removed_when_cleared():
	_world()
	MonsterAbilityFeedback.enabled_in_headless = true
	var seen := _monster("worg", Vector2i(4, 0))
	var hidden := _monster("troll", Vector2i(-6, 0))
	human.explored_tiles[Vector2i(4, 0)] = true
	grid.visibility[Vector2i(-6, 0)] = HexGrid.Visibility.UNSEEN
	grid.ability_feedback.refresh_site_markers()
	assert_eq(grid.ability_feedback.site_marker_count(), 1, "só o território já descoberto")
	var marker: Node3D = grid.ability_feedback._site_markers.values()[0]
	var label := marker.get_children().filter(func(n): return n is Label3D)[0] as Label3D
	assert_eq(label.text, "Território de Worgs", "nome por espécie — não 'Covil'")
	grid.remove_unit(seen)
	MonsterEcologySystem._refresh_sites(grid, TurnManager.turn_number)
	grid.ability_feedback.refresh_site_markers()
	assert_eq(grid.ability_feedback.site_marker_count(), 0, "área limpa: marcador some")
	assert_true(is_instance_valid(hidden))

func test_tile_inspector_explains_territory_hazards_and_repopulation_without_calling_it_a_lair():
	_world()
	_monster("worg", Vector2i(4, 0))
	grid.visibility[Vector2i(4, 0)] = HexGrid.Visibility.VISIBLE
	var inspection := TileInspector.inspect(grid, Vector2i(4, 0), human)
	var territory := TileInspector.entry_for_key(inspection, "territory")
	assert_false(territory.is_empty(), "território aparece no inspetor")
	assert_false(String(territory.title).begins_with("Covil"), "território ecológico não é Covil")
	assert_true(TileInspector.REPOPULATION_HELP in territory.lines, "texto de repopulação")
	var hive := _monster("corrupted_hero", Vector2i(-5, 0))
	MonsterHazardSystem.process_round(grid, 21, {hive.ecology_site_id: Vector2i(-5, 0)})
	var infected := HexGrid.NO_LAIR
	for coord in MonsterEcologyPlanner.sorted_coords(grid.get_neighbors(Vector2i(-5, 0))):
		if MonsterHazardSystem.is_infected(coord):
			infected = coord
			break
	assert_ne(infected, HexGrid.NO_LAIR)
	grid.visibility[infected] = HexGrid.Visibility.EXPLORED
	assert_true(TileInspector.entry_for_key(TileInspector.inspect(grid, infected, human), "hazard:infection").is_empty(), "perigo não visível agora não é revelado")
	grid.visibility[infected] = HexGrid.Visibility.VISIBLE
	var hazard := TileInspector.entry_for_key(TileInspector.inspect(grid, infected, human), "hazard:infection")
	assert_eq(String(hazard.title), "Contaminação Micótica")
	assert_true(hazard.lines.any(func(l): return String(l).contains("COMEÇA o turno")), "dano só no início do turno")
	var view := TilePresenter.build(grid, infected, human)
	assert_true(view.features.any(func(f): return String(f.kind) == "hazard"), "painel de tile mostra o perigo")

func test_unit_panel_of_an_ecology_creature_says_territory_not_lair():
	_world()
	var worg := _monster("worg", Vector2i(4, 0))
	grid.visibility[Vector2i(4, 0)] = HexGrid.Visibility.VISIBLE
	var rows: Array = UnitPresenter._footer(worg, false, human, grid)
	var texts := rows.map(func(r): return "%s: %s" % [r.caption, r.text])
	assert_true(texts.has("Território: Território de Worgs"), "painel de unidade nomeia o território")
	assert_false(texts.any(func(t): return String(t).to_lower().contains("covil")), "sem 'covil' para sítio sem estrutura")
	assert_true(texts.any(func(t): return String(t).begins_with("Faro de Sangue")), "habilidade listada")

func test_feedback_labels_on_the_same_tile_stack_instead_of_overlapping():
	_world(4)
	MonsterAbilityFeedback.enabled_in_headless = true
	var feedback := grid.ability_feedback
	feedback._label(Vector2i.ZERO, "Envenenado", Color.GREEN)
	feedback._label(Vector2i.ZERO, "Veneno −2", Color.GREEN)
	var labels := feedback.get_children().filter(func(n): return n is Label3D)
	assert_eq(labels.size(), 2)
	assert_gt(absf((labels[1] as Label3D).position.y - (labels[0] as Label3D).position.y), 0.3, "segundo rótulo acima do primeiro")

# --- Minimapa ---------------------------------------------------------------------------------------

func test_minimap_terrain_is_continuous_and_camera_polygon_is_finite_and_clipped():
	_world(10)
	for coord in grid.tiles:
		grid.visibility[coord] = HexGrid.Visibility.VISIBLE
	GameManager.human_player = null
	var minimap: Control = load("res://scripts/ui/Minimap.gd").new()
	minimap.size = Vector2(260, 120)
	add_child_autofree(minimap)
	minimap._on_restart()
	var rect: Rect2 = minimap.map_rect()
	var center: Vector2 = minimap._project(Vector2i.ZERO, grid.hex_size)
	var holes := 0
	for dy in range(-12, 13):
		for dx in range(-30, 31):
			if minimap._terrain_image.get_pixel(int(center.x) + dx, int(center.y) + dy).a < 0.5:
				holes += 1
	assert_eq(holes, 0, "geografia contínua: sem buracos entre tiles no miolo do mapa")
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = Vector3(0, 12, 8)
	camera.rotation_degrees = Vector3(-5, 0, 0) # quase no horizonte: raios de cima não acertam o chão perto
	var pieces: Array = minimap.camera_indicator(camera, Vector2(1280, 720)).polygon
	assert_false(pieces.is_empty(), "indicador continua existindo mesmo olhando o horizonte")
	for piece in pieces:
		for point in piece:
			assert_true(is_finite(point.x) and is_finite(point.y), "sem NaN/inf")
			assert_true(rect.grow(0.01).has_point(point), "recortado ao retângulo do mapa")
	GameManager.human_player = human
