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
##    efeito mágico do mapa (zona ambiental, Portal) > recurso. Cada entry: {key, kind, tag, title,
##    lines}. A primeira e' a "entidade principal"; o resto vira abas na HUD.
##  - o TERRENO nunca some: e' sempre uma secao separada (terrain_*), nunca
##    substitui a entidade principal.
## Regras de segredo (mesma nevoa do mapa, ver HexGrid._apply_fog_to_entities):
## tile UNSEEN nao revela nada; entidade de OUTRO dono so' com o tile VISIVEL
## agora; cidade/predio rival
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
const BEHAVIOR_LABELS := {
	"guardian": "Guardião (defende o território do covil)",
	"raider": "Saqueador (caça presas fracas e saqueia)",
	"invader": "Invasor (marcha sobre a cidade mais próxima)",
	"hunter": "Caçador (patrulha atrás de presas isoladas)",
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
	return state == STATE_VISIBLE

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

## "3" ou "1.5" — o poder do Ataque da Cidade só tem casa decimal em Déficit (metade).
static func _format_power(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value

static func _city_entry(city: City, hex_grid: HexGrid, viewer: PlayerData) -> Dictionary:
	var lines: Array[String] = []
	var own := city.owner_player == viewer
	# O City Level é a informação estrutural primária da cidade (Fase 13; Fase 25 — não existe mais população).
	lines.append("%s (%s)" % [V2CityLevelData.level_name(city.city_level), "sua" if own else "rival"])
	lines.append(_faction_line(city.owner_player, viewer))
	# Aetherlands V2, Fase 16 — Fortificação é fato público (qualquer observador vê a muralha); o
	# escudo só existe com ela e aparece uma vez, no bloco abaixo.
	lines.append("Vida: %d/%d" % [int(city.hp), int(city.max_hp())])
	if city.has_fortification():
		var level := city.fortification_level
		lines.append(V2FortificationData.display_name(level))
		lines.append("Escudo: %d / %d" % [int(city.shield), int(city.max_shield())])
		lines.append("Defesa urbana: +%d%%" % int(round(V2FortificationData.city_defense_bonus(level) * 100.0)))
		lines.append("Ataque da Cidade: %s | Alcance %d" % [_format_power(CityDefense.city_attack_power(city)), CityDefense.city_attack_range(city)])
	if own:
		var built_names: Array[String] = []
		for id in city.buildings.keys():
			if BuildingDatabase.get_building(id):
				var building_name := RaceTheme.building_name(id)
				# Aetherlands V2, Fase 14 (§58 do pedido): prédio CopyLimitMode.CITY_LEVEL mostra
				# quantas cópias — city.buildings só sabe "existe pelo menos uma" (ver
				# City.building_count()), a UI é quem precisa deixar a contagem real visível.
				var copies := city.building_count(id)
				built_names.append("%s ×%d" % [building_name, copies] if copies > 1 else building_name)
		var buildings_line := "Prédios: %d/%d" % [city.used_building_slots(), city.max_building_slots()]
		if built_names.size() > 0:
			buildings_line += " (%s)" % ", ".join(built_names)
		lines.append(buildings_line)
		lines.append("Território: %d tiles | Anexação: %d ponto(s)" % [city.owned_tiles.size(), city.annexation_points])
		if not city.resource_improvements.is_empty():
			var improvement_names: Array[String] = []
			for coord in city.resource_improvements:
				var resource_id := V2ResourceImprovementData.resource_for_improvement(String(city.resource_improvements[coord]))
				improvement_names.append(V2ResourceImprovementData.display_name_for_resource(resource_id))
			improvement_names.sort()
			lines.append("Melhorias: %s" % ", ".join(improvement_names))
		# Aetherlands V2, Fase 14 (§72 do pedido): Produção local da cidade + os yields globais que
		# ELA contribui (Ouro/Suprimentos/Conhecimento/Mana são agregados no PlayerData — ver
		# V2EconomyRuntime.player_*_income — mas o jogador quer saber quanto CADA cidade dá).
		lines.append("Produção: +%d PP/turno" % int(V2EconomyRuntime.city_production_income(city)))
		lines.append("Ouro: +%d | Suprimentos: +%d | Conhecimento: +%d | Mana: +%d" % [
			int(V2EconomyRuntime.city_gold_income(city)),
			int(V2EconomyRuntime.city_supply_capacity(city)),
			int(V2EconomyRuntime.city_knowledge_income(city)),
			int(V2EconomyRuntime.city_mana_income(city)),
		])
	return {"key": "city", "kind": KIND_CITY, "tag": city.city_name, "title": city.city_name, "lines": lines}

# ---------------------------------------------------------------------------
# Unidades, monstros e bosses
# ---------------------------------------------------------------------------

static func unit_class_label(unit: Unit) -> String:
	var data := unit.unit_data
	if data.is_v2_caster():
		return "Conjurador — %s" % school_name(data.v2_magic_school)
	if data.is_retinue(): # Fase 19: Hoste (retinue) — a Escola vem do dado, nunca do kind
		return "Hoste — %s" % school_name(data.retinue_school)
	if data.can_found_city:
		return "Colonizador"
	if data.attack <= 0.0:
		return "Apoio"
	# Fase 12: unidade de Doutrina usa a identidade semântica da PRÓPRIA Doutrina (branch_role).
	# Fora das Doutrinas (Guarda inicial, unidade legada de save antigo), os papéis genéricos de
	# ArmyComposition (por traço/alcance).
	var v2_branch := V2UnitLine.doctrine_branch_of(data.visual_kind)
	if v2_branch != "":
		var info := V2ResearchDatabase.branch_info(V2ResearchNode.TreeType.MILITARY_DOCTRINE, v2_branch)
		return info.get("summary", V2UnitLine.role_of(data.visual_kind))
	var labels: Array[String] = []
	for role in ArmyComposition.roles_for_kind(data.visual_kind):
		labels.append(ROLE_LABELS.get(role, role))
	if labels.is_empty():
		labels.append("Combatente")
	return ", ".join(labels)

## Título da Escola de Magia ("Escola Sagrada"...). O segundo parâmetro é só compatibilidade de
## assinatura (Fase 25: existe um único namespace de Escolas).
static func school_name(school: String, _unused: bool = true) -> String:
	return V2MagicContent.school_title(school)

static func unit_traits(unit: Unit) -> Array[String]:
	var data := unit.unit_data
	var traits: Array[String] = []
	if data.is_flying():
		traits.append("Voa")
	if data.movement_profile == UnitData.MovementProfile.INFILTRATOR:
		traits.append("Passo Sombrio (atravessa unidades)")
	if data.ranged_damage_taken_bonus > 0.0:
		traits.append("Vulnerável à distância (+%d%% de dano recebido)" % int(round(data.ranged_damage_taken_bonus * 100.0)))
	if data.attack_range > 1:
		traits.append("Ataque à distância (alcance %d)" % data.attack_range)
	if data.ignores_terrain_defense:
		traits.append("Ignora defesa de terreno")
	if data.regen_fraction > 0.0:
		traits.append("Regenera %d%% da vida por turno" % int(round(data.regen_fraction * 100.0)))
	if data.can_found_city:
		traits.append("Funda cidades")
	if UnitAbilities.is_mounted(data):
		traits.append("Montada")
	if data.has_trait(UnitData.TRAIT_SIEGE):
		traits.append("Unidade de Cerco (bônus contra cidades e fortificações)")
	if data.ignores_technique_stationary_requirement:
		traits.append("Artilharia Andante (pode usar Bombardeio Preparado mesmo tendo se movido)")
	# Fase 6: fatos PÚBLICOS de combate da unidade (um observador vê a aura em ação): Lendária + aura.
	if data.has_trait(UnitData.TRAIT_LEGENDARY):
		traits.append("Lendária")
	# Fase 17: fatos PÚBLICOS da Magia V2 — nunca o repertório (a pesquisa do rival não vaza pela inspeção).
	if data.has_trait(UnitData.TRAIT_GRAND_MANIFESTATION):
		traits.append("Grande Manifestação")
	# Fase 19: fatos PÚBLICOS de retinue — morto-vivo, Hoste e o estado SEM COMANDO (visível no mapa pelo anel cinza).
	if data.has_trait(UnitData.TRAIT_UNDEAD):
		traits.append("Morto-vivo")
	if data.is_retinue():
		traits.append("Hoste (Comando %d)" % data.retinue_command_cost)
		if not unit.can_receive_orders():
			traits.append("Sem comando — não recebe ordens")
	if data.spell_damage_multiplier > 1.0:
		var spell_passive := data.spell_damage_multiplier_name if data.spell_damage_multiplier_name != "" else "Potência Mágica"
		traits.append("%s (+%d%% de dano de feitiços)" % [spell_passive, int(round((data.spell_damage_multiplier - 1.0) * 100.0))])
	if data.spell_cooldown_reduction > 0:
		var cooldown_passive := data.spell_cooldown_reduction_name if data.spell_cooldown_reduction_name != "" else "Fluxo Mágico"
		traits.append("%s (-%d turno(s) de recarga de feitiços)" % [cooldown_passive, data.spell_cooldown_reduction])
	if data.environmental_zone_duration_bonus > 0:
		var environmental_passive := data.environmental_zone_duration_bonus_name if data.environmental_zone_duration_bonus_name != "" else "Domínio Ambiental"
		traits.append("%s (+%d rodada(s) nas zonas ambientais criadas)" % [environmental_passive, data.environmental_zone_duration_bonus])
	if not data.can_basic_attack:
		traits.append("Sem ataque básico")
	if data.has_aura():
		traits.append("%s (raio %d, +%d%% Defesa aliada)" % [data.aura_name, data.aura_radius, int(round(data.aura_defense_bonus * 100.0))])
	if data.has_trait_attack_bonus():
		traits.append("%s (%s)" % [data.trait_attack_name, UnitAbilities.trait_attack_effect_text(data).trim_suffix(".")])
	if data.has_low_hp_attack_bonus():
		traits.append("%s (+%d%% Ataque contra alvos com %d%% de HP ou menos)" % [data.low_hp_attack_name, int(round(data.low_hp_attack_bonus * 100.0)), int(round(data.low_hp_attack_threshold * 100.0))])
	return traits

static func status_effect_lines(unit: Unit) -> Array[String]:
	var lines: Array[String] = []
	lines.append_array(V2TechniqueRuntime.status_lines(unit)) # Técnicas Militares V2 ativas (Fase 4)
	lines.append_array(V2MagicRuntime.status_lines(unit)) # estados de feitiço V2 ativos (Fase 17, Égide): fato público
	return lines

## Acao e recarga do conjurador: so' o DONO ve (recarga de magia inimiga e' segredo).
static func caster_lines(unit: Unit) -> Array[String]:
	var lines: Array[String] = []
	if unit.unit_data.is_caster():
		if V2MagicRuntime.is_spellcasting_silenced(unit):
			lines.append("Ação: Silêncio — não pode conjurar feitiços.")
		elif unit.movement_left <= 0.0:
			lines.append("Ação: sem movimento neste turno — não pode conjurar.")
		else:
			lines.append("Ação: pronto para conjurar.")
	lines.append_array(V2TechniqueRuntime.cooldown_lines(unit)) # recarga das Técnicas Militares V2 (Fase 4)
	lines.append_array(V2MagicRuntime.cooldown_lines(unit)) # recarga dos feitiços V2 (Fase 17)
	return lines

## Linhas que so' o DONO deve ver (estado de comando, recarga, ordens).
static func own_unit_lines(unit: Unit) -> Array[String]:
	var lines: Array[String] = []
	lines.append_array(caster_lines(unit))
	lines.append_array(V2TechniqueRuntime.passive_lines(unit)) # Técnicas passivas V2 (Fase 5): só o dono vê
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

## Função pública do prédio: rendimento por cópia (prédio econômico, pela pesquisa do DONO), tropa
## que treina e manutenção. `owner` null = rendimento no tier 1.
static func building_function_lines(data: BuildingData, owner: PlayerData = null) -> Array[String]:
	var lines: Array[String] = []
	if V2InfrastructureEconomyData.is_economy_building(data.id):
		var resource := V2InfrastructureEconomyData.resource_for_building(data.id)
		lines.append("Rendimento: +%d %s por turno" % [int(V2EconomyRuntime.building_output(owner, data.id)), V2InfrastructureEconomyData.resource_label(resource)])
	if data.trains_unit != "":
		lines.append("Treina: %s" % RaceTheme.unit_name(data.trains_unit, "human"))
	if data.gold_upkeep > 0.0:
		lines.append("Manutenção: %d Ouro/turno" % int(data.gold_upkeep))
	return lines

static func _owner_city_of_building(building: Building, hex_grid: HexGrid) -> City:
	for entry in hex_grid.cities_by_coord.values():
		var city: City = entry
		if city.owner_player != building.owner_player:
			continue
		if city.building_coords.get(building.building_id, null) == building.coord or building.coord in city.repeatable_building_coords.get(building.building_id, []):
			return city
	return null

static func _building_entry(building: Building, hex_grid: HexGrid, viewer: PlayerData) -> Dictionary:
	var data: BuildingData = BuildingDatabase.get_building(building.building_id)
	var name: String = RaceTheme.building_name(building.building_id)
	var lines: Array[String] = [_faction_line(building.owner_player, viewer)]
	var city := _owner_city_of_building(building, hex_grid)
	if city != null:
		lines.append("Cidade: %s" % city.city_name)
	if data != null:
		lines.append_array(building_function_lines(data, building.owner_player))
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
			var name := "Obra: %s" % RaceTheme.building_name(data.id)
			return {"key": "site", "kind": KIND_SITE, "tag": "Obra", "title": name, "lines": [
				"Cidade: %s" % city.city_name, "Progresso: %d%%" % percent,
			]}
		if state == STATE_VISIBLE:
			return {"key": "site", "kind": KIND_SITE, "tag": "Obra", "title": "Obra em andamento", "lines": [
				_faction_line(city.owner_player, viewer),
			]}
	return {}

# ---------------------------------------------------------------------------
# Efeitos mágicos do mapa (zonas ambientais e Portais) — públicos só com visão atual
# ---------------------------------------------------------------------------

static func _magic_entries(coord: Vector2i, hex_grid: HexGrid, viewer: PlayerData, state: String) -> Array:
	var entries: Array = []
	if hex_grid.get_tile(coord) == null:
		return entries
	var index := 0
	# Fase 22 — zona ambiental é pública somente com o tile atualmente visível.
	var environmental_entry := V2EnvironmentalZoneSystem.zone_entry_at(coord, hex_grid)
	var environmental := V2EnvironmentalZoneSystem.zone_at(coord, hex_grid)
	if environmental != null and state == STATE_VISIBLE:
		var owner_index := int(environmental_entry.owner_index)
		var owner: PlayerData = GameManager.players[owner_index] if owner_index >= 0 and owner_index < GameManager.players.size() else null
		var creator_name := owner.civ.civ_name if owner != null and owner.civ != null else "desconhecida"
		var environmental_lines: Array[String] = [
			"Escola: %s" % school_name(String(environmental_entry.school)),
			"Criada por: %s" % creator_name,
			"Duração restante: %d rodada(s)" % int(environmental_entry.remaining_rounds),
		]
		environmental_lines.append_array(V2EnvironmentalZoneDatabase.effect_lines(environmental))
		entries.append({"key": "magic:environment", "kind": KIND_MAGIC, "tag": environmental.display_name, "title": environmental.display_name, "lines": environmental_lines})
		index += 1
	# Fase 21 — Portal é efeito mágico persistente do MAPA, não prédio nem terreno.
	# Só aparece com visão atual; o endpoint oculto do par nunca é revelado a um observador.
	var portal_pair := V2PortalSystem.endpoint_at(coord, hex_grid)
	if not portal_pair.is_empty() and state == STATE_VISIBLE:
		var owner_index := int(portal_pair.owner_index)
		var owner: PlayerData = GameManager.players[owner_index] if owner_index >= 0 and owner_index < GameManager.players.size() else null
		var portal_lines: Array[String] = ["Escola: %s" % school_name(String(portal_pair.school)), _faction_line(owner, viewer)]
		var paired := V2PortalSystem.paired_endpoint(coord, hex_grid)
		if owner == viewer and hex_grid.visibility.get(paired, HexGrid.Visibility.UNSEEN) == HexGrid.Visibility.VISIBLE:
			portal_lines.append("Conectado a: (%d, %d)" % [paired.x, paired.y])
		elif owner == viewer:
			portal_lines.append("Saída atualmente fora de visão.")
		entries.append({"key": "magic:portal", "kind": KIND_MAGIC, "tag": "Portal do Véu", "title": "Portal do Véu", "lines": portal_lines})
		index += 1
	return entries

# ---------------------------------------------------------------------------
# Recurso e terreno
# ---------------------------------------------------------------------------

## Recurso do mapa (Fase 25: só a semântica V2) — o recurso bruto não rende nada; um Construtor o
## melhora (V2ResourceImprovementData) e aí a melhoria rende pela pesquisa do DONO da cidade. Recurso
## melhorado mostra o rendimento atual; recurso bruto mostra a melhoria possível e o que ela renderia
## para o observador.
static func _resource_entry(tile: HexTileData, coord: Vector2i, hex_grid: HexGrid, viewer: PlayerData) -> Dictionary:
	var name := ResourceDatabase.display_name(tile.resource)
	var improvement_name := V2ResourceImprovementData.display_name_for_resource(tile.resource)
	var territory_owner: City = hex_grid.city_owning_tile(coord)
	var improvement_id: String = territory_owner.resource_improvements.get(coord, "") if territory_owner != null else ""
	var lines: Array[String] = []
	var title := "Recurso: %s" % name
	if improvement_id != "":
		title = "Recurso: %s — %s" % [name, improvement_name]
		lines.append("Efeito: %s" % ", ".join(_improvement_yield_lines(tile.resource, territory_owner.owner_player)))
		if hex_grid.is_tile_pillaged(coord, TurnManager.turn_number):
			lines.append("Saqueada: sem rendimento por enquanto")
	else:
		if territory_owner != null:
			title = "Recurso: %s — não explorado" % name
		if improvement_name != "":
			lines.append("Melhoria: %s (Construtor, em território próprio)" % improvement_name)
			lines.append("Efeito: %s" % ", ".join(_improvement_yield_lines(tile.resource, viewer)))
	lines.append("Território de %s" % territory_owner.city_name if territory_owner != null else "Sem dono")
	return {"key": "resource", "kind": KIND_RESOURCE, "tag": name, "title": title, "lines": lines}

## Aetherlands V2, Fase 15 — "+2 Produção local" por efeito da melhoria (a Seda mostra os dois: Ouro
## e Conhecimento). Yield pela pesquisa de `player` (o DONO ATUAL; ou o observador, para recurso bruto).
static func _improvement_yield_lines(resource_id: String, player: PlayerData) -> Array[String]:
	var lines: Array[String] = []
	for effect in V2ResourceImprovementData.effects_for_resource(resource_id):
		var tier := V2EconomyRuntime.infrastructure_tier(player, effect.branch)
		var amount := int(V2ResourceImprovementData.yield_for_effect(effect, tier))
		var label := V2InfrastructureEconomyData.resource_label(effect.resource)
		var scope := " local" if effect.resource == "production" else ""
		lines.append("+%d %s%s" % [amount, label, scope])
	return lines

static func _terrain_section(hex_grid: HexGrid, coord: Vector2i, viewer: PlayerData, state: String, tile: HexTileData) -> Dictionary:
	if tile == null or state == STATE_UNSEEN:
		return {"title": "Terreno", "lines": ["Região inexplorada."]}
	var lines: Array[String] = []
	lines.append("Mov. %d | Def. +%d%%" % [tile.movement_cost, int(round(tile.defense_bonus * 100.0))])
	var territory_owner: City = hex_grid.city_owning_tile(coord)
	if territory_owner != null and (territory_owner.owner_player == viewer or state == STATE_VISIBLE):
		lines.append("Território: %s" % territory_owner.city_name)
	# Fase 20: modificação física de terreno V2 (camada sobre o terreno-base; sem dono) — só com o tile VISÍVEL (a
	# neblina não revela o estado atual do terreno fora da visão).
	if state == STATE_VISIBLE:
		lines.append_array(V2TerrainRuntime.inspector_lines(hex_grid, coord))
	if state == STATE_EXPLORED:
		lines.append("(fora da visão — informação lembrada)")
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
