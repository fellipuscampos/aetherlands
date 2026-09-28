class_name CityPresenter
extends RefCounted

## View model do City Context Panel (Fase 30 / UI-3). Agrupa o estado V2 real da
## cidade em Visão geral / Produção / Estruturas / Território / Defesa, mais o
## Ritual quando relevante. Não existe População, Comida, Ciência nem tile
## trabalhado: a economia vem de V2EconomyRuntime e cada gate de produção usa o
## motivo do próprio runtime (City, V2LegendarySystem, V2LogisticsRuntime,
## V2ManifestationSystem). Cidade rival recebe só fatos públicos.

const UNIT_SUBGROUPS := ["Exército", "Magia", "Civis", "Lendárias e Manifestações"]
const BUILDING_SUBGROUPS := ["Economia", "Treinamento", "Maestria", "Ritual", "Outros"]
const THREAT_RECENT_TURNS := 1

static var _unit_facts: Dictionary = {}

# --- Entrada principal -------------------------------------------------------------

## `tab` limita as seções calculadas à aba aberta ("" = todas, usado por testes e
## consumidores que precisam do quadro inteiro).
static func build(city: City, viewer: PlayerData, hex_grid: HexGrid = null, tab: String = "") -> Dictionary:
	if city == null or not is_instance_valid(city):
		return {"valid": false}
	var grid := hex_grid if hex_grid != null else GameManager.hex_grid
	var own := viewer != null and city.owner_player == viewer
	var view := {
		"valid": true,
		"own": own,
		"coord": city.coord,
		"name": city.city_name,
		"owner_name": _owner_name(city.owner_player),
		"owner_color": city.owner_player.civ.color if city.owner_player != null and city.owner_player.civ != null else UIThemeTokens.COLOR_BORDER,
		"relation": _relation(city.owner_player, viewer),
		"level": city.city_level,
		"level_name": V2CityLevelData.level_name(city.city_level),
		"level_roman": V2CityLevelData.roman(city.city_level),
		"hp": city.hp,
		"max_hp": city.max_hp(),
		"shield": city.shield,
		"max_shield": city.max_shield(),
		"fortification_level": city.fortification_level,
		"fortification_name": V2FortificationData.display_name(city.fortification_level) if city.has_fortification() else "Sem fortificação",
		"badges": badges(city, own),
		"defense": defense_view(city, own, grid),
		"ritual": ritual_view(city, own, grid),
	}
	if own:
		var all := tab == ""
		view["production"] = production_snapshot(city)
		if all or tab == "overview":
			view["overview"] = overview(city)
			view["development"] = development(city)
		if all or tab == "production":
			view["catalog"] = catalog(city)
		elif tab == "defense":
			view["catalog"] = {"projects": _project_items(city)}
		if all or tab == "structures":
			view["structures"] = structures(city)
		if all or tab == "territory":
			view["territory"] = territory(city, grid)
	return view

# --- Header / status -------------------------------------------------------------

static func _owner_name(owner: PlayerData) -> String:
	if owner == null:
		return "Sem dono"
	return owner.civ.civ_name if owner.civ != null else "Civilização"

static func _relation(owner: PlayerData, viewer: PlayerData) -> String:
	if owner == null:
		return ""
	if owner == viewer:
		return "Sua"
	return "Em guerra" if viewer != null and viewer.is_at_war_with(owner) else "Em paz"

static func is_threatened(city: City) -> bool:
	return city.last_monster_warning_turn >= 0 and TurnManager.turn_number - city.last_monster_warning_turn <= THREAT_RECENT_TURNS

static func badges(city: City, own: bool) -> Array:
	var result: Array = []
	var owner := city.owner_player
	if own:
		var production := production_snapshot(city)
		if production.state == "idle":
			result.append({"text": "Sem produção", "tone": AEStatusChip.Tone.WARNING, "tooltip": AETooltip.compose("Produção ociosa", "Escolha um item na aba Produção.")})
		elif production.state == "waiting_mana":
			result.append({"text": "Aguardando Mana", "tone": AEStatusChip.Tone.WARNING, "tooltip": AETooltip.compose("Aguardando Mana", "Produção concluída em PP; faltam %d Mana." % production.missing_mana)})
		elif production.state == "waiting_gold":
			result.append({"text": "Aguardando Ouro", "tone": AEStatusChip.Tone.WARNING, "tooltip": AETooltip.compose("Aguardando Ouro", "Projeto concluído em PP; faltam %d Ouro." % production.missing_gold)})
		if owner != null and V2EconomyRuntime.is_gold_deficit(owner) and V2EconomyRuntime.city_gold_upkeep(city) > 0.0:
			result.append({"text": "Déficit", "tone": AEStatusChip.Tone.NEGATIVE, "tooltip": AETooltip.compose("Déficit de Ouro", "Prédios com manutenção operam a 50%.")})
		if is_threatened(city):
			result.append({"text": "Ameaçada", "tone": AEStatusChip.Tone.NEGATIVE, "tooltip": AETooltip.compose("Cidade ameaçada", "Monstros próximos foram avistados recentemente.")})
	if city.has_fortification():
		result.append({"text": V2FortificationData.display_name(city.fortification_level), "tone": AEStatusChip.Tone.POSITIVE, "tooltip": AETooltip.compose("Fortificada", "Escudo e defesa urbana ativos.")})
	var ritual_owner := owner if owner != null and V2TranscendenceSystem.has_active_ritual(owner) and V2TranscendenceSystem.ritual_site_coord(owner) == city.coord else null
	if ritual_owner != null:
		result.append({"text": "Ritual · %d" % V2TranscendenceSystem.ritual_rounds_remaining(ritual_owner), "tone": AEStatusChip.Tone.WARNING, "tooltip": AETooltip.compose("Ritual de Transcendência", "Rodadas restantes: %d." % V2TranscendenceSystem.ritual_rounds_remaining(ritual_owner))})
	return result

# --- Visão geral -------------------------------------------------------------------

static func overview(city: City) -> Dictionary:
	var outputs: Array = []
	for definition in [["production", "Produção", "PP", "◆"], ["gold", "Ouro", "", "●"], ["supply", "Suprimentos", "cap.", "■"], ["knowledge", "Conhecimento", "", "▲"], ["mana", "Mana", "", "✦"]]:
		var value := _city_output(city, definition[0])
		var breakdown := V2EconomyRuntime.city_income_breakdown(city, definition[0])
		var details: Array = ["Base da cidade: +%s" % _number(breakdown.base)]
		if int(breakdown.copies) > 0:
			details.append("%s ×%d: +%s%s" % [breakdown.building_name, int(breakdown.copies), _number(breakdown.building_total), " (Déficit: 50%)" if breakdown.deficit_discounted else ""])
		if float(breakdown.improvement_total) > 0.0:
			details.append("Melhorias de recurso: +%s" % _number(breakdown.improvement_total))
		if not is_equal_approx(float(breakdown.racial_multiplier), 1.0):
			details.append("Bônus racial: +%s" % _number(breakdown.racial_bonus))
		outputs.append({"key": definition[0], "caption": definition[1], "value": "+%s" % _number(value), "glyph": definition[3], "tooltip": AETooltip.compose("%s por turno" % definition[1], "Contribuição desta cidade.", details)})
	var upkeep := V2EconomyRuntime.city_gold_upkeep(city)
	var costs: Array = [{"key": "upkeep", "caption": "Manutenção", "value": "-%s Ouro" % _number(upkeep), "glyph": "●", "tooltip": AETooltip.compose("Manutenção de Ouro", "Prédios com manutenção e o nível atual de Fortificação.")}]
	return {
		"outputs": outputs,
		"costs": costs,
		"slots_used": city.used_building_slots(),
		"slots_max": city.max_building_slots(),
		"annex_points": city.annexation_points,
		"territory_tiles": city.owned_tiles.size(),
	}

static func _city_output(city: City, key: String) -> float:
	match key:
		"production":
			return V2EconomyRuntime.city_production_income(city)
		"gold":
			return V2EconomyRuntime.city_gold_income(city)
		"supply":
			return V2EconomyRuntime.city_supply_capacity(city)
		"knowledge":
			return V2EconomyRuntime.city_knowledge_income(city)
		"mana":
			return V2EconomyRuntime.city_mana_income(city)
	return 0.0

# --- Produção atual (fonte única, também usada pelo City Summary da F29) --------

static func production_snapshot(city: City) -> Dictionary:
	var result := {"state": "idle", "item_id": "", "item_name": "Sem produção", "item_type": "", "cost": 0.0, "progress": 0.0, "income": 0.0, "eta": "Escolher produção", "eta_turns": -1, "missing_mana": 0, "missing_gold": 0, "mana_cost": 0.0}
	if city == null or not is_instance_valid(city) or city.production_item == "":
		return result
	var item := city.production_item
	var cost := city.production_cost()
	var progress := minf(city.stored_production, cost)
	var income := V2EconomyRuntime.city_production_income(city)
	result.item_id = item
	result.item_name = production_name(item, _race_of(city))
	result.item_type = production_type(item)
	result.cost = cost
	result.progress = progress
	result.income = income
	result.mana_cost = _production_mana_cost(item)
	result.missing_mana = missing_mana(city)
	result.missing_gold = city.city_upgrade_waiting_for_gold()
	if progress >= cost and result.missing_mana > 0:
		result.state = "waiting_mana"
		result.eta = "Aguardando %d Mana" % result.missing_mana
	elif progress >= cost and result.missing_gold > 0:
		result.state = "waiting_gold"
		result.eta = "Aguardando %d Ouro" % result.missing_gold
	else:
		result.state = "producing"
		if income <= 0.0:
			result.eta = "Sem progresso"
		else:
			var turns := maxi(int(ceil(maxf(cost - progress, 0.0) / income)), 1)
			result.eta_turns = turns
			result.eta = "≈%d turno%s" % [turns, "" if turns == 1 else "s"]
	return result

static func missing_mana(city: City) -> int:
	if city.production_item == "" or city.owner_player == null:
		return 0
	var cost := _production_mana_cost(city.production_item)
	return maxi(int(ceil(cost - city.owner_player.mana)), 0) if cost > 0.0 else 0

static func _production_mana_cost(item_id: String) -> float:
	if not V2ResearchDatabase.is_v2_id(item_id) or BuildingDatabase.get_building(item_id) != null or V2CityLevelData.is_city_project(item_id) or V2FortificationData.is_fortification_project(item_id):
		return 0.0
	return float(_facts(item_id).mana_cost)

static func production_name(item_id: String, race: String = "human") -> String:
	var building := BuildingDatabase.get_building(item_id)
	if building != null:
		return RaceTheme.building_name(item_id, race)
	if V2CityLevelData.is_city_project(item_id):
		return "Evoluir para %s" % V2CityLevelData.level_name(V2CityLevelData.target_level_for_project(item_id))
	if V2FortificationData.is_fortification_project(item_id):
		return V2FortificationData.display_name(V2FortificationData.target_level_for_project(item_id))
	return RaceTheme.unit_name(item_id, race)

static func production_type(item_id: String) -> String:
	if BuildingDatabase.get_building(item_id) != null:
		return "Edifício"
	if V2CityLevelData.is_city_project(item_id):
		return "Desenvolvimento"
	if V2FortificationData.is_fortification_project(item_id):
		return "Defesa"
	return "Unidade"

static func _race_of(city: City) -> String:
	return city.owner_player.civ.race if city.owner_player != null and city.owner_player.civ != null else "human"

# --- Catálogo categorizado ------------------------------------------------------------

## Grupos na ordem Unidades / Edifícios / Projetos. Visibilidade idêntica ao legado:
## só aparece o que a pesquisa do dono já revelou; bloqueio visível sempre vem com o
## motivo do runtime.
static func catalog(city: City) -> Dictionary:
	return {
		"units": _unit_items(city),
		"buildings": _building_items(city),
		"projects": _project_items(city),
	}

## Fonte única para consumidores que precisam decidir se uma cidade ociosa
## realmente tem uma escolha de produção. Reutiliza o mesmo catálogo exibido.
static func startable_production_items(city: City) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var production_catalog := catalog(city)
	for group_name in ["units", "buildings", "projects"]:
		for raw_item in production_catalog[group_name]:
			var item: Dictionary = raw_item
			if item.get("state", "") == "available":
				result.append(item)
	return result

## Identifica a unidade fundadora pelo dado canônico, nunca pelo texto traduzido.
static func is_settler_production_item(item: Dictionary) -> bool:
	if item.get("category", "") != "units":
		return false
	var unit_data := UnitDatabase.create_unit(String(item.get("id", "")))
	return unit_data != null and unit_data.can_found_city

static func _facts(kind: String) -> Dictionary:
	if _unit_facts.has(kind):
		return _unit_facts[kind]
	var data := UnitDatabase.create_unit(kind)
	var subgroup := "Exército"
	if data.has_trait(UnitData.TRAIT_LEGENDARY) or V2ManifestationSystem.is_manifestation_kind(kind):
		subgroup = "Lendárias e Manifestações"
	elif data.is_v2_caster():
		subgroup = "Magia"
	elif data.can_found_city or V2ConstructorRuntime.is_builder_kind(kind) or data.attack <= 0.0:
		subgroup = "Civis"
	var facts := {"cost": data.production_cost, "mana_cost": data.production_mana_cost, "supply": data.supply_cost, "subgroup": subgroup, "description": UnitAbilities.description(kind)}
	_unit_facts[kind] = facts
	return facts

static func unit_item(city: City, kind: String) -> Dictionary:
	var player := city.owner_player
	var unlocked := V2UnlockSystem.is_unit_unlocked(player, kind) if V2ResearchDatabase.is_v2_id(kind) else kind in UnitDatabase.CORE_TRAINABLE_KINDS
	if not unlocked:
		return {}
	if V2UnitLine.is_line_unit(kind) and not V2UnitLine.is_current_trainable_form(player, kind):
		return {}
	var facts := _facts(kind)
	var can_start := city.can_train(kind)
	var reason := ""
	if not can_start:
		reason = V2LegendarySystem.slot_only_reason(player, city, kind)
		if reason == "":
			reason = V2LogisticsRuntime.training_soft_reason(player, city, kind)
		if reason == "":
			reason = V2ManifestationSystem.training_soft_reason(player, city, kind)
		if reason == "":
			var trainer := BuildingDatabase.building_that_trains(kind)
			if trainer != null and not city.buildings.has(trainer.id):
				reason = "Requer construir: %s" % RaceTheme.building_name(trainer.id)
		if reason == "":
			return {}
	var name := RaceTheme.unit_name(kind, _race_of(city))
	var cost := float(facts.cost)
	var eta := _eta_text(city, cost)
	var meta_parts: Array[String] = ["%s PP" % _number(cost)]
	if float(facts.mana_cost) > 0.0:
		meta_parts[0] = "%s PP + %s Mana" % [_number(cost), _number(facts.mana_cost)]
	if eta != "":
		meta_parts.append(eta)
	if int(facts.supply) > 0:
		meta_parts.append("Sup. %d" % int(facts.supply))
	var details: Array = ["Custo: %s" % meta_parts[0]]
	if eta != "":
		details.append("Tempo estimado: %s" % eta)
	if int(facts.supply) > 0:
		details.append("Suprimentos: %d" % int(facts.supply))
	if float(facts.mana_cost) > 0.0:
		details.append("Mana cobrada na conclusão; é preciso tê-la para iniciar.")
	var state := "current" if city.production_item == kind else ("available" if can_start else "blocked")
	return {
		"id": kind, "name": name, "category": "units", "subgroup": facts.subgroup,
		"pp": cost, "mana_cost": facts.mana_cost, "supply": facts.supply, "upkeep": 0.0,
		"meta": " · ".join(meta_parts), "state": state, "reason": reason,
		"tooltip": AETooltip.compose(name, String(facts.description), details, reason),
	}

static func _unit_items(city: City) -> Array:
	var result: Array = []
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		var item := unit_item(city, kind)
		if not item.is_empty():
			result.append(item)
	return _sorted_by_subgroup(result, UNIT_SUBGROUPS)

static func building_subgroup(building_id: String) -> String:
	if V2InfrastructureEconomyData.is_economy_building(building_id):
		return "Economia"
	var node := V2ResearchDatabase.node_for_unlock_id(building_id)
	if node != null:
		match node.tier_role:
			"mastery_structure":
				return "Maestria"
			"ritual_structure":
				return "Ritual"
			"training_structure", "school_building":
				return "Treinamento"
	var building := BuildingDatabase.get_building(building_id)
	if building != null and building.trains_unit != "":
		return "Treinamento"
	return "Outros"

static func building_item(city: City, building: BuildingData) -> Dictionary:
	if not city._research_unlocked_for_building(building.id):
		return {}
	var count := city.building_count(building.id)
	var max_copies := city.max_copies_for_building(building)
	# Prédio ÚNICO já construído mora em Estruturas; no catálogo seria só ruído.
	if building.copy_limit_mode == BuildingData.CopyLimitMode.UNIQUE and count >= 1 and city.production_item != building.id:
		return {}
	var can_start := city.can_build(building.id)
	var reason := "" if can_start else building_lock_reason(city, building)
	var name := RaceTheme.building_name(building.id)
	var eta := _eta_text(city, building.production_cost)
	var meta_parts: Array[String] = ["%s PP" % _number(building.production_cost)]
	if eta != "":
		meta_parts.append(eta)
	if building.gold_upkeep > 0.0:
		meta_parts.append("%s Ouro/t" % _number(building.gold_upkeep))
	if building.copy_limit_mode == BuildingData.CopyLimitMode.CITY_LEVEL:
		meta_parts.append("%d/%d" % [count, max_copies])
	var details: Array = []
	details.append_array(TileInspector.building_function_lines(building, city.owner_player))
	details.append("Ocupa 1 slot (%d/%d usados)" % [city.used_building_slots(), city.max_building_slots()])
	if building.requires_building != "":
		details.append("Requer na cidade: %s" % RaceTheme.building_name(building.requires_building))
	var state := "current" if city.production_item == building.id else ("available" if can_start else "blocked")
	return {
		"id": building.id, "name": name, "category": "buildings", "subgroup": building_subgroup(building.id),
		"pp": building.production_cost, "mana_cost": 0.0, "supply": 0, "upkeep": building.gold_upkeep,
		"meta": " · ".join(meta_parts), "state": state, "reason": reason,
		"tooltip": AETooltip.compose(name, "Prédio posicionado num tile do território.", details, reason),
	}

## Mesma ordem de motivos do painel legado (pesquisa → pré-requisito → cópias →
## slots → Déficit), lida do City real.
static func building_lock_reason(city: City, building: BuildingData) -> String:
	if not city._research_unlocked_for_building(building.id):
		var node := V2ResearchDatabase.node_for_unlock_id(building.id)
		return "Requer pesquisa: %s" % (node.display_name if node != null else building.id)
	if building.requires_building != "" and not city.buildings.has(building.requires_building):
		return "Requer construir: %s" % RaceTheme.building_name(building.requires_building)
	if city.building_count(building.id) >= city.max_copies_for_building(building):
		return "Limite de cópias atingido para %s" % V2CityLevelData.level_name(city.city_level)
	if city.used_building_slots() >= city.max_building_slots():
		return "Sem espaço: %d/%d prédios (evolua a cidade de nível)" % [city.used_building_slots(), city.max_building_slots()]
	return city.deficit_build_reason(building.id)

static func _building_items(city: City) -> Array:
	var result: Array = []
	for building in BuildingDatabase.all_buildings():
		var item := building_item(city, building)
		if not item.is_empty():
			result.append(item)
	return _sorted_by_subgroup(result, BUILDING_SUBGROUPS)

static func _project_items(city: City) -> Array:
	var result: Array = []
	var next_level := V2CityLevelData.next_level(city.city_level)
	if next_level > 0:
		var project_id := V2CityLevelData.project_id_for_level(next_level)
		var pp := V2CityLevelData.upgrade_production_cost(next_level)
		var gold_cost := V2CityLevelData.upgrade_gold_cost(next_level)
		var reason := city.city_upgrade_unavailable_reason()
		var name := "Evoluir para %s" % V2CityLevelData.level_name(next_level)
		var eta := _eta_text(city, pp)
		var details: Array = ["Vida máxima: %s → %s" % [_number(city.max_hp()), _number(V2CityLevelData.max_hp(next_level))], "Slots de prédio: %d → %d" % [city.max_building_slots(), V2CityLevelData.max_building_slots(next_level)], "Cópias por prédio repetível: %d → %d" % [V2CityLevelData.repeatable_building_limit(city.city_level), V2CityLevelData.repeatable_building_limit(next_level)], "Pontos de Anexação: +%d" % V2CityLevelData.annexation_grant(next_level), "Ouro cobrado na conclusão."]
		var state := "current" if city.production_item == project_id else ("available" if reason == "" else "blocked")
		result.append({
			"id": project_id, "name": name, "category": "development", "subgroup": "Desenvolvimento",
			"pp": pp, "mana_cost": 0.0, "supply": 0, "upkeep": 0.0,
			"meta": " · ".join(["%s PP + %s Ouro" % [_number(pp), _number(gold_cost)]] + ([eta] if eta != "" else [])),
			"state": state, "reason": reason if state != "current" else "",
			"tooltip": AETooltip.compose(name, "Projeto local: usa a produção normal da cidade.", details, reason if state == "blocked" else ""),
		})
	var next_fortification := V2FortificationData.next_level(city.fortification_level)
	if next_fortification > 0:
		var project_id := V2FortificationData.project_id(next_fortification)
		var pp := V2FortificationData.production_cost(next_fortification)
		var reason := city.fortification_unavailable_reason()
		var name := V2FortificationData.display_name(next_fortification)
		var eta := _eta_text(city, pp)
		var details: Array = ["Escudo máximo: %s" % _number(V2FortificationData.shield_max(next_fortification)), "Defesa urbana: +%d%%" % int(round(V2FortificationData.city_defense_bonus(next_fortification) * 100.0)), "Ataque da Cidade: %s | Alcance %d" % [_number(V2FortificationData.city_attack_power(next_fortification)), V2FortificationData.city_attack_range(next_fortification)], "Manutenção: %s Ouro/turno" % _number(V2FortificationData.gold_upkeep(next_fortification))]
		var state := "current" if city.production_item == project_id else ("available" if reason == "" else "blocked")
		result.append({
			"id": project_id, "name": name, "category": "defense", "subgroup": "Defesa",
			"pp": pp, "mana_cost": 0.0, "supply": 0, "upkeep": V2FortificationData.gold_upkeep(next_fortification),
			"meta": " · ".join(["%s PP" % _number(pp)] + ([eta] if eta != "" else []) + ["%s Ouro/t" % _number(V2FortificationData.gold_upkeep(next_fortification))]),
			"state": state, "reason": reason if state != "current" else "",
			"tooltip": AETooltip.compose(name, "Projeto local de Fortificação.", details, reason if state == "blocked" else ""),
		})
	return result

static func _sorted_by_subgroup(items: Array, order: Array) -> Array:
	var buckets: Dictionary = {}
	for item in items:
		var key: String = item.subgroup
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(item)
	var result: Array = []
	for key in order:
		result.append_array(buckets.get(key, []))
	for key in buckets:
		if not key in order:
			result.append_array(buckets[key])
	return result

static func _eta_text(city: City, cost: float) -> String:
	var income := V2EconomyRuntime.city_production_income(city)
	if income <= 0.0:
		return ""
	var turns := maxi(int(ceil(cost / income)), 1)
	return "≈%d turno%s" % [turns, "" if turns == 1 else "s"]

# --- Estruturas ------------------------------------------------------------------------

static func structures(city: City) -> Dictionary:
	var groups: Dictionary = {}
	for id in city.buildings.keys():
		var building := BuildingDatabase.get_building(String(id))
		if building == null:
			continue
		var count := city.building_count(building.id)
		var subgroup := building_subgroup(building.id)
		var repeatable := building.copy_limit_mode == BuildingData.CopyLimitMode.CITY_LEVEL
		var function_lines := TileInspector.building_function_lines(building, city.owner_player)
		var row := {
			"id": building.id,
			"name": RaceTheme.building_name(building.id),
			"count": count,
			"max_copies": city.max_copies_for_building(building),
			"repeatable": repeatable,
			"upkeep": building.gold_upkeep * float(count),
			"summary": function_lines[0] if not function_lines.is_empty() else "",
			"tooltip": AETooltip.compose(RaceTheme.building_name(building.id), "Repetível: %d/%d cópias neste nível." % [count, city.max_copies_for_building(building)] if repeatable else "Prédio único.", function_lines),
		}
		if not groups.has(subgroup):
			groups[subgroup] = []
		groups[subgroup].append(row)
	var ordered: Array = []
	for key in BUILDING_SUBGROUPS:
		if groups.has(key):
			var rows: Array = groups[key]
			rows.sort_custom(func(a, b): return String(a.name) < String(b.name))
			ordered.append({"title": key, "rows": rows})
	return {"groups": ordered, "slots_used": city.used_building_slots(), "slots_max": city.max_building_slots(), "upkeep_total": V2EconomyRuntime.city_gold_upkeep(city)}

# --- Território ---------------------------------------------------------------------------

static func territory(city: City, grid: HexGrid) -> Dictionary:
	var resources: Array = []
	if grid != null:
		var coords: Array[Vector2i] = [city.coord]
		for coord in city.owned_tiles:
			if not coord in coords:
				coords.append(coord)
		for coord in coords:
			var tile := grid.get_tile(coord)
			if tile == null or tile.resource == "":
				continue
			var improvement_id: String = city.resource_improvements.get(coord, "")
			var improved := improvement_id != ""
			var yields := TileInspector._improvement_yield_lines(tile.resource, city.owner_player)
			var pillaged := improved and grid.is_tile_pillaged(coord, TurnManager.turn_number)
			resources.append({
				"coord": coord,
				"name": ResourceDatabase.display_name(tile.resource),
				"improvement": V2ResourceImprovementData.display_name_for_resource(tile.resource),
				"improved": improved,
				"pillaged": pillaged,
				"yield_text": ", ".join(yields),
				"tooltip": AETooltip.compose(ResourceDatabase.display_name(tile.resource), "Melhoria: %s" % V2ResourceImprovementData.display_name_for_resource(tile.resource) if V2ResourceImprovementData.has_resource(tile.resource) else "", ["Efeito: %s" % ", ".join(yields)] if not yields.is_empty() else [], "Saqueada: sem rendimento por enquanto." if pillaged else ("Sem melhoria: um Construtor pode melhorá-lo." if not improved and V2ResourceImprovementData.has_resource(tile.resource) else "")),
			})
	var processing := GameManager.is_turn_processing
	var annex_reason := ""
	if processing:
		annex_reason = "Aguarde o fim do processamento do turno."
	elif city.annexation_points <= 0:
		annex_reason = "Sem Pontos de Anexação."
	return {
		"radius": V2CityLevelData.max_territory_radius(city.city_level),
		"owned_tiles": city.owned_tiles.size(),
		"annex_points": city.annexation_points,
		"annex_reason": annex_reason,
		"resources": resources,
	}

# --- Defesa --------------------------------------------------------------------------------

static func defense_view(city: City, own: bool, grid: HexGrid) -> Dictionary:
	var result := {
		"hp": city.hp,
		"max_hp": city.max_hp(),
		"shield": city.shield,
		"max_shield": city.max_shield(),
		"fortified": city.has_fortification(),
		"fortification_name": V2FortificationData.display_name(city.fortification_level) if city.has_fortification() else "Sem fortificação",
		"defense_bonus": int(round(V2FortificationData.city_defense_bonus(city.fortification_level) * 100.0)),
		"attack": {},
	}
	if city.has_fortification():
		var attack := {
			"power": TileInspector._format_power(CityDefense.city_attack_power(city)),
			"range": CityDefense.city_attack_range(city),
			"used": city.last_city_attack_turn == TurnManager.turn_number,
			"reason": "",
		}
		if own:
			var reason := CityDefense.city_attack_unavailable_reason(city)
			if reason == "" and grid != null and CityDefense.city_attack_targets(city, grid).is_empty():
				reason = "Nenhum alvo hostil visível ao alcance."
			if GameManager.is_turn_processing:
				reason = "Aguarde o fim do processamento do turno."
			attack.reason = reason
		result.attack = attack
	return result

# --- Desenvolvimento -------------------------------------------------------------------------

static func development(city: City) -> Dictionary:
	var next_level := V2CityLevelData.next_level(city.city_level)
	var result := {"level": city.city_level, "level_name": V2CityLevelData.level_name(city.city_level), "next_level": next_level, "max": next_level == 0}
	if next_level > 0:
		result["next_name"] = V2CityLevelData.level_name(next_level)
		result["pp"] = V2CityLevelData.upgrade_production_cost(next_level)
		result["gold"] = V2CityLevelData.upgrade_gold_cost(next_level)
		result["reason"] = city.city_upgrade_unavailable_reason()
		result["in_progress"] = city.production_item == V2CityLevelData.project_id_for_level(next_level)
		result["benefits"] = ["Vida %s → %s" % [_number(city.max_hp()), _number(V2CityLevelData.max_hp(next_level))], "Slots %d → %d" % [city.max_building_slots(), V2CityLevelData.max_building_slots(next_level)], "+%d Pontos de Anexação" % V2CityLevelData.annexation_grant(next_level)]
	return result

# --- Ritual --------------------------------------------------------------------------------

## Dono vê ações reais depois do acesso à Transcendência; rival vê só o Ritual
## público ativo nesta cidade (dono, rodadas) — nada sobre pesquisa ou Manifestações.
static func ritual_view(city: City, own: bool, grid: HexGrid) -> Dictionary:
	var owner := city.owner_player
	if owner == null:
		return {"visible": false}
	var active := V2TranscendenceSystem.has_active_ritual(owner)
	var here := active and V2TranscendenceSystem.ritual_site_coord(owner) == city.coord
	if not own:
		if here:
			return {"visible": true, "public": true, "state": "active", "rounds": V2TranscendenceSystem.ritual_rounds_remaining(owner), "here": true}
		return {"visible": false}
	if not V2TranscendenceSystem.has_access(owner) and not active:
		return {"visible": false}
	var result := {"visible": true, "public": false, "here": here, "rounds": V2TranscendenceSystem.ritual_rounds_remaining(owner), "mana_cost": int(V2TranscendenceSystem.MANA_COST), "rounds_required": V2TranscendenceSystem.ROUNDS_REQUIRED}
	if active:
		result["state"] = "active" if here else "active_elsewhere"
		var site := V2TranscendenceSystem.ritual_site(owner, grid)
		result["site_name"] = site.city_name if site != null else "outro local"
		result["reason"] = "Aguarde o fim do processamento do turno." if GameManager.is_turn_processing else ""
	else:
		var reason := V2TranscendenceSystem.start_unavailable_reason(owner, city)
		if GameManager.is_turn_processing:
			reason = "Aguarde o fim do processamento do turno."
		result["state"] = "available" if reason == "" else "unavailable"
		result["reason"] = reason
	return result

static func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
