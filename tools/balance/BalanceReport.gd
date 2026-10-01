class_name BalanceReport
extends RefCounted

## Fase 33B — agregação do Release Balance Lab e baseline numérica.
##
## `numeric_baseline()` lê os valores ATUAIS direto das fontes centrais (bancos de dados/constantes
## do runtime) — nunca de memória — para registrar RELEASE_BALANCE_BASELINE_PRE_TUNING.
## `build_report(dir)` lê os JSON por partida de `dir`, escreve matches.csv, civs.csv, wars.csv,
## rituals.csv, aggregate.json e report.md no MESMO diretório (user://, não versionado).
##
## Estatística: timeouts nunca entram como turno de vitória (são censurados e contados à parte);
## marcos mostram sempre reached/total; nenhum índice sintético de balanceamento é produzido.

const SUPREMACY_LOWER_BOUND_KEY := "supremacy_research_lower_bound"
const MILESTONES := [
	"first_production", "first_non_settler_production", "first_settler_produced", "second_city_founded", "third_city_founded", "fourth_city_founded",
	"n1", "n3", "n5", "n7", "n9_first", "n9_second", "military_n9_first", "military_n9_second", "magic_n9_first", "magic_n9_second",
	"infra_1", "infra_2", "infra_3", "supreme_army", "transcendence", "supremacy_research_ready", "transcendence_research_ready",
	"first_combat_unit", "first_n3_unit", "first_n5_form", "first_n7_form", "first_caster", "first_builder", "first_trained_settler",
	"first_legendary", "first_manifestation", "second_distinct_manifestation", "two_active_manifestations", "transcendence_ritual_ready", "first_ritual_start",
	"city_level_2", "city_level_3", "city_level_4", "fortification_1", "fortification_2", "fortification_3", "focus_resolved",
]
const ORIENTATION_MILESTONES := ["n9_first", "n9_second", "supreme_army", "transcendence", "supremacy_research_ready", "transcendence_research_ready", "transcendence_ritual_ready", "first_manifestation", "two_active_manifestations", "city_level_3"]
const CHECKPOINTS := [30, 50, 75, 100, 150, 200]
const VICTORY_TYPES := ["DOMINATION", "MILITARY_SUPREMACY", "TRANSCENDENCE", "TIMEOUT", "UNKNOWN_END_REASON"]

# =============================================================================================
# Baseline numérica (lida do código-fonte)
# =============================================================================================

static func numeric_baseline() -> Dictionary:
	return {
		"baseline_id": BalanceSeedSet.BASELINE_ID,
		"research": research_mathematics(),
		"economy": _economy_baseline(),
		"city": {"levels": V2CityLevelData.LEVELS, "upgrade_costs": V2CityLevelData.UPGRADE_COSTS, "max_hp_by_level": V2CityLevelData.MAX_HP_BY_LEVEL, "developed_min_level": V2CityLevelData.DEVELOPED_MIN_LEVEL, "fortifications": V2FortificationData.LEVELS},
		"units": _unit_baseline(),
		"magic": _magic_baseline(),
		"races": _race_baseline(),
		"ai": _ai_baseline(),
		"production_mathematics": production_mathematics(),
		"building_payback": building_payback(),
	}

static func research_mathematics() -> Dictionary:
	var branch_costs: Array = V2ResearchDatabase.BRANCH_TIER_COSTS
	var cumulative: Array = []
	var running := 0.0
	for cost in branch_costs:
		running += float(cost)
		cumulative.append(running)
	var one_line: float = cumulative.back()
	var infra_costs: Array = V2ResearchDatabase.INFRASTRUCTURE_TIER_COSTS
	var infra_line := 0.0
	for cost in infra_costs:
		infra_line += float(cost)
	var counts := {}
	var totals := {}
	for tree in V2ResearchDatabase.tree_types():
		var key: String = BalanceTelemetry.TREE_KEYS[tree]
		counts[key] = V2ResearchDatabase.nodes_for_tree(tree).size()
		var total := 0.0
		for node in V2ResearchDatabase.nodes_for_tree(tree):
			total += node.cost
		totals[key] = total
	var capstone: float = V2ResearchDatabase.CAPSTONE_COST
	# Pré-requisito real do capstone = CAPSTONE_REQUIRED_BRANCHES linhas completas da própria árvore.
	var lower_bound := one_line * V2ResearchDatabase.CAPSTONE_REQUIRED_BRANCHES + capstone
	# Caminho mínimo PRÁTICO até o Ritual pronto usando só pesquisa: as duas Escolas N9 já incluem a
	# Estrutura Ritual (N8) e a Manifestação (N9) de cada uma — nenhum nó extra é exigido.
	return {
		"branch_tier_costs": branch_costs,
		"branch_cumulative": cumulative,
		"one_line_n1_n9": one_line,
		"two_lines_n1_n9": one_line * 2.0,
		"capstone_cost": capstone,
		"capstone_required_branches": V2ResearchDatabase.CAPSTONE_REQUIRED_BRANCHES,
		"infrastructure_tier_costs": infra_costs,
		"infrastructure_line": infra_line,
		"infrastructure_branches": V2ResearchDatabase.INFRASTRUCTURE_BRANCHES.size(),
		"infrastructure_total": infra_line * V2ResearchDatabase.INFRASTRUCTURE_BRANCHES.size(),
		"node_counts": counts,
		"tree_totals": totals,
		"all_research_total": float(totals.military) + float(totals.magic) + float(totals.infrastructure),
		SUPREMACY_LOWER_BOUND_KEY: lower_bound,
		"transcendence_research_lower_bound": lower_bound,
		"urbanization_for_city_iii": float(infra_costs[0]) + float(infra_costs[1]),
		"urbanization_for_city_iv": infra_line,
		"notes": "Lower bound = 2 linhas completas N1-N9 + capstone da mesma árvore; ignora qualquer Infraestrutura. É limite matemático de Conhecimento, não previsão de turno.",
	}

static func _economy_baseline() -> Dictionary:
	var buildings := {}
	for branch in V2InfrastructureEconomyData.BUILDINGS:
		var entry: Dictionary = V2InfrastructureEconomyData.BUILDINGS[branch]
		var building := BuildingDatabase.get_building(String(entry.building_id))
		buildings[branch] = {
			"building_id": entry.building_id,
			"resource": entry.resource,
			"production_cost": entry.production_cost,
			"yields_by_tier": entry.yields,
			"gold_upkeep": building.gold_upkeep if building != null else 0.0,
		}
	return {
		"base_per_city": {
			"gold": V2InfrastructureEconomyData.BASE_GOLD_PER_CITY,
			"supply": V2InfrastructureEconomyData.BASE_SUPPLY_PER_CITY,
			"production": V2InfrastructureEconomyData.BASE_PRODUCTION_PER_CITY,
			"knowledge": V2InfrastructureEconomyData.BASE_KNOWLEDGE_PER_CITY,
			"mana": V2InfrastructureEconomyData.BASE_MANA_PER_CITY,
		},
		"economic_buildings": buildings,
		"deficit_output_multiplier": V2EconomyRuntime.DEFICIT_OUTPUT_MULTIPLIER,
		"tension_multiplier": V2LogisticsRuntime.TENSION_MULTIPLIER,
		"war_upkeep_gold_per_military_unit": Diplomacy.WAR_UPKEEP_GOLD_PER_MILITARY_UNIT,
		"upgrade_gold_per_production_point": V2UnitUpgrade.GOLD_PER_PRODUCTION_POINT,
	}

static func _unit_facts(kind: String) -> Dictionary:
	var data := UnitDatabase.create_unit(kind)
	return {"id": kind, "pp": data.production_cost, "mana": data.production_mana_cost, "supply": data.supply_cost, "attack": data.attack, "defense": data.defense, "hp": data.max_hp, "move": data.movement_points}

static func _unit_baseline() -> Dictionary:
	var doctrines := {}
	for info in V2ResearchDatabase.DOCTRINE_BRANCHES:
		var branch := String(info.id)
		var line := {}
		for node in V2ResearchDatabase.nodes_for_branch(V2ResearchNode.TreeType.MILITARY_DOCTRINE, branch):
			match node.tier_role:
				"training_structure", "mastery_structure":
					var building := BuildingDatabase.get_building(node.unlock_id)
					if building != null:
						line[node.tier_role] = {"id": node.unlock_id, "pp": building.production_cost, "gold_upkeep": building.gold_upkeep}
				"base_unit", "evolution_1", "elite_form", "legendary_candidate":
					if UnitDatabase.PLAYER_TRAINABLE_KINDS.has(node.unlock_id) or V2ResearchDatabase.is_v2_id(node.unlock_id):
						line[node.tier_role] = _unit_facts(node.unlock_id)
		if line.has("base_unit") and line.has("evolution_1"):
			line.upgrade_gold_n3_n5 = maxf(0.0, V2UnitUpgrade.GOLD_PER_PRODUCTION_POINT * (float(line.evolution_1.pp) - float(line.base_unit.pp)))
		if line.has("evolution_1") and line.has("elite_form"):
			line.upgrade_gold_n5_n7 = maxf(0.0, V2UnitUpgrade.GOLD_PER_PRODUCTION_POINT * (float(line.elite_form.pp) - float(line.evolution_1.pp)))
		doctrines[branch] = line
	return {
		"settler": _unit_facts("settler"),
		"builder": _unit_facts("v2_unit_builder"),
		"doctrines": doctrines,
		"legendary_max_active": V2LegendarySystem.max_active(),
		"normal_token_cap": V2AITuning.NORMAL_TOKEN_CAP,
		"hard_token_cap": V2AITuning.HARD_TOKEN_CAP,
	}

static func _magic_baseline() -> Dictionary:
	var schools := {}
	for info in V2ResearchDatabase.MAGIC_BRANCHES:
		var branch := String(info.id)
		var line := {}
		for node in V2ResearchDatabase.nodes_for_branch(V2ResearchNode.TreeType.MAGIC_SCHOOL, branch):
			match node.tier_role:
				"school_building", "ritual_structure":
					var building := BuildingDatabase.get_building(node.unlock_id)
					if building != null:
						line[node.tier_role] = {"id": node.unlock_id, "pp": building.production_cost, "gold_upkeep": building.gold_upkeep}
				"caster", "grand_manifestation":
					line[node.tier_role] = _unit_facts(node.unlock_id)
		schools[branch] = line
	var spells := []
	for spell in V2SpellDatabase.all_spells():
		spells.append({"id": spell.id, "school": spell.school_branch, "mana": spell.mana_cost, "cooldown": spell.cooldown_turns, "damage": spell.damage_amount, "heal": spell.heal_amount})
	var techniques := []
	for technique in V2DoctrineTechniqueDatabase.all_techniques():
		techniques.append({"id": technique.id, "branch": technique.doctrine_branch, "cooldown": technique.cooldown_turns, "strike": technique.strike_multiplier})
	return {
		"schools": schools,
		"spells": spells,
		"techniques": techniques,
		"ritual": {"mana_cost": V2TranscendenceSystem.MANA_COST, "rounds": V2TranscendenceSystem.ROUNDS_REQUIRED, "manifestations_required": V2TranscendenceSystem.MANIFESTATIONS_REQUIRED},
		"manifestation_max_per_school": V2ManifestationSystem.MAX_PER_SCHOOL,
	}

static func _race_baseline() -> Dictionary:
	var result := {}
	for profile in V2RaceBonusDatabase.all_profiles():
		result[profile.race_id] = {
			"gold_income_multiplier": profile.gold_income_multiplier,
			"supply_capacity_multiplier": profile.supply_capacity_multiplier,
			"city_production_multiplier": profile.city_production_multiplier,
			"knowledge_income_multiplier": profile.knowledge_income_multiplier,
			"mana_income_multiplier": profile.mana_income_multiplier,
			"unit_attack_multiplier": profile.unit_attack_multiplier,
			"builder_charge_bonus": profile.builder_charge_bonus,
			"annexation_point_bonus": profile.annexation_point_bonus,
		}
	return result

static func _ai_baseline() -> Dictionary:
	return {
		"orientation_research": V2AITuning.ORIENTATION_RESEARCH,
		"research_switch_max_progress": V2AITuning.RESEARCH_SWITCH_MAX_PROGRESS,
		"research_switch_margin": V2AITuning.RESEARCH_SWITCH_MARGIN,
		"knowledge_research_urgency": V2AITuning.KNOWLEDGE_RESEARCH_URGENCY,
		"infra_foundation_branches": V2AITuning.INFRA_FOUNDATION_BRANCHES,
		"infra_foundation_bonus": V2AITuning.INFRA_FOUNDATION_BONUS,
		"gold_reserve_base": V2AITuning.GOLD_RESERVE_BASE,
		"gold_reserve_per_city": V2AITuning.GOLD_RESERVE_PER_CITY,
		"normal_token_cap": V2AITuning.NORMAL_TOKEN_CAP,
		"hard_token_cap": V2AITuning.HARD_TOKEN_CAP,
		"supply_warning_ratio": V2AITuning.SUPPLY_WARNING_RATIO,
		"supply_free_ratio": V2AITuning.SUPPLY_FREE_RATIO,
		"city_slot_pressure": V2AITuning.CITY_SLOT_PRESSURE,
		"ritual_war_pressure": V2AITuning.RITUAL_WAR_PRESSURE,
		"settler_desired_formula": "min(6, 1 + turn/30) (V2StrategicAI._production_score)",
		"balanced_focus_resolution_turn": 45,
		"war_score_threshold": RivalAI.WAR_SCORE_THRESHOLD,
		"war_declare_chance_when_ready": RivalAI.WAR_DECLARE_CHANCE_WHEN_READY,
		"war_proximity_range": RivalAI.WAR_PROXIMITY_RANGE,
		"war_weariness_offer_peace": RivalAI.WAR_WEARINESS_OFFER_PEACE_THRESHOLD,
		"war_weariness_accepts_peace": Diplomacy.WAR_WEARINESS_ACCEPTS_PEACE_THRESHOLD,
		"truce_turns": Diplomacy.TRUCE_TURNS,
	}

## Tempo teórico de produção local (ceil(custo / PP)) para PP 4/6/8/10. Sem overflow entre itens.
static func production_mathematics() -> Dictionary:
	var items := {
		"settler": UnitDatabase.create_unit("settler").production_cost,
		"builder": UnitDatabase.create_unit("v2_unit_builder").production_cost,
		"guardian_n3_unit": UnitDatabase.create_unit("v2_unit_shieldbearer").production_cost,
		"guardian_n5_unit": UnitDatabase.create_unit("v2_unit_guardian").production_cost,
		"guardian_n7_unit": UnitDatabase.create_unit("v2_unit_sentinel").production_cost,
		"training_hall_n2": BuildingDatabase.get_building("v2_building_guardian_hall").production_cost,
		"mastery_n8": BuildingDatabase.get_building("v2_building_guardian_mastery").production_cost,
		"legendary_guardian": UnitDatabase.create_unit("v2_legendary_guardian_champion").production_cost,
		"manifestation_seraph": UnitDatabase.create_unit("v2_manifestation_seraph").production_cost,
		"market": V2InfrastructureEconomyData.production_cost_for_branch("economy"),
		"academy": V2InfrastructureEconomyData.production_cost_for_branch("academy"),
		"city_ii": V2CityLevelData.upgrade_production_cost(2),
		"city_iii": V2CityLevelData.upgrade_production_cost(3),
		"city_iv": V2CityLevelData.upgrade_production_cost(4),
		"walls_i": V2FortificationData.production_cost(1),
		"walls_ii": V2FortificationData.production_cost(2),
		"fortress": V2FortificationData.production_cost(3),
	}
	for school in V2ResearchDatabase.MAGIC_BRANCHES:
		for node in V2ResearchDatabase.nodes_for_branch(V2ResearchNode.TreeType.MAGIC_SCHOOL, String(school.id)):
			if node.tier_role == "ritual_structure" and String(school.id) == "sacred":
				items["ritual_structure_n8"] = BuildingDatabase.get_building(node.unlock_id).production_cost
			if node.tier_role == "caster" and String(school.id) == "sacred":
				items["caster_n3"] = UnitDatabase.create_unit(node.unlock_id).production_cost
	var table := {}
	for item in items:
		var turns := {}
		for pp in [4, 6, 8, 10]:
			turns[str(pp)] = int(ceil(float(items[item]) / float(pp)))
		table[item] = {"pp": items[item], "turns_at_pp": turns}
	return table

## Payback (metodologia F27 estendida): turnos para o rendimento acumulado igualar o custo em PP,
## com paridade 1 PP = 1 unidade do recurso = 1 Ouro (upkeep descontado do rendimento). É um proxy de
## comparação entre prédios, não um preço de mercado.
static func building_payback() -> Dictionary:
	var result := {}
	for branch in V2InfrastructureEconomyData.BUILDINGS:
		var entry: Dictionary = V2InfrastructureEconomyData.BUILDINGS[branch]
		var building := BuildingDatabase.get_building(String(entry.building_id))
		var upkeep := building.gold_upkeep if building != null else 0.0
		var tiers := {}
		for tier in 3:
			var yield_value := float(entry.yields[tier])
			var net := yield_value - upkeep
			tiers["tier_%d" % (tier + 1)] = {"yield": yield_value, "upkeep": upkeep, "net": net, "payback_turns": snappedf(float(entry.production_cost) / net, 0.1) if net > 0.0 else -1.0}
		result[entry.building_id] = {"resource": entry.resource, "pp": entry.production_cost, "tiers": tiers}
	return result

# =============================================================================================
# Agregação
# =============================================================================================

static func load_records(dir: String) -> Array:
	var records: Array = []
	var access := DirAccess.open(dir)
	if access == null:
		return records
	var names := Array(access.get_files())
	names.sort()
	for file_name in names:
		if not String(file_name).ends_with(".json") or String(file_name).begins_with("tmp_") or file_name in ["aggregate.json"]:
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [dir, file_name]))
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("civs"):
			records.append(parsed)
	return records

static func build_report(dir: String, cap: int = BalanceSeedSet.TURN_CAP) -> Dictionary:
	var records := load_records(dir)
	if records.is_empty():
		return {"matches": 0}
	var aggregate := aggregate_records(records, cap)
	_write_text("%s/aggregate.json" % dir, JSON.stringify(aggregate, "\t"))
	_write_text("%s/aggregate_summary.json" % dir, JSON.stringify(compact_aggregate(aggregate), "\t"))
	_write_csv("%s/matches.csv" % dir, match_rows(records))
	_write_csv("%s/civs.csv" % dir, civ_rows(records, cap))
	_write_csv("%s/wars.csv" % dir, war_rows(records))
	_write_csv("%s/rituals.csv" % dir, ritual_rows(records))
	_write_text("%s/report.md" % dir, markdown(aggregate))
	return {"matches": records.size()}

static func aggregate_records(records: Array, cap: int) -> Dictionary:
	var civs := all_civs(records)
	var math := research_mathematics()
	var result := {
		"baseline_id": BalanceSeedSet.BASELINE_ID,
		"sample": _sample(records, civs, cap),
		"victories": _victories(records),
		"milestones": {},
		"by_orientation": _grouped(civs, "orientation", records, cap),
		"by_race": _grouped(civs, "race", records, cap),
		"by_seat": _grouped(civs, "seat", records, cap),
		"research": _research(civs, math, cap),
		"economy": _economy(civs),
		"opening_expansion": _opening(civs, cap),
		"production": _production(civs, cap),
		"army": _army(civs),
		"wars": _wars(records),
		"supremacy": _supremacy(records, civs, cap),
		"transcendence": _transcendence(records, civs, cap),
		"domination": _domination(records),
		"outliers": _outliers(records, cap),
		"performance": _performance(records),
		"engagement": _engagement(records, civs, cap),
	}
	for key in MILESTONES:
		result.milestones[key] = milestone_distribution(civs, key, cap)
	return result

## Versão compacta e versionável do agregado: mesmas estatísticas, outliers só com diagnóstico curto
## (sem trace por 10 turnos nem timeout report completo, que ficam no aggregate.json em user://).
static func compact_aggregate(aggregate: Dictionary) -> Dictionary:
	var compact := aggregate.duplicate(true)
	var outliers: Dictionary = compact.outliers
	for key in ["late_gt_200", "timeouts"]:
		var short: Array = []
		for entry in outliers[key]:
			short.append({
				"match_id": entry.match_id, "seed": entry.seed, "end_reason": entry.end_reason, "turn": entry.turn,
				"primary_category": entry.primary_category, "secondary_categories": entry.secondary_categories,
				"winner_timeline": entry.winner_timeline,
				"contenders": entry.contenders.map(func(c): return {"civ": c.civ, "path": c.path, "focus": c.focus, "access_turn": c.access_turn, "post_access_turns": c.post_access_turns, "category": c.category, "subcategory": c.get("subcategory", ""), "economic_collapse": c.economic_collapse}),
			})
		outliers[key] = short
	return compact

static func all_civs(records: Array) -> Array:
	var result: Array = []
	for record in records:
		for civ in record.civs:
			var copy: Dictionary = civ
			copy["_match"] = record.config.match_id
			result.append(copy)
	return result

# --- Estatística ---------------------------------------------------------------------------------

static func distribution(values: Array) -> Dictionary:
	var numbers: Array = []
	for value in values:
		if value != null:
			numbers.append(float(value))
	if numbers.is_empty():
		return {"n": 0}
	numbers.sort()
	var total := 0.0
	for value in numbers:
		total += value
	return {
		"n": numbers.size(),
		"median": snappedf(percentile(numbers, 0.5), 0.1),
		"mean": snappedf(total / numbers.size(), 0.1),
		"p25": snappedf(percentile(numbers, 0.25), 0.1),
		"p75": snappedf(percentile(numbers, 0.75), 0.1),
		"p90": snappedf(percentile(numbers, 0.90), 0.1),
		"p95": snappedf(percentile(numbers, 0.95), 0.1),
		"min": snappedf(numbers.front(), 0.1),
		"max": snappedf(numbers.back(), 0.1),
	}

static func percentile(sorted_values: Array, fraction: float) -> float:
	if sorted_values.size() == 1:
		return float(sorted_values[0])
	var position := fraction * float(sorted_values.size() - 1)
	var low := int(floor(position))
	var high := int(ceil(position))
	return lerpf(float(sorted_values[low]), float(sorted_values[high]), position - low)

static func milestone_value(civ: Dictionary, key: String, cap: int) -> int:
	var turn := int(civ.milestones.get(key, -1))
	return turn if turn >= 0 and turn <= cap else -1

static func milestone_distribution(civs: Array, key: String, cap: int) -> Dictionary:
	var values: Array = []
	for civ in civs:
		var turn := milestone_value(civ, key, cap)
		if turn >= 0:
			values.append(turn)
	var result := distribution(values)
	result.reached = values.size()
	result.total = civs.size()
	return result

# --- Seções --------------------------------------------------------------------------------------

static func _sample(records: Array, civs: Array, cap: int) -> Dictionary:
	var timeouts := 0
	var unknown := 0
	for record in records:
		timeouts += 1 if record.end.end_reason == "TIMEOUT" else 0
		unknown += 1 if record.end.end_reason == "UNKNOWN_END_REASON" else 0
	return {"matches": records.size(), "civ_observations": civs.size(), "turn_cap": cap, "timeouts": timeouts, "unknown_end": unknown}

static func _victories(records: Array) -> Dictionary:
	var by_type := {}
	for type in VICTORY_TYPES:
		by_type[type] = []
	var all_turns: Array = []
	var by_race := {}
	var by_orientation := {}
	var by_seat := {}
	for record in records:
		var reason := String(record.end.end_reason)
		if not by_type.has(reason):
			by_type[reason] = []
		if reason in ["TIMEOUT", "UNKNOWN_END_REASON"]:
			by_type[reason].append(int(record.end.turn))
			continue
		var turn := int(record.victory.victory_turn)
		by_type[reason].append(turn)
		all_turns.append(turn)
		var race := String(record.victory.winner_race)
		var orientation := String(record.victory.winner_orientation)
		var seat := str(int(record.victory.winner_index))
		by_race[race] = int(by_race.get(race, 0)) + 1
		by_orientation[orientation] = int(by_orientation.get(orientation, 0)) + 1
		by_seat[seat] = int(by_seat.get(seat, 0)) + 1
	var table := {}
	for type in by_type:
		var entry := distribution(by_type[type]) if not type in ["TIMEOUT", "UNKNOWN_END_REASON"] else {"n": by_type[type].size()}
		entry.count = by_type[type].size()
		table[type] = entry
	var type_by_orientation := {}
	for record in records:
		if record.victory.is_empty():
			continue
		var key := "%s|%s" % [record.victory.winner_orientation, record.end.end_reason]
		type_by_orientation[key] = int(type_by_orientation.get(key, 0)) + 1
	return {"by_type": table, "valid_victory_turns": distribution(all_turns), "wins_by_race": by_race, "wins_by_orientation": by_orientation, "wins_by_seat": by_seat, "winner_orientation_x_type": type_by_orientation, "note": "Timeouts são censurados: não entram na distribuição de turno de vitória."}

static func _grouped(civs: Array, field: String, records: Array, cap: int) -> Dictionary:
	var groups := {}
	for civ in civs:
		var key := str(civ[field])
		if not groups.has(key):
			groups[key] = []
		groups[key].append(civ)
	var result := {}
	for key in groups:
		var members: Array = groups[key]
		var entry := {"n": members.size(), "milestones": {}}
		for milestone_key in ORIENTATION_MILESTONES:
			entry.milestones[milestone_key] = milestone_distribution(members, milestone_key, cap)
		var wins := 0
		var win_types := {}
		var win_turns: Array = []
		for civ in members:
			if civ.final_status == "winner":
				wins += 1
				for record in records:
					if record.config.match_id == civ._match:
						win_types[record.end.end_reason] = int(win_types.get(record.end.end_reason, 0)) + 1
						win_turns.append(int(record.victory.victory_turn))
		entry.wins = wins
		entry.win_types = win_types
		entry.win_turns = distribution(win_turns)
		entry.final_cities = distribution(members.map(func(c): return c.final_city_count))
		entry.max_cities = distribution(members.map(func(c): return c.max_city_count))
		entry.max_relevant_units = distribution(members.map(func(c): return c.max_relevant_units))
		entry.knowledge_generated = distribution(members.map(func(c): return c.research.knowledge_generated))
		entry.cities_t100 = distribution(members.map(func(c): return c.city_count_at.get("100", null)))
		entry.gold_net_t100 = distribution(members.map(func(c): return _snapshot_value(c, 100, "gold_net")))
		entry.knowledge_income_t100 = distribution(members.map(func(c): return _snapshot_value(c, 100, "knowledge_income")))
		entry.eliminated = members.filter(func(c): return int(c.eliminated_turn) >= 0).size()
		result[key] = entry
	return result

static func _snapshot_value(civ: Dictionary, turn: int, key: String) -> Variant:
	for snapshot in civ.snapshots:
		if int(snapshot.turn) == turn:
			return snapshot[key]
	return null

static func _snapshot_at(civ: Dictionary, turn: int) -> Dictionary:
	for snapshot in civ.snapshots:
		if int(snapshot.turn) == turn:
			return snapshot
	return {}

static func _series_turn_reaching(series: Array, threshold: float) -> int:
	# series[i] = valor observado no fim do turno i + 2 (o primeiro turno processado é o T2).
	for i in series.size():
		if float(series[i]) >= threshold:
			return i + 2
	return -1

static func _research(civs: Array, math: Dictionary, cap: int) -> Dictionary:
	var shares := {"military": [], "magic": [], "infrastructure": []}
	var idle: Array = []
	var idle_available: Array = []
	var switches: Array = []
	var partial: Array = []
	var generated_at := {}
	for checkpoint in CHECKPOINTS:
		generated_at[str(checkpoint)] = []
	var knowledge_income_at := {}
	for checkpoint in CHECKPOINTS:
		knowledge_income_at[str(checkpoint)] = []
	var lower_bound := float(math[SUPREMACY_LOWER_BOUND_KEY])
	var bound_turn: Array = []
	var efficiency := {"supremacy": [], "transcendence": []}
	var lag_vs_bound := {"supremacy": [], "transcendence": []}
	for civ in civs:
		var invested: Dictionary = civ.research.invested
		var total := float(invested.military) + float(invested.magic) + float(invested.infrastructure)
		if total > 0.0:
			for key in shares:
				shares[key].append(100.0 * float(invested[key]) / total)
		idle.append(int(civ.research.idle_turns))
		idle_available.append(int(civ.research.idle_turns_available))
		switches.append(int(civ.research.switches))
		partial.append(int(civ.research.get("partial_nodes", 0)))
		for checkpoint in CHECKPOINTS:
			var snapshot := _snapshot_at(civ, checkpoint)
			if not snapshot.is_empty() and bool(snapshot.alive):
				generated_at[str(checkpoint)].append(float(snapshot.knowledge_generated))
				knowledge_income_at[str(checkpoint)].append(float(snapshot.knowledge_income))
		var reach := _series_turn_reaching(civ.series.knowledge_generated, lower_bound)
		if reach >= 0 and reach <= cap:
			bound_turn.append(reach)
		for path in ["supremacy", "transcendence"]:
			var ready := milestone_value(civ, "%s_research_ready" % path, cap)
			if ready >= 0 and reach >= 0:
				lag_vs_bound[path].append(ready - reach)
				var context: Dictionary = civ.milestone_context.get("%s_research_ready" % path, {})
				if context.has("knowledge_invested") and float(context.knowledge_invested) > 0.0:
					efficiency[path].append(100.0 * lower_bound / float(context.knowledge_invested))
	var generated := {}
	var income := {}
	for checkpoint in CHECKPOINTS:
		generated[str(checkpoint)] = distribution(generated_at[str(checkpoint)])
		income[str(checkpoint)] = distribution(knowledge_income_at[str(checkpoint)])
	var context := {}
	for key in ["n9_first", "n9_second", "supremacy_research_ready", "transcendence_research_ready"]:
		var cities: Array = []
		var kpt: Array = []
		var academies: Array = []
		var spent: Array = []
		for civ in civs:
			if milestone_value(civ, key, cap) < 0:
				continue
			var entry: Dictionary = civ.milestone_context.get(key, {})
			if entry.is_empty():
				continue
			cities.append(entry.cities)
			kpt.append(entry.knowledge_per_turn)
			academies.append(entry.academies)
			spent.append(entry.knowledge_invested)
		context[key] = {"cities": distribution(cities), "knowledge_per_turn": distribution(kpt), "academies": distribution(academies), "knowledge_invested": distribution(spent)}
	return {
		"category_share_percent": {"military": distribution(shares.military), "magic": distribution(shares.magic), "infrastructure": distribution(shares.infrastructure)},
		"idle_turns": distribution(idle),
		"idle_turns_with_research_available": distribution(idle_available),
		"switches": distribution(switches),
		"partial_nodes_at_end": distribution(partial),
		"knowledge_generated_at": generated,
		"knowledge_income_at": income,
		"lower_bound_knowledge": lower_bound,
		"turn_cumulative_knowledge_reaches_lower_bound": distribution(bound_turn),
		"turn_cumulative_knowledge_reaches_lower_bound_reached": bound_turn.size(),
		"research_ready_minus_lower_bound_turn": {"supremacy": distribution(lag_vs_bound.supremacy), "transcendence": distribution(lag_vs_bound.transcendence)},
		"allocation_efficiency_percent": {"supremacy": distribution(efficiency.supremacy), "transcendence": distribution(efficiency.transcendence)},
		"milestone_context": context,
	}

static func _economy(civs: Array) -> Dictionary:
	var fields := {"deficit_total": [], "deficit_longest": [], "negative_net_total": [], "tension_total": [], "tension_longest": [], "max_supply_ratio": [], "low_mana_turns": []}
	var first_deficit: Array = []
	var first_tension: Array = []
	var with_deficit := 0
	var with_tension := 0
	var checkpoints := {}
	for checkpoint in CHECKPOINTS:
		checkpoints[str(checkpoint)] = {"gold": [], "gold_net": [], "gold_upkeep": [], "supply_used": [], "supply_capacity": [], "mana": [], "mana_income": [], "knowledge_income": [], "production_total": [], "production_mean": [], "cities": [], "mean_city_level": []}
	for civ in civs:
		fields.deficit_total.append(int(civ.deficit.total))
		fields.deficit_longest.append(int(civ.deficit.longest))
		fields.negative_net_total.append(int(civ.negative_net.total))
		fields.tension_total.append(int(civ.tension.total))
		fields.tension_longest.append(int(civ.tension.longest))
		fields.max_supply_ratio.append(float(civ.max_supply_ratio))
		fields.low_mana_turns.append(int(civ.low_mana_turns))
		if int(civ.deficit.first) >= 0:
			with_deficit += 1
			first_deficit.append(int(civ.deficit.first))
		if int(civ.tension.first) >= 0:
			with_tension += 1
			first_tension.append(int(civ.tension.first))
		for checkpoint in CHECKPOINTS:
			var snapshot := _snapshot_at(civ, checkpoint)
			if snapshot.is_empty() or not bool(snapshot.alive):
				continue
			for key in checkpoints[str(checkpoint)]:
				checkpoints[str(checkpoint)][key].append(float(snapshot[key]))
	var result := {"civs_with_deficit": with_deficit, "civs_with_tension": with_tension, "first_deficit_turn": distribution(first_deficit), "first_tension_turn": distribution(first_tension), "total": civs.size()}
	for key in fields:
		result[key] = distribution(fields[key])
	var at := {}
	for checkpoint in checkpoints:
		at[checkpoint] = {}
		for key in checkpoints[checkpoint]:
			at[checkpoint][key] = distribution(checkpoints[checkpoint][key])
	result.at_checkpoint = at
	return result

static func _opening(civs: Array, cap: int) -> Dictionary:
	var first_groups := {}
	var first_items := {}
	var city_counts := {}
	for checkpoint in BalanceTelemetry.EXPANSION_CHECKPOINTS:
		city_counts[str(checkpoint)] = []
	var produced: Array = []
	var lost: Array = []
	var unused: Array = []
	var settler_turns: Array = []
	var conversion: Array = []
	var no_expansion := 0
	var extreme_expansion := 0
	var dead_settler_accumulation := 0
	var late_founding: Array = []
	var idle_ratio: Array = []
	var idle_breakdown := {"no_startable_option": 0, "only_settler_startable": 0, "options_not_chosen": 0}
	var idle_first_30: Array = []
	for civ in civs:
		if not civ.first_production.is_empty():
			var group := String(civ.first_production.group)
			first_groups[group] = int(first_groups.get(group, 0)) + 1
			var item := String(civ.first_production.item)
			first_items[item] = int(first_items.get(item, 0)) + 1
		for checkpoint in BalanceTelemetry.EXPANSION_CHECKPOINTS:
			if civ.city_count_at.has(str(checkpoint)):
				city_counts[str(checkpoint)].append(int(civ.city_count_at[str(checkpoint)]))
		produced.append(int(civ.settlers.produced))
		lost.append(int(civ.settlers.lost))
		unused.append(int(civ.settlers.unused_at_end))
		settler_turns.append(int(civ.settlers.city_turns))
		if int(civ.settlers.produced) > 0:
			conversion.append(100.0 * float(civ.settlers.cities_founded) / float(civ.settlers.produced))
		if int(civ.max_city_count) <= 1:
			no_expansion += 1
		if int(civ.max_city_count) >= 10:
			extreme_expansion += 1
		if int(civ.settlers.unit_turns) >= 60:
			dead_settler_accumulation += 1
		var second := milestone_value(civ, "second_city_founded", cap)
		if second > 80:
			late_founding.append({"match": civ._match, "index": civ.index, "race": civ.race, "second_city": second})
		if int(civ.city_turns) > 0:
			idle_ratio.append(100.0 * float(civ.idle_city_turns) / float(civ.city_turns))
		for key in idle_breakdown:
			idle_breakdown[key] += int(civ.idle_breakdown.get(key, 0))
		var first_prod := milestone_value(civ, "first_production", cap)
		idle_first_30.append(mini(29, first_prod - 2) if first_prod >= 0 else 29)
	var counts := {}
	for checkpoint in city_counts:
		counts[checkpoint] = distribution(city_counts[checkpoint])
	return {
		"first_production_group": first_groups,
		"first_production_item": first_items,
		"idle_turns_before_first_production": distribution(idle_first_30),
		"city_count_at": counts,
		"settlers_produced": distribution(produced),
		"settlers_lost": distribution(lost),
		"settlers_unused_at_end": distribution(unused),
		"settler_city_turns": distribution(settler_turns),
		"founding_conversion_percent": distribution(conversion),
		"no_expansion_civs": no_expansion,
		"extreme_expansion_civs_10plus": extreme_expansion,
		"dead_settler_accumulation_civs": dead_settler_accumulation,
		"late_second_city_after_t80": late_founding,
		"idle_city_turn_percent": distribution(idle_ratio),
		"idle_breakdown_total_city_turns": idle_breakdown,
	}

static func _production(civs: Array, cap: int) -> Dictionary:
	var turns := {}
	var completed := {}
	var pp := {}
	var total_turns := 0
	for category in BalanceTelemetry.PRODUCTION_CATEGORIES:
		turns[category] = 0
		completed[category] = 0
		pp[category] = 0.0
	var waiting_mana: Array = []
	var waiting_gold: Array = []
	var legendary: Array = []
	for civ in civs:
		for category in BalanceTelemetry.PRODUCTION_CATEGORIES:
			turns[category] += int(civ.production_turns.get(category, 0))
			completed[category] += int(civ.production_completed.get(category, 0))
			pp[category] += float(civ.production_pp.get(category, 0.0))
			total_turns += int(civ.production_turns.get(category, 0))
		waiting_mana.append(int(civ.waiting_mana_city_turns))
		waiting_gold.append(int(civ.waiting_gold_city_turns))
		legendary.append(int(civ.legendary_produced))
	var share := {}
	for category in turns:
		share[category] = snappedf(100.0 * turns[category] / maxf(total_turns, 1), 0.1)
	return {
		"production_city_turns_by_category": turns,
		"production_city_turn_share_percent": share,
		"production_pp_by_category": pp,
		"completed_by_category": completed,
		"completed_per_civ_mean": _per_civ(completed, civs.size()),
		"waiting_mana_city_turns": distribution(waiting_mana),
		"waiting_gold_city_turns": distribution(waiting_gold),
		"legendary_produced_per_civ": distribution(legendary),
	}

static func _per_civ(totals: Dictionary, count: int) -> Dictionary:
	var result := {}
	for key in totals:
		result[key] = snappedf(float(totals[key]) / maxf(count, 1), 0.01)
	return result

static func _army(civs: Array) -> Dictionary:
	var relevant := {}
	var roles := {}
	var forms := {}
	for checkpoint in CHECKPOINTS:
		relevant[str(checkpoint)] = []
		roles[str(checkpoint)] = {}
		forms[str(checkpoint)] = {"n3": [], "n5": [], "n7": []}
	var max_relevant: Array = []
	var reached_12 := 0
	var reached_20 := 0
	for civ in civs:
		max_relevant.append(int(civ.max_relevant_units))
		reached_12 += 1 if int(civ.max_relevant_units) >= 12 else 0
		reached_20 += 1 if int(civ.max_relevant_units) >= 20 else 0
		for checkpoint in CHECKPOINTS:
			var snapshot := _snapshot_at(civ, checkpoint)
			if snapshot.is_empty() or not bool(snapshot.alive):
				continue
			relevant[str(checkpoint)].append(int(snapshot.relevant_units))
			for role in snapshot.roles:
				var bucket: Dictionary = roles[str(checkpoint)]
				bucket[role] = int(bucket.get(role, 0)) + int(snapshot.roles[role])
			for form in ["n3", "n5", "n7"]:
				forms[str(checkpoint)][form].append(int(snapshot.forms[form]))
	var relevant_dist := {}
	var forms_dist := {}
	for checkpoint in CHECKPOINTS:
		relevant_dist[str(checkpoint)] = distribution(relevant[str(checkpoint)])
		forms_dist[str(checkpoint)] = {"n3": distribution(forms[str(checkpoint)].n3), "n5": distribution(forms[str(checkpoint)].n5), "n7": distribution(forms[str(checkpoint)].n7)}
		var alive := maxf(float(relevant[str(checkpoint)].size()), 1.0)
		var mean := {}
		for role in roles[str(checkpoint)]:
			mean[role] = snappedf(float(roles[str(checkpoint)][role]) / alive, 0.01)
		roles[str(checkpoint)] = mean
	return {"relevant_units_at": relevant_dist, "max_relevant_units": distribution(max_relevant), "civs_reaching_12": reached_12, "civs_reaching_20": reached_20, "total": civs.size(), "mean_role_count_at": roles, "forms_at": forms_dist}

static func _wars(records: Array) -> Dictionary:
	var per_match: Array = []
	var durations: Array = []
	var first_war: Array = []
	var end_reasons := {}
	var stalemates := 0
	var captures_per_war: Array = []
	var losses_per_war: Array = []
	var war_fraction: Array = []
	var civ_first_war: Array = []
	var civ_war_fraction: Array = []
	var total := 0
	for record in records:
		per_match.append(record.wars.size())
		war_fraction.append(100.0 * float(record.counters.turns_any_war) / maxf(float(record.counters.turns_observed), 1.0))
		var first := 999999
		for war in record.wars:
			total += 1
			first = mini(first, int(war.start_turn))
			if war.end_reason != "ongoing_at_game_end":
				durations.append(int(war.duration))
			end_reasons[war.end_reason] = int(end_reasons.get(war.end_reason, 0)) + 1
			stalemates += 1 if bool(war.possible_stalemate) else 0
			var captures := 0
			for key in war.cities_captured:
				captures += int(war.cities_captured[key])
			captures_per_war.append(captures)
			var losses := 0
			for key in war.unit_losses:
				losses += int(war.unit_losses[key])
			losses_per_war.append(losses)
		if first < 999999:
			first_war.append(first)
		for civ in record.civs:
			if int(civ.first_war_turn) >= 0:
				civ_first_war.append(int(civ.first_war_turn))
			civ_war_fraction.append(100.0 * float(civ.war_fraction))
	return {
		"wars_total": total,
		"wars_per_match": distribution(per_match),
		"first_war_turn_per_match": distribution(first_war),
		"first_war_turn_per_civ": distribution(civ_first_war),
		"duration_closed_wars": distribution(durations),
		"end_reasons": end_reasons,
		"possible_stalemate_wars": stalemates,
		"captures_per_war": distribution(captures_per_war),
		"unit_losses_per_war": distribution(losses_per_war),
		"match_turns_with_any_war_percent": distribution(war_fraction),
		"civ_turns_at_war_percent": distribution(civ_war_fraction),
		"stalemate_definition": "possible_stalemate = >= %d turnos consecutivos sem captura e sem morte de unidade de nenhum dos lados" % BalanceTelemetry.STALEMATE_QUIET_TURNS,
		"loss_attribution_note": "Mortes de uma civilização contam para TODAS as guerras ativas dela naquele turno (o jogo não registra quem matou).",
	}

static func _supremacy(records: Array, civs: Array, cap: int) -> Dictionary:
	var lag: Array = []
	var pursuit: Array = []
	var qualifying_captures: Array = []
	var first_satisfied: Array = []
	var unsatisfied_again := 0
	var no_pursuit := 0
	for record in records:
		if record.end.end_reason != "MILITARY_SUPREMACY":
			continue
		var winner: Dictionary = record.civs[int(record.victory.winner_index)]
		var ready := int(winner.milestones.get("supremacy_research_ready", -1))
		if ready >= 0:
			lag.append(int(record.victory.victory_turn) - ready)
	for civ in civs:
		var ready := milestone_value(civ, "supremacy_research_ready", cap)
		if ready < 0:
			continue
		var after := int(civ.supremacy_pursuit.turns_after_access)
		if after > 0:
			pursuit.append(100.0 * float(civ.supremacy_pursuit.turns_at_war_with_pending_rival) / float(after))
		qualifying_captures.append(int(civ.combat.qualifying_captures))
		for rival in civ.supremacy_rivals.values():
			if int(rival.first_satisfied) >= 0:
				first_satisfied.append(int(rival.first_satisfied) - ready)
			unsatisfied_again += rival.unsatisfied_again.size()
		no_pursuit += 1 if bool(civ.diagnostic_flags.get("supremacy_no_pursuit", false)) else 0
	var censored: Array = []
	for record in records:
		for civ in record.civs:
			var ready := milestone_value(civ, "supremacy_research_ready", cap)
			if ready >= 0 and not (record.end.end_reason == "MILITARY_SUPREMACY" and int(record.victory.winner_index) == int(civ.index)):
				censored.append(int(record.end.turn) - ready)
	return {
		"access_without_supremacy_win_turns_access_to_end": distribution(censored),
		"research_ready": milestone_distribution(civs, "supremacy_research_ready", cap),
		"execution_lag_victory_minus_research_ready": distribution(lag),
		"percent_turns_after_access_at_war_with_pending_rival": distribution(pursuit),
		"qualifying_captures_per_ready_civ": distribution(qualifying_captures),
		"rival_first_satisfied_minus_ready": distribution(first_satisfied),
		"rival_condition_lost_again_events": unsatisfied_again,
		"no_pursuit_flags": no_pursuit,
	}

static func _transcendence(records: Array, civs: Array, cap: int) -> Dictionary:
	var lag_ready: Array = []
	var lag_start: Array = []
	var manifestation_lag: Array = []
	var ritual_ready_lag: Array = []
	var attempts_per_civ: Array = []
	var interruption_buckets := {"0": 0, "1": 0, "2": 0, "3+": 0}
	var reasons := {}
	var loops := 0
	var gate_totals := {}
	var casters_first: Array = []
	for record in records:
		for ritual in record.rituals:
			if bool(ritual.interrupted):
				reasons[ritual.interruption_reason] = int(reasons.get(ritual.interruption_reason, 0)) + 1
		if record.end.end_reason != "TRANSCENDENCE":
			continue
		var winner: Dictionary = record.civs[int(record.victory.winner_index)]
		var victory_turn := int(record.victory.victory_turn)
		var ready := int(winner.milestones.get("transcendence_ritual_ready", -1))
		var start := int(winner.milestones.get("first_ritual_start", -1))
		if ready >= 0:
			lag_ready.append(victory_turn - ready)
		if start >= 0:
			lag_start.append(victory_turn - start)
	for civ in civs:
		var research_ready := milestone_value(civ, "transcendence_research_ready", cap)
		var two := milestone_value(civ, "two_active_manifestations", cap)
		if research_ready >= 0 and two >= 0:
			manifestation_lag.append(two - research_ready)
		var ritual_ready := milestone_value(civ, "transcendence_ritual_ready", cap)
		if research_ready >= 0 and ritual_ready >= 0:
			ritual_ready_lag.append(ritual_ready - research_ready)
		var attempts := int(civ.ritual_attempts)
		if attempts > 0:
			attempts_per_civ.append(attempts)
			var interruptions := int(civ.ritual_interruptions)
			var bucket := "3+" if interruptions >= 3 else str(interruptions)
			interruption_buckets[bucket] += 1
		loops += 1 if bool(civ.ritual_interruption_loop) else 0
		for gate in civ.manifestation_gate_turns:
			gate_totals[gate] = int(gate_totals.get(gate, 0)) + int(civ.manifestation_gate_turns[gate])
	var censored: Array = []
	var censored_ritual_ready: Array = []
	for record in records:
		for civ in record.civs:
			var won: bool = record.end.end_reason == "TRANSCENDENCE" and int(record.victory.winner_index) == int(civ.index)
			var ready := milestone_value(civ, "transcendence_research_ready", cap)
			if ready >= 0 and not won:
				censored.append(int(record.end.turn) - ready)
			var ritual_ready := milestone_value(civ, "transcendence_ritual_ready", cap)
			if ritual_ready >= 0 and not won:
				censored_ritual_ready.append(int(record.end.turn) - ritual_ready)
	return {
		"access_without_transcendence_win_turns_access_to_end": distribution(censored),
		"ritual_ready_without_win_turns_to_end": distribution(censored_ritual_ready),
		"research_ready": milestone_distribution(civs, "transcendence_research_ready", cap),
		"first_manifestation": milestone_distribution(civs, "first_manifestation", cap),
		"second_distinct_manifestation": milestone_distribution(civs, "second_distinct_manifestation", cap),
		"two_active_manifestations": milestone_distribution(civs, "two_active_manifestations", cap),
		"ritual_ready": milestone_distribution(civs, "transcendence_ritual_ready", cap),
		"first_ritual_start": milestone_distribution(civs, "first_ritual_start", cap),
		"manifestation_lag_two_active_minus_research_ready": distribution(manifestation_lag),
		"ritual_ready_minus_research_ready": distribution(ritual_ready_lag),
		"execution_lag_victory_minus_ritual_ready": distribution(lag_ready),
		"execution_lag_victory_minus_first_ritual_start": distribution(lag_start),
		"attempts_per_attempting_civ": distribution(attempts_per_civ),
		"interruptions_per_attempting_civ": interruption_buckets,
		"interruption_reasons": reasons,
		"ritual_interruption_loops": loops,
		"gate_turns_after_access_total": gate_totals,
	}

## Fase 33D1 — engagement density (registros anteriores à D1 simplesmente não têm estes campos).
static func _engagement(records: Array, civs: Array, cap: int) -> Dictionary:
	var ascension: Array = []
	var convergence: Array = []
	var causes := {"ascension": {}, "convergence": {}}
	for record in records:
		var timeline: Dictionary = record.get("world_phase", {})
		if int(timeline.get("ascension_turn", -1)) >= 0:
			ascension.append(int(timeline.ascension_turn))
			causes.ascension[timeline.ascension_cause] = int(causes.ascension.get(timeline.ascension_cause, 0)) + 1
		if int(timeline.get("convergence_turn", -1)) >= 0:
			convergence.append(int(timeline.convergence_turn))
			causes.convergence[timeline.convergence_cause] = int(causes.convergence.get(timeline.convergence_cause, 0)) + 1
	var inactivity := {}
	for key in BalanceTelemetry.PHASE_KEYS:
		inactivity[key] = []
	var inactivity_overall: Array = []
	var lag: Array = []
	for civ in civs:
		var data: Dictionary = civ.get("inactivity", {})
		if data.is_empty():
			continue
		inactivity_overall.append(int(data.max_overall))
		for key in BalanceTelemetry.PHASE_KEYS:
			inactivity[key].append(int(data.max_by_phase.get(key, 0)))
		if int(civ.get("units_without_purpose_lag", -1)) >= 0:
			lag.append(int(civ.units_without_purpose_lag))
	var inactivity_dist := {}
	for key in inactivity:
		inactivity_dist[key] = distribution(inactivity[key])
	var wars_total := 0
	var empty := 0
	var low := 0
	for record in records:
		for war in record.wars:
			if not war.has("pair_engagements"):
				continue
			wars_total += 1
			empty += 1 if bool(war.get("empty_war", false)) else 0
			low += 1 if bool(war.get("low_activity_war", false)) else 0
	var objectives := {"issued": 0, "resolved": 0, "resolved_by_other": 0, "superseded": 0}
	for civ in civs:
		for key in objectives:
			objectives[key] += int(civ.get("objectives", {}).get(key, 0))
	var milestones := {}
	for key in BalanceTelemetry.ENGAGEMENT_MILESTONES:
		milestones[key] = milestone_distribution(civs, key, cap)
	return {
		"ascension_turn": distribution(ascension),
		"ascension_causes": causes.ascension,
		"convergence_turn": distribution(convergence),
		"convergence_causes": causes.convergence,
		"max_inactivity_streak_by_phase": inactivity_dist,
		"max_inactivity_streak_overall": distribution(inactivity_overall),
		"units_without_purpose_lag": distribution(lag),
		"units_without_purpose_lag_reached": lag.size(),
		"wars_with_pair_tracking": wars_total,
		"empty_wars": empty,
		"low_activity_wars": low,
		"objectives": objectives,
		"milestones": milestones,
		"inactivity_bands_reference": {"FOUNDATION": 12, "ASCENSION": 15, "CONVERGENCE": 10},
		"world_threats": _world_threats(records, civs),
	}

## Fase 33D2 — ameaças regionais e Guardiões. Registros F33B/D1 (sem os campos) contam como ausentes.
static func _world_threats(records: Array, civs: Array) -> Dictionary:
	var regional := {"exists": 0, "goblin": 0, "skeleton": 0, "reused": 0, "created": 0, "discovered": 0, "responded": 0, "cleared_self": 0, "cleared_other": 0, "unresolved_at_first_war": 0, "with_war": 0, "war_while_awake_turns": 0}
	var discovered_turn: Array = []
	var response_turn: Array = []
	var cleared_turn: Array = []
	var discovery_to_clear: Array = []
	var lairs := {"cleared": 0, "cleared_regional_own": 0, "cleared_regional_other": 0, "cleared_guardian": 0, "cleared_wild": 0, "structure_attacks": 0, "structure_attacks_unknown": 0}
	var guardian := {"discovered": 0, "engaged": 0, "resolved": 0}
	for civ in civs:
		var data: Dictionary = civ.get("regional_threat", {})
		for key in lairs:
			lairs[key] += int(civ.get("lairs", {}).get(key, 0))
		var guardian_data: Dictionary = civ.get("guardian", {})
		guardian.discovered += 1 if int(guardian_data.get("discovered_turn", -1)) >= 0 else 0
		guardian.engaged += 1 if int(guardian_data.get("engaged_turn", -1)) >= 0 else 0
		guardian.resolved += int(guardian_data.get("resolved", 0))
		if not bool(data.get("exists", false)):
			continue
		regional.exists += 1
		if regional.has(String(data.type)):
			regional[String(data.type)] += 1
		if regional.has(String(data.source)):
			regional[String(data.source)] += 1
		if int(data.discovered_turn) >= 0:
			regional.discovered += 1
			discovered_turn.append(int(data.discovered_turn))
		if int(data.first_response_turn) >= 0:
			regional.responded += 1
			response_turn.append(int(data.first_response_turn))
		if int(data.cleared_turn) >= 0:
			cleared_turn.append(int(data.cleared_turn))
			regional["cleared_self" if String(data.resolved_by) == "self" else "cleared_other"] += 1
			if int(data.discovered_turn) >= 0:
				discovery_to_clear.append(int(data.cleared_turn) - int(data.discovered_turn))
		if int(data.get("unresolved_at_first_war", -1)) >= 0:
			regional.with_war += 1
			regional.unresolved_at_first_war += int(data.unresolved_at_first_war)
		regional.war_while_awake_turns += int(data.get("war_while_awake_turns", 0))
	var alive_at := {}
	var sites := 0
	var resolved_sites := 0
	var resources := {}
	for record in records:
		var threats: Dictionary = record.get("world_threats", {})
		for key in threats.get("regional_alive_at", {}):
			if not alive_at.has(key):
				alive_at[key] = []
			alive_at[key].append(int(threats.regional_alive_at[key]))
		sites += int(threats.get("guardian_sites_spawned", 0))
		resolved_sites += int(threats.get("guardian_resolved", 0))
		for resource in threats.get("guardian_resources", {}):
			resources[resource] = int(resources.get(resource, 0)) + int(threats.guardian_resources[resource])
	var alive_totals := {}
	for key in alive_at:
		var total := 0
		for value in alive_at[key]:
			total += int(value)
		alive_totals[key] = {"alive": total, "matches": alive_at[key].size()}
	return {
		"regional": regional,
		"regional_discovered_turn": distribution(discovered_turn),
		"regional_first_response_turn": distribution(response_turn),
		"regional_cleared_turn": distribution(cleared_turn),
		"regional_discovery_to_clear": distribution(discovery_to_clear),
		"regional_alive_at": alive_totals,
		"lairs": lairs,
		"guardian_sites_spawned": sites,
		"guardian_sites_resolved": resolved_sites,
		"guardian_resources": resources,
		"guardian_civs": guardian,
	}

static func _domination(records: Array) -> Dictionary:
	var first: Array = []
	var second: Array = []
	var third: Array = []
	var eliminations_per_match: Array = []
	for record in records:
		var order: Array = record.elimination_order
		eliminations_per_match.append(order.size())
		if order.size() >= 1:
			first.append(int(order[0].turn))
		if order.size() >= 2:
			second.append(int(order[1].turn))
		if order.size() >= 3:
			third.append(int(order[2].turn))
	return {"eliminations_per_match": distribution(eliminations_per_match), "first_elimination": distribution(first), "second_elimination": distribution(second), "third_elimination": distribution(third)}

# --- Outliers ------------------------------------------------------------------------------------

static func _outliers(records: Array, cap: int) -> Dictionary:
	var early: Array = []
	var late: Array = []
	var timeouts: Array = []
	for record in records:
		var reason := String(record.end.end_reason)
		if reason == "TIMEOUT" or reason == "UNKNOWN_END_REASON":
			timeouts.append(_late_diagnosis(record, cap))
			continue
		var turn := int(record.victory.victory_turn)
		if turn < 120:
			early.append(_early_diagnosis(record))
		elif turn > 200:
			late.append(_late_diagnosis(record, cap))
	var primary_counts := {}
	var any_counts := {}
	for entry in late + timeouts:
		primary_counts[entry.primary_category] = int(primary_counts.get(entry.primary_category, 0)) + 1
		var seen := {entry.primary_category: true}
		for category in entry.secondary_categories:
			seen[category] = true
		for category in seen:
			any_counts[category] = int(any_counts.get(category, 0)) + 1
	return {"early_lt_120": early, "late_gt_200": late, "timeouts": timeouts, "late_and_timeout_primary_counts": primary_counts, "late_and_timeout_any_counts": any_counts}

static func _early_diagnosis(record: Dictionary) -> Dictionary:
	var winner: Dictionary = record.civs[int(record.victory.winner_index)]
	var cities := []
	for civ in record.civs:
		cities.append({"index": civ.index, "race": civ.race, "orientation": civ.orientation, "final_cities": civ.final_city_count, "eliminated": civ.eliminated_turn})
	var early_collapse: bool = record.elimination_order.filter(func(e): return int(e.turn) < 100).size() > 0
	return {
		"match_id": record.config.match_id,
		"seed": record.config.seed,
		"victory_type": record.end.end_reason,
		"victory_turn": record.victory.victory_turn,
		"winner": {"index": winner.index, "race": winner.race, "orientation": winner.orientation},
		"geography": record.geography,
		"cities": cities,
		"wars": record.wars.map(func(w): return "%d:%d->%d(%s,%d-%d)" % [int(w.war_id), int(w.initiator), int(w.target), w.end_reason, int(w.start_turn), int(w.end_turn)]),
		"winner_research_ready": {"supremacy": winner.milestones.get("supremacy_research_ready", -1), "transcendence": winner.milestones.get("transcendence_research_ready", -1), "n9_second": winner.milestones.get("n9_second", -1)},
		"early_collapse": early_collapse,
	}

## Classificação heurística pós-processamento (seção 71). Não é classificação perfeita.
##
## Só civs CANDIDATAS (com acesso de pesquisa a uma rota — Exército Supremo ou Transcendência — até o
## fim observado) contam: o motivo de uma partida não terminar é o que travou quem podia vencer.
## Cada candidata recebe UMA categoria pela evidência dominante da própria telemetria:
##   Transcendência — soma dos turnos de gate após o acesso (BalanceTelemetry.manifestation_gate):
##     IA não escolheu (construível/treinável/pronto numa cidade ociosa)  -> NO_VICTORY_PURSUIT
##     fila ocupada / item em produção                                    -> PRODUCTION_LATE (queue)
##     gate de conteúdo (sem slot, falta prédio-escola, Déficit, Supply)  -> PRODUCTION_LATE (content)
##     Mana                                                               -> MANA_LATE
##     3+ interrupções                                                    -> RITUAL_INTERRUPTION_LOOP
##   Supremacia — turnos após o acesso em guerra com algum rival ainda pendente:
##     < 50%                                          -> NO_VICTORY_PURSUIT
##     >= 50% e rival pendente noutra massa de terra  -> MAP_ACCESS
##     >= 50%                                         -> MILITARY_STALEMATE
##   economic_collapse = true quando a candidata viveu Déficit >= 20 turnos seguidos ou Tensão >= 30.
## Timeout: a categoria PRIMÁRIA é a da candidata com mais turnos pós-acesso; sem candidata ->
## RESEARCH_LATE. Vitória tardia: a linha do tempo do vencedor decide (pesquisa pronta só depois do
## T180 -> RESEARCH_LATE). Categorias distintas entre candidatas marcam multiple_causes = true.
static func _late_diagnosis(record: Dictionary, cap: int) -> Dictionary:
	var end_turn := int(record.end.turn)
	var contenders: Array = []
	for civ in record.civs:
		var finding := _civ_blocker(civ, record, end_turn)
		if not finding.is_empty():
			contenders.append(finding)
	contenders.sort_custom(func(a, b): return int(a.post_access_turns) > int(b.post_access_turns))
	var primary := "RESEARCH_LATE"
	var secondary: Array = []
	var winner_timeline := {}
	if not record.victory.is_empty():
		winner_timeline = _winner_timeline(record)
		primary = String(winner_timeline.category)
	elif not contenders.is_empty():
		primary = String(contenders[0].category)
	for finding in contenders:
		if String(finding.category) != primary and String(finding.category) not in secondary:
			secondary.append(finding.category)
	var civ_summary := []
	for civ in record.civs:
		civ_summary.append({
			"index": civ.index, "race": civ.race, "orientation": civ.orientation, "status": civ.final_status,
			"cities": civ.final_city_count, "relevant_units": civ.final_relevant_units,
			"n9_second": civ.milestones.get("n9_second", -1), "supremacy_ready": civ.milestones.get("supremacy_research_ready", -1),
			"transcendence_ready": civ.milestones.get("transcendence_research_ready", -1), "ritual_ready": civ.milestones.get("transcendence_ritual_ready", -1),
			"rituals": civ.ritual_attempts, "interruptions": civ.ritual_interruptions, "gates": civ.manifestation_gate_turns,
			"pursuit": civ.supremacy_pursuit, "focus": civ.final_focus,
		})
	var trace := []
	for civ in record.civs:
		var points := []
		for snapshot in civ.snapshots:
			if int(snapshot.turn) % 10 == 0:
				points.append({"t": snapshot.turn, "cities": snapshot.cities, "research": snapshot.research_active, "tiers": snapshot.max_tier, "gold": snapshot.gold, "supply": "%d/%s" % [int(snapshot.supply_used), str(snapshot.supply_capacity)], "mana": snapshot.mana, "units": snapshot.relevant_units, "wars": snapshot.enemies, "sup": snapshot.supremacy, "tr": snapshot.transcendence})
		trace.append({"index": civ.index, "points": points})
	return {
		"match_id": record.config.match_id,
		"seed": record.config.seed,
		"end_reason": record.end.end_reason,
		"turn": end_turn,
		"primary_category": primary,
		"secondary_categories": secondary,
		"multiple_causes": not secondary.is_empty(),
		"winner_timeline": winner_timeline,
		"contenders": contenders,
		"civs": civ_summary,
		"timeout_report": record.get("timeout_report", []),
		"trace_every_10": trace,
	}

## Gate dominante de UMA civ candidata (ver _late_diagnosis). {} quando a civ não tem acesso a rota.
static func _civ_blocker(civ: Dictionary, record: Dictionary, end_turn: int) -> Dictionary:
	if int(civ.eliminated_turn) >= 0:
		return {}
	var sup_ready := milestone_value(civ, "supremacy_research_ready", end_turn)
	var tr_ready := milestone_value(civ, "transcendence_research_ready", end_turn)
	if sup_ready < 0 and tr_ready < 0:
		return {}
	var result := {
		"civ": "%d:%s/%s" % [int(civ.index), civ.race, civ.orientation], "index": civ.index, "focus": civ.final_focus,
		"path": "", "access_turn": -1, "post_access_turns": 0, "category": "OTHER", "evidence": {},
		"economic_collapse": int(civ.deficit.longest) >= 20 or int(civ.tension.longest) >= 30,
	}
	# Rota analisada: a de acesso mais antigo.
	if tr_ready >= 0 and (sup_ready < 0 or tr_ready <= sup_ready):
		var gates: Dictionary = civ.manifestation_gate_turns
		var buckets := {
			"NO_VICTORY_PURSUIT": _sum_keys(gates, ["trainable_idle_city_not_chosen", "ritual_structure_buildable_idle_city_not_chosen", "ritual_ready_not_started"]),
			"PRODUCTION_LATE:queue": _sum_keys(gates, ["in_production", "trainable_cities_busy", "ritual_structure_in_production", "ritual_structure_buildable_cities_busy"]),
			"PRODUCTION_LATE:content": _sum_keys(gates, ["ritual_structure_no_free_slot", "ritual_structure_needs_school_building", "ritual_structure_deficit", "ritual_structure_blocked_other", "no_unlocked_free_school", "ritual_no_structure_city", "blocked_supply_or_deficit", "blocked_other", "ritual_blocked_other"]),
			"MANA_LATE": _sum_keys(gates, ["blocked_mana", "ritual_blocked_mana"]),
		}
		result.path = "TRANSCENDENCE"
		result.access_turn = tr_ready
		result.post_access_turns = end_turn - tr_ready
		result.evidence = buckets
		var best := "OTHER"
		var best_value := 0
		for key in buckets:
			if int(buckets[key]) > best_value:
				best_value = int(buckets[key])
				best = key
		result.category = best.split(":")[0]
		result.subcategory = best
		if bool(civ.ritual_interruption_loop):
			result.category = "RITUAL_INTERRUPTION_LOOP"
		return result
	var after := int(civ.supremacy_pursuit.turns_after_access)
	var at_war := int(civ.supremacy_pursuit.turns_at_war_with_pending_rival)
	var pending: Array = []
	for rival_id in civ.supremacy_rivals:
		if not bool(civ.supremacy_rivals[rival_id].satisfied_at_end):
			pending.append(int(rival_id))
	result.path = "MILITARY_SUPREMACY"
	result.access_turn = sup_ready
	result.post_access_turns = end_turn - sup_ready
	result.evidence = {"turns_after_access": after, "turns_at_war_with_pending_rival": at_war, "pending_rivals": pending, "qualifying_captures": civ.combat.qualifying_captures, "developed_city_attacks": civ.combat.developed_city_attacks}
	var seats: Array = record.geography.get("seats", [])
	var own_component := int(seats[int(civ.index)].land_component) if int(civ.index) < seats.size() else -1
	var pending_elsewhere := false
	for rival in pending:
		if rival < seats.size() and int(seats[rival].land_component) != own_component:
			pending_elsewhere = true
	if after <= 0 or float(at_war) / float(after) < 0.5:
		result.category = "NO_VICTORY_PURSUIT"
	elif pending_elsewhere:
		result.category = "MAP_ACCESS"
	else:
		result.category = "MILITARY_STALEMATE"
	return result

## Linha do tempo do vencedor de uma vitória tardia: qual trecho consumiu o tempo.
static func _winner_timeline(record: Dictionary) -> Dictionary:
	var winner: Dictionary = record.civs[int(record.victory.winner_index)]
	var victory_turn := int(record.victory.victory_turn)
	var path := String(record.end.end_reason)
	var result := {"path": path, "victory_turn": victory_turn, "category": "OTHER"}
	var key := "transcendence_research_ready" if path == "TRANSCENDENCE" else "supremacy_research_ready"
	var ready := int(winner.milestones.get(key, -1))
	result.research_ready = ready
	if path == "TRANSCENDENCE":
		var ritual_ready := int(winner.milestones.get("transcendence_ritual_ready", -1))
		result.ritual_ready = ritual_ready
		result.research_to_ritual_ready = ritual_ready - ready if ready >= 0 and ritual_ready >= 0 else -1
		result.ritual_ready_to_victory = victory_turn - ritual_ready if ritual_ready >= 0 else -1
	else:
		result.execution_lag = victory_turn - ready if ready >= 0 else -1
	if ready > 180:
		result.category = "RESEARCH_LATE"
		return result
	var blocker := _civ_blocker(winner, record, victory_turn)
	result.category = String(blocker.get("category", "OTHER"))
	result.subcategory = String(blocker.get("subcategory", ""))
	result.evidence = blocker.get("evidence", {})
	if path == "TRANSCENDENCE" and int(result.ritual_ready_to_victory) > 8 and int(winner.ritual_interruptions) >= 3:
		result.category = "RITUAL_INTERRUPTION_LOOP"
	return result

static func _sum_keys(values: Dictionary, keys: Array) -> int:
	var total := 0
	for key in keys:
		total += int(values.get(key, 0))
	return total

static func _add_evidence(evidence: Dictionary, category: String, text: String) -> void:
	if not evidence.has(category):
		evidence[category] = []
	evidence[category].append(text)

static func _performance(records: Array) -> Dictionary:
	var wall: Array = []
	var turn_p95: Array = []
	var turn_max: Array = []
	var turn_mean: Array = []
	var setup: Array = []
	var nodes_after: Array = []
	var objects_after: Array = []
	var orphans_after: Array = []
	var memory_after: Array = []
	var per_turn_ms: Array = []
	for record in records:
		var perf: Dictionary = record.performance
		wall.append(float(perf.get("wall_ms", 0.0)) / 1000.0)
		setup.append(float(perf.setup_ms))
		if perf.turn_ms.has("p95"):
			turn_p95.append(float(perf.turn_ms.p95))
			turn_max.append(float(perf.turn_ms.max))
			turn_mean.append(float(perf.turn_ms.mean))
		per_turn_ms.append(float(perf.loop_ms) / maxf(float(perf.turns_processed), 1.0))
		nodes_after.append(int(perf.monitors_after.nodes))
		objects_after.append(int(perf.monitors_after.objects))
		orphans_after.append(int(perf.monitors_after.orphan_nodes))
		memory_after.append(float(perf.monitors_after.static_memory_mb))
	return {"match_wall_seconds": distribution(wall), "setup_ms": distribution(setup), "turn_mean_ms": distribution(turn_mean), "turn_p95_ms": distribution(turn_p95), "turn_max_ms": distribution(turn_max), "loop_ms_per_turn": distribution(per_turn_ms), "nodes_after_teardown": distribution(nodes_after), "objects_after_teardown": distribution(objects_after), "orphan_nodes_after_teardown": distribution(orphans_after), "static_memory_mb_after_teardown": distribution(memory_after)}

# --- CSV ----------------------------------------------------------------------------------------

static func match_rows(records: Array) -> Array:
	var rows: Array = [["match_id", "seed", "turn_cap", "races", "orientations", "winner_index", "winner_race", "winner_orientation", "victory_type", "victory_turn", "end_reason", "timeout", "end_turn", "elimination_order", "elimination_turns", "total_wars", "total_city_captures", "recaptures", "total_ritual_attempts", "total_ritual_interruptions", "turns_any_war", "engagements", "unit_deaths", "wall_seconds"]]
	for record in records:
		var interruptions: int = record.rituals.filter(func(r): return bool(r.interrupted)).size()
		rows.append([
			record.config.match_id, record.config.seed, record.config.turn_cap, "|".join(record.config.races), "|".join(record.config.orientations),
			record.victory.get("winner_index", -1), record.victory.get("winner_race", ""), record.victory.get("winner_orientation", ""),
			record.victory.get("victory_type", ""), record.victory.get("victory_turn", -1), record.end.end_reason, record.end.timeout, record.end.turn,
			"|".join(record.elimination_order.map(func(e): return "%d:%s" % [int(e.index), e.race])), "|".join(record.elimination_order.map(func(e): return str(int(e.turn)))),
			record.wars.size(), record.counters.city_captures, record.counters.recaptures, record.rituals.size(), interruptions,
			record.counters.turns_any_war, record.counters.engagements, record.counters.unit_deaths, snappedf(float(record.performance.get("wall_ms", 0)) / 1000.0, 0.1),
		])
	return rows

static func civ_rows(records: Array, cap: int) -> Array:
	var milestone_keys := ["first_production", "first_settler_produced", "second_city_founded", "third_city_founded", "n1", "n3", "n5", "n7", "n9_first", "n9_second", "military_n9_first", "military_n9_second", "magic_n9_first", "magic_n9_second", "infra_1", "infra_2", "infra_3", "supreme_army", "transcendence", "supremacy_research_ready", "transcendence_research_ready", "first_combat_unit", "first_n3_unit", "first_n5_form", "first_n7_form", "first_caster", "first_builder", "first_legendary", "first_manifestation", "second_distinct_manifestation", "two_active_manifestations", "transcendence_ritual_ready", "first_ritual_start", "city_level_2", "city_level_3", "city_level_4", "fortification_1", "fortification_2", "fortification_3"]
	var header: Array = ["match_id", "player_index", "race", "orientation", "final_status", "eliminated_turn", "final_city_count", "max_city_count", "developed_city_count", "final_unit_count", "max_relevant_units", "final_gold", "final_gold_net", "final_mana", "final_knowledge_income", "final_supply_used", "final_supply_capacity", "knowledge_generated", "invested_military", "invested_magic", "invested_infrastructure", "research_idle_turns", "research_switches", "deficit_first", "deficit_total", "deficit_longest", "tension_first", "tension_total", "tension_longest", "max_supply_ratio", "low_mana_turns", "city_turns", "idle_city_turns", "waiting_mana_city_turns", "settlers_produced", "cities_founded", "wars_declared", "first_war_turn", "war_fraction", "cities_captured", "cities_lost", "unit_deaths", "ritual_attempts", "ritual_interruptions", "final_focus"]
	header.append_array(milestone_keys)
	var rows: Array = [header]
	for record in records:
		for civ in record.civs:
			var row: Array = [record.config.match_id, civ.index, civ.race, civ.orientation, civ.final_status, civ.eliminated_turn, civ.final_city_count, civ.max_city_count, civ.developed_city_count, civ.final_unit_count, civ.max_relevant_units, civ.final_gold, civ.final_gold_net, civ.final_mana, civ.final_knowledge_income, civ.final_supply_used, civ.final_supply_capacity, civ.research.knowledge_generated, civ.research.invested.military, civ.research.invested.magic, civ.research.invested.infrastructure, civ.research.idle_turns, civ.research.switches, civ.deficit.first, civ.deficit.total, civ.deficit.longest, civ.tension.first, civ.tension.total, civ.tension.longest, snappedf(float(civ.max_supply_ratio), 0.01), civ.low_mana_turns, civ.city_turns, civ.idle_city_turns, civ.waiting_mana_city_turns, civ.settlers.produced, civ.settlers.cities_founded, civ.wars_declared, civ.first_war_turn, civ.war_fraction, civ.combat.cities_captured, civ.combat.cities_lost, civ.combat.unit_deaths, civ.ritual_attempts, civ.ritual_interruptions, civ.final_focus]
			for key in milestone_keys:
				row.append(milestone_value(civ, key, cap))
			rows.append(row)
	return rows

static func war_rows(records: Array) -> Array:
	var rows: Array = [["match_id", "war_id", "start_turn", "end_turn", "initiator", "target", "duration", "captured_by_initiator", "captured_by_target", "losses_initiator", "losses_target", "end_reason", "possible_stalemate", "max_quiet_streak", "reason", "pair_engagements", "pair_city_attacks", "empty_war", "low_activity_war"]]
	for record in records:
		for war in record.wars:
			var a := str(int(war.initiator))
			var b := str(int(war.target))
			rows.append([record.config.match_id, war.war_id, war.start_turn, war.end_turn, war.initiator, war.target, war.duration, war.cities_captured.get(a, 0), war.cities_captured.get(b, 0), war.unit_losses.get(a, 0), war.unit_losses.get(b, 0), war.end_reason, war.possible_stalemate, war.max_quiet_streak, war.reason, war.get("pair_engagements", ""), war.get("pair_city_attacks", ""), war.get("empty_war", ""), war.get("low_activity_war", "")])
	return rows

static func ritual_rows(records: Array) -> Array:
	var rows: Array = [["match_id", "owner", "race", "orientation", "start_turn", "city", "rounds_at_start", "rounds_remaining", "interrupted", "interruption_turn", "interruption_reason", "completed", "completion_turn", "active_at_game_end"]]
	for record in records:
		for ritual in record.rituals:
			rows.append([record.config.match_id, ritual.owner, ritual.race, ritual.orientation, ritual.start_turn, ritual.city, ritual.rounds_at_start, ritual.rounds_remaining, ritual.interrupted, ritual.interruption_turn, ritual.interruption_reason, ritual.completed, ritual.completion_turn, ritual.active_at_game_end])
	return rows

static func _write_csv(path: String, rows: Array) -> void:
	var lines: PackedStringArray = []
	for row in rows:
		var cells: PackedStringArray = []
		for cell in row:
			var text := str(cell)
			if text.contains(",") or text.contains("\"") or text.contains("\n"):
				text = "\"%s\"" % text.replace("\"", "\"\"")
			cells.append(text)
		lines.append(",".join(cells))
	_write_text(path, "\n".join(lines) + "\n")

static func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

# --- Markdown (resumo legível; o JSON agregado é a fonte completa) -----------------------------

static func markdown(aggregate: Dictionary) -> String:
	var lines: PackedStringArray = []
	var sample: Dictionary = aggregate.sample
	lines.append("# Release Balance Lab — resumo agregado")
	lines.append("")
	lines.append("Partidas: %d · observações de civ: %d · cap: %d · timeouts: %d · fins desconhecidos: %d" % [sample.matches, sample.civ_observations, sample.turn_cap, sample.timeouts, sample.unknown_end])
	lines.append("")
	lines.append("## Vitórias")
	lines.append("")
	lines.append("| Tipo | N | Mediana | P25 | P75 | P90 | P95 | Mín | Máx |")
	lines.append("|---|---|---|---|---|---|---|---|---|")
	for type in aggregate.victories.by_type:
		var entry: Dictionary = aggregate.victories.by_type[type]
		lines.append("| %s | %d | %s | %s | %s | %s | %s | %s | %s |" % [type, int(entry.count), _cell(entry, "median"), _cell(entry, "p25"), _cell(entry, "p75"), _cell(entry, "p90"), _cell(entry, "p95"), _cell(entry, "min"), _cell(entry, "max")])
	var all: Dictionary = aggregate.victories.valid_victory_turns
	lines.append("| **Todas válidas** | %d | %s | %s | %s | %s | %s | %s | %s |" % [int(all.get("n", 0)), _cell(all, "median"), _cell(all, "p25"), _cell(all, "p75"), _cell(all, "p90"), _cell(all, "p95"), _cell(all, "min"), _cell(all, "max")])
	lines.append("")
	lines.append("## Marcos (turno; reached/total)")
	lines.append("")
	lines.append("| Marco | Reached | Mediana | P25 | P75 | P90 | Mín | Máx |")
	lines.append("|---|---|---|---|---|---|---|---|")
	for key in aggregate.milestones:
		var entry: Dictionary = aggregate.milestones[key]
		lines.append("| %s | %d/%d | %s | %s | %s | %s | %s | %s |" % [key, int(entry.reached), int(entry.total), _cell(entry, "median"), _cell(entry, "p25"), _cell(entry, "p75"), _cell(entry, "p90"), _cell(entry, "min"), _cell(entry, "max")])
	lines.append("")
	return "\n".join(lines) + "\n"

static func _cell(entry: Dictionary, key: String) -> String:
	return str(entry[key]) if entry.has(key) else "—"
