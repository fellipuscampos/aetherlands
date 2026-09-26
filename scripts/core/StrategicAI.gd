class_name StrategicAI
extends RefCounted

## Helpers táticos COMPARTILHADOS da execução no mapa da IA rival (chamados por RivalAI.act_for_unit/
## _handle_attacker/_handle_settler): escolher contra quem avançar, engajar monstro vizinho, explorar e
## acompanhar tropas. Fase 25: a estratégia/produção/pesquisa/feitiços V1 que moravam aqui saíram — a
## estratégia é de V2StrategicAI e a magia de V2AITacticalAI.

## Entre os inimigos em guerra, prioriza a cidade conhecida mais próxima; quem canaliza um Ritual Final
## PÚBLICO (V2TranscendenceSystem) vira alvo preferido — mesma informação pública que V2AIWorldView e
## RivalAI.decide_war já usam, nenhum dado oculto.
static func choose_opponent(player: PlayerData, grid: HexGrid, fallback: PlayerData) -> PlayerData:
	var result := fallback
	var best := INF
	for other in player.enemies:
		var ritual_threat := not V2StrategicAI.public_ritual_info_for(other).is_empty()
		for city in other.cities:
			if not player.known_enemy_cities.has(city.coord):
				continue
			var score := float(RivalAI._distance_to_nearest_own_city(player, city.coord))
			if ritual_threat:
				score -= 30.0
			if score < best:
				best = score
				result = other
	return result

static func engage_nearby_monster(unit: Unit, player: PlayerData, grid: HexGrid, visible: Dictionary) -> bool:
	for coord in grid.tiles_in_range(unit.coord, unit.unit_data.attack_range):
		var monster := grid.get_unit_at(coord)
		if monster == null or monster.owner_player != null or not visible.has(coord):
			continue
		if RivalAI.is_favorable_attack(unit, monster, grid):
			CombatResolver.resolve(unit, monster, grid)
			return true
	return false

static func explore(unit: Unit, player: PlayerData, grid: HexGrid) -> void:
	if unit.fortified or unit.movement_left <= 0.0:
		return
	var best = null
	var score := -INF
	for coord in grid.compute_reachable(unit.coord, unit.movement_left, player, unit.unit_data.flies):
		var gain := 0.0
		for near in grid.tiles_in_range(coord, unit.unit_data.vision_range):
			if not player.explored_tiles.has(near):
				gain += 1.0
		gain -= grid.get_lair_danger_at(coord) * 2.0
		if gain > score and gain > 0.0:
			score = gain
			best = coord
	if best != null:
		RivalAI.move_unit_toward(unit, grid, best)
		return
	# Uma fronteira conhecida mantém o explorador em movimento após explorar
	# toda a vizinhança. Nunca consulta recursos de território desconhecido.
	var frontier: Array = []
	for coord in player.explored_tiles:
		var tile := grid.get_tile(coord)
		if tile == null or tile.blocks_land_units():
			continue
		for near in grid.get_neighbors(coord):
			if not player.explored_tiles.has(near):
				frontier.append(coord)
				break
	frontier.sort_custom(func(a, b): return HexMetrics.axial_distance(unit.coord, a) < HexMetrics.axial_distance(unit.coord, b))
	for coord in frontier.slice(0, 6):
		if not grid.compute_path(unit.coord, coord, player, unit.unit_data.flies).is_empty():
			RivalAI.move_unit_toward(unit, grid, coord)
			return

## Unidade sem ataque (conjurador sem ação especial neste turno, Construtor sem melhoria a fazer...)
## acompanha a tropa aliada mais forte por perto em vez de ficar isolada.
static func move_support(unit: Unit, player: PlayerData, grid: HexGrid) -> void:
	var best: Unit = null
	var score := -INF
	for ally in player.units:
		if ally.unit_data.attack <= 0.0:
			continue
		var value := ally.unit_data.attack - HexMetrics.axial_distance(unit.coord, ally.coord) * 0.2
		if value > score:
			score = value
			best = ally
	if best and HexMetrics.axial_distance(best.coord, unit.coord) > 1:
		RivalAI.move_unit_toward(unit, grid, best.coord)
