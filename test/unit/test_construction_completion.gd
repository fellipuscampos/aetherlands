extends GutTest

## Conclusão de obra (2026-10-12) — relato do usuário: "o jogo não parece saber quando de fato uma construção acaba...
## a construção supostamente termina, aparece o prédio, mas a barra de progresso está tipo em 80%, aí uns 2 turnos
## depois que o prédio está construído a barra de progresso some... fica 2 construções ocupando o mesmo espaço, a
## animação da construção e o prédio pronto".
## Estes testes rodam o TURNO REAL (TurnManager.end_turn -> GameManager, com a fila de IA escalonada como no jogo) e
## conferem, em cada fase, que prédio e canteiro nunca dividem o tile e que a barra mostra a produção atual.

const HALL := "v2_building_guardian_hall"
const SITE := Vector2i(1, 0)

var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var city: City
var _original := {}
var _reduced_motion := false

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "debug_mode"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	_reduced_motion = Settings.reduced_motion
	Settings.reduced_motion = true # o aceno de conclusão tem teste próprio; aqui o estado final vale na hora
	grid = HexGrid.new()
	add_child_autofree(grid)
	for q in range(-8, 9):
		for r in range(-8, 9):
			if absi(q + r) <= 8:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var civ := CivilizationData.new()
	civ.race = "human"
	human = PlayerData.new(civ)
	var rival_civ := CivilizationData.new()
	rival_civ.race = "orc"
	rival = PlayerData.new(rival_civ)
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.debug_mode = false
	TurnManager.turn_number = 1
	human.gold = 500.0
	rival.gold = 500.0
	human.v2_research.complete_research("v2_doctrine_guardian_2")
	city = grid.found_city(Vector2i.ZERO, human, "Capital", true)
	grid.found_city(Vector2i(6, 0), rival, "Rival", true)
	grid.spawn_unit(Vector2i(6, 1), UnitDatabase.create_unit("warrior"), rival) # a fila de IA nunca fica vazia

func after_each():
	SelectionManager.reset()
	GameManager.is_turn_processing = false
	GameManager._ai_turn_queue.clear()
	Settings.reduced_motion = _reduced_motion
	for player in [human, rival]:
		player.release_relations()
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "debug_mode"]:
		GameManager.set(key, _original[key])
	TurnManager.turn_number = _original.turn

func _start_hall() -> void:
	SelectionManager.start_building_placement(city, HALL)
	SelectionManager.handle_world_click(HexMetrics.axial_to_world(SITE.x, SITE.y, grid.hex_size))

func _marker() -> Node3D:
	return grid._construction_markers.get(SITE)

## Preenchimento da barra lido dos PIXELS da textura (0..100).
func _bar_percent(marker: Node3D) -> int:
	var bar := marker.get_node("ProgressBar") as Sprite3D
	var image := bar.texture.get_image()
	var row := HexGrid.CONSTRUCTION_PROGRESS_BAR_TEX_HEIGHT / 2
	var filled := 0
	for x in range(1, image.get_width() - 1):
		var pixel := image.get_pixel(x, row)
		if absf(pixel.r - HexGrid.CONSTRUCTION_PROGRESS_BAR_FILL_COLOR.r) < 0.02 and absf(pixel.b - HexGrid.CONSTRUCTION_PROGRESS_BAR_FILL_COLOR.b) < 0.02:
			filled += 1
	return roundi(100.0 * filled / float(image.get_width() - 2))

## Restos de obra no mapa: marcadores que não estão de saída (queue_free só tira o nó da árvore no fim do quadro) e que
## não correspondem a nenhuma obra EM ANDAMENTO. A cidade rival da IA pode legitimamente começar a própria obra durante
## o cenário (desde a produção-base 5, 2026-10-14, isso acontece dentro da janela do teste) — essa não é resto.
func _leftover_markers() -> Array:
	var active := []
	for c in grid.cities_by_coord.values():
		if c.pending_building_coord != City.NO_PENDING_COORD and not grid.buildings_by_coord.has(c.pending_building_coord):
			active.append(grid._construction_markers.get(c.pending_building_coord))
	return grid._construction_root.get_children().filter(func(marker): return not marker.is_queued_for_deletion() and not (marker in active))

## Canteiros (modelo animado da obra) ainda de pé em qualquer lugar do mapa.
func _live_sites() -> int:
	var count := 0
	for marker in _leftover_markers():
		var site := (marker as Node).get_node_or_null("ConstructionSite") as Node3D
		if site != null and not site.is_queued_for_deletion() and site.is_visible_in_tree():
			count += 1
	return count

## O que precisa valer em QUALQUER fase do turno.
func _assert_consistent(phase: String) -> void:
	var built := grid.get_building_at(SITE) != null
	if built:
		assert_false(grid._construction_markers.has(SITE), "%s: prédio pronto e canteiro nunca dividem o tile" % phase)
		assert_eq(_live_sites(), 0, "%s: nenhuma animação de obra sobre o prédio pronto" % phase)
		assert_eq(city.pending_building_coord, City.NO_PENDING_COORD, phase)
	else:
		assert_true(grid._construction_markers.has(SITE), "%s: obra em andamento tem canteiro" % phase)
		var expected := roundi(100.0 * clampf(city.stored_production / city.production_cost(), 0.0, 1.0))
		assert_almost_eq(_bar_percent(_marker()), expected, 2, "%s: a barra mostra a produção ATUAL (%.0f/%.0f)" % [phase, city.stored_production, city.production_cost()])

func _drain_ai_queue() -> void:
	var guard := 0
	while GameManager.is_turn_processing and guard < 500:
		GameManager._process(1.0)
		guard += 1

func _play_until_built(staggered: bool) -> int:
	GameManager.stagger_ai_turns = staggered
	_start_hall()
	_assert_consistent("obra iniciada")
	for turn in range(1, 30):
		TurnManager.end_turn()
		# Com a fila escalonada, este é o intervalo em que a IA ainda está agindo: era aqui que prédio, canteiro e a
		# barra do turno anterior ficavam juntos.
		assert_eq(GameManager.is_turn_processing, staggered, "pré-condição do cenário")
		_assert_consistent("turno %d, logo após Encerrar (IA agindo)" % turn)
		_drain_ai_queue()
		_assert_consistent("turno %d, início do turno seguinte" % turn)
		if grid.get_building_at(SITE) != null:
			return turn
	return -1

# --- Turno real ---------------------------------------------------------------------------------------------------------

func test_building_and_site_never_share_the_tile_with_staggered_ai():
	var built_on := _play_until_built(true)
	assert_gt(built_on, 1, "a obra leva alguns turnos e conclui")
	assert_eq(city.production_item, "", "a cidade fica ociosa ao concluir")
	# Nada fica para trás nos turnos seguintes (antes: uma barra em 100% por mais um turno inteiro).
	for extra in 2:
		TurnManager.end_turn()
		_assert_consistent("turno extra %d, IA agindo" % extra)
		_drain_ai_queue()
		_assert_consistent("turno extra %d" % extra)
	assert_eq(_leftover_markers().size(), 0, "nenhum resto de obra no mapa")

func test_building_and_site_never_share_the_tile_with_synchronous_ai():
	assert_gt(_play_until_built(false), 1)
	assert_eq(_leftover_markers().size(), 0)

func test_the_bar_advances_as_soon_as_the_turn_ends_not_after_the_ai_phase():
	GameManager.stagger_ai_turns = true
	_start_hall()
	assert_eq(_bar_percent(_marker()), 0)
	TurnManager.end_turn()
	assert_true(GameManager.is_turn_processing, "a IA ainda nem começou a agir")
	assert_gt(_bar_percent(_marker()), 0, "a produção do turno já aparece na barra")
	_drain_ai_queue()

# --- Conclusão ----------------------------------------------------------------------------------------------------------

func test_completion_shows_a_full_bar_briefly_and_then_nothing():
	Settings.reduced_motion = false
	_start_hall()
	city.stored_production = city.production_cost() * 0.8
	grid.refresh_construction_markers()
	var marker := _marker()
	assert_almost_eq(_bar_percent(marker), 80, 2)
	var site := marker.get_node("ConstructionSite") as Node3D

	grid.place_building(SITE, HALL, human)

	assert_false(grid._construction_markers.has(SITE), "para o jogo, a obra acabou neste instante")
	assert_true(site.is_queued_for_deletion() and not site.visible, "o canteiro animado some junto")
	assert_false(marker.is_queued_for_deletion(), "fica só o aceno de conclusão")
	assert_eq(_bar_percent(marker), 100, "a barra fecha em 100%, nunca parada no valor do turno anterior")
	await wait_seconds(HexGrid.CONSTRUCTION_COMPLETED_HOLD + HexGrid.CONSTRUCTION_COMPLETED_FADE + 0.4)
	assert_false(is_instance_valid(marker), "e some sozinha em menos de um segundo e meio")
	assert_eq(_leftover_markers().size(), 0)

func test_reduced_motion_completion_leaves_nothing_behind_at_once():
	_start_hall()
	var marker := _marker()
	grid.place_building(SITE, HALL, human)
	assert_true(marker.is_queued_for_deletion())
	assert_false(grid._construction_markers.has(SITE))

func test_cancelling_the_work_removes_the_site_without_a_building():
	_start_hall()
	city.set_production("")
	grid.refresh_construction_markers()
	assert_false(grid._construction_markers.has(SITE))
	assert_null(grid.get_building_at(SITE))
	assert_eq(_live_sites(), 0)

func test_refresh_only_redraws_a_bar_whose_progress_changed():
	_start_hall()
	var bar := _marker().get_node("ProgressBar") as Sprite3D
	var texture := bar.texture
	grid.refresh_construction_markers()
	assert_same(bar.texture, texture, "mesmo progresso: a textura não é refeita")
	city.stored_production = city.production_cost() * 0.5
	grid.refresh_construction_markers()
	assert_ne(bar.texture, texture)
	assert_almost_eq(_bar_percent(_marker()), 50, 2)

# --- Captura ------------------------------------------------------------------------------------------------------------

func test_a_captured_city_updates_its_site_at_once():
	_start_hall()
	var human_site := _marker().get_node("ConstructionSite") as Node3D
	assert_eq(human_site.get_meta("race"), "human")
	# O novo dono não tem a pesquisa do Salão: a obra cai na revalidação e o canteiro some na hora.
	grid.capture_city(city, rival)
	assert_eq(city.pending_building_coord, City.NO_PENDING_COORD)
	assert_false(grid._construction_markers.has(SITE), "obra cancelada pela captura: sem canteiro, sem esperar o fim da rodada")
	# Com a pesquisa, a obra continua — agora com o canteiro do novo dono.
	rival.v2_research.complete_research("v2_doctrine_guardian_2")
	grid.capture_city(city, human)
	_start_hall()
	grid.capture_city(city, rival)
	assert_eq(city.pending_building_coord, SITE, "obra legítima para o novo dono continua")
	var rival_site := _marker().get_node("ConstructionSite") as Node3D
	assert_eq(rival_site.get_meta("race"), "orc", "o canteiro passa a ser o da raça do novo dono")
	assert_eq(_marker().get_meta("owner_player"), rival)

# --- Névoa --------------------------------------------------------------------------------------------------------------

func test_an_enemy_site_is_born_hidden_in_the_fog_and_ends_without_a_trace():
	Settings.reduced_motion = false
	var rival_city: City = grid.get_city_at(Vector2i(6, 0))
	var rival_site := Vector2i(7, 0)
	for coord in grid.tiles:
		grid.visibility[coord] = HexGrid.Visibility.EXPLORED # o jogador conhece o mapa, mas não vê a cidade rival agora
	rival_city.start_building("v2_building_market", rival_site, grid)
	grid.refresh_construction_markers()
	var marker: Node3D = grid._construction_markers[rival_site]
	assert_false(marker.visible, "obra inimiga fora da visão já nasce escondida — sem esperar o próximo recálculo de névoa")
	grid.place_building(rival_site, "v2_building_market", rival)
	assert_true(marker.is_queued_for_deletion(), "conclusão fora da visão: nenhum aceno que entregue a obra")
	# A própria obra o dono sempre vê.
	_start_hall()
	assert_true(_marker().visible)
