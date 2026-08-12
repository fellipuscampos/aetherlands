extends GutTest

## Cobre MonsterDatabase (dados dos guardioes de Covil de Monstro) e a
## geracao deterministica de covis no mapa (HexGrid._spawn_monster_lairs).

func test_create_monster_returns_positive_gold_reward():
	for kind in MonsterDatabase.KINDS:
		var data = MonsterDatabase.create_monster(kind)
		assert_gt(data.gold_reward, 0.0, "%s deveria ter recompensa de ouro > 0" % kind)

## Regressao de "nao trava": spawna de verdade os 5 tipos, como camp boss
## (exercita a criacao do guardiao reforcado, ver MonsterDatabase.
## create_monster) e como reforco comum (exercita
## Unit._build_procedural_body pra cada visual_kind, incluindo os branches
## novos "skeleton"/"dragon") — sem isso, nenhum teste da suite chega a
## instanciar de verdade um Dragao (exige ameaca >= 0.85 + bioma LAVA ao
## mesmo tempo, uma combinacao rara demais pra aparecer por acaso numa
## geracao de mapa normal), entao um erro de GDScript na construcao do
## mesh dele passaria despercebido ate alguem jogar uma partida de verdade.
func test_spawn_monster_at_builds_visual_for_every_kind_without_error():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.tiles[Vector2i.ZERO] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var col := 1
	for kind in MonsterDatabase.KINDS:
		for is_boss in [false, true]:
			var coord = Vector2i(col, 0)
			hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
			var unit = hex_grid.spawn_monster_at(coord, kind, is_boss)
			assert_not_null(unit, "%s (boss=%s) deveria ter spawnado sem erro" % [kind, is_boss])
			assert_eq(unit.unit_data.visual_kind, MonsterDatabase.KIND_DATA[kind].visual_kind)
			col += 1

	hex_grid.queue_free()

## So o "camp boss" (ocupante ORIGINAL do covil, ver HexGrid.
## _spawn_monster_lairs/spawn_monster_at(is_camp_boss=true)) nunca se move
## — reforco comum agora tem movement_points de verdade, "ficar parado" e
## escolha de IA (MonsterAI, comportamento Guardiao), nao mais uma trava
## de stat (ver test_create_monster_regular_kind_has_positive_movement).
func test_create_monster_camp_boss_never_moves():
	for kind in MonsterDatabase.KINDS:
		var data = MonsterDatabase.create_monster(kind, true)
		assert_eq(data.movement_points, 0.0, "%s como camp boss nunca deveria sair do proprio tile" % kind)

func test_create_monster_regular_kind_has_positive_movement():
	for kind in MonsterDatabase.KINDS:
		var data = MonsterDatabase.create_monster(kind)
		assert_gt(data.movement_points, 0.0, "%s como reforco comum deveria conseguir se mover" % kind)

## Camp boss vem com HP/ataque reforcados em cima da tabela base — le como
## um "chefao" de verdade, nao so mais um reforco igual aos outros.
func test_create_monster_camp_boss_has_boosted_stats():
	for kind in MonsterDatabase.KINDS:
		var base = MonsterDatabase.create_monster(kind)
		var boss = MonsterDatabase.create_monster(kind, true)
		assert_gt(boss.max_hp, base.max_hp, "%s camp boss deveria ter mais HP que um reforco comum" % kind)
		assert_gt(boss.attack, base.attack, "%s camp boss deveria ter mais ataque que um reforco comum" % kind)

func test_random_kind_always_returns_a_known_kind():
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(50):
		assert_true(MonsterDatabase.random_kind(rng) in MonsterDatabase.KINDS)

func test_random_kind_is_deterministic_for_same_seed():
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 777
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 777
	var sequence_a := []
	var sequence_b := []
	for i in range(10):
		sequence_a.append(MonsterDatabase.random_kind(rng_a))
		sequence_b.append(MonsterDatabase.random_kind(rng_b))
	assert_eq(sequence_a, sequence_b)

func test_generate_map_spawns_monster_lairs_with_neutral_owner():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(25, 25, 321)

	assert_gt(hex_grid.lair_coords.size(), 0, "um mapa medio deveria ter pelo menos um covil")
	for coord in hex_grid.lair_coords:
		var guardian = hex_grid.get_unit_at(coord)
		assert_not_null(guardian, "todo lair_coords deveria ter um guardiao vivo logo apos gerar o mapa")
		assert_null(guardian.owner_player, "guardiao de covil deveria ser neutro (owner_player nulo)")

	hex_grid.queue_free()

func test_monster_lairs_never_spawn_on_ocean():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(29, 29, 4242)

	for coord in hex_grid.lair_coords:
		var data: HexTileData = hex_grid.get_tile(coord)
		assert_ne(data.terrain_type, HexTileData.TerrainType.OCEAN)

	hex_grid.queue_free()

## Regressao: um covil em cima do tile inicial do humano (perto do centro
## do mapa) tornaria o comeco de jogo injusto/impossivel — ver
## HexGrid.LAIR_MIN_DISTANCE_FROM_CENTER_FRACTION.
func test_monster_lairs_never_spawn_too_close_to_map_center():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(33, 33, 99)

	var min_dist = hex_grid._min_distance_from_center()
	for coord in hex_grid.lair_coords:
		assert_true(HexMetrics.axial_distance(coord, Vector2i.ZERO) >= min_dist)

	hex_grid.queue_free()

func test_generate_map_lair_placement_is_deterministic_for_same_seed():
	var grid_a := HexGrid.new()
	grid_a._ready()
	grid_a.generate_map(21, 21, 555)

	var grid_b := HexGrid.new()
	grid_b._ready()
	grid_b.generate_map(21, 21, 555)

	assert_eq(grid_a.lair_coords, grid_b.lair_coords, "a mesma semente deveria colocar os covis nos mesmos tiles")

	grid_a.queue_free()
	grid_b.queue_free()

## Regressao: lair_kind_by_coord precisa bater com o tipo do guardiao de
## verdade que esta la (process_monster_lairs usa esse dicionario pra
## saber o que gerar de reforco — se estivesse errado, um covil de troll
## comecaria a spawnar goblin ao redor, por exemplo).
func test_generate_map_records_lair_kind_matching_the_guardian():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(33, 33, 2024)

	assert_gt(hex_grid.lair_coords.size(), 0, "precondicao: deveria ter pelo menos um covil")
	for coord in hex_grid.lair_coords:
		var guardian = hex_grid.get_unit_at(coord)
		assert_eq(hex_grid.lair_kind_by_coord.get(coord, ""), guardian.unit_data.visual_kind)

	hex_grid.queue_free()

## Regressao critica (pedido do usuario: "ao redor de um covil de goblin
## pode spawnar ate sei la 5 goblins... tem que ter um limite pra nao
## spawnar pra sempre"): rodar process_monster_lairs() MUITAS vezes (bem
## mais que o necessario pra bater o limite, dado LAIR_SPAWN_CHANCE) nunca
## deveria deixar nenhum covil com mais monstros vivos na propria area (a
## celula do covil + 6 vizinhos) do que o limite POR TIPO daquele covil
## (MonsterDatabase.KIND_DATA[kind].lair_cap, ver HexGrid._lair_cap_for —
## substituiu o antigo limite global unico LAIR_SPAWN_CAP).
func test_process_monster_lairs_never_exceeds_the_cap():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(41, 41, 111)

	for i in range(300):
		hex_grid.process_monster_lairs()

	for lair_coord in hex_grid.lair_coords:
		var kind = hex_grid.lair_kind_by_coord[lair_coord]
		var cap = hex_grid._lair_cap_for(kind)
		var count = hex_grid._count_live_monsters_near_lair(lair_coord)
		assert_lte(count, cap, "covil de %s em %s excedeu o proprio limite de populacao (%d > %d)" % [kind, lair_coord, count, cap])

	hex_grid.queue_free()

## Complementar ao teste acima: nao so "nunca excede", mas realmente
## CRESCE ate o limite do proprio tipo com o tempo — senao o teste anterior
## passaria trivialmente com process_monster_lairs() nao fazendo nada.
func test_process_monster_lairs_eventually_reaches_the_cap():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(41, 41, 111)

	assert_gt(hex_grid.lair_coords.size(), 0, "precondicao: deveria ter pelo menos um covil")

	for i in range(300):
		hex_grid.process_monster_lairs()

	var any_at_cap = false
	for lair_coord in hex_grid.lair_coords:
		var kind = hex_grid.lair_kind_by_coord[lair_coord]
		if hex_grid._count_live_monsters_near_lair(lair_coord) == hex_grid._lair_cap_for(kind):
			any_at_cap = true
			break
	assert_true(any_at_cap, "depois de varias tentativas, pelo menos um covil deveria ter atingido o limite de populacao do proprio tipo")

	hex_grid.queue_free()

## Regressao: monstro novo gerado por um covil precisa ser do MESMO tipo
## (kind) que o guardiao original — process_monster_lairs nao deveria
## nunca misturar tipos dentro da area de um unico covil.
func test_process_monster_lairs_spawns_matching_kind():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(41, 41, 111)

	for i in range(300):
		hex_grid.process_monster_lairs()

	for lair_coord in hex_grid.lair_coords:
		var expected_kind = hex_grid.lair_kind_by_coord.get(lair_coord, "")
		for coord in hex_grid._lair_area(lair_coord):
			var unit = hex_grid.get_unit_at(coord)
			if unit != null and unit.owner_player == null:
				assert_eq(unit.unit_data.visual_kind, expected_kind, "monstro gerado perto do covil em %s deveria ser %s" % [lair_coord, expected_kind])

	hex_grid.queue_free()

## Verificacao direta de que reforco de covil instancia uma `Unit` de
## verdade (a mesma classe usada por unidade de jogador/rival) — nao existe
## nenhuma classe/cena de "Covil" neste projeto pra instanciar por engano:
## um covil e so uma coordenada (lair_coords/lair_kind_by_coord), o
## marcador visual dele E o proprio guardiao Unit parado ali (ver
## HexGrid.spawn_monster_at).
func test_process_monster_lairs_reinforcement_spawns_a_unit_instance():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(41, 41, 111)

	for i in range(300):
		hex_grid.process_monster_lairs()

	var found_any := false
	for unit in hex_grid.neutral_units():
		found_any = true
		assert_true(unit is Unit, "monstro neutro no mapa deveria ser uma instancia de Unit")
		assert_true(unit is Node3D, "Unit e sempre um Node3D (nenhum node de 'Covil' separado existe)")
	assert_true(found_any, "precondicao: deveria haver pelo menos um monstro neutro no mapa apos reforcar")

	hex_grid.queue_free()

## _threat_level (0..1) combina distancia-do-centro e turno por MAXIMO, nao
## soma — ver HexGrid._threat_level.
func test_threat_level_is_zero_at_center_on_turn_zero():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.map_width = 80
	hex_grid.map_height = 60
	assert_eq(hex_grid._threat_level(0.0, 0), 0.0)
	hex_grid.queue_free()

func test_threat_level_saturates_far_from_center_even_at_turn_zero():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.map_width = 80
	hex_grid.map_height = 60
	var far_distance = float(min(80, 60)) / 2.0 # bem alem de THREAT_DISTANCE_FULL_FRACTION do raio
	assert_eq(hex_grid._threat_level(far_distance, 0), 1.0, "tile na borda do mapa deveria saturar ameaca mesmo no turno 0")
	hex_grid.queue_free()

func test_threat_level_saturates_after_ramp_turns_even_at_center():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.map_width = 80
	hex_grid.map_height = 60
	assert_eq(hex_grid._threat_level(0.0, int(hex_grid.THREAT_TURN_RAMP_TURNS)), 1.0, "turno tardio deveria saturar ameaca mesmo no centro")
	hex_grid.queue_free()

## Regra de fantasia (progressao): perto do centro do mapa (onde a capital
## tende a nascer) so Goblin pode ser sorteado pro covil, nunca Troll/Vivern
## por azar — ver MonsterDatabase.KIND_MIN_THREAT.
func test_random_kind_at_zero_threat_never_returns_troll_or_wyvern():
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	for i in range(200):
		var kind = MonsterDatabase.random_kind(rng, 0.0)
		assert_eq(kind, "goblin", "ameaca zero deveria sempre sortear goblin, nao %s" % kind)

## Ameaca maxima (regiao profunda do mapa) precisa realmente conseguir
## sortear os tipos mais fortes, nao so nao travar em goblin por acidente.
func test_random_kind_at_full_threat_can_return_troll_or_wyvern():
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	var saw_strong := false
	for i in range(200):
		if MonsterDatabase.random_kind(rng, 1.0) in ["troll", "wyvern"]:
			saw_strong = true
			break
	assert_true(saw_strong, "ameaca maxima deveria conseguir sortear Troll ou Vivern em 200 tentativas")

## _reinforce_chance sobe com o turno (mundo fica mais perigoso com o
## tempo) mas nunca ultrapassa base + bonus.
func test_reinforce_chance_increases_with_turn_and_is_capped():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.map_width = 80
	hex_grid.map_height = 60
	var early = hex_grid._reinforce_chance(0)
	var late = hex_grid._reinforce_chance(int(hex_grid.THREAT_TURN_RAMP_TURNS))
	var very_late = hex_grid._reinforce_chance(int(hex_grid.THREAT_TURN_RAMP_TURNS) * 10)
	assert_almost_eq(early, HexGrid.LAIR_SPAWN_CHANCE, 0.001)
	assert_almost_eq(late, HexGrid.LAIR_SPAWN_CHANCE + HexGrid.LAIR_SPAWN_CHANCE_TURN_BONUS, 0.001)
	assert_almost_eq(very_late, late, 0.001, "chance nao deveria continuar subindo depois de saturar")
	hex_grid.queue_free()

## Regressao critica (determinismo, pedido do usuario: "impede replays"):
## dois HexGrid com a MESMA semente, processando process_monster_lairs() o
## MESMO numero de vezes com os MESMOS turnos, precisam terminar com
## exatamente os mesmos monstros neutros (coord/tipo/hp) — antes disso
## process_monster_lairs usava randf()/randi() GLOBAIS (sem semente
## controlavel), entao duas rodadas identicas podiam divergir. Agora usa
## HexGrid.monster_turn_rng, seedado por map_seed.
func test_process_monster_lairs_is_deterministic_for_same_seed_and_turns():
	var grid_a := HexGrid.new()
	grid_a._ready()
	grid_a.generate_map(41, 41, 111)
	var grid_b := HexGrid.new()
	grid_b._ready()
	grid_b.generate_map(41, 41, 111)

	for turn in range(1, 21):
		grid_a.process_monster_lairs(turn)
		grid_b.process_monster_lairs(turn)

	var units_a = grid_a.neutral_units()
	var units_b = grid_b.neutral_units()
	assert_eq(units_a.size(), units_b.size(), "mesma semente/turnos deveria produzir o mesmo numero de monstros neutros")
	var coords_a: Array[Vector2i] = []
	var coords_b: Array[Vector2i] = []
	for u in units_a:
		coords_a.append(u.coord)
	for u in units_b:
		coords_b.append(u.coord)
	coords_a.sort()
	coords_b.sort()
	assert_eq(coords_a, coords_b, "mesma semente/turnos deveria posicionar os monstros neutros nos mesmos tiles")

	grid_a.queue_free()
	grid_b.queue_free()

## Regra de fantasia (patrulha): covil CHEIO (no LAIR_SPAWN_CAP) move um
## morador pra outro tile livre da PROPRIA area em vez de deixar todo mundo
## parado pra sempre — nunca aumenta a populacao da area (so reposiciona) e
## nunca sai da area do proprio covil (garante por construcao que nunca
## invade a area de um covil vizinho).
func test_maybe_roam_lair_repositions_within_the_same_lair_area_when_full():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(41, 41, 111)

	# Procura um covil cuja area tenha os 6 vizinhos completos (perto de
	# borda do mapa, get_neighbors devolve menos de 6) E todos os 7 tiles
	# sejam terra firme — precisa sobrar pelo menos 1 tile livre depois de
	# ocupar LAIR_SPAWN_CAP=5 deles pra patrulha ter pra onde ir.
	var lair_coord: Vector2i = Vector2i.ZERO
	var area: Array[Vector2i] = []
	var found_lair := false
	for candidate in hex_grid.lair_coords:
		var candidate_area = hex_grid._lair_area(candidate)
		if candidate_area.size() <= HexGrid.LAIR_SPAWN_CAP:
			continue
		var all_land := true
		for coord in candidate_area:
			var data = hex_grid.get_tile(coord)
			if data == null or data.blocks_land_units():
				all_land = false
				break
		if all_land:
			lair_coord = candidate
			area = candidate_area
			found_lair = true
			break
	assert_true(found_lair, "precondicao: deveria haver pelo menos um covil longe o bastante da borda pra este teste")
	var kind = hex_grid.lair_kind_by_coord[lair_coord]

	# Forca o covil pro teto de populacao manualmente (independente de
	# process_monster_lairs/RNG) — so pra isolar o comportamento de
	# _maybe_roam_lair.
	for coord in area:
		var existing = hex_grid.get_unit_at(coord)
		if existing != null:
			hex_grid.remove_unit(existing)
	for i in range(HexGrid.LAIR_SPAWN_CAP):
		hex_grid.spawn_monster_at(area[i], kind)

	var initial_coords := {}
	for coord in area:
		var unit = hex_grid.get_unit_at(coord)
		if unit != null:
			initial_coords[unit] = coord

	var repositioned := false
	for i in range(200):
		hex_grid._maybe_roam_lair(lair_coord)
		var count_now = hex_grid._count_live_monsters_near_lair(lair_coord)
		assert_eq(count_now, HexGrid.LAIR_SPAWN_CAP, "patrulha so deveria reposicionar, nunca mudar a populacao da area")
		for unit in initial_coords.keys():
			if unit.coord != initial_coords[unit]:
				repositioned = true
	assert_true(repositioned, "em 200 tentativas com ROAM_CHANCE=0.2, pelo menos um morador deveria ter sido reposicionado")

	for coord in area:
		var unit = hex_grid.get_unit_at(coord)
		if unit != null:
			assert_eq(unit.unit_data.visual_kind, kind, "morador patrulhado continua sendo o mesmo tipo do covil")

	hex_grid.queue_free()

## HexGrid.neutral_units()/clear_neutral_units() sao a fonte de verdade
## usada por SaveManager pra salvar/restaurar o mapa de monstros inteiro
## (ver test_save_manager.gd) — cobertura minima isolada do par aqui.
func test_neutral_units_and_clear_neutral_units():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(15, 15, 42)

	var coord = hex_grid.tiles.keys().filter(func(c): return not hex_grid.tiles[c].blocks_land_units())[0]
	var unit = hex_grid.spawn_monster_at(coord, "goblin")
	assert_true(unit in hex_grid.neutral_units())

	hex_grid.clear_neutral_units()
	assert_eq(hex_grid.neutral_units().size(), 0, "clear_neutral_units deveria remover TODO monstro neutro do mapa")
	assert_null(hex_grid.get_unit_at(coord))

	hex_grid.queue_free()

## Regra de fantasia (biomas): cada tipo so pode ser sorteado pro bioma
## certo (MonsterDatabase.KIND_DATA[kind].biomes) — LAVA so elegivel pra
## Vivern/Dragao, nunca Goblin/Troll/Esqueleto.
func test_random_kind_respects_biome_eligibility():
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for i in range(200):
		var kind = MonsterDatabase.random_kind(rng, 1.0, HexTileData.TerrainType.LAVA)
		assert_true(kind in ["wyvern", "dragon"], "LAVA deveria so sortear Vivern/Dragao, nao %s" % kind)

## Se o bioma tem um tipo elegivel (Esqueleto em DESERTO) mas a ameaca do
## local nao bate o min_threat dele, random_kind cai pro filtro so-por-
## ameaca (ignora bioma) em vez de travar sem candidato nenhum.
func test_random_kind_falls_back_when_biome_has_no_eligible_kind_at_threat():
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for i in range(50):
		var kind = MonsterDatabase.random_kind(rng, 0.0, HexTileData.TerrainType.DESERT)
		assert_eq(kind, "goblin", "sem tipo elegivel por bioma+ameaca ao mesmo tempo, deveria cair pro mais fraco (goblin)")

func test_dragon_lair_cap_is_one():
	assert_eq(MonsterDatabase.KIND_DATA["dragon"].lair_cap, 1, "Dragao deveria ser 'apenas 1 unidade por covil'")

## Dragao (boss raro) exige ameaca alta E bioma vulcanico ao mesmo tempo —
## nunca aparece so por estar em LAVA se a ameaca do local for baixa.
func test_dragon_requires_high_threat_and_lava_biome():
	var low_threat_rng := RandomNumberGenerator.new()
	low_threat_rng.seed = 77
	for i in range(200):
		var kind = MonsterDatabase.random_kind(low_threat_rng, 0.5, HexTileData.TerrainType.LAVA)
		assert_ne(kind, "dragon", "ameaca 0.5 (< min_threat 0.85) nunca deveria sortear Dragao")

	var high_threat_rng := RandomNumberGenerator.new()
	high_threat_rng.seed = 77
	var saw_dragon := false
	for i in range(200):
		if MonsterDatabase.random_kind(high_threat_rng, 1.0, HexTileData.TerrainType.LAVA) == "dragon":
			saw_dragon = true
			break
	assert_true(saw_dragon, "ameaca maxima em bioma LAVA deveria conseguir sortear Dragao em 200 tentativas")

## Esqueleto nasce em GRUPO (batch_spawn=3) quando o covil acerta o roll de
## reforco — a populacao da area deveria poder saltar de mais de 1 de uma
## vez, nao so trickle de 1 em 1 como o resto dos tipos.
func test_skeleton_reinforcement_can_spawn_more_than_one_at_once():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(41, 41, 111)
	assert_gt(hex_grid.lair_coords.size(), 0, "precondicao: deveria ter pelo menos um covil")

	# Forca um covil existente a virar Esqueleto (nao precisa ser o kind
	# sorteado naturalmente — so testa o mecanismo de batch, ja coberto por
	# outros testes o sorteio em si) e limpa a area pra ter espaco de sobra
	# pro grupo inteiro nascer de uma vez.
	var lair_coord: Vector2i = hex_grid.lair_coords[0]
	hex_grid.lair_kind_by_coord[lair_coord] = "skeleton"
	for coord in hex_grid._lair_area(lair_coord):
		var existing = hex_grid.get_unit_at(coord)
		if existing != null:
			hex_grid.remove_unit(existing)

	var saw_batch := false
	for i in range(500):
		var before = hex_grid._count_live_monsters_near_lair(lair_coord)
		if before >= hex_grid._lair_cap_for("skeleton"):
			break
		hex_grid.process_monster_lairs()
		var after = hex_grid._count_live_monsters_near_lair(lair_coord)
		if after - before > 1:
			saw_batch = true
			break
	assert_true(saw_batch, "Esqueleto deveria conseguir nascer em grupo (mais de 1 de uma vez) em 500 tentativas")

	hex_grid.queue_free()

## Covil como estrutura de terreno independente (LairStructure) — matar/
## afastar o chefao (is_camp_boss) NAO deveria mais apagar o covil do mapa
## nem cancelar o reforco, ao contrario do comportamento antigo em que a
## tenda vivia pendurada na propria Unit guardia (Unit._build_camp_marker,
## removido).
func test_lair_structure_and_reinforcement_survive_camp_boss_death():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(29, 29, 555)
	assert_gt(hex_grid.lair_coords.size(), 0, "precondicao: deveria ter pelo menos um covil")

	var lair_coord: Vector2i = hex_grid.lair_coords[0]
	var boss = hex_grid.get_unit_at(lair_coord)
	hex_grid.remove_unit(boss)

	assert_true(lair_coord in hex_grid.lair_coords, "covil deveria continuar ATIVO (reforco liberado) mesmo com o chefao morto")
	assert_true(hex_grid.lairs_by_coord.has(lair_coord), "estrutura visual do covil deveria continuar no tile mesmo com o chefao morto/afastado")

	hex_grid.queue_free()

## Pilhagem de Covil (pedido do usuario: "entrar no tile de um covil ativo
## sem defensores destroi o covil e concede um premio de ouro"). move_unit
## so e chamado com um dest que ja passou por compute_reachable — que
## exclui tile ocupado — entao "sem defensor" e garantido por construcao,
## nao precisa recriar aqui (ver HexGrid.move_unit).
func test_entering_empty_lair_destroys_it_and_grants_gold():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(29, 29, 555)
	var lair_coord: Vector2i = hex_grid.lair_coords[0]
	var kind: String = hex_grid.lair_kind_by_coord[lair_coord]
	var boss = hex_grid.get_unit_at(lair_coord)
	hex_grid.remove_unit(boss)

	var human := PlayerData.new(CivilizationData.new())
	var soldier = hex_grid.spawn_unit(lair_coord, UnitDatabase.create_unit("warrior"), human)

	hex_grid.move_unit(soldier, lair_coord, 1.0)

	assert_eq(human.gold, MonsterDatabase.lair_clear_reward(kind), "deveria conceder exatamente a recompensa de limpeza do tipo do covil")
	assert_false(lair_coord in hex_grid.lair_coords, "covil deveria sair de lair_coords pra sempre (reforco cancelado)")
	assert_false(hex_grid.lairs_by_coord.has(lair_coord), "estrutura visual deveria ser removida do mapa")

	hex_grid.queue_free()

## Regressao: um monstro (owner_player nulo, ex: Invasor marchando) nunca
## deveria destruir um covil so por passar pelo tile — a recompensa e "unidade
## MILITAR DE JOGADOR", nao qualquer movimento (ver HexGrid.move_unit).
func test_monster_movement_does_not_destroy_a_lair():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(29, 29, 555)
	var lair_coord: Vector2i = hex_grid.lair_coords[0]
	var boss = hex_grid.get_unit_at(lair_coord)
	hex_grid.remove_unit(boss)

	var wanderer = hex_grid.spawn_monster_at(lair_coord, "goblin") # reforco comum, owner_player nulo
	hex_grid.move_unit(wanderer, lair_coord, 0.0)

	assert_true(lair_coord in hex_grid.lair_coords, "movimento de monstro (owner_player nulo) nunca deveria destruir um covil")

	hex_grid.queue_free()

## Regressao: Colonizador (attack 0.0, nao e "unidade militar") entrando no
## tile vazio nao deveria limpar o covil nem conceder ouro.
func test_settler_entering_empty_lair_does_not_destroy_it():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(29, 29, 555)
	var lair_coord: Vector2i = hex_grid.lair_coords[0]
	var boss = hex_grid.get_unit_at(lair_coord)
	hex_grid.remove_unit(boss)

	var human := PlayerData.new(CivilizationData.new())
	var settler = hex_grid.spawn_unit(lair_coord, UnitDatabase.create_unit("settler"), human)
	hex_grid.move_unit(settler, lair_coord, 1.0)

	assert_true(lair_coord in hex_grid.lair_coords, "Colonizador (unidade nao militar, attack=0) nao deveria limpar covil")
	assert_eq(human.gold, 0.0)

	hex_grid.queue_free()

## Saque de Invasor sobre tile trabalhado: coberto em test_monster_ai.gd
## (test_invader_ending_turn_on_worked_tile_pillages_it/test_invader_does_
## not_repillage_an_already_pillaged_tile) — esse arquivo ja tem o harness
## certo (GameManager.players/human_player) que MonsterAI._nearest_city_
## coord/_hostile_in_attack_range precisam pra funcionar sem tocar estado
## global de outros testes.

	hex_grid.queue_free()
