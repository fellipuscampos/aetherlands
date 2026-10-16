extends GutTest

## EMBARQUE AUTOMÁTICO (2026-10-10): toda tropa de civilização que anda pelo chão atravessa água embarcável (Oceano/Mar
## Gelado/Costa) ao custo normal do tile; entrar na água vira o barquinho da raça, pisar em terra volta a tropa. O estado
## `embarked` é derivado do tile (HexGrid.sync_embarked). Monstros e voadores não embarcam. Técnicas de deslocamento
## continuam só por terra; embarcado não ataca.

const MANIFEST_PATH := "res://assets/generated/embark_boats_manifest.json"
const RACES := ["human", "dwarf", "elf", "orc"]

var _players: Array[PlayerData] = []

func after_each():
	for player in _players:
		player.release_relations()
	_players.clear()

func _player(race: String = "human") -> PlayerData:
	var civ := CivilizationData.new()
	civ.race = race
	var player := PlayerData.new(civ)
	_players.append(player)
	return player

## Grade de grama (raio 4) com um "mar" na coluna q = 1 e terra de novo em q >= 2.
func _grid(in_tree: bool = false) -> HexGrid:
	var grid := HexGrid.new()
	if in_tree:
		add_child_autofree(grid)
	else:
		grid._ready()
		autofree(grid)
	for q in range(-4, 5):
		for r in range(-4, 5):
			if absi(q + r) <= 4:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	for r in range(-4, 5):
		if grid.tiles.has(Vector2i(1, r)):
			grid.tiles[Vector2i(1, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	return grid

func _spawn(grid: HexGrid, kind: String, owner: PlayerData, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	unit.movement_left = 10.0
	return unit

# --- Quem embarca -------------------------------------------------------------------------------------------------------

func test_civilization_ground_units_embark_and_monsters_and_flyers_do_not():
	var grid := _grid()
	var me := _player()
	var kinds := ["settler", "v2_unit_warrior", "v2_unit_archer", "v2_unit_druid", "v2_legendary_shadow_master"]
	for i in kinds.size():
		assert_true(_spawn(grid, kinds[i], me, Vector2i(-3, i - 1)).can_embark(), kinds[i])
	var goblin := grid.spawn_monster_at(Vector2i(0, -2), "goblin")
	assert_false(goblin.can_embark(), "monstro neutro não embarca")
	var flyer_data := UnitDatabase.create_unit("v2_unit_warrior")
	flyer_data.movement_profile = UnitData.MovementProfile.FLYING
	var flyer := grid.spawn_unit(Vector2i(0, 2), flyer_data, me)
	assert_false(flyer.can_embark(), "voador sobrevoa, não embarca")
	var griffon := grid.spawn_unit(Vector2i(-2, 2), UnitDatabase.create_unit("v2_legendary_griffon_rider"), me)
	assert_true(griffon.can_embark(), "o Cavaleiro de Grifo anda pelo chão desde 2026-10-10: embarca")

# --- Rota ---------------------------------------------------------------------------------------------------------------

func test_a_route_crosses_land_water_land_at_normal_cost_from_the_start():
	var grid := _grid()
	var me := _player()
	var warrior := _spawn(grid, "v2_unit_warrior", me, Vector2i(0, 0))
	var reach := grid.unit_reachable(warrior)
	assert_almost_eq(float(reach[Vector2i(1, 0)]), 1.0, 0.001, "água custa o tile normal")
	assert_almost_eq(float(reach[Vector2i(2, 0)]), 2.0, 0.001, "terra do outro lado no mesmo comando")
	assert_eq(grid.unit_path(warrior, Vector2i(3, 0)), [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)] as Array[Vector2i])
	var goblin := grid.spawn_monster_at(Vector2i(-2, 0), "goblin")
	goblin.movement_left = 10.0
	assert_false(grid.unit_reachable(goblin).has(Vector2i(1, 0)), "monstro não entra na água")
	assert_true(grid.unit_path(goblin, Vector2i(3, 0)).is_empty(), "nem atravessa")

func test_lava_and_mountains_still_block_the_crossing():
	var grid := _grid()
	var me := _player()
	for r in range(-4, 5):
		if grid.tiles.has(Vector2i(1, r)):
			grid.tiles[Vector2i(1, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS if r % 2 == 0 else HexTileData.TerrainType.LAVA)
	grid._amphibious_component_tile_count = -1
	var warrior := _spawn(grid, "v2_unit_warrior", me, Vector2i(0, 0))
	assert_true(grid.unit_path(warrior, Vector2i(3, 0)).is_empty())

## Rejeição rápida (sem A* pelo mapa inteiro): um lago fechado por montanhas não liga com o mar de fora.
func test_the_amphibious_components_reject_an_enclosed_lake_without_searching():
	var grid := _grid()
	var lake := Vector2i(-3, 1)
	grid.tiles[lake] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	for n in grid.get_neighbors(lake):
		grid.tiles[n] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	grid._amphibious_component_tile_count = -1
	grid._land_component_tile_count = -1
	assert_false(grid._route_possible(Vector2i(1, 0), lake, true), "o mar não chega ao lago")
	assert_true(grid._route_possible(Vector2i(0, 0), Vector2i(3, 0), true), "terra -> mar -> terra é um componente só")
	assert_false(grid._route_possible(Vector2i(0, 0), Vector2i(3, 0), false), "só por terra, são duas margens")

# --- Estado derivado do tile -------------------------------------------------------------------------------------------

func test_moving_into_water_embarks_and_stepping_on_land_disembarks():
	var grid := _grid()
	var me := _player()
	var warrior := _spawn(grid, "v2_unit_warrior", me, Vector2i(0, 0))
	warrior.fortified = true
	grid.move_unit(warrior, Vector2i(1, 0), 1.0)
	assert_true(warrior.embarked, "na água: embarcado")
	assert_false(warrior.fortified, "em trânsito não fica fortificado")
	assert_almost_eq(warrior.position.y, HexGrid.LIQUID_LEVEL_Y, 0.001, "flutua no plano d'água, não no fundo do prisma")
	assert_almost_eq(warrior.movement_left, 9.0, 0.001)
	grid.move_unit(warrior, Vector2i(2, 0), 1.0)
	assert_false(warrior.embarked, "em terra: desembarca")

func test_spawn_teleport_terrain_change_and_a_stale_save_flag_all_resolve_from_the_tile():
	var grid := _grid()
	var me := _player()
	var summoned := _spawn(grid, "v2_unit_warrior", me, Vector2i(1, 1))
	assert_true(summoned.embarked, "nasce na água: já de barco")
	assert_true(summoned.is_boat_visual())
	var walker := _spawn(grid, "settler", me, Vector2i(-2, 0))
	grid.teleport_unit(walker, Vector2i(1, -1))
	assert_true(walker.embarked, "teleporte para a água")
	grid.teleport_unit(walker, Vector2i(3, -1))
	assert_false(walker.embarked, "teleporte para a terra")
	grid.transform_tile_terrain(Vector2i(3, -1), HexTileData.TerrainType.OCEAN)
	assert_true(walker.embarked, "a terra virou água embaixo dela")
	var stale := _spawn(grid, "v2_unit_warrior", me, Vector2i(-3, 2))
	stale.embarked = true # save antigo / estado inconsistente
	grid.sync_embarked(stale)
	assert_false(stale.embarked, "o tile manda (o load do save chama sync_embarked)")

func test_the_save_load_path_rederives_embarked_from_the_tile():
	var source := FileAccess.get_file_as_string("res://scripts/autoload/SaveManager.gd")
	assert_true(source.contains("hex_grid.sync_embarked(unit)"), "o load re-deriva o estado e monta o barco")
	assert_false(source.contains('unit.embarked = u.get("embarked"'), "nunca confia no campo salvo")

# --- Ações bloqueadas na água ------------------------------------------------------------------------------------------

func test_an_embarked_unit_cannot_attack_but_can_be_attacked():
	var grid := _grid()
	var me := _player()
	var rival := _player()
	Diplomacy.declare_war(me, rival)
	var sailor := _spawn(grid, "v2_unit_warrior", me, Vector2i(1, 0))
	var foe := _spawn(grid, "v2_unit_warrior", rival, Vector2i(2, 0))
	assert_true(sailor.embarked)
	assert_false(CombatResolver.can_attack_unit(sailor, foe, grid), "de barco não ataca")
	var foe_hp := foe.hp
	CombatResolver.resolve(sailor, foe, grid)
	assert_eq(foe.hp, foe_hp, "resolve é fail-closed para quem está embarcado (IA incluída)")
	assert_true(CombatResolver.can_attack_unit(foe, sailor, grid), "mas pode ser atacado")

func test_movement_techniques_stay_on_land():
	var grid := _grid()
	var me := _player()
	var warrior := _spawn(grid, "v2_unit_warrior", me, Vector2i(0, 0))
	var land_only := grid.unit_reachable(warrior, -1.0, false, false)
	assert_false(land_only.has(Vector2i(1, 0)), "Carga/Retirada: só por terra")
	var source := FileAccess.get_file_as_string("res://scripts/core/V2TechniqueRuntime.gd")
	assert_eq(source.count("unit_reachable(unit, -1.0, false, false)"), 2, "Carga: alcance de aproximação só por terra")
	assert_true(source.contains("technique.relocate_flat_cost, false)"), "Retirada: só por terra")

# --- IA ---------------------------------------------------------------------------------------------------------------

func test_ai_greedy_picks_land_as_the_destination_unless_already_at_sea():
	var grid := _grid()
	var me := _player()
	var warrior := _spawn(grid, "v2_unit_warrior", me, Vector2i(0, 0))
	warrior.movement_left = 3.0
	var landing := grid.unit_landing_reachable(warrior)
	assert_true(landing.has(Vector2i(2, 0)), "a rota passa pela água")
	for coord in landing:
		assert_false(grid.get_tile(coord).can_be_embarked_on(), "mas o destino escolhido é terra")
	var sailor := _spawn(grid, "v2_unit_warrior", me, Vector2i(1, 2))
	assert_true(grid.unit_landing_reachable(sailor).has(Vector2i(1, 3)), "quem já está no mar pode seguir navegando")

func test_ai_approach_prefers_a_land_tile_next_to_the_target():
	var grid := _grid()
	var me := _player()
	var rival := _player()
	Diplomacy.declare_war(me, rival)
	var foe := _spawn(grid, "v2_unit_warrior", rival, Vector2i(2, 0))
	var attacker := _spawn(grid, "v2_unit_warrior", me, Vector2i(1, -1)) # no mar, colado ao alvo
	attacker.movement_left = 2.0
	RivalAI.move_unit_toward(attacker, grid, foe.coord)
	assert_false(grid.get_tile(attacker.coord).can_be_embarked_on(), "sai da água para uma casa em terra ao lado do alvo")
	assert_eq(HexMetrics.axial_distance(attacker.coord, foe.coord), 1)

# --- Visual: o barquinho -----------------------------------------------------------------------------------------------

func test_each_race_gets_its_own_boat_and_the_troop_body_hides():
	for race in RACES:
		var grid := _grid()
		var unit := _spawn(grid, "v2_unit_warrior", _player(race), Vector2i(0, 0))
		assert_false(unit.is_boat_visual(), "%s: em terra, a tropa" % race)
		grid.move_unit(unit, Vector2i(1, 0), 1.0)
		assert_true(unit.embarked and unit.is_boat_visual(), "%s: na água, o barco" % race)
		var boat := unit._visual_root.get_node(Unit.BOAT_NODE_NAME) as Node3D
		assert_true(boat.visible)
		var model := boat.get_child(0) as Node3D
		assert_eq(model.scene_file_path, UnitArtCatalog.boat_scene_path(race), "%s: o barco da raça" % race)
		assert_almost_eq(rad_to_deg(model.rotation.y), UnitArtCatalog.BOAT_YAW_DEGREES, 0.01, "frente −Z virada para a frente +Z das unidades")
		assert_almost_eq((model.get_node("Visual") as Node3D).scale.x, UnitArtCatalog.BOAT_SCALE, 0.0001, "escala de mapa do pacote")
		for part in unit._troop_parts():
			assert_false(part.visible, "%s: corpo da tropa escondido (%s)" % [race, part.name])
		grid.teleport_unit(unit, Vector2i(-2, 0))
		assert_false(unit.is_boat_visual(), "%s: de volta à terra, a tropa" % race)
		assert_false(boat.visible, "%s: barco escondido" % race)
		for part in unit._troop_parts():
			assert_true(part.visible, "%s: corpo de volta (%s)" % [race, part.name])
			assert_eq(part.scale, unit._troop_part_scales[part], "escala original restaurada")

func test_the_boat_clips_loop_and_crossfade():
	var grid := _grid()
	var unit := _spawn(grid, "settler", _player("orc"), Vector2i(1, 0))
	var player := unit._boat_player
	assert_not_null(player)
	for clip in [UnitArtCatalog.BOAT_IDLE_CLIP, UnitArtCatalog.BOAT_WALK_CLIP]:
		assert_true(player.has_animation(clip), clip)
		assert_eq(player.get_animation(clip).loop_mode, Animation.LOOP_LINEAR, "%s em loop" % clip)
	assert_almost_eq(player.playback_default_blend_time, UnitArtCatalog.BOAT_BLEND_TIME, 0.0001, "crossfade idle <-> walk")
	assert_eq(player.current_animation, UnitArtCatalog.BOAT_IDLE_CLIP, "parado: idle")

## Uma unidade evolui/troca de forma estando na água: continua de barco.
func test_changing_form_at_sea_keeps_the_boat():
	var grid := _grid(true) # na árvore: apply_form libera o corpo antigo com queue_free
	var unit := _spawn(grid, "v2_unit_warrior", _player("elf"), Vector2i(1, 0))
	unit.apply_form(UnitDatabase.create_unit("v2_unit_swordsman"))
	assert_true(unit.is_boat_visual())
	assert_not_null(unit._visual_root.get_node_or_null(Unit.BOAT_NODE_NAME))
	for part in unit._troop_parts():
		assert_false(part.visible, "o corpo novo também fica escondido")
	await wait_physics_frames(2)

## O passo que cruza a margem troca tropa -> barco NO MEIO do trecho; o barco rema (walk) enquanto anda e volta ao idle.
func test_walking_into_the_water_swaps_mid_step_and_the_boat_walks_then_idles():
	var grid := _grid(true)
	var unit := _spawn(grid, "v2_unit_warrior", _player("dwarf"), Vector2i(0, 0))
	grid.move_unit(unit, Vector2i(1, 0), 1.0)
	assert_true(unit.embarked, "o estado lógico muda na hora")
	assert_false(unit.is_boat_visual(), "o visual só troca quando cruza a margem")
	# Navega mais dois tiles de mar (fila de walk_path, como continue_move_order): ainda andando quando conferido.
	grid.move_unit(unit, Vector2i(1, 1), 1.0)
	grid.move_unit(unit, Vector2i(1, 2), 1.0)
	await wait_seconds(Unit.MOVE_DURATION * 0.5 + 0.1)
	assert_true(unit.is_boat_visual(), "no meio do primeiro passo, vira barco")
	assert_true(unit._walking)
	assert_eq(unit._boat_player.current_animation, UnitArtCatalog.BOAT_WALK_CLIP, "andando: walk")
	await wait_seconds(Unit.MOVE_DURATION * 3.0 + Unit.BOAT_SWAP_DURATION + 0.3)
	assert_eq(unit._boat_player.current_animation, UnitArtCatalog.BOAT_IDLE_CLIP, "parado: idle (crossfade)")
	for part in unit._troop_parts():
		assert_false(part.visible, "fim da troca: tropa fora da renderização")
	assert_false(unit._anim_player.active, "e o AnimationPlayer dela parado")
	grid.move_unit(unit, Vector2i(2, 1), 1.0)
	await wait_seconds(Unit.MOVE_DURATION + Unit.BOAT_SWAP_DURATION + 0.2)
	assert_false(unit.is_boat_visual(), "desembarca")
	assert_true(unit._anim_player.active, "a tropa volta a animar")
	assert_eq(String(unit._anim_player.current_animation), unit.idle_animation, "no repouso")

# --- Arte: o pacote bate com o catálogo --------------------------------------------------------------------------------

func test_the_four_boat_packages_match_the_manifest():
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	var seen := []
	for asset in manifest.assets:
		var race := String(asset.race)
		seen.append(race)
		assert_true(ResourceLoader.exists("res://" + String(asset.glb)), "%s: glb" % race)
		var scene_path := UnitArtCatalog.boat_scene_path(race)
		assert_true(ResourceLoader.exists(scene_path), "%s: cena" % race)
		assert_eq(String(asset.forward_godot), "-Z", "%s: frente −Z (yaw 180 no jogo)" % race)
		assert_almost_eq(float(asset.recommended_map_scale), UnitArtCatalog.BOAT_SCALE, 0.0001, race)
		var instance: Node3D = (load(scene_path) as PackedScene).instantiate()
		assert_almost_eq((instance.get_node("Visual") as Node3D).scale.x, UnitArtCatalog.BOAT_SCALE, 0.0001, "%s: a cena aplica a escala" % race)
		var player := _find_player(instance)
		assert_not_null(player, race)
		if player != null:
			for clip in [UnitArtCatalog.BOAT_IDLE_CLIP, UnitArtCatalog.BOAT_WALK_CLIP]:
				assert_true(player.has_animation(clip), "%s: %s" % [race, clip])
				assert_true((asset.animations as Dictionary).has(clip), "%s: %s no manifesto" % [race, clip])
		instance.free()
	seen.sort()
	var expected := RACES.duplicate()
	expected.sort()
	assert_eq(seen, expected, "um barco por raça")

func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null
