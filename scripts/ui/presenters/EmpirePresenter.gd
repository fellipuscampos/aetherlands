class_name EmpirePresenter
extends RefCounted

## View model da tela IMPÉRIO (Fase 30 / UI-3): Visão geral, Cidades e Unidades
## do jogador humano. Só lê o estado real e os presenters já existentes
## (CityPresenter.production_snapshot, AttentionService, V2* runtimes); cada bloco
## carrega um deep link para a superfície onde a decisão acontece.

const FILTER_ALL := "all"
const FILTER_MILITARY := "military"
const FILTER_CASTER := "caster"
const FILTER_SPECIAL := "special"
const SORT_ATTENTION := "attention"
const SORT_NAME := "name"
const SORT_LEVEL := "level"
const SORT_PRODUCTION := "production"

# --- Visão geral ---------------------------------------------------------------------

static func overview(player: PlayerData, attention: Array = []) -> Dictionary:
	if player == null:
		return {"valid": false}
	var cities := city_rows(player, SORT_ATTENTION)
	var idle := 0
	var waiting := 0
	var threatened := 0
	for row in cities:
		if row.production_state == "idle":
			idle += 1
		elif row.production_state == "waiting_mana":
			waiting += 1
		if row.threatened:
			threatened += 1
	var units := unit_rows(player, FILTER_ALL)
	var counts := {FILTER_MILITARY: 0, FILTER_CASTER: 0, FILTER_SPECIAL: 0}
	var ready := 0
	var uncommanded := 0
	for row in units:
		counts[row.filter] = int(counts[row.filter]) + 1
		if row.can_act:
			ready += 1
		if row.uncommanded:
			uncommanded += 1
	var wars: Array[String] = []
	for rival in GameManager.rival_players:
		if player.is_at_war_with(rival) and not V2VictoryConditions.is_eliminated(rival):
			wars.append(rival.civ.civ_name if rival.civ != null else "Rival")
	var research := {"active": false, "name": "Nenhuma pesquisa ativa", "ratio": 0.0}
	var active := V2ResearchDatabase.get_node(player.v2_research.active_id) if player.v2_research != null else null
	if active != null:
		research = {"active": true, "name": active.display_name, "ratio": player.v2_research.get_progress_ratio(active.id)}
	var warnings: Array = []
	for item in attention:
		if item is AttentionItem:
			warnings.append({"id": item.id, "title": item.title, "description": item.description, "action": item.primary_action, "label": item.primary_action_label, "required": item.priority == AttentionItem.Priority.REQUIRED, "target": item.target_coord if item.has_target_coord else null, "item": item})
	return {
		"valid": true,
		"resources": {
			"gold": int(player.gold),
			"gold_net": int(V2EconomyRuntime.player_gold_net_income(player)),
			"deficit": V2EconomyRuntime.is_gold_deficit(player),
			"mana": int(player.mana),
			"mana_income": int(V2EconomyRuntime.player_mana_income(player)),
			"knowledge_income": int(V2EconomyRuntime.player_knowledge_income(player)),
			"supply_used": V2LogisticsRuntime.player_supply_used(player),
			"supply_capacity": int(V2EconomyRuntime.player_supply_capacity(player)),
			"tension": V2LogisticsRuntime.is_logistically_strained(player),
		},
		"cities": {"count": cities.size(), "idle": idle, "waiting_mana": waiting, "threatened": threatened},
		"units": {"count": units.size(), "military": counts[FILTER_MILITARY], "caster": counts[FILTER_CASTER], "special": counts[FILTER_SPECIAL], "ready": ready, "uncommanded": uncommanded},
		"wars": wars,
		"research": research,
		"victory": victory_highlight(player),
		"warnings": warnings,
	}

## Uma linha só quando existe objetivo de vitória crítico/ativo e público.
static func victory_highlight(player: PlayerData) -> Dictionary:
	if V2TranscendenceSystem.has_active_ritual(player):
		return {"text": "Seu Ritual de Transcendência: %d rodada(s)." % V2TranscendenceSystem.ritual_rounds_remaining(player), "detail": "transcendence", "tone": "success"}
	for ritual in V2TranscendenceSystem.public_rituals():
		if int(ritual.owner_index) != V2VictoryConditions.stable_id(player):
			return {"text": "%s conduz um Ritual: %d rodada(s)." % [ritual.owner_name, int(ritual.remaining_rounds)], "detail": "transcendence", "tone": "critical"}
	var supremacy := V2VictoryConditions.military_supremacy_status(player)
	if supremacy.access:
		return {"text": "Supremacia Militar: %d / %d rivais satisfeitos." % [supremacy.satisfied_count, supremacy.rival_count], "detail": "supremacy", "tone": "success"}
	return {}

# --- Cidades -------------------------------------------------------------------------

static func city_rows(player: PlayerData, sort_key: String = SORT_ATTENTION) -> Array:
	var rows: Array = []
	if player == null:
		return rows
	var order := 0
	for city in player.cities:
		if city == null or not is_instance_valid(city) or city.owner_player != player:
			continue
		var production := CityPresenter.production_snapshot(city)
		var alerts: Array[String] = []
		var rank := 3
		match String(production.state):
			"idle":
				alerts.append("Ociosa")
				rank = 0
			"waiting_mana":
				alerts.append("Aguardando Mana")
				rank = 2
			"waiting_gold":
				alerts.append("Aguardando Ouro")
				rank = 2
		var threatened := CityPresenter.is_threatened(city)
		if threatened:
			alerts.append("Ameaçada")
			rank = mini(rank, 1)
		if V2TranscendenceSystem.has_active_ritual(player) and V2TranscendenceSystem.ritual_site_coord(player) == city.coord:
			alerts.append("Ritual")
		rows.append({
			"city": city,
			"coord": city.coord,
			"name": city.city_name,
			"level": city.city_level,
			"level_name": V2CityLevelData.level_name(city.city_level),
			"hp": city.hp,
			"max_hp": city.max_hp(),
			"shield": city.shield,
			"max_shield": city.max_shield(),
			"fortification": V2FortificationData.display_name(city.fortification_level) if city.has_fortification() else "",
			"production_state": String(production.state),
			"production_name": String(production.item_name),
			"production_eta": String(production.eta),
			"production_ratio": float(production.progress) / maxf(float(production.cost), 1.0),
			"alerts": alerts,
			"threatened": threatened,
			"rank": rank,
			"order": order,
		})
		order += 1
	match sort_key:
		SORT_NAME:
			rows.sort_custom(func(a, b): return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
		SORT_LEVEL:
			rows.sort_custom(func(a, b): return a.level > b.level if a.level != b.level else a.order < b.order)
		SORT_PRODUCTION:
			rows.sort_custom(func(a, b): return _production_rank(a) < _production_rank(b) if _production_rank(a) != _production_rank(b) else a.order < b.order)
		_:
			rows.sort_custom(func(a, b): return a.rank < b.rank if a.rank != b.rank else a.order < b.order)
	return rows

static func _production_rank(row: Dictionary) -> int:
	match String(row.production_state):
		"idle":
			return 0
		"waiting_mana", "waiting_gold":
			return 1
	return 2

# --- Unidades ------------------------------------------------------------------------

static func unit_filter(unit: Unit) -> String:
	var data := unit.unit_data
	if V2LegendarySystem.is_legendary_unit(unit) or V2ManifestationSystem.is_manifestation_unit(unit) or data.is_retinue() or data.can_found_city or V2ConstructorRuntime.is_builder_unit(unit):
		return FILTER_SPECIAL
	if data.is_v2_caster():
		return FILTER_CASTER
	return FILTER_MILITARY

static func unit_rows(player: PlayerData, filter: String = FILTER_ALL) -> Array:
	var rows: Array = []
	if player == null:
		return rows
	var grid := GameManager.hex_grid
	var race: String = player.civ.race if player.civ != null else "human"
	for unit in player.units:
		if unit == null or not is_instance_valid(unit) or unit.hp <= 0.0:
			continue
		var unit_filter_value := unit_filter(unit)
		if filter != FILTER_ALL and unit_filter_value != filter:
			continue
		var data := unit.unit_data
		var badge := ""
		if V2LegendarySystem.is_legendary_unit(unit):
			badge = "Lendária"
		elif V2ManifestationSystem.is_manifestation_unit(unit):
			badge = "Manifestação"
		elif data.is_retinue():
			badge = "Hoste"
		var uncommanded := data.is_retinue() and not unit.can_receive_orders()
		var status := ""
		if uncommanded:
			status = "SEM COMANDO"
		elif V2MagicRuntime.is_spellcasting_silenced(unit):
			status = "Silêncio"
		elif unit.fortified:
			status = "Fortificada"
		elif unit.exploring:
			status = "Explorando"
		elif unit.move_order_target != Unit.NO_MOVE_ORDER:
			status = "Em marcha"
		else:
			var technique := V2TechniqueRuntime.active_technique_name(unit)
			var spell := V2MagicRuntime.active_status_name(unit)
			status = technique if technique != "" else spell
		var location := "(%d, %d)" % [unit.coord.x, unit.coord.y]
		var city_here: City = grid.get_city_at(unit.coord) if grid != null else null
		if city_here != null:
			location = city_here.city_name
		var upgrade_target := V2UnitUpgrade.get_upgrade_target(unit)
		rows.append({
			"unit": unit,
			"serial_id": unit.serial_id,
			"coord": unit.coord,
			"name": RaceTheme.unit_name(data.visual_kind, race),
			"role": TileInspector.unit_class_label(unit),
			"filter": unit_filter_value,
			"hp": unit.hp,
			"max_hp": data.max_hp,
			"movement": unit.movement_left,
			"max_movement": data.movement_points,
			"can_act": unit.movement_left > 0.0 and unit.can_receive_orders(),
			"location": location,
			"status": status,
			"badge": badge,
			"uncommanded": uncommanded,
			"charges": unit.work_charges_remaining if V2ConstructorRuntime.is_builder_unit(unit) else -1,
			"upgrade": upgrade_target != "" and V2UnlockSystem.is_unlocked(player, upgrade_target),
		})
	return rows

static func uncommanded_retinues(player: PlayerData) -> Array[Unit]:
	var result: Array[Unit] = []
	if player == null:
		return result
	for unit in player.units:
		if unit != null and is_instance_valid(unit) and unit.unit_data.is_retinue() and not unit.can_receive_orders():
			result.append(unit)
	return result
