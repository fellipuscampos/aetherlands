class_name StrategicAI
extends RefCounted

## Heurísticas adicionais sobre os mesmos custos, requisitos e ações do jogador.
static func strategy(player: PlayerData) -> String:
	var best := CityIdentity.AXIS_MILITAR
	var score := -1.0
	for axis in [CityIdentity.AXIS_MILITAR, CityIdentity.AXIS_ARCANA, CityIdentity.AXIS_COMERCIAL, CityIdentity.AXIS_INDUSTRIAL]:
		var value := float(player.personality.get(axis, 0.0))
		if value > score:
			score = value
			best = axis
	return best

static func production_score(player: PlayerData, city: City, id: String, grid: HexGrid) -> float:
	var magic_score := MagicAI.production_score(player, city, id)
	var building := BuildingDatabase.get_building(id)
	if building:
		var value := 0.0
		var yields := city.collect_yields(grid)
		if building.bonus_food > 0 and yields.food <= city.population + 2:
			value += 2.0
		if building.bonus_production > 0:
			value += 1.0
		if building.bonus_mana > 0 and player.mana_income_per_turn < player.cities.size() * 3:
			value += 1.5
		if building.bonus_gold > 0 and player.gold < 80:
			value += 0.8
		if building.trains_unit != "":
			for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
				var trainer := BuildingDatabase.building_that_trains(kind)
				if trainer == building and player.has_unlocked(kind):
					value += 1.5
					break
		return value + magic_score
	var data := UnitDatabase.create_unit(id)
	var same_kind := player.units.filter(func(u): return u.unit_data.visual_kind == id).size()
	if data.attack == 0.0:
		return 1.0 if same_kind == 0 and player.units.size() >= 4 else -10.0
	if id in ["scout", "batedor_montado"]:
		return 2.0 if same_kind == 0 else -2.0
	var military_count := player.units.filter(func(u): return u.unit_data.attack > 0).size()
	var army_target := maxi(6, player.cities.size() * (5 if not player.enemies.is_empty() else 3))
	if military_count >= army_target and data.magic_school == "":
		return -8.0
	var need := 2.0 if military_count < maxi(3, player.cities.size() * 2) else -1.0
	var strength := (data.attack + data.defense + data.max_hp * 0.15) / maxf(data.production_cost, 1.0)
	return need + strength + data.attack * 0.08 - same_kind * 0.08 + magic_score

static func research_score(player: PlayerData, tech: TechData) -> float:
	var magic := MagicDatabase.get_tech(tech.id) != null
	var preference := strategy(player)
	var score := 0.0
	# A escola não substitui comida, oficinas e a infantaria de escolta.
	# Reserva uma base material e mantém perfis mágicos/mundanos distintos.
	var desired_techs := maxi(4, player.researched_magic.size() / 2) if preference == CityIdentity.AXIS_ARCANA else maxi(4, player.researched_magic.size() * 2)
	if not magic and player.researched_techs.size() < desired_techs:
		score += 3.0
		if tech.id in ["quartel", "celeiro", "oficina", "homem_de_armas"]:
			score += 0.4
	if magic:
		score += 1.1 if preference == CityIdentity.AXIS_ARCANA else 0.15
		if player.researched_magic.is_empty() and player.researched_techs.size() >= 5:
			score += 1.5
		if tech.unlocks_spell != "":
			score += 0.5
	else:
		if TechDatabase._researched_count_in_tier(tech.tier, player.researched_techs) < TechDatabase.TIER_UNLOCK_THRESHOLD:
			score += 0.6
	if tech.unlocks_unit != "":
		var trainer := BuildingDatabase.building_that_trains(tech.unlocks_unit)
		if trainer and not player.cities.any(func(c): return c.buildings.has(trainer.id)):
			score -= 0.8
	if tech.unlocks_building != "":
		var building := BuildingDatabase.get_building(tech.unlocks_building)
		if building and building.trains_unit != "" and player.has_unlocked(building.trains_unit):
			score += 1.0
	# Pequena preferência por descobertas próximas; não ignora o late game.
	return score + MagicAI.research_score(player, tech) + 0.2 / maxf(tech.cost / 30.0, 1.0)

static func choose_opponent(player: PlayerData, grid: HexGrid, fallback: PlayerData) -> PlayerData:
	var result := fallback
	var best := INF
	for other in player.enemies:
		for city in other.cities:
			if not player.known_enemy_cities.has(city.coord):
				continue
			var score := float(RivalAI._distance_to_nearest_own_city(player, city.coord))
			if other.arcane_ritual_active or other.territorial_streak > 0 or VictoryCampaign.supremacy_threat(other, GameManager.players) or MagicAI.public_threat_target(other, player, grid) != MagicRuntime.INVALID:
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

static func move_support(unit: Unit, player: PlayerData, grid: HexGrid) -> void:
	if unit.unit_data.visual_kind == "mercador":
		for coord in player.known_enemy_cities:
			var city := grid.get_city_at(coord)
			if city and city.owner_player != player and not player.is_at_war_with(city.owner_player) and TradeManager.active_route_count(city) < city.max_trade_routes(grid):
				RivalAI.move_unit_toward(unit, grid, coord)
				return
	else:
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

static func cast_spells(player: PlayerData, grid: HexGrid) -> void:
	MagicAI.take_turn(player, grid)
	var visible := grid.compute_visible_tiles(player)
	for spell_name in MagicDatabase.unlocked_spells_for(player.researched_magic):
		if not SpellManager.is_castable(player, spell_name, TurnManager.turn_number, grid):
			continue
		var spell := SpellDatabase.get_spell(spell_name)
		if spell.effect != "":
			continue
		var target: Unit = null
		var best := 0.0
		for unit in grid.units_by_coord.values():
			var value := 0.0
			if spell.damage > 0 and visible.has(unit.coord) and unit.owner_player != player and (unit.owner_player == null or player.is_at_war_with(unit.owner_player)):
				value = minf(spell.damage, unit.hp) + (5.0 if unit.hp <= spell.damage else 0.0)
				if spell.damage_area_radius > 0:
					for near in grid.get_neighbors(unit.coord):
						var neighbor := grid.get_unit_at(near)
						if neighbor and neighbor.owner_player == player:
							value -= spell.damage
			elif spell.heal_fraction > 0 and unit.owner_player == player:
				value = unit.unit_data.max_hp - unit.hp
			elif spell.transforms_terrain and unit.owner_player == player and grid.city_owning_tile(unit.coord) != null:
				var tech := MagicDatabase.tech_that_unlocks_spell(spell_name)
				if grid.get_tile(unit.coord).terrain_type in tech.terrain_transform.get("from", []):
					value = 5.0
			if value > best:
				best = value
				target = unit
		if target:
			var message := SpellManager.cast(player, spell_name, target, grid, TurnManager.turn_number)
			if visible.has(target.coord) and grid.visibility.get(target.coord, 0) == HexGrid.Visibility.VISIBLE:
				EventBus.notify.emit("%s: %s" % [player.civ.civ_name, message], "combat")
