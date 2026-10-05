extends GutTest

## V3 / Etapa 4 — Ecology Habitats, Minimap Closure & Graphics Foundation: raide do Goblin (até 2 Ouro por golpe,
## aproxima-golpeia-recua sem ficar parado na cidade, feedback), Esqueleto sem roubo, chips de estado do card da unidade
## (nome, duração, tooltip canônico, expiração, sinal), minimapa de enquadramento FIXO com raster hexagonal e indicador
## de câmera, opções gráficas reais (AA/sombras, persistência, reset, fallback) e habitat data-driven das 12 espécies.

const TEST_SETTINGS_PATH := "user://test_settings_e4.cfg"

var _original := {}
var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _events: Array = []
var _connections: Array = []

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "ai_controls_human_seat"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	_original.events = WorldEventManager.to_save_dict()
	_original.aa = Settings.anti_aliasing
	_original.shadows = Settings.shadow_quality
	GameManager.stagger_ai_turns = false
	_events.clear()
	var callable := func(action: String, info: Dictionary): _events.append([action, info.duplicate()])
	EventBus.combat_ecology_event.connect(callable)
	_connections.append([EventBus.combat_ecology_event, callable])
	_world()

func after_each():
	for entry in _connections:
		if (entry[0] as Signal).is_connected(entry[1]):
			(entry[0] as Signal).disconnect(entry[1])
	_connections.clear()
	for player in GameManager.players:
		player.release_relations()
	if grid != null and is_instance_valid(grid):
		grid.queue_free()
	grid = null
	for key in _original:
		if key not in ["turn", "events", "aa", "shadows"]:
			GameManager.set(key, _original[key])
	TurnManager.turn_number = _original.turn
	WorldEventManager.reset_for_new_match()
	WorldEventManager.from_save_dict(_original.events)
	MonsterHazardSystem.reset()
	MonsterAbilityFeedback.enabled_in_headless = false
	MonsterEcologySystem.habitat_enabled = true
	if Settings.anti_aliasing != _original.aa or Settings.shadow_quality != _original.shadows:
		Settings.anti_aliasing = _original.aa
		Settings.shadow_quality = _original.shadows
		Settings.save_settings() # devolve o arquivo real do jogador ao que era
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))

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

func _ability_events(id: String) -> Array:
	return _events.filter(func(e): return e[0] == "ability" and String(e[1].get("ability", "")) == id)

# --- Goblin: Saque Rápido ------------------------------------------------------------------------

func test_goblin_steals_exactly_up_to_two_gold_per_valid_hit_never_negative():
	var city := grid.found_city(Vector2i.ZERO, human, "Capital", true)
	var goblin := _monster("goblin", Vector2i(1, 0))
	human.gold = 10.0
	assert_eq(MonsterAbilitySystem.on_city_hit(goblin, city), 2.0)
	assert_eq(human.gold, 8.0, "10 → 8")
	MonsterAbilitySystem.on_city_hit(goblin, city)
	assert_eq(human.gold, 6.0, "8 → 6")
	human.gold = 1.0
	assert_eq(MonsterAbilitySystem.on_city_hit(goblin, city), 1.0)
	assert_eq(human.gold, 0.0, "1 → 0")
	assert_eq(MonsterAbilitySystem.on_city_hit(goblin, city), 0.0)
	assert_eq(human.gold, 0.0, "nunca negativo")
	var hits := _ability_events(MonsterAbilityData.QUICK_PLUNDER)
	assert_eq(hits.size(), 4, "todo golpe válido dispara o Saque (sem sorteio)")
	assert_eq(int(hits[3][1].no_gold), 1, "golpe com tesouro vazio marcado para a telemetria")
	assert_eq(int(hits[0][1].no_gold), 0)

func test_skeleton_city_hit_steals_nothing():
	var city := grid.found_city(Vector2i.ZERO, human, "Capital", true)
	var skeleton := _monster("skeleton", Vector2i(1, 0))
	human.gold = 10.0
	assert_eq(MonsterAbilitySystem.on_city_hit(skeleton, city), 0.0)
	assert_eq(human.gold, 10.0, "Esqueleto não tem inteligência econômica")
	assert_true(_ability_events(MonsterAbilityData.QUICK_PLUNDER).is_empty())

func test_goblin_raid_loop_approach_strike_steal_retreat_never_idles_in_the_city():
	var city := grid.found_city(Vector2i.ZERO, human, "Capital", true)
	human.gold = 10.0
	var goblin := _monster("goblin", Vector2i(4, 0))
	var struck := -1
	for turn in range(12, 20):
		_act(goblin, turn)
		assert_gt(HexMetrics.axial_distance(goblin.coord, city.coord), 1, "T%d: o Goblin nunca termina a ação colado na cidade" % turn)
		if not _ability_events(MonsterAbilityData.QUICK_PLUNDER).is_empty():
			struck = turn
			break
	assert_gt(struck, 0, "aproxima e golpeia")
	assert_eq(human.gold, 8.0, "golpe rouba 2")
	assert_lt(city.hp, city.max_hp(), "o golpe causa dano normal")
	var moves := _events.filter(func(e): return e[0] == "move" and String(e[1].get("reason", "")) == "raid_retreat")
	assert_eq(moves.size(), 1, "recua no mesmo turno do golpe")
	assert_eq(goblin.ecology_rest_until, struck + 8, "descanso do raide")
	assert_eq(goblin.ability_state.get("raid_target"), null, "raide encerrado")
	for turn in range(struck + 1, struck + 4):
		_act(goblin, turn)
		assert_gt(HexMetrics.axial_distance(goblin.coord, city.coord), 1, "no descanso volta para casa, não ronda a cidade")

func test_goblin_gives_up_when_no_attack_position_is_reachable():
	var city := grid.found_city(Vector2i.ZERO, human, "Capital", true)
	for coord in grid.get_neighbors(Vector2i.ZERO):
		grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	var goblin := _monster("goblin", Vector2i(3, 0))
	var abandoned := -1
	for turn in range(12, 20):
		_act(goblin, turn)
		if not _events.filter(func(e): return e[0] == "raid_abandoned").is_empty():
			abandoned = turn
			break
	assert_gt(abandoned, 0, "sem posição de ataque: desiste em vez de rondar parado")
	assert_eq(goblin.ecology_rest_until, abandoned + 8, "volta para casa no descanso")
	assert_true(_ability_events(MonsterAbilityData.QUICK_PLUNDER).is_empty())
	assert_eq(city.owner_player, human)

func test_aggro_never_chases_a_garrison_and_idle_goblin_never_parks_next_to_a_city():
	var city := grid.found_city(Vector2i.ZERO, human, "Capital", true)
	var garrison := _soldier(Vector2i.ZERO)
	var goblin := _monster("goblin", Vector2i(2, 0), Vector2i(3, 0))
	var behavior := MonsterEcologyData.behavior("goblin")
	assert_true(MonsterAI._ecology_unpursuable(goblin, garrison, grid, behavior), "guarnição só se enfrenta no raide")
	var outside := _soldier(Vector2i(0, 4))
	assert_false(MonsterAI._ecology_unpursuable(goblin, outside, grid, behavior), "unidade no campo continua presa válida")
	grid.remove_unit(outside)
	grid.remove_unit(garrison) # com guarnição ao alcance ele a ATACA (combate visível, caminho inalterado)
	WorldEventManager.world_phase = WorldPhaseRules.Phase.ASCENSION # sem raide de cidade para BASIC
	grid.teleport_unit(goblin, Vector2i(1, 0))
	for turn in range(40, 44):
		_act(goblin, turn)
		assert_gt(HexMetrics.axial_distance(goblin.coord, city.coord), 1, "T%d: ocioso não fica colado na cidade" % turn)

func test_unreachable_pursuit_is_dropped_after_two_turns_without_progress():
	var island := Vector2i(7, 0)
	for coord in grid.get_neighbors(island):
		grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var goblin := _monster("goblin", Vector2i(3, 0))
	var prey := grid.spawn_unit(island, UnitDatabase.create_unit("settler"), human)
	goblin.ability_state["aggro_target"] = prey.serial_id
	goblin.ability_state["aggro_coord"] = [prey.coord.x, prey.coord.y]
	var behavior := MonsterEcologyData.behavior("goblin")
	for i in 6:
		goblin.reset_movement()
		MonsterAI._ecology_hunt(goblin, grid, prey, Vector2i(3, 0), 8, behavior, 20 + i)
		if not goblin.ability_state.has("aggro_target"):
			break
	assert_false(goblin.ability_state.has("aggro_target"), "sem progresso: perde o interesse")
	assert_true(bool(goblin.ability_state.get("returning", false)), "e volta para casa")

func test_plunder_feedback_shows_real_amount_only_for_the_humans_city():
	assert_eq(MonsterAbilityFeedback.plunder_text({"gold_stolen": 2.0, "target": 0}), "−2 Ouro")
	assert_eq(MonsterAbilityFeedback.plunder_text({"gold_stolen": 1.0, "target": 0}), "−1 Ouro", "valor real se restava menos")
	assert_eq(MonsterAbilityFeedback.plunder_text({"gold_stolen": 0.0, "target": 0}), "Saque: tesouro vazio")
	assert_eq(MonsterAbilityFeedback.plunder_text({"gold_stolen": 2.0, "target": 1}), "Saque!", "tesouro do rival não é revelado")
	MonsterAbilityFeedback.enabled_in_headless = true
	for coord in grid.tiles:
		grid.visibility[coord] = HexGrid.Visibility.VISIBLE
	var feedback := grid.ability_feedback
	if feedback == null:
		feedback = MonsterAbilityFeedback.new(grid)
		grid.add_child(feedback)
	EventBus.combat_ecology_event.emit("ability", {"ability": MonsterAbilityData.QUICK_PLUNDER, "gold_stolen": 2.0, "target": 0, "target_coord": [0, 0], "source": [1, 0]})
	var labels := feedback.get_children().filter(func(n): return n is Label3D and String(n.text) == "−2 Ouro")
	assert_eq(labels.size(), 1, "rótulo flutuante na cidade")

func test_goblin_raid_telemetry_counts_hits_gold_and_empty_treasury():
	var telemetry := EcologyTelemetry.new()
	telemetry.start(grid)
	var city := grid.found_city(Vector2i.ZERO, human, "Capital", true)
	var goblin := _monster("goblin", Vector2i(1, 0))
	human.gold = 3.0
	for i in 3:
		MonsterAbilitySystem.on_city_hit(goblin, city)
	var record := telemetry.finish(grid)
	assert_eq(int(record.goblin_raids.city_hits), 3)
	assert_eq(int(record.goblin_raids.gold_stolen), 3, "2 + 1 + 0")
	assert_eq(int(record.goblin_raids.hits_with_no_gold), 1)

# --- Chips de estado ------------------------------------------------------------------------------

func test_every_ecology_status_shows_a_chip_with_duration_canonical_tooltip_and_expires():
	var unit := _soldier(Vector2i(2, 2))
	for id in UnitStatusEffects.DEFS:
		unit.magic_status.clear()
		assert_true(UnitStatusEffects.apply(unit, id, 2), id)
		var view := UnitPresenter.build(unit, human, grid)
		var chips: Array = view.statuses.filter(func(c): return String(c.get("status_id", "")) == id)
		assert_eq(chips.size(), 1, "%s: um chip" % id)
		var chip: Dictionary = chips[0]
		assert_eq(chip.title, String(UnitStatusEffects.DEFS[id].name))
		assert_eq(int(chip.turns), 2, "%s: duração real em turnos da vítima" % id)
		assert_eq(chip.tone, AEStatusChip.Tone.NEGATIVE)
		assert_true(String(chip.tooltip).contains(UnitStatusEffects.effect_text(unit, id)), "%s: efeito mecânico real no tooltip" % id)
		assert_true(String(chip.tooltip).contains("Restam 2 turnos"), id)
	TurnManager.turn_number += 10
	var expired := UnitPresenter.build(unit, human, grid)
	assert_true(expired.statuses.filter(func(c): return c.has("status_id")).is_empty(), "expirado some do card")

func test_status_tooltips_use_canonical_numbers():
	var unit := _soldier(Vector2i(2, 2))
	var poison := UnitStatusEffects.effect_text(unit, UnitStatusEffects.POISON)
	assert_true(poison.contains("Perde %s de Vida" % UnitStatusEffects._amount(UnitStatusEffects.dot_amount(unit, UnitStatusEffects.POISON))), poison)
	assert_true(poison.contains("4%"), poison)
	var petrified := UnitStatusEffects.effect_text(unit, UnitStatusEffects.PETRIFIED)
	assert_true(petrified.contains("Movimento 0") and petrified.contains("Defesa −20%"), petrified)
	assert_true(UnitStatusEffects.effect_text(unit, UnitStatusEffects.STAGGERED).contains("-1 Movimento"))
	assert_true(UnitStatusEffects.effect_text(unit, UnitStatusEffects.SILENCED).contains("Não pode conjurar"))

func test_barrier_is_a_buff_chip_and_mycotic_area_a_debuff_without_invented_counters():
	var devourer := _monster("mana_devourer", Vector2i(-3, 0))
	devourer.arcane_barrier = 4.0
	var view := UnitPresenter.build(devourer, human, grid)
	var barrier: Array = view.statuses.filter(func(c): return String(c.get("status_id", "")) == "arcane_barrier")
	assert_eq(barrier.size(), 1)
	assert_eq(barrier[0].tone, AEStatusChip.Tone.POSITIVE, "buff distinto de debuff")
	assert_eq(int(barrier[0].turns), -1, "sem duração: sem contador")
	assert_true(String(barrier[0].tooltip).contains("4"))
	var unit := _soldier(Vector2i(3, 3))
	MonsterHazardSystem._infected[unit.coord] = true
	var infected := UnitPresenter.build(unit, human, grid)
	var area: Array = infected.statuses.filter(func(c): return String(c.get("status_id", "")) == "mycotic_area")
	assert_eq(area.size(), 1)
	assert_eq(int(area[0].turns), -1)
	assert_true(String(area[0].tooltip).contains("Cura recebida −50%"))

func test_status_changes_emit_the_card_refresh_signal():
	var unit := _soldier(Vector2i(2, 2))
	var seen: Array = []
	var callable := func(u: Unit): seen.append(u)
	EventBus.unit_status_changed.connect(callable)
	_connections.append([EventBus.unit_status_changed, callable])
	UnitStatusEffects.apply(unit, UnitStatusEffects.POISON, 1)
	assert_true(seen.has(unit), "aplicado")
	seen.clear()
	UnitStatusEffects.process_round(GameManager.players, grid, TurnManager.turn_number)
	assert_true(seen.has(unit), "tick")
	seen.clear()
	UnitStatusEffects.process_round(GameManager.players, grid, TurnManager.turn_number + 5)
	assert_true(seen.has(unit), "expirou")

func test_status_chip_label_format_and_overflow_indicator():
	var chip := AEStatusChip.new()
	add_child_autofree(chip)
	chip.set_status("Envenenado", AEStatusChip.Tone.NEGATIVE, 2)
	assert_eq(chip.label.text, "Envenenado · 2t")
	chip.set_status("Barreira Arcana", AEStatusChip.Tone.POSITIVE, -1)
	assert_eq(chip.label.text, "Barreira Arcana", "sem duração, sem contador")
	var panel: Control = load("res://scenes/ui/context/UnitContextPanel.tscn").instantiate()
	add_child_autofree(panel)
	var statuses: Array = []
	for i in 9:
		statuses.append({"title": "Estado %d" % i, "tone": AEStatusChip.Tone.NEGATIVE, "turns": 1, "tooltip": "x"})
	panel.view = {"statuses": statuses}
	panel.status_chips.clear()
	var box: Control = panel._statuses()
	add_child_autofree(box)
	assert_eq(panel.status_chips.size(), panel.MAX_STATUS_CHIPS - 1, "limite de chips visíveis")
	assert_not_null(box.find_child("MoreStatuses", true, false), "+N para o resto")

# --- Minimapa -------------------------------------------------------------------------------------

func _minimap(minimap_size: Vector2) -> Control:
	var minimap: Control = load("res://scripts/ui/Minimap.gd").new()
	minimap.size = minimap_size
	add_child_autofree(minimap)
	minimap._on_restart()
	return minimap

func _camera_at(x: float, z: float, height: float = 15.0) -> Camera3D:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = Vector3(x, height, z + height * 0.8)
	camera.rotation_degrees = Vector3(-50, 0, 0)
	return camera

func _polygon_center(pieces: Array) -> Vector2:
	var total := Vector2.ZERO
	var count := 0
	for piece in pieces:
		for point in piece:
			total += point
			count += 1
	return total / float(maxi(count, 1))

func test_minimap_frame_stays_fixed_while_the_camera_sweeps_the_whole_map():
	for coord in grid.tiles:
		grid.visibility[coord] = HexGrid.Visibility.VISIBLE
	var minimap := _minimap(Vector2(368, 186))
	var bounds: Rect2 = minimap.world_bounds()
	var rect: Rect2 = minimap.map_rect()
	var layouts: int = minimap.layout_rebuilds
	var terrains: int = minimap.terrain_rebuilds
	var image: Image = minimap._terrain_image
	var centers := {}
	for spot in [["west", -20.0, 0.0, 15.0], ["east", 20.0, 0.0, 15.0], ["north", 0.0, -14.0, 15.0], ["south", 0.0, 14.0, 15.0], ["zoom_in", 0.0, 0.0, 6.0], ["zoom_out", 0.0, 0.0, 30.0]]:
		var indicator: Dictionary = minimap.camera_indicator(_camera_at(spot[1], spot[2], spot[3]), Vector2(1600, 900))
		assert_false((indicator.polygon as Array).is_empty(), "%s: indicador presente" % spot[0])
		for piece in indicator.polygon:
			for point in piece:
				assert_true(rect.grow(0.01).has_point(point), "%s: recortado ao mapa" % spot[0])
		centers[spot[0]] = _polygon_center(indicator.polygon)
	for i in 3: # atravessa o continente várias vezes
		for x in [-20.0, 20.0]:
			minimap.camera_indicator(_camera_at(x, 0.0), Vector2(1600, 900))
	assert_lt(centers.west.x, centers.east.x, "indicador acompanha a câmera (oeste < leste)")
	assert_lt(centers.north.y, centers.south.y, "norte acima do sul")
	assert_eq(minimap.world_bounds(), bounds, "limites do mundo fixos")
	assert_eq(minimap.map_rect(), rect, "enquadramento fixo")
	assert_eq(minimap.layout_rebuilds, layouts, "câmera nunca recalcula o enquadramento")
	assert_eq(minimap.terrain_rebuilds, terrains, "câmera nunca refaz o terreno")
	assert_same(minimap._terrain_image, image)

func test_minimap_camera_completely_outside_the_world_shows_an_edge_marker():
	var minimap := _minimap(Vector2(368, 186))
	var rect: Rect2 = minimap.map_rect()
	var indicator: Dictionary = minimap.camera_indicator(_camera_at(400.0, 0.0), Vector2(1600, 900))
	assert_true((indicator.polygon as Array).is_empty(), "nada do trapézio dentro do mundo")
	assert_true(indicator.has("edge_marker"), "marcador na borda mais próxima")
	var tip: Vector2 = indicator.edge_marker[0]
	assert_almost_eq(tip.x, rect.end.x, 0.01, "na borda leste, apontando para fora")
	for point in indicator.edge_marker:
		assert_true(is_finite(point.x) and is_finite(point.y))

func test_minimap_raster_is_hexagonal_not_square():
	for coord in grid.tiles:
		grid.visibility[coord] = HexGrid.Visibility.VISIBLE
	var minimap := _minimap(Vector2(900, 900)) # hex grande o bastante para medir a forma
	var center: Vector2 = minimap._project(Vector2i.ZERO, grid.hex_size)
	assert_eq(minimap.pixel_tile(Vector2i(floori(center.x), floori(center.y))), Vector2i.ZERO, "o centro pertence ao próprio hex")
	var rows := {}
	for index in minimap._tile_pixels[Vector2i.ZERO]:
		var y: int = index / minimap._image_size.x
		rows[y] = int(rows.get(y, 0)) + 1
	var ys := rows.keys()
	ys.sort()
	var middle := int(rows[ys[ys.size() / 2]])
	assert_lt(float(rows[ys[0]]), middle * 0.5, "ponta superior estreita (pointy-top), não quadrado")
	assert_lt(float(rows[ys[ys.size() - 1]]), middle * 0.5, "ponta inferior estreita")
	var below: Vector2 = minimap._project(Vector2i(0, 1), grid.hex_size)
	var hex_width: float = sqrt(3.0) * grid.hex_size * minimap._scale
	assert_almost_eq(absf(below.x - center.x), hex_width * 0.5, 0.6, "fileira seguinte deslocada meio hex")
	assert_true(minimap._hex_edges, "hex largo: contorno sutil ligado")

func test_minimap_fog_delta_repaints_without_rebuilding_layout():
	var minimap := _minimap(Vector2(368, 186))
	var layouts: int = minimap.layout_rebuilds
	var terrains: int = minimap.terrain_rebuilds
	grid.visibility[Vector2i(2, 0)] = HexGrid.Visibility.VISIBLE
	grid.last_fog_changed = [Vector2i(2, 0)]
	grid.last_fog_was_full = false
	minimap._on_fog_updated()
	assert_eq(minimap.layout_rebuilds, layouts)
	assert_eq(minimap.terrain_rebuilds, terrains, "delta não refaz a imagem inteira")
	var px: Vector2 = minimap._project(Vector2i(2, 0), grid.hex_size)
	assert_gt(minimap._terrain_image.get_pixelv(Vector2i(floori(px.x), floori(px.y))).a, 0.0)

# --- Opções gráficas ------------------------------------------------------------------------------

func test_graphics_settings_persist_reset_and_fall_back_on_invalid_values():
	Settings.anti_aliasing = GraphicsQuality.AA_FXAA
	Settings.shadow_quality = GraphicsQuality.SHADOW_HIGH
	Settings.save_settings(TEST_SETTINGS_PATH)
	Settings.anti_aliasing = GraphicsQuality.AA_OFF
	Settings.shadow_quality = GraphicsQuality.SHADOW_OFF
	Settings.load_settings(TEST_SETTINGS_PATH)
	assert_eq(Settings.anti_aliasing, GraphicsQuality.AA_FXAA, "AA persiste")
	assert_eq(Settings.shadow_quality, GraphicsQuality.SHADOW_HIGH, "sombras persistem")
	var cfg := ConfigFile.new()
	cfg.load(TEST_SETTINGS_PATH)
	cfg.set_value("graphics", "anti_aliasing", "ssaa_64x")
	cfg.set_value("graphics", "shadow_quality", 7)
	cfg.save(TEST_SETTINGS_PATH)
	Settings.load_settings(TEST_SETTINGS_PATH)
	assert_eq(Settings.anti_aliasing, GraphicsQuality.DEFAULT_ANTI_ALIASING, "valor inválido volta ao padrão")
	assert_eq(Settings.shadow_quality, GraphicsQuality.DEFAULT_SHADOW_QUALITY)
	var fired := [0]
	var callable := func(): fired[0] += 1
	Settings.graphics_changed.connect(callable)
	_connections.append([Settings.graphics_changed, callable])
	Settings.set_anti_aliasing(GraphicsQuality.AA_MSAA_4X)
	Settings.set_shadow_quality(GraphicsQuality.SHADOW_LOW)
	Settings.reset_graphics_to_defaults()
	assert_eq(fired[0], 3, "cada mudança avisa o Main para aplicar ao vivo")
	assert_eq(Settings.anti_aliasing, GraphicsQuality.DEFAULT_ANTI_ALIASING, "reset")
	assert_eq(Settings.shadow_quality, GraphicsQuality.DEFAULT_SHADOW_QUALITY)

func test_anti_aliasing_options_change_the_real_viewport_and_never_combine():
	var viewport := SubViewport.new()
	add_child_autofree(viewport)
	GraphicsQuality.apply_anti_aliasing(viewport, GraphicsQuality.AA_OFF)
	assert_eq(viewport.msaa_3d, Viewport.MSAA_DISABLED)
	assert_eq(viewport.screen_space_aa, Viewport.SCREEN_SPACE_AA_DISABLED)
	GraphicsQuality.apply_anti_aliasing(viewport, GraphicsQuality.AA_FXAA)
	assert_eq(viewport.screen_space_aa, Viewport.SCREEN_SPACE_AA_FXAA)
	assert_eq(viewport.msaa_3d, Viewport.MSAA_DISABLED, "FXAA desliga MSAA")
	GraphicsQuality.apply_anti_aliasing(viewport, GraphicsQuality.AA_MSAA_2X)
	assert_eq(viewport.msaa_3d, Viewport.MSAA_2X)
	assert_eq(viewport.screen_space_aa, Viewport.SCREEN_SPACE_AA_DISABLED, "MSAA desliga FXAA")
	GraphicsQuality.apply_anti_aliasing(viewport, GraphicsQuality.AA_MSAA_4X)
	assert_eq(viewport.msaa_3d, Viewport.MSAA_4X)
	assert_false(viewport.use_taa)

func test_shadow_quality_levels_map_to_distinct_real_settings():
	var sun := DirectionalLight3D.new()
	add_child_autofree(sun)
	GraphicsQuality.apply_shadows(sun, GraphicsQuality.SHADOW_OFF)
	assert_false(sun.shadow_enabled, "Desativadas = sombra realmente desligada")
	var seen := {}
	for id in [GraphicsQuality.SHADOW_LOW, GraphicsQuality.SHADOW_MEDIUM, GraphicsQuality.SHADOW_HIGH]:
		GraphicsQuality.apply_shadows(sun, id)
		assert_true(sun.shadow_enabled, id)
		var profile: Dictionary = GraphicsQuality.SHADOW_PROFILES[id]
		assert_eq(sun.directional_shadow_max_distance, float(profile.max_distance), id)
		assert_eq(sun.directional_shadow_mode, int(profile.mode), id)
		seen["%d:%d:%d" % [int(profile.atlas), int(profile.filter), int(profile.max_distance)]] = id
	assert_eq(seen.size(), 3, "três níveis com parâmetros diferentes (não três rótulos iguais)")
	assert_lt(int(GraphicsQuality.SHADOW_PROFILES.low.atlas), int(GraphicsQuality.SHADOW_PROFILES.high.atlas))

# --- Habitat --------------------------------------------------------------------------------------

func _paint(center: Vector2i, radius: int, terrain: int) -> void:
	for coord in [center] + HexMetrics.coords_within(center, radius):
		if grid.tiles.has(coord):
			grid.tiles[coord] = TerrainDatabase.create_tile(terrain)

func _score(kind: String, coord: Vector2i, mana: Array[Vector2i] = []) -> float:
	return MonsterHabitatProfile.score(kind, MonsterHabitatProfile.features(grid, coord, mana), 0.0)

func test_habitat_scores_follow_the_local_terrain_signals():
	var forest := Vector2i(-10, 0)
	var arid := Vector2i(10, 0)
	var rocky := Vector2i(0, -10)
	_paint(forest, 3, HexTileData.TerrainType.FOREST)
	_paint(arid, 3, HexTileData.TerrainType.DESERT)
	_paint(rocky, 3, HexTileData.TerrainType.HILLS)
	grid.tiles[rocky + Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	for kind in ["giant_spider", "worg", "arboreal_ancient"]:
		assert_gt(_score(kind, forest), _score(kind, arid), "%s prefere floresta a deserto" % kind)
	for kind in ["giant_spider", "arboreal_ancient"]:
		for other in ["colossal_worm", "basilisk", "skeleton"]:
			assert_gt(_score(kind, forest), _score(other, forest), "floresta: %s > %s" % [kind, other])
	for kind in ["colossal_worm", "basilisk", "skeleton"]:
		assert_gt(_score(kind, arid), _score(kind, forest), "%s prefere o árido" % kind)
		for other in ["giant_spider", "arboreal_ancient", "goblin"]:
			assert_gt(_score(kind, arid), _score(other, arid), "árido: %s > %s" % [kind, other])
	for other in ["troll", "minotaur", "basilisk"]:
		assert_gt(_score("wyvern", rocky), _score(other, rocky), "alto/rochoso: Wyvern > %s" % other)
	var mana_node := Vector2i(0, 10)
	grid.tiles[mana_node].resource = MonsterHabitatProfile.MANA_RESOURCE
	var mana: Array[Vector2i] = [mana_node]
	assert_gt(_score("mana_devourer", mana_node + Vector2i(1, 0), mana), _score("mana_devourer", Vector2i(-12, 12), mana), "Devorador perto do Nódulo Arcano")
	assert_gt(_score("goblin", Vector2i(-6, 6)), _score("goblin", arid), "Goblin: planície vegetada > deserto profundo")

func _generated_world(seed_value: int) -> HexGrid:
	var world := HexGrid.new()
	add_child(world)
	world._ready()
	world.generate_map(60, 40, seed_value)
	return world

func _anchors_by_species() -> Array:
	var result: Array = []
	for site in MonsterEcologySystem.sites:
		result.append([String(site.species), site.anchor])
	return result

func test_habitat_placement_is_deterministic_and_raises_habitat_fit_over_uniform():
	var placements: Array = []
	var mean_scores: Array = []
	for mode in ["habitat", "habitat", "uniform"]:
		MonsterEcologySystem.habitat_enabled = mode == "habitat"
		var world := _generated_world(4242)
		GameManager.hex_grid = world
		GameManager.players = [] as Array[PlayerData]
		MonsterEcologySystem.populate_new_match(world, true)
		placements.append(_anchors_by_species())
		var cache := MonsterEcologyPlanner.new_habitat_cache(world)
		var total := 0.0
		for site in MonsterEcologySystem.sites:
			total += MonsterHabitatProfile.score(String(site.species), MonsterEcologyPlanner.habitat_features(world, site.anchor, cache), 1.0)
		mean_scores.append(total / float(maxi(MonsterEcologySystem.sites.size(), 1)))
		world.queue_free()
	MonsterEcologySystem.habitat_enabled = true
	MonsterEcologySystem.reset()
	GameManager.hex_grid = grid
	assert_false(placements[0].is_empty())
	assert_eq(placements[0], placements[1], "mesma seed/config → mesma distribuição ecológica")
	assert_gt(float(mean_scores[0]), float(mean_scores[2]), "habitat coloca as espécies em regiões mais coerentes que o sorteio uniforme")
