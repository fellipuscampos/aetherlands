extends GutTest

## Brilho do mundo (2026-10-12) — pedido do usuário: "ponha o cristal e o nódulo arcano para terem um certo brilho,
## que ilumine inclusive o mapa dependendo da iluminação: se tiver claro não dá pra ver muito o brilho, mas conforme a
## luminosidade diminuir, fica mais evidente... faça de forma que possamos utilizar esse mesmo efeito em outras coisas".
## Cobre os perfis (GlowProfiles), a escuridão da cena (DayNightCycle/DayNightController), o sistema reutilizável
## (WorldGlow) e o primeiro usuário dele (ResourcePropsManager: Gemas e Nódulo Arcano, com névoa de guerra).

const GROUP := &"teste"
const GEMS := Vector2i(1, 0)
const MANA := Vector2i(-1, 0)
const IRON := Vector2i(0, 1)

var grid: HexGrid
var glow: WorldGlow

func before_each():
	grid = HexGrid.new()
	add_child_autofree(grid)
	for q in range(-3, 4):
		for r in range(-3, 4):
			if absi(q + r) <= 3:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	grid.get_tile(GEMS).resource = "gems"
	grid.get_tile(MANA).resource = "mana_node"
	grid.get_tile(IRON).resource = "iron"
	glow = grid.world_glow

func _show_resources(state: int = HexGrid.Visibility.VISIBLE) -> void:
	for coord in grid.tiles:
		grid.visibility[coord] = state
	grid._apply_prop_fog()

func _resource_light(coord: Vector2i) -> OmniLight3D:
	return glow.get_light(ResourcePropsManager.GLOW_GROUP, coord)

# --- Perfis -----------------------------------------------------------------------------------------------------------

func test_every_profile_is_complete_and_fades_in_with_darkness():
	assert_gt(GlowProfiles.ids().size(), 0)
	for id in GlowProfiles.ids():
		var profile := GlowProfiles.profile(id)
		for key in ["light_color", "light_energy", "light_range", "light_height", "light_attenuation", "emission_energy", "day_strength"]:
			assert_true(profile.has(key), "%s.%s" % [id, key])
		assert_between(float(profile.day_strength), 0.0, 0.5, "%s: de dia o brilho é discreto" % id)
		assert_almost_eq(GlowProfiles.strength(id, 0.0), float(profile.day_strength), 0.0001)
		assert_almost_eq(GlowProfiles.strength(id, 1.0), 1.0, 0.0001, "%s: à noite, brilho cheio" % id)
		assert_gt(GlowProfiles.strength(id, 0.6), GlowProfiles.strength(id, 0.3), "%s: mais escuro, mais brilho" % id)
	assert_eq(GlowProfiles.profile(&"nao_existe"), {})

# --- Escuridão da cena ------------------------------------------------------------------------------------------------

func _darkness_at(minute: float) -> float:
	return float(DayNightCycle.sample(DayNightCycle.phase_for_minute(minute)).darkness)

func test_the_whole_day_is_bright_and_the_deep_night_is_fully_dark():
	var minute := DayNightCycle.DAY_START_MINUTE
	while minute <= DayNightCycle.DAY_END_MINUTE:
		assert_almost_eq(_darkness_at(minute), 0.0, 0.0001, "minuto %.1f é dia" % minute)
		minute += 0.5
	for night_minute in [19.0, 19.5, 0.0, 0.5, 1.0]:
		assert_almost_eq(_darkness_at(night_minute), 1.0, 0.0001, "minuto %.1f é noite profunda" % night_minute)

func test_dusk_only_darkens_and_dawn_only_brightens():
	var previous := _darkness_at(DayNightCycle.DAY_END_MINUTE)
	var minute := DayNightCycle.DAY_END_MINUTE
	while minute <= 19.0:
		assert_gte(_darkness_at(minute), previous - 0.0001, "anoitecer no minuto %.2f" % minute)
		previous = _darkness_at(minute)
		minute += 0.05
	previous = _darkness_at(1.0)
	minute = 1.0
	while minute <= DayNightCycle.DAY_START_MINUTE:
		assert_lte(_darkness_at(minute), previous + 0.0001, "amanhecer no minuto %.2f" % minute)
		previous = _darkness_at(minute)
		minute += 0.05

func test_closed_weather_adds_a_little_darkness_and_never_passes_full():
	var noon := DayNightCycle.sample(DayNightCycle.noon_phase())
	var rainy_noon := DayNightCycle.with_weather(noon, WeatherKinds.look(WeatherKinds.RAIN), 1.0)
	assert_between(float(rainy_noon.darkness), 0.05, 0.4, "chuva ao meio-dia: o brilho aparece um pouco mais, longe de noite")
	assert_lt(float(DayNightCycle.with_weather(noon, WeatherKinds.look(WeatherKinds.SNOW), 1.0).darkness), float(rainy_noon.darkness), "a neve fecha menos o tempo")
	var night := DayNightCycle.sample(DayNightCycle.phase_for_minute(0.0))
	assert_almost_eq(float(DayNightCycle.with_weather(night, WeatherKinds.look(WeatherKinds.RAIN), 1.0).darkness), 1.0, 0.0001)
	assert_eq(float(DayNightCycle.with_weather(noon, WeatherKinds.look(WeatherKinds.RAIN), 0.0).darkness), 0.0, "sem clima, intacto")

func test_the_day_night_controller_publishes_the_darkness_only_when_it_changes():
	var controller := DayNightController.new()
	add_child_autofree(controller)
	controller.setup(null, null)
	controller.running = true
	watch_signals(controller)
	controller.set_phase(DayNightCycle.phase_for_minute(0.0))
	assert_almost_eq(controller.darkness, 1.0, 0.0001)
	assert_signal_emit_count(controller, "darkness_changed", 1)
	controller.set_phase(DayNightCycle.phase_for_minute(0.2)) # ainda noite profunda
	assert_signal_emit_count(controller, "darkness_changed", 1, "mesmo valor: nada é reenviado")
	controller.set_phase(DayNightCycle.noon_phase())
	assert_almost_eq(controller.darkness, 0.0, 0.0001)
	assert_signal_emit_count(controller, "darkness_changed", 2)
	controller.set_weather_look(WeatherKinds.look(WeatherKinds.RAIN), 1.0)
	controller.set_phase(DayNightCycle.noon_phase())
	assert_gt(controller.darkness, 0.0, "o clima entra na escuridão publicada")

# --- WorldGlow ----------------------------------------------------------------------------------------------------------

func test_a_light_is_born_off_and_follows_its_profile_once_shown():
	var profile := GlowProfiles.profile(GlowProfiles.ARCANE)
	var light := glow.add_light(GROUP, "a", Vector3(2, 0.5, 3), GlowProfiles.ARCANE)
	assert_not_null(light)
	assert_false(light.visible, "nasce apagada: quem pediu decide quando aparece")
	assert_false(light.shadow_enabled, "sem sombra")
	assert_eq(light.light_color, profile.light_color)
	assert_almost_eq(light.omni_range, float(profile.light_range), 0.0001)
	assert_almost_eq(light.position.y, 0.5 + float(profile.light_height), 0.0001, "acima do ponto de apoio")
	glow.set_light_shown(GROUP, "a", true)
	assert_true(light.visible)
	assert_almost_eq(light.light_energy, float(profile.light_energy) * float(profile.day_strength), 0.0001, "de dia: só a fração do perfil")
	assert_null(glow.add_light(GROUP, "b", Vector3.ZERO, &"nao_existe"), "perfil desconhecido não cria luz")
	assert_eq(glow.light_count(GROUP), 1)

func test_lights_grow_with_the_darkness_of_the_scene():
	var profile := GlowProfiles.profile(GlowProfiles.AMETHYST)
	var light := glow.add_light(GROUP, "a", Vector3.ZERO, GlowProfiles.AMETHYST)
	glow.set_light_shown(GROUP, "a", true)
	var day_energy := light.light_energy
	glow.set_darkness(0.5)
	assert_gt(light.light_energy, day_energy, "anoitecendo: mais luz")
	glow.set_darkness(1.0)
	assert_almost_eq(light.light_energy, float(profile.light_energy), 0.0001, "noite profunda: energia cheia do perfil")
	var hidden := glow.add_light(GROUP, "b", Vector3.ZERO, GlowProfiles.AMETHYST)
	assert_false(hidden.visible, "luz nova nasce apagada mesmo à noite")
	glow.set_darkness(0.0)
	assert_almost_eq(light.light_energy, day_energy, 0.0001, "amanheceu: volta ao mínimo")

func test_groups_are_independent_and_lights_can_be_moved_and_removed():
	glow.add_light(GROUP, 1, Vector3.ZERO, GlowProfiles.ARCANE)
	glow.add_light(GROUP, 2, Vector3.ZERO, GlowProfiles.ARCANE)
	glow.add_light(&"outro", 1, Vector3.ZERO, GlowProfiles.AMETHYST)
	assert_eq(glow.light_count(), 3)
	var same := glow.add_light(GROUP, 1, Vector3(5, 0, 0), GlowProfiles.AMETHYST)
	assert_eq(glow.light_count(GROUP), 2, "mesma chave: a luz é reaproveitada, não duplicada")
	assert_eq(same.light_color, GlowProfiles.profile(GlowProfiles.AMETHYST).light_color, "e troca de perfil")
	glow.move_light(GROUP, 1, Vector3(5, 2, 0))
	assert_almost_eq(same.position.y, 2.0 + float(GlowProfiles.profile(GlowProfiles.AMETHYST).light_height), 0.0001)
	glow.remove_light(GROUP, 2)
	assert_false(glow.has_light(GROUP, 2))
	glow.clear_group(GROUP)
	assert_eq(glow.light_count(GROUP), 0)
	assert_eq(glow.light_count(&"outro"), 1, "limpar um grupo não toca nos outros")

func test_the_glow_material_keeps_the_source_look_and_adds_the_profile_emission():
	var source := StandardMaterial3D.new()
	source.albedo_texture = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	source.roughness = 0.7
	var material := WorldGlow.prop_material(source, GlowProfiles.ARCANE, true)
	assert_eq(material.shader, WorldGlow.PROP_SHADER)
	assert_eq(material.get_shader_parameter("albedo_texture"), source.albedo_texture)
	assert_almost_eq(float(material.get_shader_parameter("roughness")), 0.7, 0.0001)
	assert_almost_eq(float(material.get_shader_parameter("glow_energy")), float(GlowProfiles.profile(GlowProfiles.ARCANE).emission_energy), 0.0001)
	assert_true(bool(material.get_shader_parameter("glow_per_instance")))
	assert_null(WorldGlow.prop_material(source, &"nao_existe"))
	var code := WorldGlow.PROP_SHADER.code
	assert_string_contains(code, "global uniform float world_darkness", "a emissão segue a escuridão global da cena")
	assert_true(ProjectSettings.has_setting("shader_globals/world_darkness"), "parâmetro global declarado no projeto")

# --- Recursos de mapa -----------------------------------------------------------------------------------------------

func test_gems_and_arcane_nodes_glow_and_other_resources_do_not():
	grid._rebuild_props()
	assert_true(glow.has_light(ResourcePropsManager.GLOW_GROUP, GEMS))
	assert_true(glow.has_light(ResourcePropsManager.GLOW_GROUP, MANA))
	assert_false(glow.has_light(ResourcePropsManager.GLOW_GROUP, IRON), "Ferro não brilha")
	assert_eq(glow.light_count(ResourcePropsManager.GLOW_GROUP), 2)
	assert_eq(_resource_light(GEMS).light_color, GlowProfiles.profile(GlowProfiles.AMETHYST).light_color)
	assert_eq(_resource_light(MANA).light_color, GlowProfiles.profile(GlowProfiles.ARCANE).light_color)
	var props := grid._resource_props_manager
	for kind in ["gems", "mana_node"]:
		var material := (props._instances[kind] as MultiMeshInstance3D).material_override as ShaderMaterial
		assert_not_null(material, "%s usa o material de brilho" % kind)
		assert_eq(material.shader, WorldGlow.PROP_SHADER)
		assert_not_null(material.get_shader_parameter("albedo_texture"), "%s conserva o atlas do modelo" % kind)
		assert_true((props._instances[kind] as MultiMeshInstance3D).multimesh.use_custom_data, "brilho por instância (névoa)")
	assert_true((props._instances["iron"] as MultiMeshInstance3D).material_override is StandardMaterial3D, "Ferro continua com o material comum")
	# (O RenderingServer headless não guarda transforms de MultiMesh: compara com o centro do tile, não com a instância.)
	var tile_center := grid.world_for_coord(GEMS)
	assert_lt(Vector2(_resource_light(GEMS).position.x - tile_center.x, _resource_light(GEMS).position.z - tile_center.z).length(), 0.3, "a luz fica no tile do recurso")

func test_fog_of_war_only_lights_what_is_visible_right_now():
	grid._rebuild_props()
	assert_false(_resource_light(GEMS).visible, "antes da névoa ser aplicada: apagada")
	_show_resources(HexGrid.Visibility.UNSEEN)
	assert_false(_resource_light(GEMS).visible, "tile nunca visto: luz acesa entregaria o recurso")
	_show_resources(HexGrid.Visibility.EXPLORED)
	assert_false(_resource_light(GEMS).visible, "tile explorado é memória: sem luz")
	assert_false(grid._resource_props_manager._glow_shown.has(GEMS))
	_show_resources(HexGrid.Visibility.VISIBLE)
	assert_true(_resource_light(GEMS).visible)
	assert_true(_resource_light(MANA).visible)
	assert_true(grid._resource_props_manager._glow_shown.has(GEMS), "emissão da instância ligada junto com a luz")
	grid.visibility[GEMS] = HexGrid.Visibility.EXPLORED
	grid._apply_prop_fog()
	assert_false(_resource_light(GEMS).visible, "saiu da visão: apaga")
	assert_true(_resource_light(MANA).visible, "o outro tile continua aceso")

func test_resource_lights_follow_the_scene_darkness():
	grid._rebuild_props()
	_show_resources()
	var day_energy := _resource_light(MANA).light_energy
	glow.set_darkness(1.0)
	assert_gt(_resource_light(MANA).light_energy, day_energy * 3.0, "à noite o nódulo ilumina bem mais o mapa")
	assert_gt(_resource_light(GEMS).light_energy, 1.0)

func test_a_destroyed_or_rebuilt_resource_does_not_leave_a_light_behind():
	grid._rebuild_props()
	_show_resources()
	grid.destroy_resource_at(GEMS)
	assert_false(glow.has_light(ResourcePropsManager.GLOW_GROUP, GEMS), "recurso destruído: a luz sai junto")
	assert_true(glow.has_light(ResourcePropsManager.GLOW_GROUP, MANA))
	grid.get_tile(MANA).resource = ""
	grid._rebuild_props()
	assert_eq(glow.light_count(ResourcePropsManager.GLOW_GROUP), 0, "reconstruir os props refaz só as luzes que ainda existem")
