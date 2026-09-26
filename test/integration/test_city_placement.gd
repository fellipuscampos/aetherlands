extends GutTest

## Task 22 -- EXPANSAO E FUNDACAO DE CIDADES: harness de metricas de
## posicionamento (varias seeds/tamanhos de mapa, IA contra IA) + regressoes
## estruturais (CitySite). Espelha test_simulation_balance.gd (mesmo mundo
## gerado, mesmas capitais, GameManager._on_turn_changed real), so' que mede
## ONDE as cidades sao fundadas em vez de economia/guerra.
##
## Metricas (ver _aggregate): distancia minima/media entre cidades da mesma
## civ, pares "apertados", cidades isoladas, recursos/Nodulos no territorio,
## sobreposicao (territorio desperdicado), sobrevivencia de cidades distantes
## e frequencia de locais objetivamente ruins (medidos com uma regua
## INDEPENDENTE da pontuacao da IA, ver _objective_quality).
##
## `legacy` reproduz a politica ANTIGA (distancia 3 + "vizinhos com recurso",
## ver _legacy_handle_settler) so' pra comparar antes/depois; o jogo real
## nunca usa isso.

const RIVAL_COUNT := 3
const RIVAL_RACES := ["elf", "dwarf", "orc"]
const AI_SEED_BASE := 7100

var _original_hex_grid: HexGrid
var _original_human_player: PlayerData
var _original_rival_players: Array[PlayerData]
var _original_players: Array[PlayerData]
var _original_state
var _original_stagger: bool
var _original_debug_mode: bool
var _original_turn_number: int
var _original_player_count: int
var _original_min_distance: int

func before_each():
	_original_hex_grid = GameManager.hex_grid
	_original_human_player = GameManager.human_player
	_original_rival_players = GameManager.rival_players
	_original_players = GameManager.players
	_original_state = GameManager.state
	_original_stagger = GameManager.stagger_ai_turns
	_original_debug_mode = GameManager.debug_mode
	_original_turn_number = TurnManager.turn_number
	_original_player_count = TurnManager.player_count
	_original_min_distance = CitySite.min_city_distance

func after_each():
	GameManager.hex_grid = _original_hex_grid
	GameManager.human_player = _original_human_player
	GameManager.rival_players = _original_rival_players
	GameManager.players = _original_players
	GameManager.state = _original_state
	GameManager.stagger_ai_turns = _original_stagger
	GameManager.debug_mode = _original_debug_mode
	GameManager.is_turn_processing = false
	TurnManager.turn_number = _original_turn_number
	TurnManager.player_count = _original_player_count
	CitySite.min_city_distance = _original_min_distance

# ---------------------------------------------------------------------------
# Harness de simulacao
# ---------------------------------------------------------------------------

func _make_player(civ_name: String, race: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = civ_name
	civ.leader_name = civ_name
	civ.race = race
	return PlayerData.new(civ)

## Roda `turns` turnos de IA-contra-IA (4 civs) e devolve as metricas de UMA
## partida. `legacy`: politica antiga de assentamento (ver cabecalho).
func _simulate(seed_value: int, map_size: int, turns: int, legacy: bool = false, keep_grid: bool = false, min_distance: int = 0) -> Dictionary:
	CitySite.min_city_distance = min_distance if min_distance > 0 else (3 if legacy else _original_min_distance)
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(map_size, map_size, seed_value)

	var primary := _make_player("Principal", "human")
	var rivals: Array[PlayerData] = []
	for i in range(RIVAL_COUNT):
		rivals.append(_make_player("Rival %d" % (i + 1), RIVAL_RACES[i % RIVAL_RACES.size()]))
	# Fase 25: a IA V2 (mesma inicialização de GameManager.setup_players) substitui a personalidade V1.
	V2StrategicAI.initialize_player(primary, rivals.size(), grid.map_seed, rivals.size() + 1)
	for i in range(rivals.size()):
		V2StrategicAI.initialize_player(rivals[i], i, grid.map_seed, rivals.size() + 1)

	var players: Array[PlayerData] = [primary]
	players.append_array(rivals)
	var claimed: Array[Vector2i] = []
	_spawn_capital(grid, primary, Vector2i(0, 0), claimed)
	var half := float(map_size) / 2.0
	for i in range(rivals.size()):
		var angle := TAU * float(i) / float(rivals.size())
		var origin := Vector2i(int(round(cos(angle) * half * 0.6)), int(round(sin(angle) * half * 0.6)))
		_spawn_capital(grid, rivals[i], origin, claimed)

	GameManager.hex_grid = grid
	GameManager.human_player = primary
	GameManager.rival_players = rivals
	GameManager.players = players
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.stagger_ai_turns = true # a fila do GameManager e' drenada abaixo, pra poder trocar so' a politica de colonizador
	GameManager.debug_mode = false
	TurnManager.turn_number = 1
	TurnManager.player_count = 1
	seed(AI_SEED_BASE + seed_value)

	var founded: Array = [] # {owner, coord, turn, ...}
	var known_cities := {}
	for coord in grid.cities_by_coord.keys():
		known_cities[coord] = true
		founded.append(_founding_record(grid, grid.cities_by_coord[coord], 0, players, true))
	var settle_ticks := 0

	for turn_index in range(turns):
		V2StrategicAI.plan_turn(primary, grid)
		GameManager._on_turn_changed(TurnManager.turn_number, 0)
		# Drena a fila de IA do GameManager (rivais + monstros), trocando so' o
		# tratamento dos colonizadores no modo legacy.
		while not GameManager._ai_turn_queue.is_empty():
			var item: Dictionary = GameManager._ai_turn_queue.pop_front()
			var unit: Unit = item.unit
			if not is_instance_valid(unit):
				continue
			if item.kind == "rival":
				if legacy and unit.unit_data.can_found_city:
					_legacy_handle_settler(unit, grid, item.player)
				else:
					RivalAI.act_for_unit(unit, grid, item.player, item.opponent, item.visible)
			else:
				MonsterAI.act_for_unit(unit, grid, item.turn)
		if GameManager.is_turn_processing:
			GameManager.is_turn_processing = false
			GameManager._finish_turn()
		# Turno do "primary" (100% IA neste harness).
		var visible := RivalAI.begin_turn(primary, grid, rivals[0])
		for unit in primary.units.duplicate():
			if not is_instance_valid(unit):
				continue
			if legacy and unit.unit_data.can_found_city:
				if unit.movement_left > 0.0 and unit.hp > 0.0:
					_legacy_handle_settler(unit, grid, primary)
			else:
				RivalAI.act_for_unit(unit, grid, primary, rivals[0], visible)
		for coord in grid.cities_by_coord.keys():
			if not known_cities.has(coord):
				known_cities[coord] = true
				founded.append(_founding_record(grid, grid.cities_by_coord[coord], TurnManager.turn_number, players, false))
		if GameManager.state == GameManager.GameState.GAME_OVER:
			break
		TurnManager.turn_number += 1

	var result := _measure(grid, players, founded)
	result["seed"] = seed_value
	result["map_size"] = map_size
	result["turns"] = turns
	result["founded"] = founded
	if keep_grid:
		result["grid"] = grid
		result["players"] = players
	else:
		for player in players:
			player.release_relations()
		grid.free()
	GameManager.hex_grid = null
	return result

func _spawn_capital(grid: HexGrid, player: PlayerData, origin: Vector2i, claimed: Array[Vector2i]) -> void:
	var start := WorldSetup.find_start_tile(grid, origin, claimed)
	claimed.append(start)
	grid.found_city(start, player, player.civ.civ_name + " - Capital")
	var guard := WorldSetup.find_spawn_tile(grid, start)
	grid.spawn_unit(guard, UnitDatabase.create_unit("warrior"), player)

## Politica ANTIGA (pre-Task 22), copiada do RivalAI/StrategicAI de entao:
## distancia minima 3 (aplicada via CitySite.min_city_distance = 3), varre o
## mapa explorado inteiro com penalidade de so' 0.15/tile pela distancia, e
## pontua so' "vizinhos imediatos com recurso" + rendimento dos vizinhos.
func _legacy_handle_settler(unit: Unit, grid: HexGrid, player: PlayerData) -> void:
	if _legacy_settle_toward_resources(unit, player, grid):
		return
	if grid.get_city_at(unit.coord) == null and _legacy_far_enough(unit.coord, grid):
		WorldSetup.found_city_from_settler(grid, unit)
		return
	var reachable := grid.compute_reachable(unit.coord, unit.movement_left, unit.owner_player)
	if reachable.size() > 0:
		var best_coord = null
		var best_score := -INF
		for candidate in reachable.keys():
			var score := _legacy_score(candidate, grid, player)
			if score > best_score:
				best_score = score
				best_coord = candidate
		grid.move_unit(unit, best_coord, reachable[best_coord])

func _legacy_far_enough(coord: Vector2i, grid: HexGrid) -> bool:
	for city in grid.cities_by_coord.values():
		if HexMetrics.axial_distance(coord, city.coord) < 3:
			return false
	return true

func _legacy_score(coord: Vector2i, grid: HexGrid, player: PlayerData) -> float:
	var score := 0.0
	for n in grid.get_neighbors(coord):
		var data: HexTileData = grid.get_tile(n)
		if data and data.resource != "":
			score += 1.0
	if grid.is_under_rival_pressure(coord, player):
		score -= 2.0
	score -= grid.get_lair_danger_at(coord) * 3.0
	return score

func _legacy_settle_toward_resources(unit: Unit, player: PlayerData, grid: HexGrid) -> bool:
	if player.cities.size() < 2 or player.explored_tiles.is_empty():
		return false
	var candidates: Array = []
	for coord in player.explored_tiles:
		var tile := grid.get_tile(coord)
		if tile == null or tile.blocks_land_units() or not _legacy_far_enough(coord, grid):
			continue
		if grid.get_unit_at(coord) != null and coord != unit.coord:
			continue
		var score := _legacy_score(coord, grid, player) - HexMetrics.axial_distance(unit.coord, coord) * 0.15
		for near in grid.get_neighbors(coord):
			if not player.explored_tiles.has(near):
				continue
			var land := grid.get_tile(near)
			score += land.food_yield * 0.4 + land.production_yield * 0.3
			if land.resource == "mana_node" and grid.city_owning_tile(near) == null:
				score += 12.0 if player.v2_ai_strategy.orientation == V2AIStrategyState.Orientation.ARCANE else 5.0
		candidates.append({"coord": coord, "score": score})
	candidates.sort_custom(func(a, b): return a.score > b.score)
	for candidate in candidates.slice(0, 8):
		if candidate.coord == unit.coord:
			WorldSetup.found_city_from_settler(grid, unit)
			return true
		if not grid.compute_path(unit.coord, candidate.coord, player).is_empty():
			RivalAI.move_unit_toward(unit, grid, candidate.coord)
			return true
	return false

# --- Medicao -----------------------------------------------------------------

## Regua INDEPENDENTE da pontuacao da IA: o que o local realmente oferece
## num raio 2, ignorando posse/coesao (nao da' pra "otimizar pro proprio
## teste"). Devolve tiles trabalhaveis, pontos de rendimento bruto, recursos,
## Nodulos, terreno do centro e perigo de covil.
func _objective_quality(grid: HexGrid, coord: Vector2i) -> Dictionary:
	var workable := 0
	var points := 0.0
	var resources := 0
	var nodes := 0
	for tile_coord in grid.tiles_in_range(coord, 2):
		var data: HexTileData = grid.get_tile(tile_coord)
		if data == null or not data.is_usable_land():
			continue
		workable += 1
		points += CitySite.tile_points(data)
		if data.resource != "":
			resources += 1
			if data.resource == "mana_node":
				nodes += 1
	var center: HexTileData = grid.get_tile(coord)
	return {
		"workable": workable, "points": points, "resources": resources, "nodes": nodes,
		"center_terrain": center.terrain_type if center else -1,
		"lair_danger": grid.get_lair_danger_at(coord),
	}

const BAD_SITE_MIN_WORKABLE := 8
const BAD_SITE_MIN_POINTS := 5.0
const BAD_SITE_LAIR_DANGER := 0.15

func _is_bad_site(quality: Dictionary) -> bool:
	return quality.workable < BAD_SITE_MIN_WORKABLE or quality.points < BAD_SITE_MIN_POINTS or quality.lair_danger >= BAD_SITE_LAIR_DANGER

func _founding_record(grid: HexGrid, city: City, turn: int, players: Array[PlayerData], is_capital: bool) -> Dictionary:
	var owner_index := players.find(city.owner_player)
	var nearest_own := 999
	var nearest_any := 999
	for other in grid.cities_by_coord.values():
		if other == city:
			continue
		var distance := HexMetrics.axial_distance(city.coord, other.coord)
		nearest_any = mini(nearest_any, distance)
		if other.owner_player == city.owner_player:
			nearest_own = mini(nearest_own, distance)
	return {
		"owner": owner_index, "coord": city.coord, "turn": turn, "capital": is_capital,
		"nearest_own": nearest_own, "nearest_any": nearest_any,
		"quality": _objective_quality(grid, city.coord),
	}

func _measure(grid: HexGrid, players: Array[PlayerData], founded: Array) -> Dictionary:
	var settled: Array = founded.filter(func(r): return not r.capital)
	var alive_settled := 0
	var distant := 0
	var distant_alive := 0
	var bad := 0
	var bad_workable := 0
	var bad_points := 0
	var bad_lair := 0
	var too_close_at_founding := 0
	var isolated_at_founding := 0
	var node_cities := 0
	var resources_sum := 0
	var points_sum := 0.0
	for record in settled:
		var alive := grid.get_city_at(record.coord) != null
		if alive:
			alive_settled += 1
		if record.nearest_own > 8 and record.nearest_own < 999:
			distant += 1
			if alive:
				distant_alive += 1
		if record.nearest_own < CitySite.IDEAL_SPACING_MIN:
			too_close_at_founding += 1
		if record.nearest_own > 10 and record.nearest_own < 999:
			isolated_at_founding += 1
		if _is_bad_site(record.quality):
			bad += 1
			if record.quality.workable < BAD_SITE_MIN_WORKABLE:
				bad_workable += 1
			if record.quality.points < BAD_SITE_MIN_POINTS:
				bad_points += 1
			if record.quality.lair_danger >= BAD_SITE_LAIR_DANGER:
				bad_lair += 1
		if record.quality.nodes > 0:
			node_cities += 1
		resources_sum += record.quality.resources
		points_sum += record.quality.points

	# Metricas de estado final por civ (cidades vivas, qualquer origem).
	var min_pair := 999
	var same_owner_min := 999
	var nn_sum := 0.0
	var nn_count := 0
	var nn_max := 0
	var overlap_num := 0.0
	var overlap_den := 0.0
	var cities_total := 0
	var isolated_final := 0
	var civ_city_counts: Array[int] = []
	# Acesso REAL a recursos: tiles de recurso distintos dentro do territorio de
	# alguma cidade da civ (o que a civ controla de fato, sem contar duas vezes
	# o mesmo tile so' porque duas cidades sobrepostas o enxergam).
	var owned_resources := 0
	var owned_nodes := 0
	for player in players:
		var seen_tiles := {}
		for city in player.cities:
			for owned in city.owned_tiles:
				if seen_tiles.has(owned):
					continue
				seen_tiles[owned] = true
				var owned_data: HexTileData = grid.get_tile(owned)
				if owned_data != null and owned_data.resource != "":
					owned_resources += 1
					if owned_data.resource == "mana_node":
						owned_nodes += 1
	# Capitais sao posicionadas pela geracao do mapa (WorldSetup.find_start_tile,
	# nao pela regra de fundacao): par capital-capital fica fora das metricas de
	# distancia -- em mapas pequenos duas capitais podem nascer coladas.
	var capital_coords := {}
	for record in founded:
		if record.capital:
			capital_coords[record.coord] = true
	for player in players:
		civ_city_counts.append(player.cities.size())
		cities_total += player.cities.size()
		var cities: Array[City] = player.cities
		for city in cities:
			var nearest_same := 999
			for other in grid.cities_by_coord.values():
				if other == city or (capital_coords.has(city.coord) and capital_coords.has(other.coord)):
					continue
				var distance := HexMetrics.axial_distance(city.coord, other.coord)
				min_pair = mini(min_pair, distance)
				if other.owner_player == player:
					nearest_same = mini(nearest_same, distance)
					same_owner_min = mini(same_owner_min, distance)
			if cities.size() >= 2 and nearest_same < 999:
				nn_sum += nearest_same
				nn_count += 1
				nn_max = maxi(nn_max, nearest_same)
				if nearest_same > 10:
					isolated_final += 1
			# Sobreposicao: tiles do raio 2 desta cidade que tambem caem no raio 2 de outra cidade da MESMA civ.
			for tile_coord in grid.tiles_in_range(city.coord, 2):
				overlap_den += 1.0
				for other_city in cities:
					if other_city != city and HexMetrics.axial_distance(tile_coord, other_city.coord) <= 2:
						overlap_num += 1.0
						break
	return {
		"settled": settled.size(), "alive_settled": alive_settled,
		"distant": distant, "distant_alive": distant_alive,
		"bad": bad, "bad_workable": bad_workable, "bad_points": bad_points, "bad_lair": bad_lair, "too_close_at_founding": too_close_at_founding, "isolated_at_founding": isolated_at_founding,
		"node_cities": node_cities,
		"avg_resources": resources_sum / maxf(float(settled.size()), 1.0),
		"avg_points": points_sum / maxf(float(settled.size()), 1.0),
		"min_pair": min_pair, "same_owner_min": same_owner_min,
		"avg_nearest_same": nn_sum / maxf(float(nn_count), 1.0), "max_nearest_same": nn_max,
		"overlap": overlap_num / maxf(overlap_den, 1.0),
		"cities_total": cities_total, "isolated_final": isolated_final,
		"owned_resources": owned_resources, "owned_nodes": owned_nodes,
		"civ_city_counts": civ_city_counts,
	}

func _aggregate(label: String, runs: Array) -> void:
	var n := float(runs.size())
	var sums := {}
	for key in ["settled", "alive_settled", "distant", "distant_alive", "bad", "too_close_at_founding", "isolated_at_founding", "bad_workable", "bad_points", "bad_lair", "node_cities", "avg_resources", "avg_points", "avg_nearest_same", "overlap", "cities_total", "isolated_final", "owned_resources", "owned_nodes"]:
		var total := 0.0
		for run in runs:
			total += float(run[key])
		sums[key] = total
	var min_pair := 999
	var min_same := 999
	var max_nn := 0
	for run in runs:
		min_pair = mini(min_pair, run.min_pair)
		min_same = mini(min_same, run.same_owner_min)
		max_nn = maxi(max_nn, run.max_nearest_same)
	var settled: float = maxf(sums.settled, 1.0)
	print("[Task22] %-28s runs=%d | cidades/partida=%.1f (fundadas=%.1f, vivas=%.1f) | dist.min(qualquer)=%d, dist.min(mesma civ)=%d, dist.media_vizinha=%.2f, max=%d | apertadas(<%d)=%.0f%% | isoladas(>10)=%.0f%% (final: %.1f/partida) | distantes(>8)=%.1f/partida sobrev=%.0f%% | ruins=%.0f%% (agua/poucos tiles=%.0f%%, pobres=%.0f%%, covil=%.0f%%) | recursos/cidade=%.1f, pts/cidade=%.1f, cidades c/ Nodulo=%.0f%% | sobreposicao=%.1f%% | controlados/partida: recursos=%.1f, Nodulos=%.1f" % [
		label, runs.size(), sums.cities_total / n, sums.settled / n, sums.alive_settled / n, min_pair, min_same,
		sums.avg_nearest_same / n, max_nn, CitySite.IDEAL_SPACING_MIN, 100.0 * sums.too_close_at_founding / settled,
		100.0 * sums.isolated_at_founding / settled, sums.isolated_final / n, sums.distant / n,
		100.0 * sums.distant_alive / maxf(sums.distant, 1.0), 100.0 * sums.bad / settled,
		100.0 * sums.bad_workable / settled, 100.0 * sums.bad_points / settled, 100.0 * sums.bad_lair / settled,
		sums.avg_resources / n, sums.avg_points / n, 100.0 * sums.node_cities / settled, 100.0 * sums.overlap / n,
		sums.owned_resources / n, sums.owned_nodes / n])

# ---------------------------------------------------------------------------
# Simulacao como teste (rapida -- o experimento completo vive no script descartavel)
# ---------------------------------------------------------------------------

const SEEDS_FAST := [2201, 2202, 2203]

func test_simulated_placement_respects_the_rule_and_avoids_bad_sites():
	var runs: Array = []
	for seed_value in SEEDS_FAST:
		runs.append(_simulate(seed_value, 41, 90))
	_aggregate("novo (rapido)", runs)
	for run in runs:
		assert_gte(run.same_owner_min, CitySite.min_city_distance, "seed %d: cidades da mesma civ mais perto que o minimo" % run.seed)
		assert_gte(run.min_pair, CitySite.min_city_distance, "seed %d: cidades de civs diferentes mais perto que o minimo" % run.seed)
		assert_gt(run.settled, 0, "seed %d: ninguem fundou cidade nenhuma em 90 turnos" % run.seed)
		assert_lte(run.too_close_at_founding, maxi(1, run.settled / 4), "seed %d: cidades demais apertadas alem do espacamento ideal" % run.seed)
		assert_lte(run.isolated_at_founding, maxi(1, run.settled / 10), "seed %d: enclaves demais longe do imperio" % run.seed)
		assert_lte(run.bad, maxi(1, run.settled / 5), "seed %d: locais objetivamente ruins demais" % run.seed)
