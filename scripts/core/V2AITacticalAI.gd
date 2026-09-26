class_name V2AITacticalAI
extends RefCounted

## Local, data-driven V2 action evaluator. It never grants an action: every
## chosen technique, spell, portal traversal, movement or improvement is
## committed by the same runtime used by the human player.

static var _turn_views: Dictionary = {} # PlayerData -> {turn, view}; transient

static func prepare_turn(player: PlayerData, grid: HexGrid) -> V2AIWorldView:
	var view := V2AIWorldView.capture(player, grid)
	_turn_views[player] = {"turn": TurnManager.turn_number, "view": view}
	return view

static func view_for(player: PlayerData, grid: HexGrid) -> V2AIWorldView:
	var entry: Dictionary = _turn_views.get(player, {})
	if int(entry.get("turn", -1)) != TurnManager.turn_number:
		return prepare_turn(player, grid)
	return entry.view

static func clear_views() -> void:
	_turn_views.clear()

## True means this layer consumed the unit's decision for the turn (an action,
## a movement, or a command-invalid retinue that must not reach legacy AI).
static func take_special_action(unit: Unit, player: PlayerData, grid: HexGrid) -> bool:
	if not V2StrategicAI.is_enabled_for(player) or unit == null or not is_instance_valid(unit):
		return false
	if not unit.can_receive_orders():
		return true
	if unit.movement_left <= 0.0 or unit.hp <= 0.0:
		return true
	var view := view_for(player, grid)
	if V2ConstructorRuntime.is_builder_unit(unit):
		return _builder_action(unit, player, grid, view)
	if _try_portal_traversal(unit, player, grid, view):
		return true
	if V2MagicRuntime.is_v2_caster(unit):
		if _try_spell(unit, player, grid, view):
			return true
		if V2ManifestationSystem.is_manifestation_unit(unit) and V2TranscendenceSystem.has_active_ritual(player):
			return _guard_ritual_site(unit, player, grid, view)
		if _move_caster(unit, player, grid, view):
			return true
	if V2ResearchDatabase.is_v2_id(unit.unit_data.visual_kind) and _try_technique(unit, grid, view):
		return true
	if V2ManifestationSystem.is_manifestation_unit(unit) and V2TranscendenceSystem.has_active_ritual(player):
		return _guard_ritual_site(unit, player, grid, view)
	# Legacy RivalAI uses ground pathfinding. Special profiles move here so the
	# old layer can keep handling targets/combat without flattening their reach.
	if unit.unit_data.movement_profile != UnitData.MovementProfile.GROUND:
		return _move_special_profile(unit, player, grid, view)
	return false

static func _builder_action(unit: Unit, player: PlayerData, grid: HexGrid, view: V2AIWorldView) -> bool:
	if V2ConstructorRuntime.can_improve(unit, grid):
		return V2ConstructorRuntime.improve_resource(unit, grid)
	var targets := V2StrategicAI.known_unimproved_resources(player, view)
	if targets.is_empty():
		return true
	var reachable := grid.unit_reachable(unit)
	var best: Variant = null
	var best_score := -INF
	for coord in reachable:
		var score := -float(_nearest_distance(coord, targets)) - float(reachable[coord]) * 0.05
		if coord in targets:
			score += 100.0 + _resource_need_score(player, grid.get_tile(coord).resource)
		if score > best_score or (is_equal_approx(score, best_score) and _coord_less(coord, best)):
			best_score = score
			best = coord
	if best != null:
		grid.move_unit(unit, best, float(reachable[best]))
		if V2ConstructorRuntime.can_improve(unit, grid):
			V2ConstructorRuntime.improve_resource(unit, grid)
	return true

static func _resource_need_score(player: PlayerData, resource_id: String) -> float:
	var score := 0.0
	for effect in V2ResourceImprovementData.effects_for_resource(resource_id):
		score += 1.0 + V2StrategicAI._economic_urgency(player, String(effect.branch))
	return score

static func _try_technique(unit: Unit, grid: HexGrid, view: V2AIWorldView) -> bool:
	var best_technique: V2DoctrineTechniqueData = null
	var best_coord := V2TechniqueRuntime.NO_TILE
	var best_score := V2AITuning.SPECIAL_ACTION_UTILITY
	for technique in V2TechniqueRuntime.active_techniques_for_unit(unit):
		if not V2TechniqueRuntime.can_use(unit, technique.id, grid):
			continue
		if technique.is_city_strike():
			for city in V2TechniqueRuntime.city_strike_targets(unit, technique, grid):
				if not view.is_visible(city.coord):
					continue
				var score := technique.strike_multiplier * unit.unit_data.attack * 3.0 + city.fortification_level * 8.0
				if score > best_score:
					best_score = score
					best_technique = technique
					best_coord = city.coord
		elif technique.is_strike():
			var targets := V2TechniqueRuntime.strike_targets(unit, technique, grid)
			if technique.strike_targeting == V2DoctrineTechniqueData.StrikeTargeting.ADJACENT_ENEMIES:
				var aggregate := 0.0
				for target in targets:
					if view.is_visible(target.coord):
						aggregate += _strike_utility(unit, target, technique, grid)
				if aggregate > best_score:
					best_score = aggregate
					best_technique = technique
					best_coord = V2TechniqueRuntime.NO_TILE
			else:
				for target in targets:
					if not view.is_visible(target.coord):
						continue
					var score := _strike_utility(unit, target, technique, grid)
					if score > best_score:
						best_score = score
						best_technique = technique
						best_coord = target.coord
		elif technique.is_relocation():
			var current_risk := _local_risk(unit.coord, unit, view)
			if current_risk <= 0.0 and unit.hp >= unit.unit_data.max_hp * 0.5:
				continue
			for coord in V2TechniqueRuntime.relocation_tiles(unit, technique, grid):
				if not view.is_visible(coord):
					continue
				var wounded_urgency := (1.0 - unit.hp / maxf(unit.unit_data.max_hp, 1.0)) * 12.0
				var score := (current_risk - _local_risk(coord, unit, view)) * 15.0 + technique.self_defense_bonus * 20.0 + wounded_urgency
				if score > best_score:
					best_score = score
					best_technique = technique
					best_coord = coord
		elif technique.has_defense_effect():
			var threats := view.visible_hostiles_near(unit.coord, 3).size()
			var allies := 0
			for ally in unit.owner_player.units:
				if ally != unit and HexMetrics.axial_distance(ally.coord, unit.coord) <= technique.adjacent_radius:
					allies += 1
			var score := threats * 12.0 + allies * technique.adjacent_ally_defense_bonus * 20.0 + technique.self_defense_bonus * 20.0
			if score > best_score:
				best_score = score
				best_technique = technique
	if best_technique == null:
		return false
	if best_technique.needs_target():
		return V2TechniqueRuntime.perform_targeted(unit, best_technique.id, best_coord, grid)
	if best_technique.is_strike():
		return V2TechniqueRuntime.perform_strike(unit, best_technique.id, null, grid)
	return V2TechniqueRuntime.activate(unit, best_technique.id)

static func _strike_utility(attacker: Unit, target: Unit, technique: V2DoctrineTechniqueData, grid: HexGrid) -> float:
	var result := CombatResolver.predict(attacker, target, grid, technique.strike_multiplier, technique.strike_defense_penetration, technique.strike_prevents_counterattack)
	var normal := CombatResolver.predict(attacker, target, grid)
	var utility: float = float(result.damage_to_defender) - float(result.damage_to_attacker) * 0.8
	if result.defender_dies:
		utility += 25.0 + target.unit_data.production_cost * 0.1
	if result.attacker_dies:
		utility -= 35.0
	if not result.defender_dies and result.damage_to_defender < normal.damage_to_defender * V2AITuning.SPECIAL_ACTION_GAIN and not technique.strike_prevents_counterattack:
		utility -= 12.0
	return utility

static func _try_spell(caster: Unit, player: PlayerData, grid: HexGrid, view: V2AIWorldView) -> bool:
	var best_spell: V2SpellData = null
	var best_coord := caster.coord
	var best_score := V2AITuning.SPECIAL_ACTION_UTILITY
	for spell in V2MagicRuntime.spells_for_unit(caster):
		if not V2MagicRuntime.can_cast(caster, spell.id, grid):
			continue
		if player.mana - spell.mana_cost < V2StrategicAI.strategic_mana_reserve(player):
			# Emergency healing may use part of the reserve; ordinary casts may not.
			if not spell.is_heal():
				continue
		var coords := V2MagicRuntime.target_coords(caster, spell, grid)
		for coord in coords:
			if not view.is_visible(coord):
				continue
			var score := _spell_utility(caster, spell, coord, grid, view)
			if score > best_score or (is_equal_approx(score, best_score) and _coord_less(coord, best_coord)):
				best_score = score
				best_spell = spell
				best_coord = coord
	if best_spell == null:
		return false
	return V2MagicRuntime.cast(caster, best_spell.id, best_coord, grid)

static func _spell_utility(caster: Unit, spell: V2SpellData, coord: Vector2i, grid: HexGrid, view: V2AIWorldView) -> float:
	var target := grid.get_unit_at(coord)
	var score := 0.0
	if spell.is_heal() and target != null:
		for ally in V2MagicRuntime.affected_units(caster, spell, target, grid):
			var missing := maxf(0.0, ally.unit_data.max_hp - ally.hp)
			var amount := missing if spell.heal_to_full else minf(missing, spell.heal_amount)
			score += amount * (1.5 if ally.hp / maxf(ally.unit_data.max_hp, 1.0) < 0.35 else 1.0)
	elif spell.is_damage() and target != null and view.is_visible(target.coord):
		for victim in V2MagicRuntime.affected_units(caster, spell, target, grid):
			var damage := V2MagicRuntime.predict_damage(caster, victim, spell)
			score += minf(damage, victim.hp) + (18.0 if damage >= victim.hp else 0.0)
	elif spell.is_buff() and target != null:
		if not V2MagicRuntime.is_status_active(target, spell.id) and not view.visible_hostiles_near(target.coord, 4).is_empty():
			score += 12.0 + target.unit_data.production_cost * 0.15 + (12.0 if V2ManifestationSystem.is_manifestation_unit(target) or V2LegendarySystem.is_legendary_unit(target) else 0.0)
	elif spell.is_summon():
		if not caster.owner_player.enemies.is_empty() and V2StrategicAI.relevant_unit_count(caster.owner_player) < V2AITuning.target_relevant_units(caster.owner_player):
			score += 18.0
	elif spell.teleport_caster:
		var risk_before := _local_risk(caster.coord, caster, view)
		var risk_after := _local_risk(coord, caster, view)
		score += (risk_before - risk_after) * 15.0
	elif spell.silences_spellcasting and target != null and target.unit_data.is_v2_caster():
		score += 24.0 + (12.0 if V2ManifestationSystem.is_manifestation_unit(target) else 0.0)
	elif spell.dispel_at_tile:
		if V2MagicRuntime.has_dispellable_effect_at(caster, coord, grid):
			score += 20.0
	elif spell.creates_portal_pair:
		var objective = V2StrategicAI.strategic_target_coord(caster.owner_player, view)
		if objective != null:
			var gain := HexMetrics.axial_distance(caster.coord, objective) - HexMetrics.axial_distance(coord, objective)
			if gain >= V2AITuning.PORTAL_MIN_DISTANCE_GAIN:
				score += gain * 6.0
	elif spell.environmental_zone_id != "":
		var zone := V2EnvironmentalZoneDatabase.get_zone(spell.environmental_zone_id)
		for area_coord in V2MagicRuntime.environmental_area_tiles(caster, spell, coord, grid):
			var affected := grid.get_unit_at(area_coord)
			if affected == null:
				continue
			var value := zone.round_tick_magic_damage + absf(zone.vision_delta) + absf(1.0 - zone.physical_ranged_attack_multiplier) * 10.0
			score += value if affected.owner_player != caster.owner_player else -value * V2AITuning.FRIENDLY_FIRE_PENALTY
	elif spell.is_terrain_spell():
		var occupant := grid.get_unit_at(coord)
		if spell.remove_terrain_modification:
			score += 14.0 if occupant != null and occupant.owner_player != caster.owner_player else 0.0
		else:
			# As criações miram tile vazio; avaliar o ocupante do próprio tile
			# tornava o caso útil impossível. Uma frente aliada/hostil adjacente
			# é informação visível e dá utilidade ao choke sem prever o futuro.
			score += 4.0
			for near in grid.get_neighbors(coord):
				var nearby := grid.get_unit_at(near)
				if nearby == null:
					continue
				score += 5.0 if nearby.owner_player == caster.owner_player else 2.0
	return score - spell.mana_cost * 0.08

static func _try_portal_traversal(unit: Unit, player: PlayerData, grid: HexGrid, view: V2AIWorldView) -> bool:
	if not V2PortalSystem.can_traverse(unit, grid):
		return false
	var destination := V2PortalSystem.traversal_destination(unit, grid)
	if not view.is_visible(destination):
		return false
	var objective = V2StrategicAI.strategic_target_coord(player, view)
	var severe_danger := _local_risk(unit.coord, unit, view) >= 2.0 and _local_risk(destination, unit, view) == 0.0
	if objective == null and not severe_danger:
		return false
	var gain := 0
	if objective != null:
		gain = HexMetrics.axial_distance(unit.coord, objective) - HexMetrics.axial_distance(destination, objective)
	return V2PortalSystem.traverse(unit, grid) if gain >= V2AITuning.PORTAL_MIN_DISTANCE_GAIN or severe_danger else false

static func _move_special_profile(unit: Unit, player: PlayerData, grid: HexGrid, view: V2AIWorldView) -> bool:
	# Let legacy combat execute if a visible hostile is already attackable.
	for target in view.visible_enemy_units:
		if (target.owner_player == null or player.is_at_war_with(target.owner_player)) and HexMetrics.axial_distance(unit.coord, target.coord) <= unit.unit_data.attack_range:
			return false
	var objective = V2StrategicAI.strategic_target_coord(player, view)
	if objective == null:
		return false
	var reachable := grid.unit_reachable(unit)
	var best: Variant = null
	var best_distance := HexMetrics.axial_distance(unit.coord, objective)
	for coord in reachable:
		var distance := HexMetrics.axial_distance(coord, objective)
		if distance < best_distance or (distance == best_distance and (best == null or _coord_less(coord, best))):
			best_distance = distance
			best = coord
	if best != null:
		grid.move_unit(unit, best, float(reachable[best]))
		return true
	return false

static func _move_caster(unit: Unit, player: PlayerData, grid: HexGrid, view: V2AIWorldView) -> bool:
	# Keep a legal basic attack in the legacy combat pipeline. Otherwise move
	# toward the nearest useful anchor while strongly avoiding adjacency.
	for enemy in view.visible_enemy_units:
		if (enemy.owner_player == null or player.is_at_war_with(enemy.owner_player)) and HexMetrics.axial_distance(unit.coord, enemy.coord) <= unit.unit_data.attack_range:
			return false
	var anchors: Array[Vector2i] = []
	for ally in player.units:
		if ally != unit and ally.hp > 0.0 and ally.unit_data.attack > 0.0 and not ally.unit_data.is_v2_caster():
			anchors.append(ally.coord)
	for city in player.cities:
		anchors.append(city.coord)
	var objective = V2StrategicAI.strategic_target_coord(player, view)
	var reachable := grid.unit_reachable(unit)
	var best := unit.coord
	var best_score := _caster_tile_score(unit.coord, unit, anchors, objective, view)
	for coord in reachable:
		var score := _caster_tile_score(coord, unit, anchors, objective, view)
		if score > best_score or (is_equal_approx(score, best_score) and _coord_less(coord, best)):
			best_score = score
			best = coord
	if best != unit.coord:
		grid.move_unit(unit, best, float(reachable[best]))
		return true
	return false

static func _caster_tile_score(coord: Vector2i, unit: Unit, anchors: Array[Vector2i], objective: Variant, view: V2AIWorldView) -> float:
	var risk := _local_risk(coord, unit, view)
	var score := -risk * 30.0
	if not anchors.is_empty():
		score -= float(_nearest_distance(coord, anchors)) * 1.5
	if objective != null:
		score -= float(HexMetrics.axial_distance(coord, objective)) * 0.2
	for enemy in view.visible_enemy_units:
		if enemy.owner_player == null or unit.owner_player.is_at_war_with(enemy.owner_player):
			if HexMetrics.axial_distance(coord, enemy.coord) <= 1:
				score -= 40.0
	return score

static func _guard_ritual_site(unit: Unit, player: PlayerData, grid: HexGrid, view: V2AIWorldView) -> bool:
	var site := V2TranscendenceSystem.ritual_site_coord(player)
	if site == V2TranscendenceSystem.INVALID_COORD:
		return true
	var reachable := grid.unit_reachable(unit)
	var best := unit.coord
	var best_score := -float(HexMetrics.axial_distance(unit.coord, site)) * 4.0 - _local_risk(unit.coord, unit, view) * 25.0
	for coord in reachable:
		var score := -float(HexMetrics.axial_distance(coord, site)) * 4.0 - _local_risk(coord, unit, view) * 25.0
		if score > best_score or (is_equal_approx(score, best_score) and _coord_less(coord, best)):
			best_score = score
			best = coord
	if best != unit.coord:
		grid.move_unit(unit, best, float(reachable[best]))
	return true

static func _local_risk(coord: Vector2i, unit: Unit, view: V2AIWorldView) -> float:
	var risk := 0.0
	for enemy in view.visible_enemy_units:
		if enemy.owner_player != null and not unit.owner_player.is_at_war_with(enemy.owner_player):
			continue
		var distance := HexMetrics.axial_distance(coord, enemy.coord)
		if distance <= maxi(enemy.unit_data.attack_range, 2):
			risk += maxf(enemy.unit_data.attack, 1.0) / maxf(unit.unit_data.max_hp, 1.0)
	return risk

static func _nearest_distance(coord: Vector2i, targets: Array[Vector2i]) -> int:
	var best := 999999
	for target in targets:
		best = mini(best, HexMetrics.axial_distance(coord, target))
	return best

static func _coord_less(a: Vector2i, b: Variant) -> bool:
	return b == null or a.x < b.x or (a.x == b.x and a.y < b.y)
