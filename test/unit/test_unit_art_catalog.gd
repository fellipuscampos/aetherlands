extends GutTest

## Arte de tropas por raça (UnitArtCatalog) e a escolta inicial (UnitDatabase.STARTING_ESCORT_KINDS).

const RACES := ["dwarf", "elf", "orc"]

var _players: Array[PlayerData] = []

func after_each() -> void:
	for player in _players:
		player.release_relations()
	_players.clear()

func _player(race: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.race = race
	civ.civ_name = race
	var player := PlayerData.new(civ)
	_players.append(player)
	return player

func _unit(kind: String, player: PlayerData) -> Unit:
	var unit := Unit.new()
	add_child_autofree(unit)
	unit.setup(UnitDatabase.create_unit(kind), player, Vector2i.ZERO)
	return unit

func _model(unit: Unit) -> Node3D:
	for node in unit.find_children("*", "Node3D", true, false):
		if (node as Node3D).scene_file_path != "":
			return node
	return null

func _player_of(model: Node) -> AnimationPlayer:
	var found := model.find_children("*", "AnimationPlayer", true, false)
	return found[0] if not found.is_empty() else null

func test_every_registered_model_loads_with_its_declared_clips() -> void:
	for kind in UnitArtCatalog.registered_kinds():
		assert_true(kind in UnitDatabase.PLAYER_TRAINABLE_KINDS, kind)
		for race in RACES:
			var art := UnitArtCatalog.entry(kind, race)
			if art.is_empty():
				assert_eq(UnitArtCatalog.model_path(kind, race), "", "%s/%s mantém o fallback humano" % [kind, race])
				continue
			var path := UnitArtCatalog.model_path(kind, race)
			assert_true(path.contains("/%s/" % BuildingArtCatalog.RACE_FOLDERS[race]), path)
			var scene := load(path) as PackedScene
			assert_not_null(scene, path)
			if scene == null:
				continue
			var report_path := path.get_basename() + "_report.json"
			if FileAccess.file_exists(report_path):
				var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(report_path))
				if report is Dictionary and report.has("gameplay_id"):
					assert_eq(report.gameplay_id, kind, "o asset é da tropa certa: %s" % path)
			var model := scene.instantiate()
			var player := _player_of(model)
			assert_not_null(player, path)
			if player != null:
				var clips: Array = [art.idle, art.walk, art.attack, String(art.get("cast", "")), String(art.get("work", "")), art.shield_wall, art.shield_wall_hold]
				clips.append_array((art.techniques as Dictionary).values())
				for clip in clips:
					if clip != "":
						assert_true(player.has_animation(clip), "%s sem o clipe %s" % [path, clip])
			model.free()

func test_human_and_unknown_races_keep_the_same_resource() -> void:
	var data := UnitDatabase.create_unit("v2_unit_warrior")
	assert_same(UnitArtCatalog.for_owner(data, null), data)
	assert_same(UnitArtCatalog.for_owner(data, _player("human")), data)
	assert_same(UnitArtCatalog.for_owner(data, _player("")), data)
	var builder := UnitDatabase.create_unit("v2_unit_builder")
	assert_eq(UnitArtCatalog.for_owner(builder, _player("")).model_scene_path,
		UnitArtCatalog.model_path("v2_unit_builder", "human"), "raça desconhecida usa o construtor humano")

func test_race_art_is_a_copy_and_never_touches_gameplay() -> void:
	var data := UnitDatabase.create_unit("v2_unit_warrior")
	var human_path := data.model_scene_path
	var themed := UnitArtCatalog.for_owner(data, _player("orc"))
	assert_ne(themed, data)
	assert_eq(data.model_scene_path, human_path, "o UnitData original fica humano")
	assert_eq(themed.model_scene_path, UnitArtCatalog.model_path("v2_unit_warrior", "orc"))
	assert_eq([themed.attack, themed.defense, themed.max_hp, themed.movement_points, themed.supply_cost, themed.production_cost, themed.visual_kind],
		[data.attack, data.defense, data.max_hp, data.movement_points, data.supply_cost, data.production_cost, data.visual_kind])
	assert_same(UnitArtCatalog.for_owner(themed, _player("orc")), themed, "idempotente")
	var dwarf := UnitArtCatalog.for_owner(UnitDatabase.create_unit("v2_unit_shieldbearer"), _player("dwarf"))
	assert_eq(dwarf.shield_wall_hold_animation_override, "shield_wall_hold", "postura própria do rig anão")
	assert_true(dwarf.technique_animation_overrides.is_empty())

func test_spawned_units_wear_the_owner_race_and_animate() -> void:
	for race in RACES:
		var player := _player(race)
		for kind in UnitDatabase.STARTING_ESCORT_KINDS:
			var unit := _unit(kind, player)
			var model := _model(unit)
			assert_not_null(model, "%s/%s" % [race, kind])
			if model == null:
				continue
			assert_eq(model.scene_file_path, UnitArtCatalog.model_path(kind, race))
			assert_eq(model.scale, Vector3.ONE, "altura da raça já está no modelo")
			assert_not_null(unit._anim_player)
			assert_eq(String(unit._anim_player.current_animation), UnitArtCatalog.entry(kind, race).idle)

func test_upgrade_keeps_the_race_model() -> void:
	var unit := _unit("v2_unit_shieldbearer", _player("dwarf"))
	unit.apply_form(UnitDatabase.create_unit("v2_unit_guardian"))
	await get_tree().process_frame
	assert_eq(_model(unit).scene_file_path, UnitArtCatalog.model_path("v2_unit_guardian", "dwarf"))

func test_legacy_guard_from_old_saves_loads_a_real_model() -> void:
	var human := _model(_unit("warrior", _player("human")))
	assert_not_null(human, "o Guarda antigo não depende mais do guard_blocky apagado")
	assert_true(ResourceLoader.exists(UnitDatabase.create_unit("warrior").model_scene_path))
	var orc := _model(_unit("warrior", _player("orc")))
	assert_eq(orc.scene_file_path, UnitArtCatalog.model_path("v2_unit_warrior", "orc"))
	assert_eq(UnitDatabase.create_unit("warrior").unit_name, "Guarda", "stats/nome do save antigo intactos")

func test_missing_model_falls_back_to_a_procedural_body() -> void:
	var data := UnitDatabase.create_unit("v2_unit_warrior")
	data.model_scene_path = "res://assets/generated/humans/inexistente/inexistente.glb"
	data.animation_scene_path = data.model_scene_path
	var unit := Unit.new()
	add_child_autofree(unit)
	unit.setup(data, null, Vector2i.ZERO)
	assert_null(_model(unit))
	assert_gt(unit.find_children("*", "MeshInstance3D", true, false).size(), 0, "corpo procedural no lugar do modelo ausente")

## Tropas das seis linhas de Doutrina + Colonizador (2026-10-09: "tudo com exceção dos magos" — Construtor e magos ainda
## não têm modelo). Toda raça tem o PRÓPRIO modelo (assets/generated/<pasta da raça>), 1:1, frente +Z, com crossfade.
func _art_kinds() -> Array[String]:
	var kinds: Array[String] = []
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		var data := UnitDatabase.create_unit(kind)
		# Manifestações não usam os modelos treináveis comuns.
		if kind.begins_with("v2_manifestation_"):
			continue
		kinds.append(kind)
	return kinds

func _resolved(kind: String, race: String) -> UnitData:
	return UnitArtCatalog.for_owner(UnitDatabase.create_unit(kind), _player(race))

func test_every_troop_and_settler_has_its_own_model_in_every_race() -> void:
	var kinds := _art_kinds()
	assert_eq(kinds.size(), 32, "Colonizador + Construtor + 6 linhas x 4 formas + 6 magos")
	for race in ["human"] + RACES:
		var folder: String = BuildingArtCatalog.RACE_FOLDERS[BuildingArtCatalog.normalize_race(race)]
		for kind in kinds:
			var data := _resolved(kind, race)
			var label := "%s/%s" % [race, kind]
			assert_true(data.model_scene_path.begins_with("res://assets/generated/%s/" % folder), "%s: %s" % [label, data.model_scene_path])
			assert_eq(data.animation_scene_path, data.model_scene_path, "%s: clipes do próprio GLB" % label)
			assert_true(ResourceLoader.exists(data.model_scene_path), label)
			assert_gt(data.animation_blend_time, 0.0, "%s: crossfade entre os clipes" % label)
			assert_eq(data.model_scale_multiplier, 1.0, label)
			assert_eq(data.model_yaw_offset_degrees, 0.0, label)
			var caster := UnitDatabase.create_unit(kind).is_caster()
			assert_eq(data.attack_animation_override == "", kind in ["settler", "v2_unit_builder"] or caster, "%s: unidades civis e magos não atacam" % label)
			assert_eq(data.cast_animation_override, UnitDatabase.MAGE_CAST_CLIP if caster else "", "%s: conjuração só nos magos" % label)
			var scene := load(data.model_scene_path) as PackedScene
			if scene == null:
				continue
			var model := scene.instantiate()
			var anim := _player_of(model)
			assert_not_null(anim, label)
			if anim != null:
				var clips: Array = [data.idle_animation_override, data.walk_animation_override, data.attack_animation_override,
					data.work_animation_override, data.shield_wall_animation_override, data.shield_wall_hold_animation_override]
				clips.append_array(data.technique_animation_overrides.values())
				for clip in clips:
					if clip != "":
						assert_true(anim.has_animation(clip), "%s sem o clipe %s" % [label, clip])
			model.free()

## Relato do usuário 2026-10-12: "a textura dos orcs in game tá bugada". Presas, olhos, espinhos e argolas de arma
## tinham TODAS as UVs no canto exato do atlas (face sem UV no Blender): lá o canto cai sempre no mesmo pixel e o
## preview fica certo; no jogo a amostragem `nearest` com repetição oscila entre os quatro pixels do canto e a peça
## vira um chuvisco bege/preto. Nenhuma tropa em jogo pode ter face texturizada presa num canto do atlas — depois de
## reexportar uma tropa, rodar `python tools/art_pipeline/fix_unmapped_uv_faces.py --apply` e reimportar.
func test_no_troop_model_has_faces_stuck_on_an_atlas_corner() -> void:
	var checked := {}
	for race in ["human"] + RACES:
		for kind in _art_kinds():
			var path := _resolved(kind, race).model_scene_path
			if checked.has(path) or not ResourceLoader.exists(path):
				continue
			checked[path] = true
			var scene := load(path) as PackedScene
			if scene == null:
				continue
			var model := scene.instantiate()
			assert_eq(_faces_on_atlas_corner(model), 0, "%s: faces com a UV inteira num canto do atlas" % path.get_file())
			model.free()
	assert_gt(checked.size(), 100, "os modelos das quatro raças foram conferidos")

## Triângulos texturizados cujos três vértices têm a UV exatamente num canto (0|1, 0|1) da textura.
func _faces_on_atlas_corner(node: Node) -> int:
	var count := 0
	var mesh_node := node as MeshInstance3D
	if mesh_node != null and mesh_node.mesh != null:
		for surface in mesh_node.mesh.get_surface_count():
			var material := mesh_node.get_active_material(surface) as BaseMaterial3D
			if material == null or material.albedo_texture == null:
				continue # cor lisa: a UV não é lida
			var arrays := mesh_node.mesh.surface_get_arrays(surface)
			var uvs = arrays[Mesh.ARRAY_TEX_UV]
			if uvs == null or uvs.is_empty():
				continue
			var indices = arrays[Mesh.ARRAY_INDEX]
			var triangle_count: int = (indices.size() if indices != null and not indices.is_empty() else uvs.size()) / 3
			for triangle in triangle_count:
				var on_corner := true
				for corner in 3:
					var vertex: int = indices[triangle * 3 + corner] if indices != null and not indices.is_empty() else triangle * 3 + corner
					var uv: Vector2 = uvs[vertex]
					if not ((uv.x == 0.0 or uv.x == 1.0) and (uv.y == 0.0 or uv.y == 1.0)):
						on_corner = false
						break
				if on_corner:
					count += 1
	for child in node.get_children():
		count += _faces_on_atlas_corner(child)
	return count

## O que o jogador vê: a unidade nasce no Idle, com crossfade no AnimationPlayer, e os ciclos (Idle, Walk, postura da
## Muralha) em loop mesmo quando o GLB importou sem a flag (elfos/orcs).
func test_spawned_troops_loop_their_cycles_and_crossfade() -> void:
	for race in ["human"] + RACES:
		var owner := _player(race)
		for kind in _art_kinds():
			var unit := _unit(kind, owner)
			var label := "%s/%s" % [race, kind]
			assert_not_null(unit._anim_player, label)
			if unit._anim_player == null:
				continue
			assert_gt(unit._anim_player.playback_default_blend_time, 0.0, label)
			assert_eq(String(unit._anim_player.current_animation), unit.unit_data.idle_animation_override, label)
			for clip in [unit.idle_animation, unit.moving_animation, unit.unit_data.shield_wall_hold_animation_override]:
				if clip != "":
					assert_eq(unit._anim_player.get_animation(clip).loop_mode, Animation.LOOP_LINEAR, "%s: %s em loop" % [label, clip])
			if unit.attack_animation != "":
				assert_eq(unit._anim_player.get_animation(unit.attack_animation).loop_mode, Animation.LOOP_NONE, "%s: ataque toca uma vez" % label)
			if unit.cast_animation != "":
				assert_eq(unit._anim_player.get_animation(unit.cast_animation).loop_mode, Animation.LOOP_NONE, "%s: conjuração toca uma vez" % label)
