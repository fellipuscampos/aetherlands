class_name V2StrategicAI
extends RefCounted

## Fase 24: autoridade estratégica V2 para civilizações rivais major.
## Escolhe objetivos; execução e validação continuam nas APIs do jogador.

const CORE_ROLES := ["tank_frontline", "melee_damage", "ranged_combat"]
const COMPLEMENT_ROLES := ["mobility_shock", "sabotage_assassination", "city_conquest"]
const MAGIC_SUPPORT_ROLES := ["sustain", "terrain_manipulation", "mobility_utility"]
const MAGIC_PRESSURE_ROLES := ["magical_damage", "undead_summoning", "environmental_control"]
const OBSERVED_TRAITS := ["mounted", "siege", "caster", "legendary", "grand_manifestation", "undead", "retinue", "flying"]

static func is_enabled_for(player: PlayerData) -> bool:
	return player != null and player != GameManager.human_player and player in GameManager.rival_players

static func initialize_player(player: PlayerData, rival_index: int, world_seed: int, rival_count: int) -> void:
	if player == null:
		return
	player.v2_ai_strategy.initialize(rival_index, world_seed, rival_count)
	_ensure_preferences(player)

static func plan_turn(player: PlayerData, grid: HexGrid) -> Dictionary:
	if not is_enabled_for(player) or grid == null:
		return {}
	var rival_index := GameManager.rival_players.find(player)
	initialize_player(player, rival_index, grid.map_seed, GameManager.rival_players.size())
	var view := V2AIWorldView.capture(player, grid)
	_review_strategy(player, view)
	_choose_research(player)
	_annex_known_tiles(player, view)
	_start_ritual_if_ready(player, view)
	_upgrade_units(player, view)
	_plan_production(player, view)
	var report := debug_snapshot(player)
	if OS.is_debug_build() and ProjectSettings.get_setting("debug/ai_v2_log", false):
		print("[AI V2] %s — %s | Research: %s | Economy: %s | Army: %d/%d | Supply: %d/%d | Goal: %s | Why: %s" % [
			player.civ.civ_name, V2AIStrategyState.orientation_name(player.v2_ai_strategy.orientation),
			player.v2_research.active_id, _dominant_economic_need(player), relevant_unit_count(player), V2AITuning.target_relevant_units(player),
			V2LogisticsRuntime.player_supply_used(player), int(V2EconomyRuntime.player_supply_capacity(player)),
			V2AIStrategyState.focus_name(player.v2_ai_strategy.victory_focus), "; ".join(player.v2_ai_strategy.last_reasons)])
	return report

static func _ensure_preferences(player: PlayerData) -> void:
	var state: V2AIStrategyState = player.v2_ai_strategy
	if state.preferred_doctrine_branches.is_empty():
		state.preferred_doctrine_branches.append(_branch_for_role_set(V2ResearchNode.TreeType.MILITARY_DOCTRINE, CORE_ROLES, state.strategy_seed))
		if state.orientation == V2AIStrategyState.Orientation.MILITARY:
			_append_distinct(state.preferred_doctrine_branches, _branch_for_role_set_excluding(V2ResearchNode.TreeType.MILITARY_DOCTRINE, COMPLEMENT_ROLES + CORE_ROLES, state.strategy_seed / 7 + 1, state.preferred_doctrine_branches))
	if state.preferred_magic_branches.is_empty():
		state.preferred_magic_branches.append(_branch_for_role_set(V2ResearchNode.TreeType.MAGIC_SCHOOL, MAGIC_SUPPORT_ROLES, state.strategy_seed / 11 + 2))
		if state.orientation == V2AIStrategyState.Orientation.ARCANE:
			_append_distinct(state.preferred_magic_branches, _branch_for_role_set(V2ResearchNode.TreeType.MAGIC_SCHOOL, MAGIC_PRESSURE_ROLES, state.strategy_seed / 13 + 3))
	state.preferred_doctrine_branches = state.preferred_doctrine_branches.filter(func(v): return v != "")
	state.preferred_magic_branches = state.preferred_magic_branches.filter(func(v): return v != "")

static func _branch_for_role_set(tree_type: int, roles: Array, seed: int) -> String:
	var candidates: Array[String] = []
	for info in V2ResearchDatabase.branches_for_tree(tree_type):
		if String(info.get("role", "")) in roles:
			candidates.append(String(info.get("id", "")))
	candidates.sort()
	return candidates[posmod(seed, candidates.size())] if not candidates.is_empty() else ""

static func _append_distinct(values: Array[String], value: String) -> void:
	if value != "" and value not in values:
		values.append(value)

static func _branch_for_role_set_excluding(tree_type: int, roles: Array, seed: int, excluded: Array[String]) -> String:
	var candidates: Array[String] = []
	for info in V2ResearchDatabase.branches_for_tree(tree_type):
		var branch := String(info.get("id", ""))
		if branch not in excluded and String(info.get("role", "")) in roles:
			candidates.append(branch)
	candidates.sort()
	return candidates[posmod(seed, candidates.size())] if not candidates.is_empty() else ""

static func _review_strategy(player: PlayerData, view: V2AIWorldView) -> void:
	var state: V2AIStrategyState = player.v2_ai_strategy
	if state.last_strategy_review_turn == TurnManager.turn_number:
		return
	var sample: Dictionary = {}
	for unit in view.visible_enemy_units:
		var role := V2UnitLine.role_of(unit.unit_data.visual_kind)
		if role == "":
			role = "ranged_combat" if unit.unit_data.attack_range > 1 else "melee_damage"
		sample[role] = float(sample.get(role, 0.0)) + 1.0
		for trait_id in OBSERVED_TRAITS:
			if unit.unit_data.has_trait(trait_id):
				sample[trait_id] = float(sample.get(trait_id, 0.0)) + 1.0
	var keys := state.pressure_by_role_or_trait.keys()
	for key in sample:
		if key not in keys:
			keys.append(key)
	for key in keys:
		var value := float(state.pressure_by_role_or_trait.get(key, 0.0)) * V2AITuning.PRESSURE_MEMORY + float(sample.get(key, 0.0)) * V2AITuning.PRESSURE_SAMPLE
		if value < 0.01:
			state.pressure_by_role_or_trait.erase(key)
		else:
			state.pressure_by_role_or_trait[key] = value
	state.adaptive_doctrine_branch = _adaptive_branch(state)
	_resolve_balanced_focus(player)
	state.last_strategy_review_turn = TurnManager.turn_number

static func _adaptive_branch(state: V2AIStrategyState) -> String:
	var role_pressure := {
		"tank_frontline": float(state.pressure_by_role_or_trait.get("mounted", 0.0)),
		"sabotage_assassination": float(state.pressure_by_role_or_trait.get("caster", 0.0)) + float(state.pressure_by_role_or_trait.get("siege", 0.0)),
		"ranged_combat": float(state.pressure_by_role_or_trait.get("legendary", 0.0)),
		"mobility_shock": float(state.pressure_by_role_or_trait.get("ranged_combat", 0.0)),
	}
	var best_role := ""
	var best := 0.75 # one sighting cannot immediately rewrite the strategy
	for role in role_pressure:
		if float(role_pressure[role]) > best:
			best = role_pressure[role]
			best_role = role
	if best_role == "":
		return ""
	for info in V2ResearchDatabase.branches_for_tree(V2ResearchNode.TreeType.MILITARY_DOCTRINE):
		if info.get("role", "") == best_role:
			return String(info.get("id", ""))
	return ""

static func _resolve_balanced_focus(player: PlayerData) -> void:
	var state: V2AIStrategyState = player.v2_ai_strategy
	if state.orientation != V2AIStrategyState.Orientation.BALANCED or state.victory_focus != V2AIStrategyState.VictoryFocus.UNDECIDED:
		return
	var military := _tree_progress(player, V2ResearchNode.TreeType.MILITARY_DOCTRINE)
	var magic := _tree_progress(player, V2ResearchNode.TreeType.MAGIC_SCHOOL)
	if military >= magic + 5.0:
		state.victory_focus = V2AIStrategyState.VictoryFocus.MILITARY_SUPREMACY
	elif magic >= military + 5.0:
		state.victory_focus = V2AIStrategyState.VictoryFocus.TRANSCENDENCE
	elif TurnManager.turn_number >= 45:
		state.victory_focus = V2AIStrategyState.VictoryFocus.MILITARY_SUPREMACY if posmod(state.strategy_seed, 2) == 0 else V2AIStrategyState.VictoryFocus.TRANSCENDENCE
	if state.victory_focus == V2AIStrategyState.VictoryFocus.MILITARY_SUPREMACY and state.preferred_doctrine_branches.size() < 2:
		_append_distinct(state.preferred_doctrine_branches, _branch_for_role_set_excluding(V2ResearchNode.TreeType.MILITARY_DOCTRINE, COMPLEMENT_ROLES + CORE_ROLES, state.strategy_seed / 17 + 4, state.preferred_doctrine_branches))
	elif state.victory_focus == V2AIStrategyState.VictoryFocus.TRANSCENDENCE and state.preferred_magic_branches.size() < 2:
		_append_distinct(state.preferred_magic_branches, _branch_for_role_set_excluding(V2ResearchNode.TreeType.MAGIC_SCHOOL, MAGIC_PRESSURE_ROLES + MAGIC_SUPPORT_ROLES, state.strategy_seed / 19 + 5, state.preferred_magic_branches))

static func _tree_progress(player: PlayerData, tree_type: int) -> float:
	var result := 0.0
	for node in V2ResearchDatabase.nodes_for_tree(tree_type):
		if player.v2_research.is_completed(node.id):
			result += 1.0
		else:
			result += player.v2_research.get_progress_ratio(node.id)
	return result

static func _choose_research(player: PlayerData) -> void:
	var available: Array[V2ResearchNode] = []
	for node in V2ResearchDatabase.all_nodes():
		if player.v2_research.is_available(node.id):
			available.append(node)
	if available.is_empty():
		return
	available.sort_custom(func(a: V2ResearchNode, b: V2ResearchNode) -> bool: return a.id < b.id)
	var best: V2ResearchNode = null
	var best_score := -INF
	for node in available:
		var score := research_score(player, node)
		if score > best_score:
			best_score = score
			best = node
	if best == null:
		return
	var active := player.v2_research.active_id
	if active != "" and active != best.id:
		var active_node := V2ResearchDatabase.get_node(active)
		var urgent := _economic_urgency(player, best.branch_role) >= 40.0
		if not urgent or player.v2_research.get_progress_ratio(active) >= V2AITuning.RESEARCH_SWITCH_MAX_PROGRESS:
			return
		if active_node != null and best_score < research_score(player, active_node) + V2AITuning.RESEARCH_SWITCH_MARGIN:
			return
	player.v2_research.select_research(best.id)
	player.v2_ai_strategy.last_reasons = ["Pesquisa: %s (%.1f)" % [best.display_name, best_score]]

static func research_score(player: PlayerData, node: V2ResearchNode) -> float:
	var state: V2AIStrategyState = player.v2_ai_strategy
	var tree_key := "infrastructure"
	if node.tree_type == V2ResearchNode.TreeType.MILITARY_DOCTRINE:
		tree_key = "military"
	elif node.tree_type == V2ResearchNode.TreeType.MAGIC_SCHOOL:
		tree_key = "magic"
	var orientation_key := V2AIStrategyState.orientation_name(state.orientation)
	var score := float(V2AITuning.ORIENTATION_RESEARCH.get(orientation_key, {}).get(tree_key, 10.0))
	if node.branch in state.preferred_doctrine_branches or node.branch in state.preferred_magic_branches:
		score += 28.0
	if node.branch == state.adaptive_doctrine_branch:
		score += 12.0
	if node.is_universal:
		var right_focus := (node.tree_type == V2ResearchNode.TreeType.MILITARY_DOCTRINE and state.victory_focus == V2AIStrategyState.VictoryFocus.MILITARY_SUPREMACY) or (node.tree_type == V2ResearchNode.TreeType.MAGIC_SCHOOL and state.victory_focus == V2AIStrategyState.VictoryFocus.TRANSCENDENCE)
		score += 100.0 if right_focus else -20.0
	else:
		score += node.tier * 1.8
		score += 8.0 if node.tier_role in ["training_structure", "school_building", "base_unit", "caster"] else 0.0
	if node.tree_type == V2ResearchNode.TreeType.INFRASTRUCTURE:
		score += _economic_urgency(player, node.branch_role)
		var foundation_count := 0
		for info in V2ResearchDatabase.branches_for_tree(V2ResearchNode.TreeType.INFRASTRUCTURE):
			var first := V2ResearchDatabase.nodes_for_branch(V2ResearchNode.TreeType.INFRASTRUCTURE, String(info.id))[0]
			if player.v2_research.is_completed(first.id):
				foundation_count += 1
		if node.tier == 1 and foundation_count < V2AITuning.INFRA_FOUNDATION_BRANCHES:
			score += V2AITuning.INFRA_FOUNDATION_BONUS
	# Prefer a partially researched item without overriding true emergencies.
	score += player.v2_research.get_progress_ratio(node.id) * 10.0
	return score - node.cost * 0.006

static func _economic_urgency(player: PlayerData, role: String) -> float:
	match role:
		"gold":
			return 90.0 if V2EconomyRuntime.is_gold_deficit(player) else (28.0 if V2EconomyRuntime.player_gold_net_income(player) < 1.0 else 4.0)
		"supplies":
			var cap := maxf(1.0, V2EconomyRuntime.player_supply_capacity(player))
			return 65.0 if float(V2LogisticsRuntime.player_supply_used(player)) / cap >= V2AITuning.SUPPLY_WARNING_RATIO else 5.0
		"production":
			var average := 0.0
			for city in player.cities:
				average += V2EconomyRuntime.city_production_income(city)
			average /= maxf(player.cities.size(), 1)
			return 30.0 if average < 6.0 else 4.0
		"knowledge":
			return V2AITuning.KNOWLEDGE_RESEARCH_URGENCY if player.v2_research.completed_ids.size() < V2ResearchDatabase.all_nodes().size() else -20.0
		"mana":
			return 36.0 if player.v2_ai_strategy.orientation == V2AIStrategyState.Orientation.ARCANE and player.mana < strategic_mana_reserve(player) else 4.0
		"city_fortification":
			# Urbanização deixa de ser cosmética quando uma cidade já usa a
			# maior parte dos slots. O valor precisa superar uma preferência
			# temática: sem isso a IA enchia Cidade I e jamais pesquisava a rota
			# real que desbloqueia o próximo nível.
			return 85.0 if player.cities.any(func(c): return c.used_building_slots() >= int(ceil(c.max_building_slots() * V2AITuning.CITY_SLOT_PRESSURE))) else 3.0
	return 0.0

static func strategic_mana_reserve(player: PlayerData) -> float:
	if player.v2_ai_strategy.victory_focus == V2AIStrategyState.VictoryFocus.TRANSCENDENCE:
		if V2TranscendenceSystem.has_access(player) and not V2TranscendenceSystem.has_active_ritual(player):
			return V2TranscendenceSystem.MANA_COST
		var largest := 0.0
		for node in V2ResearchDatabase.nodes_for_tree(V2ResearchNode.TreeType.MAGIC_SCHOOL):
			if node.tier_role == "grand_manifestation" and node.branch in player.v2_ai_strategy.preferred_magic_branches and V2UnlockSystem.is_unit_unlocked(player, node.unlock_id):
				largest = maxf(largest, UnitDatabase.create_unit(node.unlock_id).production_mana_cost)
		if V2ManifestationSystem.active_manifestation_count(player) < V2TranscendenceSystem.MANIFESTATIONS_REQUIRED:
			return maxf(largest, 20.0)
	return 12.0

static func _annex_known_tiles(player: PlayerData, view: V2AIWorldView) -> void:
	for city in player.cities:
		while city.annexation_points > 0:
			var candidates := city.eligible_annexation_tiles(view.grid)
			if candidates.is_empty():
				break
			candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				var sa := _annex_score(a, view)
				var sb := _annex_score(b, view)
				return a.x < b.x if is_equal_approx(sa, sb) and a.x != b.x else (a.y < b.y if is_equal_approx(sa, sb) else sa > sb))
			if not city.annex_tile(candidates[0], view.grid):
				break

static func _annex_score(coord: Vector2i, view: V2AIWorldView) -> float:
	var score := 1.0
	if view.is_visible(coord):
		var tile := view.grid.get_tile(coord)
		if tile != null and V2ResourceImprovementData.has_resource(tile.resource):
			for effect in V2ResourceImprovementData.effects_for_resource(tile.resource):
				score += 8.0 + _economic_urgency(view.observer, String(effect.branch)) * 0.2
	return score

static func _upgrade_units(player: PlayerData, view: V2AIWorldView) -> void:
	if player.gold <= V2AITuning.gold_reserve(player):
		return
	for unit in player.units.duplicate():
		if not is_instance_valid(unit) or not V2ResearchDatabase.is_v2_id(unit.unit_data.visual_kind):
			continue
		var cost := V2UnitUpgrade.upgrade_cost(unit)
		if player.gold - cost >= V2AITuning.gold_reserve(player) and view.visible_hostiles_near(unit.coord, 2).is_empty() and V2UnitUpgrade.can_upgrade(player, unit, view.grid):
			V2UnitUpgrade.perform_upgrade(player, unit, view.grid)

static func _plan_production(player: PlayerData, view: V2AIWorldView) -> void:
	var queued_roles := _queued_roles(player)
	for city in player.cities:
		if city.production_item != "":
			continue
		var choice := _best_production(player, city, view, queued_roles)
		if choice == "":
			continue
		city.set_production(choice)
		player.v2_ai_strategy.last_reasons.append("Produção em %s: %s" % [city.city_name, choice])
		if BuildingDatabase.get_building(choice) != null:
			city.pending_building_coord = _building_site(city, view.grid)
		var role := V2UnitLine.role_of(choice)
		if role != "":
			queued_roles[role] = int(queued_roles.get(role, 0)) + 1

static func _best_production(player: PlayerData, city: City, view: V2AIWorldView, queued_roles: Dictionary) -> String:
	var candidates: Array[String] = []
	for building in BuildingDatabase.all_buildings():
		if city.can_build(building.id) and _building_site(city, view.grid) != City.NO_PENDING_COORD:
			candidates.append(building.id)
	if city.can_start_city_upgrade():
		candidates.append(V2CityLevelData.project_id_for_level(V2CityLevelData.next_level(city.city_level)))
	if city.can_start_fortification() and _city_threat_score(city, view) > 0.0:
		candidates.append(V2FortificationData.project_id(V2FortificationData.next_level(city.fortification_level)))
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		var data := UnitDatabase.create_unit(kind)
		var allowed_v2 := V2ResearchDatabase.is_v2_id(kind) and (V2UnitLine.is_line_unit(kind) or data.is_v2_caster() or V2ManifestationSystem.is_manifestation_kind(kind) or V2LegendarySystem.is_legendary_kind(kind) or V2ConstructorRuntime.is_builder_kind(kind))
		if (allowed_v2 or data.can_found_city) and player.has_unlocked(kind) and city.can_train(kind):
			candidates.append(kind)
	candidates.sort()
	var best := ""
	var best_score := 0.0
	for id in candidates:
		var score := _production_score(player, city, id, view, queued_roles)
		if score > best_score:
			best_score = score
			best = id
	return best

static func _production_score(player: PlayerData, city: City, id: String, view: V2AIWorldView, queued_roles: Dictionary) -> float:
	var building := BuildingDatabase.get_building(id)
	if building != null:
		if building.gold_upkeep > 0.0 and (V2EconomyRuntime.is_gold_deficit(player) or player.gold < V2AITuning.gold_reserve(player)):
			return -100.0
		var branch := V2InfrastructureEconomyData.branch_for_building(id)
		if branch != "":
			var role := String(V2ResearchDatabase.branch_info(V2ResearchNode.TreeType.INFRASTRUCTURE, branch).get("role", ""))
			return 15.0 + _economic_urgency(player, role) - city.building_count(id) * 7.0
		var node := V2ResearchDatabase.node_for_unlock_id(id)
		if node != null:
			var preferred := node.branch in player.v2_ai_strategy.preferred_doctrine_branches or node.branch in player.v2_ai_strategy.preferred_magic_branches or node.branch == player.v2_ai_strategy.adaptive_doctrine_branch
			if node.tier_role in ["training_structure", "school_building"]:
				return 48.0 if preferred else 14.0
			if node.tier_role in ["mastery_structure", "ritual_structure"]:
				return 38.0 if preferred else 8.0
		return 5.0
	if V2CityLevelData.is_city_project(id):
		var target_level := V2CityLevelData.target_level_for_project(id)
		if player.gold - V2CityLevelData.upgrade_gold_cost(target_level) < V2AITuning.gold_reserve(player):
			return -100.0
		var ratio := float(city.used_building_slots()) / maxf(city.max_building_slots(), 1)
		var core_bonus := 15.0 if city == _core_city(player) else 0.0
		return 42.0 + core_bonus if ratio >= V2AITuning.CITY_SLOT_PRESSURE else -5.0
	if V2FortificationData.is_fortification_project(id):
		return 25.0 + _city_threat_score(city, view)
	var data := UnitDatabase.create_unit(id)
	if data.can_found_city:
		var queued_settlers := player.units.filter(func(u): return u.unit_data.can_found_city).size() + player.cities.filter(func(c): return c.production_item != "" and UnitDatabase.create_unit(c.production_item).can_found_city).size()
		var desired := mini(6, 1 + TurnManager.turn_number / 30)
		return 24.0 if player.cities.size() + queued_settlers < desired and CitySite.has_acceptable_site(view.grid, player) else -100.0
	if V2ConstructorRuntime.is_builder_kind(id):
		return 32.0 if _builder_needed(player, view) else -100.0
	var tokens := relevant_unit_count(player) + queued_relevant_count(player)
	if tokens >= V2AITuning.HARD_TOKEN_CAP:
		return -100.0
	var manifestation := V2ManifestationSystem.is_manifestation_kind(id)
	if tokens >= V2AITuning.target_relevant_units(player) and not (manifestation and V2ManifestationSystem.active_manifestation_count(player) < 2):
		return -60.0
	var supply_cap := int(V2EconomyRuntime.player_supply_capacity(player))
	var projected_free := supply_cap - V2LogisticsRuntime.player_supply_used(player) - data.supply_cost
	var war := not player.enemies.is_empty()
	var buffer := maxi(V2AITuning.SUPPLY_FREE_MIN, int(ceil(supply_cap * V2AITuning.SUPPLY_FREE_RATIO)))
	if not war and projected_free < buffer and data.supply_cost > 0:
		return -40.0
	if manifestation:
		var need := V2TranscendenceSystem.MANIFESTATIONS_REQUIRED - V2ManifestationSystem.active_manifestation_count(player)
		return 90.0 if player.v2_ai_strategy.victory_focus == V2AIStrategyState.VictoryFocus.TRANSCENDENCE and need > 0 else 18.0
	if V2LegendarySystem.is_legendary_kind(id):
		return 72.0 if player.v2_ai_strategy.orientation == V2AIStrategyState.Orientation.MILITARY else 32.0
	if data.is_v2_caster():
		var count := player.units.filter(func(u): return u.unit_data.v2_magic_school == data.v2_magic_school).size()
		for queued_city in player.cities:
			if queued_city.production_item in UnitDatabase.PLAYER_TRAINABLE_KINDS and UnitDatabase.create_unit(queued_city.production_item).v2_magic_school == data.v2_magic_school:
				count += 1
		return (55.0 if player.v2_ai_strategy.orientation == V2AIStrategyState.Orientation.ARCANE else 25.0) - count * 12.0
	var role := V2UnitLine.role_of(id)
	var desired_role := _desired_role_count(player, role)
	var current := player.units.filter(func(u): return V2UnitLine.role_of(u.unit_data.visual_kind) == role).size() + int(queued_roles.get(role, 0))
	if role == "" or current >= desired_role:
		return -10.0
	return 18.0 + (desired_role - current) * 14.0 + data.attack * 0.15

static func _desired_role_count(player: PlayerData, role: String) -> int:
	if role == "":
		return 0
	var target := V2AITuning.target_relevant_units(player)
	var branches := player.v2_ai_strategy.preferred_doctrine_branches.duplicate()
	if player.v2_ai_strategy.adaptive_doctrine_branch != "":
		branches.append(player.v2_ai_strategy.adaptive_doctrine_branch)
	var preferred_roles: Array[String] = []
	for branch in branches:
		preferred_roles.append(String(V2ResearchDatabase.branch_info(V2ResearchNode.TreeType.MILITARY_DOCTRINE, branch).get("role", "")))
	return maxi(1, int(ceil(target * (0.35 if role in preferred_roles else 0.08))))

static func _queued_roles(player: PlayerData) -> Dictionary:
	var result := {}
	for city in player.cities:
		var role := V2UnitLine.role_of(city.production_item)
		if role != "":
			result[role] = int(result.get(role, 0)) + 1
	return result

static func relevant_unit_count(player: PlayerData) -> int:
	var count := 0
	for unit in player.units:
		if not is_instance_valid(unit) or unit.hp <= 0.0 or unit.unit_data.can_found_city or V2ConstructorRuntime.is_builder_unit(unit):
			continue
		if unit.unit_data.attack > 0.0 or unit.unit_data.is_v2_caster() or unit.unit_data.has_trait(UnitData.TRAIT_RETINUE) or V2ManifestationSystem.is_manifestation_unit(unit) or V2LegendarySystem.is_legendary_unit(unit):
			count += 1
	return count

static func queued_relevant_count(player: PlayerData) -> int:
	var count := 0
	for city in player.cities:
		if city.production_item == "" or city.production_item not in UnitDatabase.PLAYER_TRAINABLE_KINDS:
			continue
		var data := UnitDatabase.create_unit(city.production_item)
		if not data.can_found_city and not V2ConstructorRuntime.is_builder_kind(city.production_item):
			count += 1
	return count

static func _builder_needed(player: PlayerData, view: V2AIWorldView) -> bool:
	var builders := player.units.filter(func(u): return V2ConstructorRuntime.is_builder_unit(u) and u.work_charges_remaining > 0).size()
	builders += player.cities.filter(func(c): return V2ConstructorRuntime.is_builder_kind(c.production_item)).size()
	if builders >= maxi(1, int(ceil(player.cities.size() / 2.0))):
		return false
	return not known_unimproved_resources(player, view).is_empty()

static func known_unimproved_resources(player: PlayerData, view: V2AIWorldView) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for city in player.cities:
		for coord in city.owned_tiles:
			if not view.is_visible(coord) or city.resource_improvements.has(coord):
				continue
			var tile := view.grid.get_tile(coord)
			if tile != null and V2ResourceImprovementData.has_resource(tile.resource) and view.grid.get_building_at(coord) == null:
				result.append(coord)
	result.sort_custom(func(a: Vector2i, b: Vector2i): return a.x < b.x if a.x != b.x else a.y < b.y)
	return result

static func _city_threat_score(city: City, view: V2AIWorldView) -> float:
	var score := view.visible_hostiles_near(city.coord, V2AITuning.LOCAL_THREAT_RADIUS).size() * 12.0
	if V2TranscendenceSystem.has_active_ritual(city.owner_player) and V2TranscendenceSystem.ritual_site_coord(city.owner_player) == city.coord:
		score += 40.0
	if city.hp < city.max_hp() * 0.65 or city.shield < city.max_shield() * 0.35:
		score += 15.0
	return score

static func _core_city(player: PlayerData) -> City:
	var result: City = null
	var best := -INF
	for city in player.cities:
		var score := V2EconomyRuntime.city_production_income(city) + city.city_level * 5.0
		if score > best:
			best = score
			result = city
	return result

static func _building_site(city: City, grid: HexGrid) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for coord in city.owned_tiles:
		if city.is_valid_building_tile(coord, grid):
			candidates.append(coord)
	for coord in grid.get_neighbors(city.coord):
		if city.is_valid_building_tile(coord, grid) and coord not in candidates:
			candidates.append(coord)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i): return a.x < b.x if a.x != b.x else a.y < b.y)
	return candidates[0] if not candidates.is_empty() else City.NO_PENDING_COORD

static func _start_ritual_if_ready(player: PlayerData, view: V2AIWorldView) -> void:
	if player.v2_ai_strategy.victory_focus != V2AIStrategyState.VictoryFocus.TRANSCENDENCE or V2TranscendenceSystem.has_active_ritual(player):
		return
	var best_city: City = null
	var best := -INF
	for city in player.cities:
		if not V2TranscendenceSystem.can_start_ritual(player, city):
			continue
		var score := city.city_level * 8.0 + city.fortification_level * 12.0 + city.hp + city.shield - _city_threat_score(city, view)
		if score > best:
			best = score
			best_city = city
	if best_city != null:
		V2TranscendenceSystem.start_ritual(player, best_city)

static func strategic_target_coord(player: PlayerData, view: V2AIWorldView) -> Variant:
	var ritual_site = public_ritual_target_coord(view)
	if ritual_site != null:
		return ritual_site
	if not view.own_lost_cities.is_empty():
		return view.own_lost_cities[0].coord
	if player.v2_ai_strategy.victory_focus == V2AIStrategyState.VictoryFocus.MILITARY_SUPREMACY:
		var pending_ids: Dictionary = {}
		for rival in V2VictoryConditions.military_supremacy_status(player).rivals:
			if rival.reason == V2VictoryConditions.REASON_PENDING:
				pending_ids[int(rival.player_id)] = true
		for city in view.known_enemy_cities:
			# City level is not public through fog. A known-but-currently-hidden
			# city remains a normal campaign target, but never a specialized
			# Supremacy target based on secret development.
			if bool(city.visible) and bool(city.get("developed", false)) and pending_ids.has(int(city.owner_id)) and bool(city.at_war):
				return city.coord
	# A campanha V1 continua sendo a memória territorial oficial durante a
	# transição. Só lemos o alvo público já escolhido; se não houver campanha,
	# uma cidade previamente conhecida e em guerra é um objetivo legítimo para
	# posicionamento, voo, infiltração e portais.
	for opponent in player.war_campaigns:
		var campaign: Dictionary = player.war_campaigns[opponent]
		if campaign.get("status", "") == "active" and player.is_at_war_with(opponent):
			return campaign.get("target_coord")
	var known_war_cities := view.known_enemy_cities.filter(func(city): return bool(city.at_war))
	if not known_war_cities.is_empty():
		var anchor := _core_city(player).coord if _core_city(player) != null else Vector2i.ZERO
		known_war_cities.sort_custom(func(a: Dictionary, b: Dictionary):
			var da := HexMetrics.axial_distance(anchor, a.coord)
			var db := HexMetrics.axial_distance(anchor, b.coord)
			return da < db if da != db else _coord_less(a.coord, b.coord))
		return known_war_cities[0].coord
	return null

## Sede do Ritual Final público mais urgente de um rival (menos rodadas restantes; empate pela
## coordenada) — o alvo que sobrepõe qualquer campanha. null sem Ritual público visível.
static func public_ritual_target_coord(view: V2AIWorldView) -> Variant:
	var rituals := view.public_enemy_rituals()
	if rituals.is_empty():
		return null
	rituals.sort_custom(func(a: Dictionary, b: Dictionary):
		if int(a.remaining_rounds) != int(b.remaining_rounds):
			return int(a.remaining_rounds) < int(b.remaining_rounds)
		return _coord_less(a.site_coord, b.site_coord))
	return rituals[0].site_coord

static func public_ritual_info_for(player: PlayerData) -> Dictionary:
	if player == null:
		return {}
	var stable_id := V2VictoryConditions.stable_id(player)
	for info in V2TranscendenceSystem.public_rituals():
		if int(info.owner_index) == stable_id:
			return info.duplicate()
	return {}

static func public_ritual_war_pressure(player: PlayerData) -> float:
	var info := public_ritual_info_for(player)
	return float(V2AITuning.RITUAL_WAR_PRESSURE.get(int(info.get("remaining_rounds", 0)), 0.0))

static func _dominant_economic_need(player: PlayerData) -> String:
	var best_role := "none"
	var best_score := -INF
	for role in ["gold", "supplies", "production", "knowledge", "mana", "city_fortification"]:
		var score := _economic_urgency(player, role)
		if score > best_score:
			best_score = score
			best_role = role
	return "%s(%.0f)" % [best_role, best_score]

static func ritual_urgency(remaining: int) -> float:
	return {4: 15.0, 3: 35.0, 2: 70.0, 1: 120.0}.get(remaining, 0.0)

static func debug_snapshot(player: PlayerData) -> Dictionary:
	return {
		"orientation": V2AIStrategyState.orientation_name(player.v2_ai_strategy.orientation),
		"victory_focus": V2AIStrategyState.focus_name(player.v2_ai_strategy.victory_focus),
		"research": player.v2_research.active_id,
		"army": relevant_unit_count(player),
		"army_target": V2AITuning.target_relevant_units(player),
		"supply_used": V2LogisticsRuntime.player_supply_used(player),
		"supply_capacity": V2EconomyRuntime.player_supply_capacity(player),
		"economic_need": _dominant_economic_need(player),
		"reasons": player.v2_ai_strategy.last_reasons.duplicate(),
	}

static func _coord_less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x if a.x != b.x else a.y < b.y
