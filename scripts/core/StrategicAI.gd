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
	var milestones := PublicVictoryMilestones.public_facts()
	for other in player.enemies:
		var ritual_threat := not V2StrategicAI.public_ritual_info_for(other).is_empty()
		# Fase 33D3: marco público (Exército Supremo / 2ª Manifestação) só desempata a escolha do alvo entre
		# inimigos JÁ em guerra — nenhum peso de guerra/paz muda.
		var milestone_threat := milestones.has(V2VictoryConditions.stable_id(other))
		for city in other.cities:
			if not player.known_enemy_cities.has(city.coord):
				continue
			var score := float(RivalAI._distance_to_nearest_own_city(player, city.coord))
			if ritual_threat:
				score -= 30.0
			elif milestone_threat:
				score -= 0.5
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
		gain -= grid.get_lair_danger_at(coord, player.explored_tiles) * 2.0 # Fase 33D1: só covis que a civ descobriu
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

## Fase 33D2 — execução da resposta a covil conhecido (V2StrategicAI.lair_response_plan). Só no modo
## "attack" e só para unidades de combate aptas perto do covil; guarnição necessária em guerra fica. Ataca a
## ESTRUTURA pela regra canônica (CombatResolver.can_attack_lair/resolve_lair_attack — a mesma do humano),
## enfrenta defensor visível do covil quando sobrevive ao golpe, ou avança por movimento normal (sem
## teleporte). true = consumiu o turno da unidade.
static func respond_to_lair(unit: Unit, player: PlayerData, grid: HexGrid) -> bool:
	if not V2StrategicAI.is_lair_responder(unit) or unit.movement_left <= 0.0:
		return false
	var view := V2AITacticalAI.view_for(player, grid)
	var plan := V2StrategicAI.lair_response_plan(player, view)
	if String(plan.mode) != "attack":
		return false
	var lair: Vector2i = plan.target
	if HexMetrics.axial_distance(unit.coord, lair) > V2StrategicAI.LAIR_FORCE_RADIUS or _is_needed_garrison(unit, player):
		return false
	var defender: Unit = null
	for enemy in view.visible_enemy_units:
		if not is_instance_valid(enemy) or enemy.owner_player != null or HexMetrics.axial_distance(enemy.coord, lair) > 1:
			continue
		if defender == null or HexMetrics.axial_distance(unit.coord, enemy.coord) < HexMetrics.axial_distance(unit.coord, defender.coord):
			defender = enemy
	if defender == null:
		if CombatResolver.can_attack_lair(unit, lair, grid):
			CombatResolver.resolve_lair_attack(unit, lair, grid)
			return true
	elif HexMetrics.axial_distance(unit.coord, defender.coord) <= unit.unit_data.attack_range:
		if CombatResolver.can_attack_unit(unit, defender, grid) and not bool(CombatResolver.predict(unit, defender, grid).attacker_dies):
			CombatResolver.resolve(unit, defender, grid)
		return true
	var goal := defender.coord if defender != null else lair
	if HexMetrics.axial_distance(unit.coord, goal) <= unit.unit_data.attack_range:
		return true # em posição; o covil ainda não pode ser atacado (defensor fora da vista) — segura
	var approach := _approach_tile(unit, goal, grid)
	RivalAI.move_unit_toward(unit, grid, approach if approach != HexGrid.NO_LAIR else goal)
	return true

## Fase 33D3 — execução do plano do Relicário (V2StrategicAI.reliquary_plan): só as unidades escolhidas; durante
## a preparação, aproximam-se do local; ativo, enfrentam guardião visível que não as mata e ocupam o tile do
## Relicário (movimento normal, sem teleporte); em cima dele, seguram a posição. true = consumiu o turno.
static func respond_to_reliquary(unit: Unit, player: PlayerData, grid: HexGrid) -> bool:
	if not V2StrategicAI.is_lair_responder(unit) or unit.movement_left <= 0.0:
		return false
	var view := V2AITacticalAI.view_for(player, grid)
	var plan := V2StrategicAI.reliquary_plan(player, view)
	if String(plan.mode) != "go" or not unit in plan.units:
		return false
	var site: Vector2i = plan.site
	if unit.coord == site:
		return true
	var guardian: Unit = null
	for enemy in view.visible_enemy_units:
		if is_instance_valid(enemy) and enemy.owner_player == null and HexMetrics.axial_distance(enemy.coord, site) <= 1:
			if guardian == null or HexMetrics.axial_distance(unit.coord, enemy.coord) < HexMetrics.axial_distance(unit.coord, guardian.coord):
				guardian = enemy
	if guardian != null and HexMetrics.axial_distance(unit.coord, guardian.coord) <= unit.unit_data.attack_range:
		if CombatResolver.can_attack_unit(unit, guardian, grid) and not bool(CombatResolver.predict(unit, guardian, grid).attacker_dies):
			CombatResolver.resolve(unit, guardian, grid)
		return true
	if grid.get_unit_at(site) == null:
		RivalAI.move_unit_toward(unit, grid, site)
	else:
		var approach := _approach_tile(unit, site, grid)
		RivalAI.move_unit_toward(unit, grid, approach if approach != HexGrid.NO_LAIR else site)
	return true

## Em guerra, a última unidade de combate a até CityDefense.GARRISON_RADIUS de uma cidade própria fica.
static func _is_needed_garrison(unit: Unit, player: PlayerData) -> bool:
	if player.enemies.is_empty():
		return false
	for city in player.cities:
		if HexMetrics.axial_distance(unit.coord, city.coord) > CityDefense.GARRISON_RADIUS:
			continue
		var others := 0
		for ally in player.units:
			if ally != unit and V2StrategicAI.is_lair_responder(ally) and HexMetrics.axial_distance(ally.coord, city.coord) <= CityDefense.GARRISON_RADIUS:
				others += 1
		if others == 0:
			return true
	return false

## Vizinho livre de `goal` mais próximo da unidade (o tile do covil/defensor em si não é destino).
static func _approach_tile(unit: Unit, goal: Vector2i, grid: HexGrid) -> Vector2i:
	var best := HexGrid.NO_LAIR
	var best_distance := 999999
	for neighbor in grid.get_neighbors(goal):
		var tile := grid.get_tile(neighbor)
		if tile == null or (tile.blocks_land_units() and not unit.unit_data.flies) or grid.lairs_by_coord.has(neighbor) or grid.get_city_at(neighbor) != null:
			continue
		var occupant := grid.get_unit_at(neighbor)
		if occupant != null and occupant != unit:
			continue
		var distance := HexMetrics.axial_distance(unit.coord, neighbor)
		if distance < best_distance or (distance == best_distance and (neighbor.x < best.x or (neighbor.x == best.x and neighbor.y < best.y))):
			best_distance = distance
			best = neighbor
	return best
