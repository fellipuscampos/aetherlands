class_name TileInspector
extends RefCounted

## INSPECAO DE TILES, UNIDADES, MONSTROS E ESTRUTURAS (Task 23) -- modelo
## UNICO de "o que existe neste tile?", separado da HUD pra ser testavel sem
## cena e pra HUD/UnitPanel/qualquer outro consumidor mostrarem exatamente
## os mesmos fatos.
##
## PROBLEMA ANTERIOR: HUD._on_tile_selected montava o texto so' do TERRENO
## (+ cidade); unidade rival, boss, covil (estrutura), predio, estrutura
## magica e recurso isolado nao apareciam; TODO monstro neutro era rotulado
## "Covil de Monstro" (mesmo um Esqueleto andando); e a nevoa nao era
## respeitada (clicar num tile nunca visto mostrava o terreno).
##
## inspect() devolve {coord, state, entries, terrain_title, terrain_lines}:
##  - `entries` = entidades relevantes visiveis AGORA, na ordem de prioridade
##    cidade > unidade/personagem > monstro/boss > covil > predio/obra >
##    estrutura magica/ritual > recurso. Cada entry: {key, kind, tag, title,
##    lines}. A primeira e' a "entidade principal"; o resto vira abas na HUD.
##  - o TERRENO nunca some: e' sempre uma secao separada (terrain_*), nunca
##    substitui a entidade principal.
## Regras de segredo (mesma nevoa do mapa, ver HexGrid._apply_fog_to_entities):
## tile UNSEEN nao revela nada; entidade de OUTRO dono so' com o tile VISIVEL
## agora e nao ocultada por veu (MagicRuntime.concealed); cidade/predio rival
## nao mostram producao/estoque/lista de predios; unidade rival nao mostra
## recarga de magia, movimento restante nem ordens; a HP/escudo de cidade e
## de unidade sao as mesmas das barras que o mapa ja desenha.

const KIND_CITY := "city"
const KIND_UNIT := "unit"
const KIND_MONSTER := "monster"
const KIND_BOSS := "boss"
const KIND_LAIR := "lair"
const KIND_BUILDING := "building"
const KIND_SITE := "site"
const KIND_MAGIC := "magic"
const KIND_RESOURCE := "resource"

const STATE_UNSEEN := "unseen"
const STATE_EXPLORED := "explored"
const STATE_VISIBLE := "visible"

const ROLE_LABELS := {"melee": "Corpo a corpo", "ranged": "À distância", "cavalry": "Cavalaria", "siege": "Cerco"}
const STATUS_LABELS := {
	"silence": "Silenciado", "slow": "Lentidão", "curse": "Maldição", "blessing": "Bênção",
	"blood_pact": "Pacto de sangue", "storm": "Tempestade", "revealed": "Revelado",
}
const BEHAVIOR_LABELS := {
	"guardian": "Guardião (defende o território do covil)",
	"raider": "Saqueador (caça presas fracas e saqueia)",
	"invader": "Invasor (marcha sobre a cidade mais próxima)",
	"hunter": "Caçador (patrulha atrás de presas isoladas)",
}
const RESOURCE_EFFECTS := {
	"iron": "Reduz o custo de unidades pesadas (até -%d%%)",
	"horses": "Reduz o custo de Cavalaria (até -%d%%)",
	"gems": "Reduz o custo de compra rápida (até -%d%%)",
	"mana_node": "Reduz o custo de feitiços (até -%d%%)",
	"silk": "Aumenta a capacidade de rotas comerciais (até +%d)",
}

# ---------------------------------------------------------------------------
# Entrada principal
# ---------------------------------------------------------------------------

static func visibility_state(hex_grid: HexGrid, coord: Vector2i) -> String:
	match hex_grid.visibility.get(coord, HexGrid.Visibility.UNSEEN):
		HexGrid.Visibility.VISIBLE:
			return STATE_VISIBLE
		HexGrid.Visibility.EXPLORED:
			return STATE_EXPLORED
	return STATE_UNSEEN

static func inspect(hex_grid: HexGrid, coord: Vector2i, viewer: PlayerData) -> Dictionary:
	var state := visibility_state(hex_grid, coord)
	var entries: Array = []
	var tile: HexTileData = hex_grid.get_tile(coord)

	var city: City = hex_grid.get_city_at(coord)
	if city != null and (city.owner_player == viewer or state == STATE_VISIBLE):
		entries.append(_city_entry(city, hex_grid, viewer))

	var unit: Unit = hex_grid.get_unit_at(coord)
	if unit != null and is_instance_valid(unit) and _unit_is_perceived(unit, viewer, state, hex_grid):
		entries.append(_unit_entry(unit, hex_grid, viewer))

	var lair: LairStructure = hex_grid.lairs_by_coord.get(coord)
	if lair != null and is_instance_valid(lair) and state != STATE_UNSEEN:
		entries.append(_lair_entry(lair, coord, hex_grid, state))

	var building: Building = hex_grid.buildings_by_coord.get(coord)
	if building != null and is_instance_valid(building) and (building.owner_player == viewer or state == STATE_VISIBLE):
		entries.append(_building_entry(building, hex_grid, viewer))
	else:
		var site := _construction_entry(coord, hex_grid, viewer, state)
		if not site.is_empty():
			entries.append(site)

	entries.append_array(_magic_entries(coord, hex_grid, viewer, state))

	if tile != null and tile.resource != "" and state != STATE_UNSEEN:
		entries.append(_resource_entry(tile, coord, hex_grid, viewer))

	var terrain := _terrain_section(hex_grid, coord, viewer, state, tile)
	return {
		"coord": coord, "state": state, "entries": entries,
		"terrain_title": terrain.title, "terrain_lines": terrain.lines,
	}

## Texto completo: entidade selecionada (`selected_key`, ou a principal se ""
## /inexistente) + secao de terreno. Devolve "" so' se nao ha nada a mostrar.
static func render(inspection: Dictionary, selected_key: String = "") -> String:
	var lines: Array[String] = []
	var entry := entry_for_key(inspection, selected_key)
	if not entry.is_empty():
		lines.append(entry.title)
		lines.append_array(entry.lines)
		lines.append("")
	lines.append(inspection.terrain_title)
	lines.append_array(inspection.terrain_lines)
	return "\n".join(lines)

static func entry_for_key(inspection: Dictionary, key: String) -> Dictionary:
	var entries: Array = inspection.entries
	for entry in entries:
		if entry.key == key:
			return entry
	return entries[0] if not entries.is_empty() else {}

# ---------------------------------------------------------------------------
# Percepcao (segredo)
# ---------------------------------------------------------------------------

static func _unit_is_perceived(unit: Unit, viewer: PlayerData, state: String, hex_grid: HexGrid) -> bool:
	if unit.owner_player == viewer or unit.always_visible:
		return true
	return state == STATE_VISIBLE and not MagicRuntime.concealed(unit, viewer, hex_grid)

static func _faction_line(owner: PlayerData, viewer: PlayerData) -> String:
	if owner == null:
		return "Facção: Monstros (hostis a todos)"
	var civ_name: String = owner.civ.civ_name if owner.civ else "Civilização"
	if owner == viewer:
		return "Facção: %s (sua)" % civ_name
	if viewer != null and viewer.is_at_war_with(owner):
		return "Facção: %s (em guerra)" % civ_name
	return "Facção: %s (em paz)" % civ_name

# ---------------------------------------------------------------------------
# Cidade
# ---------------------------------------------------------------------------

static func _city_entry(city: City, hex_grid: HexGrid, viewer: PlayerData) -> Dictionary:
	var lines: Array[String] = []
	var own := city.owner_player == viewer
	lines.append("Cidade %s | População: %d" % ["sua" if own else "rival", city.population])
	lines.append(_faction_line(city.owner_player, viewer))
	lines.append("Vida: %d/%d | Escudo: %d/%d" % [int(city.hp), int(city.max_hp()), int(city.shield), int(city.max_shield())])
	if own:
		var race: String = city.owner_player.civ.race
		var net_food: float = city.collect_yields(hex_grid).food - city.population * City.FOOD_CONSUMPTION_PER_POP
		lines.append("Comida: %d/%d (%s%d/turno)" % [
			int(city.stored_food), int(city.food_storage_cap()), "+" if net_food >= 0.0 else "", int(net_food)
		])
		var built_names: Array[String] = []
		for id in city.buildings.keys():
			if BuildingDatabase.get_building(id):
				built_names.append(RaceTheme.building_name(id, race))
		var buildings_line := "Predios: %d/%d" % [city.used_building_slots(), city.max_building_slots()]
		if built_names.size() > 0:
			buildings_line += " (%s)" % ", ".join(built_names)
		lines.append(buildings_line)
	elif city.buildings.has("walls"):
		lines.append("Possui muralhas.")
	return {"key": "city", "kind": KIND_CITY, "tag": city.city_name, "title": city.city_name, "lines": lines}

# ---------------------------------------------------------------------------
# Unidades, monstros e bosses
# ---------------------------------------------------------------------------

static func unit_class_label(unit: Unit) -> String:
	var data := unit.unit_data
	if data.magic_school != "":
		return "Conjurador — %s" % school_name(data.magic_school)
	if data.can_found_city:
		return "Colonizador"
	if unit.summoner_id != 0:
		return "Invocação"
	if data.attack <= 0.0:
		return "Apoio"
	var labels: Array[String] = []
	for role in ArmyComposition.roles_for_kind(data.visual_kind):
		labels.append(ROLE_LABELS.get(role, role))
	if labels.is_empty():
		labels.append("Combatente")
	return ", ".join(labels)

static func school_name(school: String) -> String:
	return MagicContent.SCHOOLS.get(school, {}).get("name", school.capitalize())

static func unit_traits(unit: Unit) -> Array[String]:
	var data := unit.unit_data
	var traits: Array[String] = []
	if data.flies:
		traits.append("Voa")
	if data.attack_range > 1:
		traits.append("Ataque à distância (alcance %d)" % data.attack_range)
	if data.ignores_terrain_defense:
		traits.append("Ignora defesa de terreno")
	if data.regen_fraction > 0.0:
		traits.append("Regenera %d%% da vida por turno" % int(round(data.regen_fraction * 100.0)))
	if data.can_found_city:
		traits.append("Funda cidades")
	return traits

static func status_effect_lines(unit: Unit) -> Array[String]:
	var lines: Array[String] = []
	for effect in STATUS_LABELS:
		var until: int = int(unit.magic_status.get(effect, 0))
		if until > TurnManager.turn_number:
			lines.append("%s (%d turno(s))" % [STATUS_LABELS[effect], until - TurnManager.turn_number])
	return lines

## Acao e recarga do conjurador + prazo de invocacao: so' o DONO ve (recarga
## de magia inimiga e' segredo). Sem a linha de ritual/manutencao/ordens, que
## o UnitPanel ja mostra por conta propria.
static func caster_lines(unit: Unit) -> Array[String]:
	var lines: Array[String] = []
	if unit.unit_data.magic_school != "" and unit.ritual_id == "":
		if MagicRuntime.status_active(unit, "silence"):
			lines.append("Ação: silenciado — não pode conjurar.")
		elif unit.movement_left <= 0.0:
			lines.append("Ação: sem movimento neste turno — não pode conjurar.")
		else:
			lines.append("Ação: pronto para conjurar.")
	var cooldowns: Array[String] = []
	for spell_name in unit.magic_cooldowns:
		var ready_turn: int = int(unit.magic_cooldowns[spell_name])
		if ready_turn > TurnManager.turn_number:
			cooldowns.append("%s (%d)" % [spell_name, ready_turn - TurnManager.turn_number])
	if not cooldowns.is_empty():
		lines.append("Recarga: %s" % ", ".join(cooldowns))
	if unit.expires_turn > TurnManager.turn_number:
		lines.append("Invocação: some em %d turno(s)." % (unit.expires_turn - TurnManager.turn_number))
	return lines

## Linhas que so' o DONO deve ver (estado de comando, recarga, manutencao).
static func own_unit_lines(unit: Unit) -> Array[String]:
	var lines: Array[String] = []
	if unit.ritual_id != "":
		lines.append("Canalizando ritual: movimento e feitiços indisponíveis.")
	lines.append_array(caster_lines(unit))
	if unit.unit_data.mana_upkeep > 0.0:
		lines.append("Manutenção: %.0f mana/turno" % unit.unit_data.mana_upkeep)
	if unit.fortified:
		lines.append("Fortificada (+%d%% defesa, cura passiva)" % int(CombatResolver.FORTIFY_DEFENSE_BONUS * 100))
	if unit.exploring:
		lines.append("Explorando automaticamente")
	return lines

static func _unit_entry(unit: Unit, hex_grid: HexGrid, viewer: PlayerData) -> Dictionary:
	if unit.owner_player == null:
		return _monster_entry(unit, hex_grid)
	var data := unit.unit_data
	var own := unit.owner_player == viewer
	var race: String = unit.owner_player.civ.race if unit.owner_player.civ else "human"
	var name := RaceTheme.unit_name(data.visual_kind, race)
	var lines: Array[String] = []
	lines.append("%s%s" % [unit_class_label(unit), " | %s" % unit.veterancy_title() if unit.veterancy_level > 0 else ""])
	lines.append(_faction_line(unit.owner_player, viewer))
	var movement := "Movimento %.1f/%.1f" % [unit.movement_left, data.movement_points] if own else "Movimento %.1f" % data.movement_points
	lines.append("HP %d/%d | Ataque %.1f | Defesa %.1f | %s" % [int(unit.hp), int(data.max_hp), data.attack, data.defense, movement])
	var traits := unit_traits(unit)
	if unit.ritual_id != "" and not own:
		traits.append("Canalizando um ritual")
	if not traits.is_empty():
		lines.append(" · ".join(traits))
	var statuses := status_effect_lines(unit)
	if not statuses.is_empty():
		lines.append(" · ".join(statuses))
	if own:
		lines.append_array(own_unit_lines(unit))
	return {"key": "unit", "kind": KIND_UNIT, "tag": name, "title": name, "lines": lines}

static func _monster_entry(unit: Unit, hex_grid: HexGrid) -> Dictionary:
	var data := unit.unit_data
	var lines: Array[String] = []
	var is_boss := unit.is_camp_boss or unit.world_event_managed
	var lair_kind: String = _lair_kind_near(unit.coord, hex_grid)
	if unit.world_event_managed:
		lines.append("Criatura de evento mundial")
	elif unit.is_camp_boss:
		var home: String = " do covil de %s" % MonsterDatabase.KIND_DATA[lair_kind].unit_name if lair_kind != "" else " do covil"
		lines.append("Chefe%s — não sai do covil" % home)
	lines.append(_faction_line(null, null))
	lines.append("HP %d/%d | Ataque %.1f | Defesa %.1f | Movimento %.1f%s" % [int(unit.hp), int(data.max_hp), data.attack, data.defense, data.movement_points, " (voa)" if data.flies else ""])
	if not unit.is_camp_boss and not unit.world_event_managed:
		lines.append("Comportamento: %s" % BEHAVIOR_LABELS.get(MonsterAI._effective_behavior(unit), "Desconhecido"))
	var statuses := status_effect_lines(unit)
	if not statuses.is_empty():
		lines.append(" · ".join(statuses))
	if data.gold_reward > 0.0:
		lines.append("Recompensa por derrotar: %d ouro" % int(data.gold_reward))
	var kind := KIND_BOSS if is_boss else KIND_MONSTER
	return {"key": kind, "kind": kind, "tag": data.unit_name, "title": data.unit_name, "lines": lines}

static func _lair_kind_near(coord: Vector2i, hex_grid: HexGrid) -> String:
	var lair_coord := hex_grid.home_lair_for(coord)
	if lair_coord == HexGrid.NO_LAIR:
		return ""
	var kind: String = hex_grid.lair_kind_by_coord.get(lair_coord, "")
	return kind if MonsterDatabase.KIND_DATA.has(kind) else ""

# ---------------------------------------------------------------------------
# Covil
# ---------------------------------------------------------------------------

static func _lair_entry(lair: LairStructure, coord: Vector2i, hex_grid: HexGrid, state: String) -> Dictionary:
	var info: Dictionary = MonsterDatabase.KIND_DATA.get(lair.kind, {})
	var kind_name: String = info.get("unit_name", "Monstros")
	var lines: Array[String] = [_faction_line(null, null)]
	if state == STATE_VISIBLE:
		lines.append("Estrutura: %d/%d HP" % [int(lair.hp), int(lair.max_hp)])
		var defenders := 0
		for area_coord in hex_grid._lair_area(coord):
			var occupant: Unit = hex_grid.get_unit_at(area_coord)
			if occupant != null and occupant.owner_player == null and hex_grid.visibility.get(area_coord, 0) == HexGrid.Visibility.VISIBLE:
				defenders += 1
		if defenders > 0:
			lines.append("Estado: defendido por %d monstro(s) visível(is)" % defenders)
		else:
			lines.append("Estado: sem defensores à vista — pode ser destruído por ataque")
	else:
		lines.append("Estado atual desconhecido (fora da sua visão).")
	var gold := MonsterDatabase.lair_clear_reward(lair.kind)
	var mana := MonsterDatabase.lair_clear_mana_reward(lair.kind)
	var reward := "Recompensa ao destruir: %d ouro" % int(gold)
	if mana > 0.0:
		reward += " + %d mana" % int(mana)
	lines.append(reward)
	return {"key": "lair", "kind": KIND_LAIR, "tag": "Covil", "title": "Covil de %s" % kind_name, "lines": lines}

# ---------------------------------------------------------------------------
# Construcoes
# ---------------------------------------------------------------------------

static func building_function_lines(data: BuildingData) -> Array[String]:
	var lines: Array[String] = []
	var effects: Array[String] = []
	if data.bonus_food > 0:
		effects.append("+%d comida" % data.bonus_food)
	if data.bonus_production > 0:
		effects.append("+%d produção" % data.bonus_production)
	if data.bonus_gold > 0:
		effects.append("+%d ouro" % data.bonus_gold)
	if data.bonus_mana > 0:
		effects.append("+%d mana" % data.bonus_mana)
	if data.storage_bonus > 0.0:
		effects.append("+%d armazenamento de comida" % int(data.storage_bonus))
	if data.defense_bonus > 0.0:
		effects.append("+%d%% defesa da cidade" % int(round(data.defense_bonus * 100.0)))
	if not effects.is_empty():
		lines.append("Efeitos: %s" % ", ".join(effects))
	if data.trains_unit != "":
		lines.append("Treina: %s" % RaceTheme.unit_name(data.trains_unit, "human"))
	var school := MagicContent.school_for_building(data.id)
	if school != "":
		var ritual: bool = data.id == MagicContent.SCHOOLS[school].ritual_building
		lines.append("Estrutura %s — %s" % ["ritual" if ritual else "mágica", school_name(school)])
	return lines

static func _owner_city_of_building(building: Building, hex_grid: HexGrid) -> City:
	for entry in hex_grid.cities_by_coord.values():
		var city: City = entry
		if city.owner_player == building.owner_player and city.building_coords.get(building.building_id, null) == building.coord:
			return city
	return null

static func _building_entry(building: Building, hex_grid: HexGrid, viewer: PlayerData) -> Dictionary:
	var data: BuildingData = BuildingDatabase.get_building(building.building_id)
	var race: String = building.owner_player.civ.race if building.owner_player and building.owner_player.civ else "human"
	var name: String = RaceTheme.building_name(building.building_id, race) if data != null else building.building_id
	var lines: Array[String] = [_faction_line(building.owner_player, viewer)]
	var city := _owner_city_of_building(building, hex_grid)
	if city != null:
		lines.append("Cidade: %s" % city.city_name)
	if data != null:
		lines.append_array(building_function_lines(data))
	lines.append("Estado: operacional")
	return {"key": "building", "kind": KIND_BUILDING, "tag": name, "title": name, "lines": lines}

static func _construction_entry(coord: Vector2i, hex_grid: HexGrid, viewer: PlayerData, state: String) -> Dictionary:
	# Obra propria: qualquer cidade do viewer com este tile reservado (mesma
	# fonte de HexGrid.refresh_construction_markers). Obra alheia so' aparece
	# com o tile visivel e sem revelar QUAL predio esta sendo construido.
	for entry in hex_grid.cities_by_coord.values():
		var city: City = entry
		if city.pending_building_coord != coord or city.production_item == "":
			continue
		var data: BuildingData = BuildingDatabase.get_building(city.production_item)
		if data == null:
			continue
		if city.owner_player == viewer:
			var cost := city.production_cost()
			var percent := int(round(100.0 * city.stored_production / maxf(cost, 1.0)))
			var race: String = viewer.civ.race
			var name := "Obra: %s" % RaceTheme.building_name(data.id, race)
			return {"key": "site", "kind": KIND_SITE, "tag": "Obra", "title": name, "lines": [
				"Cidade: %s" % city.city_name, "Progresso: %d%%" % percent,
			]}
		if state == STATE_VISIBLE:
			return {"key": "site", "kind": KIND_SITE, "tag": "Obra", "title": "Obra em andamento", "lines": [
				_faction_line(city.owner_player, viewer),
			]}
	return {}

# ---------------------------------------------------------------------------
# Estruturas magicas (areas e rituais) -- mesma regra publica do MagicOverlay
# ---------------------------------------------------------------------------

static func _magic_entries(coord: Vector2i, hex_grid: HexGrid, viewer: PlayerData, state: String) -> Array:
	var entries: Array = []
	if hex_grid.get_tile(coord) == null:
		return entries
	var index := 0
	for player in GameManager.players:
		if player.civ == null:
			continue
		for region in player.magic_effects:
			if int(region.expires) <= TurnManager.turn_number:
				continue
			if HexMetrics.axial_distance(MagicRuntime.coord_of(region.center), coord) > int(region.radius):
				continue
			if player != viewer and state != STATE_VISIBLE:
				continue
			var title := MagicOverlay.region_title(region)
			var school := MagicOverlay.school_for_effect(region.effect)
			entries.append({"key": "magic:%d" % index, "kind": KIND_MAGIC, "tag": title, "title": title, "lines": [
				"Escola: %s" % school_name(school),
				_faction_line(player, viewer),
				"Duração restante: %d turno(s) | Raio: %d" % [int(region.expires) - TurnManager.turn_number, int(region.radius)],
			]})
			index += 1
		for ritual in player.rituals:
			if ritual.status != "channeling" or MagicRuntime.coord_of(ritual.seat) != coord:
				continue
			if player != viewer and state != STATE_VISIBLE:
				continue
			var ritual_title := "Ritual: %s" % ritual.spell
			entries.append({"key": "magic:%d" % index, "kind": KIND_MAGIC, "tag": "Ritual", "title": ritual_title, "lines": [
				"Escola: %s" % school_name(ritual.school),
				_faction_line(player, viewer),
				"Progresso: %d/%d" % [int(ritual.progress), int(ritual.turns)],
			]})
			index += 1
	return entries

# ---------------------------------------------------------------------------
# Recurso e terreno
# ---------------------------------------------------------------------------

static func _resource_entry(tile: HexTileData, coord: Vector2i, hex_grid: HexGrid, viewer: PlayerData) -> Dictionary:
	var name := ResourceDatabase.display_name(tile.resource)
	var bonus := ResourceDatabase.yield_for(tile.resource)
	var parts: Array[String] = []
	for pair in [["food", "comida"], ["production", "produção"], ["gold", "ouro"], ["mana", "mana"]]:
		if int(bonus.get(pair[0], 0)) > 0:
			parts.append("+%d %s" % [int(bonus[pair[0]]), pair[1]])
	var lines: Array[String] = []
	if not parts.is_empty():
		lines.append("Rendimento extra ao ser trabalhado: %s" % ", ".join(parts))
	lines.append(_resource_effect(tile.resource))
	var territory_owner: City = hex_grid.city_owning_tile(coord)
	lines.append("Território de %s" % territory_owner.city_name if territory_owner != null else "Sem dono")
	return {"key": "resource", "kind": KIND_RESOURCE, "tag": name, "title": "Recurso: %s" % name, "lines": lines}

static func _resource_effect(resource: String) -> String:
	var template: String = RESOURCE_EFFECTS.get(resource, "")
	if template == "":
		return ""
	match resource:
		"iron":
			return template % int(ResourceDatabase.IRON_COST_DISCOUNT_MAX * 100.0)
		"horses":
			return template % int(ResourceDatabase.CAVALRY_COST_DISCOUNT_MAX * 100.0)
		"gems":
			return template % int(ResourceDatabase.GEMS_RUSH_BUY_DISCOUNT_MAX * 100.0)
		"mana_node":
			return template % int(ResourceDatabase.MANA_COST_DISCOUNT_MAX * 100.0)
		"silk":
			return template % ResourceDatabase.SILK_ROUTE_CAPACITY_BONUS_MAX
	return ""

static func _terrain_section(hex_grid: HexGrid, coord: Vector2i, viewer: PlayerData, state: String, tile: HexTileData) -> Dictionary:
	if tile == null or state == STATE_UNSEEN:
		return {"title": "Terreno", "lines": ["Região inexplorada."]}
	var lines: Array[String] = []
	lines.append("Comida %d | Produção %d | Ouro %d | Mov. %d | Def. +%d%%" % [
		tile.food_yield, tile.production_yield, tile.gold_yield, tile.movement_cost, int(round(tile.defense_bonus * 100.0))
	])
	var territory_owner: City = hex_grid.city_owning_tile(coord)
	if territory_owner != null and (territory_owner.owner_player == viewer or state == STATE_VISIBLE):
		lines.append("Território: %s" % territory_owner.city_name)
	if state == STATE_EXPLORED:
		lines.append("(fora da visão — informação lembrada)")
	elif hex_grid.is_tile_pillaged(coord, TurnManager.turn_number):
		lines.append("Saqueado: sem rendimento por enquanto")
	return {"title": "Terreno: %s (%d, %d)" % [tile.display_name, coord.x, coord.y], "lines": lines}

## Resumo de UMA linha do tile, pra o painel de unidade propria (onde o painel
## de tile nao aparece): terreno + demais coisas relevantes neste tile.
static func summary_line(inspection: Dictionary, skip_key: String = "unit") -> String:
	var parts: Array[String] = []
	var title: String = inspection.terrain_title
	parts.append(title.trim_prefix("Terreno: "))
	var others: Array[String] = []
	for entry in inspection.entries:
		if entry.key != skip_key:
			others.append(entry.tag)
	if not others.is_empty():
		parts.append("também aqui: %s" % ", ".join(others))
	return " | ".join(parts)
