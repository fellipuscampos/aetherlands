extends GutTest

## NÚCLEOS QUE ILUMINAM (2026-10-13) — pedido do usuário: "pegue o mesmo efeito de iluminação usado nos cristais in
## game, e coloque nos núcleos das grandes manifestações, e conclua colocando uma opção de vídeo nas configurações de
## desligar iluminação do mapa e outra pra desligar iluminação das criaturas".
## O efeito é o do WorldGlow (test_world_glow.gd): luz sem sombra que ilumina o mapa + emissão do modelo, os dois
## crescendo com a escuridão da cena. Aqui: a luz presa ao osso do núcleo (attach_light), a emissão do modelo
## (track_emission) e as camadas que as duas opções de vídeo desligam.

const SERAPH := "v2_manifestation_seraph"
const GEMS := Vector2i(3, 0)

var grid: HexGrid
var glow: WorldGlow
var human: PlayerData
var _players: Array[PlayerData] = []
var _map_lighting: bool
var _creature_lighting: bool

func before_each():
	_map_lighting = Settings.map_lighting_enabled
	_creature_lighting = Settings.creature_lighting_enabled
	grid = HexGrid.new()
	add_child_autofree(grid)
	for q in range(-4, 5):
		for r in range(-4, 5):
			grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	glow = grid.world_glow
	human = _player()

func after_each():
	# Os setters gravam em settings.cfg: devolve a preferência real do jogador ao arquivo.
	if Settings.map_lighting_enabled != _map_lighting:
		Settings.set_map_lighting_enabled(_map_lighting)
	if Settings.creature_lighting_enabled != _creature_lighting:
		Settings.set_creature_lighting_enabled(_creature_lighting)
	glow.set_darkness(0.0) # os materiais dos modelos são compartilhados: voltam ao dia
	for player in _players:
		player.release_relations()
	_players.clear()

func _player() -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = "Aurora"
	civ.color = Color(0.2, 0.45, 0.85)
	var player := PlayerData.new(civ)
	_players.append(player)
	return player

func _spawn(kind: String, coord: Vector2i = Vector2i.ZERO) -> Unit:
	return grid.spawn_unit(coord, UnitDatabase.create_unit(kind), human)

func _body_material(unit: Unit) -> BaseMaterial3D:
	for mesh in unit.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			return (mesh as MeshInstance3D).get_active_material(0) as BaseMaterial3D
	return null

func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.0005 and absf(a.g - b.g) < 0.0005 and absf(a.b - b.b) < 0.0005

# --- Perfis ---------------------------------------------------------------------------------------------------------------

func test_every_manifestation_has_a_core_profile_on_a_real_bone():
	assert_eq(UnitDatabase.MANIFESTATION_CORES.size(), 6)
	var profiles := {}
	for kind in UnitDatabase.MANIFESTATION_MODELS:
		assert_true(UnitDatabase.MANIFESTATION_CORES.has(kind), kind)
		var data := UnitDatabase.create_unit(kind)
		assert_true(GlowProfiles.has_profile(data.glow_profile), "%s: perfil %s" % [kind, data.glow_profile])
		profiles[data.glow_profile] = true
		var model: Node = (load(data.model_scene_path) as PackedScene).instantiate()
		var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		assert_gte(skeleton.find_bone(data.glow_bone), 0, "%s: o osso %s existe no modelo" % [kind, data.glow_bone])
		model.free()
		var profile := GlowProfiles.profile(data.glow_profile)
		assert_gt(float(profile.light_range), 4.0, "%s: o núcleo fica alto — a luz precisa chegar ao chão" % kind)
		assert_eq(float(profile.emission_day), 1.0, "%s: de dia o modelo fica como foi aprovado" % kind)
		assert_gt(float(profile.emission_energy), 1.5, "%s: à noite o núcleo acende" % kind)
	assert_eq(profiles.size(), 6, "cada núcleo com a sua cor")
	assert_eq(UnitDatabase.create_unit("v2_unit_archer").glow_profile, &"", "tropa comum não ilumina")

func test_emission_factor_goes_from_the_day_look_to_the_night_boost():
	for id in [GlowProfiles.SERAPH_CORE, GlowProfiles.PRIMORDIAL_CORE]:
		var profile := GlowProfiles.profile(id)
		assert_almost_eq(GlowProfiles.emission_factor(id, 0.0), 1.0, 0.0001)
		assert_almost_eq(GlowProfiles.emission_factor(id, 1.0), float(profile.emission_energy), 0.0001)
		assert_gt(GlowProfiles.emission_factor(id, 0.7), GlowProfiles.emission_factor(id, 0.3))
	# Perfil de prop (sem emission_day): a mesma conta do shader dos cristais.
	var arcane := GlowProfiles.profile(GlowProfiles.ARCANE)
	assert_almost_eq(GlowProfiles.emission_factor(GlowProfiles.ARCANE, 0.0), float(arcane.emission_energy) * float(arcane.day_strength), 0.0001)
	assert_almost_eq(GlowProfiles.emission_factor(GlowProfiles.ARCANE, 1.0), float(arcane.emission_energy), 0.0001)

# --- A luz presa ao núcleo -----------------------------------------------------------------------------------------------

func test_every_manifestation_carries_a_light_on_its_core():
	var coords := [Vector2i(0, 0), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, -2)]
	var index := 0
	for kind in UnitDatabase.MANIFESTATION_MODELS:
		var unit := _spawn(kind, coords[index])
		index += 1
		var light := unit.core_glow_light()
		var profile := GlowProfiles.profile(unit.unit_data.glow_profile)
		assert_not_null(light, kind)
		if light == null:
			continue
		assert_true(unit.is_ancestor_of(light), "%s: a luz é do próprio modelo (anda, some e morre com ele)" % kind)
		var anchor := light.get_parent() as BoneAttachment3D
		assert_not_null(anchor, "%s: presa a um osso" % kind)
		assert_eq(anchor.bone_name, unit.unit_data.glow_bone, kind)
		assert_true(anchor.get_parent() is Skeleton3D, kind)
		assert_false(light.shadow_enabled, "%s: sem sombra (barata)" % kind)
		assert_eq(light.light_color, profile.light_color, kind)
		assert_almost_eq(light.omni_range, float(profile.light_range), 0.0001, kind)
		assert_eq(light.position, Vector3.ZERO, "%s: no centro do núcleo" % kind)
		assert_true(light.visible, "%s: nasce acesa" % kind)
		assert_almost_eq(light.light_energy, float(profile.light_energy) * float(profile.day_strength), 0.0001, "%s: de dia, discreta" % kind)
	assert_eq(glow.light_count(WorldGlow.GROUP_UNITS), 6)

func test_the_core_light_grows_with_the_darkness_like_the_crystals():
	var unit := _spawn(SERAPH)
	var light := unit.core_glow_light()
	var profile := GlowProfiles.profile(GlowProfiles.SERAPH_CORE)
	var energies: Array[float] = []
	for darkness in [0.0, 0.35, 0.85, 1.0]:
		glow.set_darkness(darkness)
		energies.append(light.light_energy)
	assert_almost_eq(energies[0], float(profile.light_energy) * float(profile.day_strength), 0.0001)
	assert_almost_eq(energies[3], float(profile.light_energy), 0.0001, "noite profunda: luz cheia")
	assert_true(energies[0] < energies[1] and energies[1] < energies[2] and energies[2] < energies[3], "mais escuro, mais luz")

func test_the_light_follows_the_core_bone():
	var unit := _spawn(SERAPH)
	var light := unit.core_glow_light()
	var skeleton := unit.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var bone := skeleton.find_bone("core")
	skeleton.set_bone_pose_position(bone, skeleton.get_bone_pose_position(bone) + Vector3(0.0, 0.4, 0.0))
	await wait_frames(2)
	var core_world := skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
	assert_almost_eq(light.global_position.distance_to(core_world), 0.0, 0.01, "a luz sobe e desce com o núcleo")
	assert_gt(light.global_position.y, unit.global_position.y + 1.0, "o núcleo fica no alto do modelo")

func test_the_light_hides_and_dies_with_the_unit():
	var unit := _spawn(SERAPH)
	var light := unit.core_glow_light()
	assert_true(light.is_visible_in_tree())
	unit.visible = false # névoa de guerra
	assert_false(light.is_visible_in_tree(), "unidade escondida: a luz não entrega onde ela está")
	unit.visible = true
	assert_true(light.is_visible_in_tree())

	grid.remove_unit(unit)
	await wait_frames(2)
	assert_false(is_instance_valid(light), "a luz morre com a unidade")
	assert_eq(glow.light_count(WorldGlow.GROUP_UNITS), 0)
	glow.set_darkness(0.5) # reaplicar com a entrada órfã não quebra e a esquece
	assert_eq(glow.light_count(), 0)

func test_rebuilding_the_model_keeps_exactly_one_light():
	var unit := _spawn(SERAPH)
	var first := unit.core_glow_light()
	unit.apply_form(UnitDatabase.create_unit(SERAPH))
	var second := unit.core_glow_light()
	assert_not_null(second)
	assert_ne(second, first, "o modelo foi refeito: luz nova no osso novo")
	assert_true(unit.is_ancestor_of(second))
	await wait_frames(2)
	assert_false(is_instance_valid(first), "a antiga saiu com o modelo antigo")
	assert_eq(glow.light_count(WorldGlow.GROUP_UNITS), 1)
	var lights := unit.find_children("*", "OmniLight3D", true, false)
	assert_eq(lights.size(), 1)

func test_units_without_a_profile_or_outside_a_map_have_no_light():
	var archer := _spawn("v2_unit_archer", Vector2i(1, 1))
	assert_null(archer.core_glow_light())
	assert_eq(archer.find_children("*", "OmniLight3D", true, false).size(), 0)
	# Cena de revisão/teste isolado: sem HexGrid não há WorldGlow — o modelo fica só com a emissão que já tem.
	var loose := Unit.new()
	add_child_autofree(loose)
	loose.setup(UnitDatabase.create_unit(SERAPH), human, Vector2i.ZERO)
	assert_null(loose.core_glow_light())
	assert_eq(loose.find_children("*", "OmniLight3D", true, false).size(), 0)
	assert_not_null(loose._anim_player, "e continua animando normalmente")

# --- A emissão do modelo -------------------------------------------------------------------------------------------------

func test_the_model_emission_grows_with_the_darkness_and_returns_exactly():
	for kind in UnitDatabase.MANIFESTATION_MODELS:
		var unit := _spawn(kind)
		var material := _body_material(unit)
		assert_not_null(material, kind)
		assert_true(material.emission_enabled and material.emission_texture != null, "%s: o mapa de emissão do modelo" % kind)
		var base: Color = material.get_meta(WorldGlow.BASE_EMISSION_META)
		var night := float(GlowProfiles.profile(unit.unit_data.glow_profile).emission_energy)
		assert_true(_close(material.emission, base), "%s: de dia, a emissão aprovada" % kind)
		glow.set_darkness(1.0)
		assert_true(_close(material.emission, Color(base.r * night, base.g * night, base.b * night)), "%s: à noite, ×%.1f" % [kind, night])
		glow.set_darkness(0.5)
		assert_gt(material.emission.r, base.r, kind)
		assert_lt(material.emission.r, base.r * night, kind)
		glow.set_darkness(0.0)
		assert_true(_close(material.emission, base), "%s: volta exatamente ao dia" % kind)
		grid.remove_unit(unit)
		await wait_frames(1)

func test_emission_never_compounds_across_units_or_matches():
	var first := _spawn(SERAPH, Vector2i(0, 0))
	var material := _body_material(first)
	var base: Color = material.get_meta(WorldGlow.BASE_EMISSION_META)
	glow.set_darkness(1.0)
	var night := material.emission
	var second := _spawn(SERAPH, Vector2i(2, 0))
	assert_same(_body_material(second), material, "as unidades do mesmo modelo dividem o material")
	assert_true(_close(material.emission, night), "uma segunda unidade não multiplica de novo")
	assert_eq(glow.tracked_emission_count(), 1)
	# Partida nova: outro mapa, outro WorldGlow, de dia — parte da emissão ORIGINAL, não da que a noite anterior deixou.
	var other := HexGrid.new()
	add_child_autofree(other)
	for q in range(-2, 3):
		for r in range(-2, 3):
			other.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	other.spawn_unit(Vector2i.ZERO, UnitDatabase.create_unit(SERAPH), human)
	assert_true(_close(material.emission, base))
	assert_true(_close(material.get_meta(WorldGlow.BASE_EMISSION_META), base), "a base guardada nunca muda")

func test_the_primordial_keeps_its_own_emission_pulse():
	# O clipe do Primordial anima a ENERGIA da emissão; o brilho mexe na COR: os dois se multiplicam, nenhum apaga o outro.
	var unit := _spawn("v2_manifestation_elemental_primordial")
	var material := _body_material(unit)
	var energies := {}
	for step in 12:
		unit._anim_player.advance(0.5)
		energies[snappedf(material.emission_energy_multiplier, 0.01)] = true
	assert_gt(energies.size(), 1, "o pulso do núcleo continua animado")
	glow.set_darkness(1.0)
	assert_gt(material.emission.r, (material.get_meta(WorldGlow.BASE_EMISSION_META) as Color).r)

# --- Camadas: as duas opções de vídeo -----------------------------------------------------------------------------------

func _resource_light() -> OmniLight3D:
	grid.get_tile(GEMS).resource = "gems"
	grid._resource_props_manager.rebuild(grid.tiles)
	for coord in grid.tiles:
		grid.visibility[coord] = HexGrid.Visibility.VISIBLE
	grid._apply_prop_fog()
	return glow.get_light(ResourcePropsManager.GLOW_GROUP, GEMS)

func test_groups_belong_to_the_map_or_to_the_creatures():
	assert_eq(WorldGlow.layer_of(WorldGlow.GROUP_UNITS), WorldGlow.LAYER_CREATURES)
	assert_eq(WorldGlow.layer_of(ResourcePropsManager.GLOW_GROUP), WorldGlow.LAYER_MAP)
	assert_eq(WorldGlow.layer_of(&"predios_do_futuro"), WorldGlow.LAYER_MAP, "o que não é criatura é do mapa")

func test_each_video_option_turns_off_only_its_own_lights():
	var crystal := _resource_light()
	var core := _spawn(SERAPH).core_glow_light()
	assert_not_null(crystal)
	glow.set_darkness(1.0)
	assert_true(crystal.visible and core.visible)

	glow.set_layer_enabled(WorldGlow.LAYER_MAP, false)
	assert_false(crystal.visible, "luzes do mapa desligadas")
	assert_true(core.visible, "as das criaturas continuam")
	glow.set_layer_enabled(WorldGlow.LAYER_CREATURES, false)
	assert_false(core.visible)
	glow.set_layer_enabled(WorldGlow.LAYER_MAP, true)
	assert_true(crystal.visible, "religar acende de novo, na energia da hora")
	assert_almost_eq(crystal.light_energy, float(GlowProfiles.profile(GlowProfiles.AMETHYST).light_energy), 0.0001)
	assert_false(core.visible)
	glow.set_layer_enabled(WorldGlow.LAYER_CREATURES, true)
	assert_true(core.visible)

func test_a_disabled_layer_stays_off_for_new_lights_and_through_the_night():
	glow.apply_lighting_settings(false, false)
	var crystal := _resource_light()
	var core := _spawn(SERAPH).core_glow_light()
	assert_false(crystal.visible, "recurso revelado com a opção desligada nasce apagado")
	assert_false(core.visible, "manifestação invocada com a opção desligada nasce apagada")
	for darkness in [1.0, 0.4, 0.0, 0.8]:
		glow.set_darkness(darkness)
		assert_false(crystal.visible or core.visible, "anoitecer não religa (escuridão %.1f)" % darkness)
	glow.apply_lighting_settings(true, true)
	assert_true(crystal.visible and core.visible)

func test_turning_the_lights_off_keeps_the_model_glowing():
	var unit := _spawn(SERAPH)
	var material := _body_material(unit)
	glow.set_darkness(1.0)
	var night := material.emission
	glow.apply_lighting_settings(false, false)
	assert_true(_close(material.emission, night), "a emissão do modelo não é luz: continua")
	assert_true(material.emission_enabled)

# --- Configurações → Vídeo ---------------------------------------------------------------------------------------------------

func test_both_options_persist_default_on_and_reset():
	var path := "user://test_lighting_settings.cfg"
	Settings.map_lighting_enabled = false
	Settings.creature_lighting_enabled = false
	Settings.save_settings(path)
	var cfg := ConfigFile.new()
	cfg.load(path)
	assert_eq([cfg.get_value("graphics", "map_lighting"), cfg.get_value("graphics", "creature_lighting")], [false, false])
	Settings.map_lighting_enabled = true
	Settings.creature_lighting_enabled = true
	Settings.load_settings(path)
	assert_false(Settings.map_lighting_enabled, "preferência salva em settings.cfg")
	assert_false(Settings.creature_lighting_enabled)
	# Arquivo antigo, sem as chaves: fica no padrão (ligado).
	cfg.erase_section_key("graphics", "map_lighting")
	cfg.erase_section_key("graphics", "creature_lighting")
	cfg.save(path)
	Settings.map_lighting_enabled = true
	Settings.creature_lighting_enabled = true
	Settings.load_settings(path)
	assert_true(Settings.map_lighting_enabled and Settings.creature_lighting_enabled)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Settings.map_lighting_enabled = _map_lighting
	Settings.creature_lighting_enabled = _creature_lighting

func test_the_video_page_has_the_two_switches_wired_to_the_settings():
	var screen: Control = (load("res://scenes/ui/SettingsScreen.tscn") as PackedScene).instantiate()
	add_child_autofree(screen)
	var map_check: CheckButton = screen.map_lighting_check
	var creature_check: CheckButton = screen.creature_lighting_check
	assert_eq(map_check.get_parent().name, "VideoPage")
	assert_eq(creature_check.get_parent().name, "VideoPage")
	assert_string_contains(map_check.text, "Luzes do mapa")
	assert_string_contains(creature_check.text, "Luzes das criaturas")
	assert_ne(map_check.tooltip_text, "")
	assert_ne(creature_check.tooltip_text, "")

	Settings.set_map_lighting_enabled(true)
	Settings.set_creature_lighting_enabled(true)
	screen.refresh()
	assert_true(map_check.button_pressed and creature_check.button_pressed)
	watch_signals(Settings)
	map_check.button_pressed = false
	assert_false(Settings.map_lighting_enabled)
	assert_true(Settings.creature_lighting_enabled, "uma opção não mexe na outra")
	assert_signal_emitted(Settings, "graphics_changed")
	creature_check.button_pressed = false
	assert_false(Settings.creature_lighting_enabled)

	screen._on_reset_graphics_pressed()
	assert_true(Settings.map_lighting_enabled and Settings.creature_lighting_enabled, "restaurar padrões religa as duas")
	assert_true(map_check.button_pressed and creature_check.button_pressed)

func test_the_game_applies_the_options_to_the_world_glow():
	# Main reaplica as opções gráficas no início e a cada Settings.graphics_changed.
	var source := FileAccess.get_file_as_string("res://scripts/main/Main.gd")
	assert_string_contains(source, "world_glow.apply_lighting_settings(Settings.map_lighting_enabled, Settings.creature_lighting_enabled)")
	assert_string_contains(source, "Settings.graphics_changed.connect(_apply_graphics_settings)")
	glow.apply_lighting_settings(false, true)
	assert_false(glow.is_layer_enabled(WorldGlow.LAYER_MAP))
	assert_true(glow.is_layer_enabled(WorldGlow.LAYER_CREATURES))
