class_name V2ManifestationOrders
extends RefCounted

## Persistent strategic commands; one decision/action per owner round, never per frame.
## Target identities are serial IDs/coordinates, so saves contain no Node references.
const ATTACK_CITY := "attack_city"
const ATTACK_UNIT := "attack_unit"
const PROTECT_CITY := "protect_city"
const PROTECT_UNIT := "protect_unit"
const MODES := [ATTACK_CITY, ATTACK_UNIT, PROTECT_CITY, PROTECT_UNIT]
const LABELS := {ATTACK_CITY:"Atacar cidade", ATTACK_UNIT:"Atacar unidade", PROTECT_CITY:"Proteger cidade", PROTECT_UNIT:"Proteger unidade"}
const GUARD_RADIUS := 4
const SEARCH_ROUNDS := 2

static func is_bound(unit: Unit) -> bool:
	return V2ManifestationSystem.is_manifestation_unit(unit)

static func _live(unit: Unit, grid: HexGrid) -> bool:
	return is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.hp > 0.0 and grid.get_unit_at(unit.coord) == unit

static func is_protecting(unit: Unit) -> bool:
	return String(unit.manifestation_order.get("mode", "")).begins_with("protect_")

static func target_coord(unit: Unit) -> Vector2i:
	return Vector2i(int(unit.manifestation_order.get("q", unit.coord.x)), int(unit.manifestation_order.get("r", unit.coord.y)))

static func _visible(owner: PlayerData, coord: Vector2i, grid: HexGrid) -> bool:
	if GameManager.is_human_controlled(owner):
		return grid.visibility.is_empty() or grid.visibility.get(coord, HexGrid.Visibility.UNSEEN) == HexGrid.Visibility.VISIBLE
	return owner.explored_tiles.has(coord) and V2AITacticalAI.view_for(owner, grid).is_visible(coord)

static func target_reason(unit: Unit, mode: String, coord: Vector2i, grid: HexGrid) -> String:
	if not is_bound(unit) or grid == null or not _live(unit, grid) or unit.owner_player == null or not mode in MODES:
		return "Entidade ou ordem inválida."
	if mode.ends_with("city"):
		var city := grid.get_city_at(coord)
		if city == null:
			return "Escolha uma cidade."
		if mode == PROTECT_CITY:
			return "" if city.owner_player == unit.owner_player else "Escolha uma cidade própria."
		if not _visible(unit.owner_player, coord, grid) and not unit.owner_player.known_enemy_cities.has(coord):
			return "A cidade precisa ser conhecida."
		return "" if unit.owner_player.is_at_war_with(city.owner_player) else "Escolha uma cidade de um reino em guerra."
	var target := grid.get_unit_at(coord)
	if not _live(target, grid) or target == unit:
		return "Escolha outra unidade."
	if mode == PROTECT_UNIT:
		return "" if target.owner_player == unit.owner_player else "Escolha uma unidade própria."
	if not _visible(unit.owner_player, coord, grid):
		return "A unidade precisa estar visível."
	return "" if CombatResolver.is_hostile_unit_target(unit.owner_player, target, grid) else "Escolha uma unidade hostil."

static func assign(unit: Unit, mode: String, coord: Vector2i, grid: HexGrid) -> bool:
	if target_reason(unit, mode, coord, grid) != "":
		return false
	var target := grid.get_unit_at(coord)
	var serial := target.serial_id if mode.ends_with("unit") else 0
	var same: bool = unit.manifestation_order.get("mode", "") == mode and target_coord(unit) == coord and int(unit.manifestation_order.get("serial",0)) == serial
	var blocked := int(unit.manifestation_order.get("blocked",0)) if same else 0
	unit.manifestation_order = {"mode":mode, "q":coord.x, "r":coord.y, "serial":serial, "lost":0, "blocked":blocked}
	if not same:
		unit.manifestation_route.clear()
		unit.manifestation_route_goal = Unit.NO_MOVE_ORDER
	unit.move_order_target = Unit.NO_MOVE_ORDER
	unit.exploring = false
	unit.fortified = false
	return true # Issuing/reissuing is free, but never grants an extra action.

static func target_coords(unit: Unit, mode: String, grid: HexGrid) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if mode.ends_with("city"):
		for coord in grid.cities_by_coord:
			if target_reason(unit, mode, coord, grid) == "": result.append(coord)
	else:
		if mode == PROTECT_UNIT:
			for target in unit.owner_player.units:
				if _live(target, grid) and target_reason(unit, mode, target.coord, grid) == "": result.append(target.coord)
		else:
			for target in V2AIWorldView.capture(unit.owner_player, grid).visible_enemy_units:
				if target_reason(unit, mode, target.coord, grid) == "": result.append(target.coord)
	result.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return a.x < b.x if a.x != b.x else a.y < b.y)
	return result

static func describe(unit: Unit) -> String:
	var mode := String(unit.manifestation_order.get("mode", ""))
	var waiting := TurnManager.turn_number < unit.manifestation_ready_turn
	if mode == "": return "Vínculo em formação; desperta na próxima rodada." if waiting else "Aguarda ordem; protege a cidade própria mais próxima."
	var text := "%s · (%d, %d)" % [String(LABELS.get(mode, "Aguardar")), target_coord(unit).x, target_coord(unit).y]
	if mode.ends_with("city") and GameManager.hex_grid != null:
		var city := GameManager.hex_grid.get_city_at(target_coord(unit))
		if city != null: text = "%s · %s" % [String(LABELS[mode]),city.city_name]
	if int(unit.manifestation_order.get("lost", 0)) > 0: text += " · procurando no último local visto"
	if int(unit.manifestation_order.get("blocked", 0)) > 0: text += " · rota bloqueada; aguardando passagem"
	if waiting: text += " · desperta na próxima rodada"
	return text

static func restore(unit: Unit, value: Variant) -> void:
	unit.manifestation_order = {}
	unit.manifestation_route.clear()
	unit.manifestation_route_goal = Unit.NO_MOVE_ORDER
	if not is_bound(unit) or not value is Dictionary or not value.get("mode", "") in MODES: return
	unit.manifestation_order = {"mode":String(value.mode), "q":int(value.get("q", unit.coord.x)), "r":int(value.get("r", unit.coord.y)), "serial":maxi(0,int(value.get("serial",0))), "lost":clampi(int(value.get("lost",0)),0,SEARCH_ROUNDS), "blocked":maxi(0,int(value.get("blocked",0)))}

static func default_guard(unit: Unit, grid: HexGrid) -> void:
	var best: City = null
	var distance := 2147483647
	for city in unit.owner_player.cities:
		if not is_instance_valid(city): continue
		var d := HexMetrics.axial_distance(unit.coord, city.coord)
		if d < distance:
			best = city
			distance = d
	if best != null: assign(unit, PROTECT_CITY, best.coord, grid)
	else: unit.manifestation_order = {}

static func choose_ai_order(unit: Unit, grid: HexGrid, visible: Dictionary) -> void:
	# The rival chooses the same four orders; it never manually moves/casts entities.
	if V2TranscendenceSystem.has_active_ritual(unit.owner_player):
		var site := V2TranscendenceSystem.ritual_site_coord(unit.owner_player)
		if assign(unit, PROTECT_CITY, site, grid): return
	var threat := AIWarTactics.threatened_city_for(unit, unit.owner_player, grid, visible)
	if not threat.is_empty():
		assign(unit, PROTECT_CITY, (threat.city as City).coord, grid)
		return
	if not unit.manifestation_order.is_empty() and not is_protecting(unit): return
	var nearest: Variant = null
	var distance := 2147483647
	for record in V2AITacticalAI.view_for(unit.owner_player, grid).known_enemy_cities:
		if not record.at_war: continue
		var d := HexMetrics.axial_distance(unit.coord, record.coord)
		if d < distance:
			nearest = record.coord
			distance = d
	if nearest != null: assign(unit, ATTACK_CITY, nearest, grid)
	elif unit.manifestation_order.is_empty(): default_guard(unit, grid)

static func act(unit: Unit, grid: HexGrid, visible: Dictionary) -> void:
	if not is_bound(unit) or not _live(unit, grid) or unit.owner_player == null: return
	if TurnManager.turn_number < unit.manifestation_ready_turn or unit.manifestation_acted_turn == TurnManager.turn_number: return
	unit.manifestation_acted_turn = TurnManager.turn_number
	unit.exploring = false
	unit.move_order_target = Unit.NO_MOVE_ORDER
	if unit.movement_left <= 0.0: return
	if unit.manifestation_order.is_empty(): default_guard(unit, grid)
	_refresh_local_visibility(unit, grid, visible)
	var goal := _resolve_goal(unit, grid, visible)
	unit.fortified = false
	# Rejoin an escaping ward before incidental support consumes the whole action.
	# Also leave damaging ground before committing to a stationary attack/cast.
	var ward_distance := HexMetrics.axial_distance(unit.coord,goal)
	var rejoin := is_protecting(unit) and ward_distance > 2 and (ward_distance > GUARD_RADIUS or not _threats_near(unit.coord,unit,grid,visible))
	if rejoin or _tile_danger(unit,unit.coord,grid) > 0.0:
		_advance(unit,goal,2 if is_protecting(unit) else unit.unit_data.attack_range,grid)
		_refresh_local_visibility(unit,grid,visible)
	if _take_action(unit, goal, grid, visible, true): return
	var movement_goal := goal
	var desired := 2 if is_protecting(unit) else unit.unit_data.attack_range
	if is_protecting(unit):
		var threat_distance := 2147483647
		for coord in HexMetrics.coords_within(goal, GUARD_RADIUS):
			var threat := grid.get_unit_at(coord)
			if _eligible_enemy(unit,threat,goal,grid,visible):
				var distance := HexMetrics.axial_distance(coord,goal)
				if distance < threat_distance:
					movement_goal = coord
					desired = unit.unit_data.attack_range
					threat_distance = distance
	if HexMetrics.axial_distance(unit.coord, movement_goal) > desired:
		_advance(unit, movement_goal, desired, grid)
		_refresh_local_visibility(unit, grid, visible)
		if _take_action(unit, goal, grid, visible): return
	if is_protecting(unit) and HexMetrics.axial_distance(unit.coord, goal) <= 2:
		unit.fortified = true

static func _refresh_local_visibility(unit: Unit, grid: HexGrid, visible: Dictionary) -> void:
	# Merge only the moving entity's small vision radius, not another whole-owner scan.
	var local := {}
	grid._mark_visible(unit.coord, V2EnvironmentalZoneSystem.effective_unit_vision(unit, grid), local)
	visible.merge(local)
	for coord in local:
		unit.owner_player.explored_tiles[coord] = true
		if GameManager.is_human_controlled(unit.owner_player):
			grid.visibility[coord] = HexGrid.Visibility.VISIBLE

static func _resolve_goal(unit: Unit, grid: HexGrid, visible: Dictionary) -> Vector2i:
	var order := unit.manifestation_order
	var mode := String(order.get("mode", ""))
	var goal := target_coord(unit)
	if mode.ends_with("city"):
		var city := grid.get_city_at(goal)
		if city == null or (mode == PROTECT_CITY and city.owner_player != unit.owner_player):
			default_guard(unit, grid)
			return target_coord(unit)
		if mode == ATTACK_CITY and city.owner_player == unit.owner_player:
			assign(unit, PROTECT_CITY, goal, grid) # Capture completes the siege; hold the conquest.
		elif mode == ATTACK_CITY and not unit.owner_player.is_at_war_with(city.owner_player):
			default_guard(unit, grid) # Never declare war or keep attacking after peace.
		return target_coord(unit)
	if mode.ends_with("unit"):
		# Scan the sparse occupancy index, not every tile in a growing visibility dictionary. Enemy
		# coordinates are read into the order only while currently observed.
		var candidates: Array = unit.owner_player.units if mode == PROTECT_UNIT else []
		if mode == ATTACK_UNIT:
			var last_seen := grid.get_unit_at(goal)
			candidates = [last_seen] if last_seen != null and last_seen.serial_id == int(order.get("serial",0)) else grid.units_by_coord.values()
		for candidate in candidates:
			if not _live(candidate, grid) or candidate.serial_id != int(order.get("serial",0)): continue
			if mode == ATTACK_UNIT:
				if not visible.has(candidate.coord): continue
				if not CombatResolver.is_hostile_unit_target(unit.owner_player,candidate,grid):
					default_guard(unit,grid)
					return target_coord(unit)
			order.q = candidate.coord.x
			order.r = candidate.coord.y
			order.lost = 0
			return candidate.coord
		if mode == ATTACK_UNIT and not visible.has(goal):
			return goal # Walk to the last sighting, not through hidden coordinates.
		order.lost = int(order.get("lost",0)) + 1
		if mode == PROTECT_UNIT or int(order.lost) > SEARCH_ROUNDS:
			default_guard(unit,grid)
			return target_coord(unit)
	return goal

static func _eligible_enemy(unit: Unit, target: Unit, goal: Vector2i, grid: HexGrid, visible: Dictionary) -> bool:
	if not _live(target,grid) or not visible.has(target.coord) or not CombatResolver.is_hostile_unit_target(unit.owner_player,target,grid): return false
	return not is_protecting(unit) or HexMetrics.axial_distance(target.coord,goal) <= GUARD_RADIUS

static func _take_action(unit: Unit, goal: Vector2i, grid: HexGrid, visible: Dictionary, before_moving: bool = false) -> bool:
	if unit.embarked or unit.movement_left <= 0.0: return false
	var best_score := 0.0
	var best: Dictionary = {}
	for coord in grid.tiles_in_range(unit.coord,unit.unit_data.attack_range):
		var target := grid.get_unit_at(coord)
		if _eligible_enemy(unit,target,goal,grid,visible) and CombatResolver.can_attack_unit(unit,target,grid):
			var prediction := CombatResolver.predict(unit,target,grid)
			var score := minf(float(prediction.damage_to_defender),target.hp) - float(prediction.damage_to_attacker)
			if prediction.defender_dies: score += 16.0 + minf(12.0,target.unit_data.attack*.75)
			if target.serial_id == int(unit.manifestation_order.get("serial",0)) or HexMetrics.axial_distance(target.coord,goal) <= 1: score += 8.0
			if prediction.attacker_dies: score = -1.0
			if score > best_score:
				best_score = score
				best = {"kind":"unit", "target":target}
	var city := grid.get_city_at(goal)
	if String(unit.manifestation_order.get("mode","")) == ATTACK_CITY and city != null and visible.has(goal) and HexMetrics.axial_distance(unit.coord,goal) <= unit.unit_data.attack_range and grid.get_unit_at(goal) == null and CombatResolver.can_attack_city(unit,city):
		var siege := CombatResolver.predict_city_attack(unit,city)
		var score := float(siege.damage) + 12.0 + (24.0 if siege.captures else 0.0)
		if score > best_score:
			best_score = score
			best = {"kind":"city", "target":city}
	for spell in V2MagicRuntime.spells_for_unit(unit):
		if V2MagicRuntime.unavailable_reason(unit,spell.id,grid,false) != "": continue
		if spell.health_cost_fraction > 0.0 and unit.hp - V2MagicRuntime.health_cost(unit,spell) < unit.unit_data.max_hp * .25: continue
		for coord in _spell_coords(unit,spell,goal,grid,visible):
			var score := _spell_score(unit,spell,coord,goal,grid,visible)
			# Cheap support must not indefinitely replace closing to attack. Reconsider
			# after moving (or a blocked approach), without any second reachability search.
			if before_moving and not is_protecting(unit) and HexMetrics.axial_distance(unit.coord,goal) > unit.unit_data.attack_range and score < unit.unit_data.attack:
				var zone := V2EnvironmentalZoneDatabase.get_zone(spell.environmental_zone_id)
				if spell.is_buff() or spell.terrain_modification_id != "" or (zone != null and zone.round_tick_magic_damage <= 0.0): continue
			if score > best_score:
				best_score = score
				best = {"kind":"spell", "spell":spell.id, "coord":coord}
	if best.is_empty(): return false
	if best.kind == "spell": return V2MagicRuntime.cast(unit,best.spell,best.coord,grid)
	if best.kind == "city":
		CombatResolver.resolve_city_attack(unit,best.target,grid)
		if _live(unit,grid) and best.target.owner_player == unit.owner_player:
			assign(unit,PROTECT_CITY,best.target.coord,grid)
	else: CombatResolver.resolve(unit,best.target,grid)
	return true

static func _spell_coords(unit: Unit, spell: V2SpellData, goal: Vector2i, grid: HexGrid, visible: Dictionary) -> Array[Vector2i]:
	if not spell.targets_tile(): return V2MagicRuntime.target_coords(unit,spell,grid)
	var candidates: Array[Vector2i] = []
	if spell.creates_portal_pair or spell.remove_terrain_modification: return candidates
	if spell.teleport_caster:
		if HexMetrics.axial_distance(unit.coord,goal) <= 3: return candidates
		candidates = V2MagicRuntime.target_tiles(unit,spell,grid)
	elif spell.dispel_at_tile:
		# Status/zone effects may be on any nearby tile, not just objective neighbours.
		candidates = V2MagicRuntime.target_tiles(unit,spell,grid)
	elif spell.environmental_zone_id != "":
		for coord in grid.tiles_in_range(unit.coord,V2MagicRuntime.effective_range(unit,spell)):
			var enemy := grid.get_unit_at(coord)
			if _eligible_enemy(unit,enemy,goal,grid,visible): candidates.append(coord)
	else:
		candidates.assign([unit.coord,goal])
		for coord in grid.get_neighbors(unit.coord):
			if not coord in candidates: candidates.append(coord)
		for coord in grid.get_neighbors(goal):
			if not coord in candidates: candidates.append(coord)
	var result: Array[Vector2i] = []
	for coord in candidates:
		if visible.has(coord) and V2MagicRuntime.tile_reason(unit,spell,coord,grid) == "": result.append(coord)
	return result

static func _spell_score(unit: Unit, spell: V2SpellData, coord: Vector2i, goal: Vector2i, grid: HexGrid, visible: Dictionary) -> float:
	var target := grid.get_unit_at(coord)
	var score := -V2MagicRuntime.health_cost(unit,spell)*1.1 - V2ManifestationBalance.mana_cost(unit,spell)*.3
	if spell.is_heal() and target != null:
		for ally in V2MagicRuntime.affected_units(unit,spell,target,grid):
			var missing := maxf(0.0,ally.unit_data.max_hp-ally.hp)
			var amount := (ally.unit_data.max_hp if spell.heal_to_full else spell.heal_amount) * MonsterHazardSystem.heal_multiplier(ally)
			score += minf(missing,amount) * (1.5 if ally.hp < ally.unit_data.max_hp*.4 else 1.0)
		# Save long recargas for meaningful healing rather than a few incidental HP.
		score -= spell.cooldown_turns * .5
		if HexMetrics.axial_distance(unit.coord,goal) > 2 and score < 4.0: return -1.0
	elif spell.is_damage() and _eligible_enemy(unit,target,goal,grid,visible):
		for victim in V2MagicRuntime.affected_units(unit,spell,target,grid):
			if not visible.has(victim.coord): continue
			var damage := V2MagicRuntime.predict_damage(unit,victim,spell)
			score += minf(damage,victim.hp) + (16.0 + minf(12.0,victim.unit_data.attack*.75) if damage >= victim.hp else 0.0)
	elif spell.is_buff() and target != null and not V2MagicRuntime.is_status_active(target,spell.id) and _threats_near(target.coord,unit,grid,visible):
		score += 6.0 + target.unit_data.attack*spell.attack_bonus + target.unit_data.defense*spell.defense_bonus
	elif spell.silences_spellcasting and _eligible_enemy(unit,target,goal,grid,visible) and target.unit_data.is_v2_caster() and not V2MagicRuntime.is_spellcasting_silenced(target):
		score += 23.0
	elif spell.is_summon() and _threats_near(unit.coord,unit,grid,visible):
		var summoned := V2MagicRuntime.summon_data(spell)
		score += 8.0 + summoned.attack*1.5 + summoned.max_hp*.4
	elif spell.teleport_caster and HexMetrics.axial_distance(unit.coord,goal) > 3:
		if _tile_danger(unit,coord,grid) > 0.0: return -1.0
		if is_protecting(unit) and HexMetrics.axial_distance(unit.coord,goal) <= GUARD_RADIUS and HexMetrics.axial_distance(coord,goal) > GUARD_RADIUS: return -1.0
		var gain := HexMetrics.axial_distance(unit.coord,goal)-HexMetrics.axial_distance(coord,goal)
		if gain >= 3: score += gain*3.0
	elif spell.dispel_at_tile:
		# Dispel also closes the portal and removes the zone on this tile. Never
		# destroy our own logistics or beneficial pressure as a side effect.
		var portal := V2PortalSystem.endpoint_at(coord,grid)
		if not portal.is_empty() and int(portal.owner_index) == GameManager.players.find(unit.owner_player): return -1.0
		if target != null:
			if target.owner_player == unit.owner_player or _eligible_enemy(unit,target,goal,grid,visible):
				if not V2MagicRuntime.dispellable_statuses_for(unit,target,grid).is_empty(): score += 14.0
			var zone := V2EnvironmentalZoneSystem.zone_at(coord,grid)
			if zone != null and zone.dispellable:
				var pressure := _zone_pressure(zone,target)
				if target.owner_player == unit.owner_player: score += pressure*2.0
				elif CombatResolver.is_hostile_unit_target(unit.owner_player,target,grid): score -= pressure*2.0
	elif spell.environmental_zone_id != "":
		var zone := V2EnvironmentalZoneDatabase.get_zone(spell.environmental_zone_id)
		for area in V2MagicRuntime.environmental_area_tiles(unit,spell,coord,grid):
			var occupant := grid.get_unit_at(area)
			if occupant == null: continue
			if not visible.has(area): continue
			var pressure := _zone_pressure(zone,occupant)
			if not CombatResolver.is_hostile_unit_target(unit.owner_player,occupant,grid):
				if zone.round_tick_magic_damage > 0.0: return -1.0
				score -= pressure*2.0
			elif _eligible_enemy(unit,occupant,goal,grid,visible): score += pressure
	elif spell.terrain_modification_id != "" and _threats_near(goal,unit,grid,visible):
		# Only count units actually receiving new cover, not adjacent units: terrain
		# defense applies on its own tile. Never spend every attack turn planting woods.
		for area in V2MagicRuntime.terrain_area_tiles(unit,spell,coord,grid):
			var ally := grid.get_unit_at(area)
			if ally == null: continue
			if ally.owner_player != unit.owner_player: return -1.0
			if _threats_near(ally.coord,unit,grid,visible): score += ally.unit_data.defense*.6 + 2.0
	return score

static func _zone_pressure(zone: V2EnvironmentalZoneData, target: Unit) -> float:
	var pressure := minf(zone.round_tick_magic_damage,target.hp)*1.3 + absf(zone.vision_delta)*1.5
	if target.unit_data.attack_range > 1:
		pressure += target.unit_data.attack * (1.0-zone.physical_ranged_attack_multiplier)*2.0
	return pressure

static func _tile_danger(unit: Unit, coord: Vector2i, grid: HexGrid) -> float:
	# Sparse O(1) lookups; never inspect unknown ground for hidden hazards.
	if not unit.owner_player.explored_tiles.has(coord): return 0.0
	var zone := V2EnvironmentalZoneSystem.zone_at(coord,grid)
	var damage := zone.round_tick_magic_damage if zone != null else 0.0
	if MonsterHazardSystem.is_infected(coord): damage += MonsterHazardSystem.infection_damage(unit)
	return damage

static func _threats_near(coord: Vector2i, unit: Unit, grid: HexGrid, visible: Dictionary) -> bool:
	for near in HexMetrics.coords_within(coord,GUARD_RADIUS):
		if _eligible_enemy(unit,grid.get_unit_at(near),coord,grid,visible): return true
	return false

static func _advance(unit: Unit, goal: Vector2i, desired: int, grid: HexGrid) -> void:
	if unit.movement_left <= 0.0: return
	if unit.manifestation_route_goal != goal: unit.manifestation_route.clear()
	var reachable := grid.unit_reachable(unit) if not unit.manifestation_route.is_empty() and unit.can_embark() else grid.unit_landing_reachable(unit)
	if not unit.manifestation_route.is_empty() and _follow_detour(unit,goal,desired,grid,reachable): return
	var current := HexMetrics.axial_distance(unit.coord,goal)
	var best := unit.coord
	var best_score := -float(maxi(0,current-desired))*10.0 - _tile_danger(unit,unit.coord,grid)*6.0
	for coord in reachable:
		if is_protecting(unit) and HexMetrics.axial_distance(coord,target_coord(unit)) > GUARD_RADIUS and HexMetrics.axial_distance(unit.coord,target_coord(unit)) <= GUARD_RADIUS: continue
		var distance := HexMetrics.axial_distance(coord,goal)
		var danger := _tile_danger(unit,coord,grid)
		if danger >= unit.hp: continue
		var score := -float(maxi(0,distance-desired))*10.0-float(reachable[coord])*.05-danger*6.0
		if distance <= desired and float(reachable[coord]) < unit.movement_left: score += 5.0
		if score > best_score:
			best = coord
			best_score = score
	if best != unit.coord:
		grid.move_unit(unit,best,float(reachable[best]))
		unit.manifestation_order.blocked = 0
		return
	# One cached engine A* only when a ground detour is needed. Never flood the
	# full map per candidate/hover. Repeated failures back off to every third round.
	if unit.unit_data.movement_profile != UnitData.MovementProfile.GROUND: return
	var blocked := int(unit.manifestation_order.get("blocked",0))
	if blocked >= 2 and TurnManager.turn_number % 3 != 0: return
	unit.manifestation_order.blocked = blocked+1
	# Ranged entities need a firing position, not necessarily an adjacent tile.
	var destinations := grid.tiles_in_range(goal,maxi(1,desired))
	destinations.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return HexMetrics.axial_distance(unit.coord,a)<HexMetrics.axial_distance(unit.coord,b))
	var legal: Array[Vector2i] = []
	for destination in destinations:
		if grid.get_unit_at(destination) != null or grid.unit_destination_reason(unit,destination) != "": continue
		if not grid._route_possible(unit.coord,destination,unit.can_embark()): continue
		legal.append(destination)
	if legal.is_empty(): return
	# Rotate failed approaches, otherwise a disconnected first neighbour would stall forever.
	var path := grid.unit_path(unit,legal[blocked % legal.size()])
	if unit.can_embark() and not path.is_empty(): reachable = grid.unit_reachable(unit)
	unit.manifestation_route = path
	unit.manifestation_route_goal = goal
	_follow_detour(unit,goal,desired,grid,reachable)

static func _follow_detour(unit: Unit, goal: Vector2i, desired: int, grid: HexGrid, reachable: Dictionary) -> bool:
	# Once committed to a detour, don't undo it just because moving backwards
	# would reduce axial distance. Revalidate the affordable prefix every turn.
	var best := unit.coord
	var last := -1
	for index in unit.manifestation_route.size():
		var step := unit.manifestation_route[index]
		if step == unit.coord: continue
		if not reachable.has(step): break
		if _tile_danger(unit,step,grid) > 0.0: continue
		if is_protecting(unit) and HexMetrics.axial_distance(unit.coord,target_coord(unit)) <= GUARD_RADIUS and HexMetrics.axial_distance(step,target_coord(unit)) > GUARD_RADIUS: break
		best = step
		last = index
		if HexMetrics.axial_distance(step,goal) <= desired: break
	if best == unit.coord:
		unit.manifestation_route.clear()
		return false
	grid.move_unit(unit,best,float(reachable[best]))
	unit.manifestation_route.assign(unit.manifestation_route.slice(last+1))
	unit.manifestation_order.blocked = 0
	return true
