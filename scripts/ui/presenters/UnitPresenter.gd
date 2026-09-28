class_name UnitPresenter
extends RefCounted

## View model do Unit Context Panel (Fase 30 / UI-3). Só CONSULTA os runtimes
## (Técnicas, Magia, Hostes, Portais, Construtor, upgrade, logística) e agrupa o
## resultado em header / stats / comandos / habilidades / passivas / status /
## rodapé. Nenhuma regra é decidida aqui: disponibilidade e motivo vêm sempre do
## helper real (`unavailable_reason`, `traversal_reason`...), e unidade de outro
## dono recebe apenas fatos públicos (sem recarga, pesquisa nem ordens).

const SPELL_TARGET_LABELS := {
	V2SpellData.TargetMode.OWN_UNIT: "Unidade própria",
	V2SpellData.TargetMode.HOSTILE_UNIT: "Unidade hostil",
	V2SpellData.TargetMode.EMPTY_TILE: "Tile livre",
	V2SpellData.TargetMode.TILE: "Tile",
}

static func build(unit: Unit, viewer: PlayerData, hex_grid: HexGrid = null) -> Dictionary:
	if unit == null or not is_instance_valid(unit) or unit.unit_data == null:
		return {"valid": false}
	var grid := hex_grid if hex_grid != null else GameManager.hex_grid
	var data := unit.unit_data
	var own := viewer != null and unit.owner_player == viewer
	var monster := unit.owner_player == null
	var race: String = unit.owner_player.civ.race if unit.owner_player != null and unit.owner_player.civ != null else "human"
	var view := {
		"valid": true,
		"own": own,
		"monster": monster,
		"serial_id": unit.serial_id,
		"coord": unit.coord,
		"name": data.unit_name if monster else RaceTheme.unit_name(data.visual_kind, race),
		"subtitle": _subtitle(unit),
		"owner_name": _owner_name(unit.owner_player),
		"relation": _relation(unit.owner_player, viewer),
		"owner_color": unit.owner_player.civ.color if unit.owner_player != null and unit.owner_player.civ != null else UIThemeTokens.COLOR_CRITICAL,
		"portrait_glyph": _portrait_glyph(unit),
		"portrait_accent": _identity_color(unit),
		"portrait_caption": _role_short(unit),
		"badges": _badges(unit),
		"hp": unit.hp,
		"max_hp": data.max_hp,
		"stats": _stats(unit, own),
		"warning": _warning(unit, own),
		"commands": [] as Array[UnitAbilityViewData],
		"abilities": [] as Array[UnitAbilityViewData],
		"ability_title": "Habilidades",
		"ability_empty_text": "",
		"passives": _passives(unit, own),
		"statuses": _statuses(unit, own, grid),
		"footer": _footer(unit, own, viewer, grid),
	}
	if own:
		view.commands = commands_for(unit, grid)
		view.abilities = abilities_for(unit, grid)
		if V2MagicRuntime.is_v2_caster(unit):
			view.ability_title = "Magia · %s" % V2MagicContent.school_title(data.v2_magic_school)
			if V2MagicRuntime.spells_for_unit(unit).is_empty():
				view.ability_empty_text = "Nenhum feitiço pesquisado nesta Escola."
	return view

# --- Header --------------------------------------------------------------------

static func _owner_name(owner: PlayerData) -> String:
	if owner == null:
		return "Monstros"
	return owner.civ.civ_name if owner.civ != null else "Civilização"

static func _relation(owner: PlayerData, viewer: PlayerData) -> String:
	if owner == null:
		return "Hostil a todos"
	if owner == viewer:
		return "Sua"
	if viewer != null and viewer.is_at_war_with(owner):
		return "Em guerra"
	return "Em paz"

static func _subtitle(unit: Unit) -> String:
	if unit.owner_player == null:
		if unit.world_event_managed:
			return "Criatura de evento mundial"
		return "Chefe de covil" if unit.is_camp_boss else "Monstro"
	var parts: Array[String] = [TileInspector.unit_class_label(unit)]
	var form := form_label(unit.unit_data.visual_kind)
	if not form.is_empty():
		parts.append(form)
	return " · ".join(parts)

## "Forma-base", "Evolução" ou "Elite" quando a unidade pertence a uma linha de Doutrina.
static func form_label(kind: String) -> String:
	var node := V2UnitLine.node_for(kind)
	if node == null:
		return ""
	match node.tier_role:
		"base_unit":
			return "Forma-base · N%d" % node.tier
		"evolution_1":
			return "Evolução · N%d" % node.tier
		"elite_form":
			return "Elite · N%d" % node.tier
	return "N%d" % node.tier

static func _role_short(unit: Unit) -> String:
	var data := unit.unit_data
	if unit.owner_player == null:
		return "Monstro"
	if V2ManifestationSystem.is_manifestation_unit(unit):
		return "Manifest."
	if data.has_trait(UnitData.TRAIT_LEGENDARY):
		return "Lendária"
	if data.is_v2_caster():
		return "Conjurador"
	if data.is_retinue():
		return "Hoste"
	if data.can_found_city:
		return "Colono"
	if V2ConstructorRuntime.is_builder_unit(unit):
		return "Construtor"
	if data.has_trait(UnitData.TRAIT_SIEGE):
		return "Cerco"
	if UnitAbilities.is_mounted(data):
		return "Montada"
	if data.attack_range > 1:
		return "Distância"
	return "Combate"

static func _portrait_glyph(unit: Unit) -> String:
	var data := unit.unit_data
	if unit.owner_player == null:
		return "✕"
	if V2ManifestationSystem.is_manifestation_unit(unit) or data.has_trait(UnitData.TRAIT_LEGENDARY):
		return "★"
	if data.is_v2_caster():
		return "✦"
	if data.is_retinue():
		return "✚"
	if data.can_found_city:
		return "⌂"
	if V2ConstructorRuntime.is_builder_unit(unit):
		return "■"
	if data.has_trait(UnitData.TRAIT_SIEGE):
		return "◈"
	if data.is_flying():
		return "▲"
	if UnitAbilities.is_mounted(data):
		return "▶"
	if data.attack_range > 1:
		return "◎"
	return "◆"

static func _identity_color(unit: Unit) -> Color:
	var data := unit.unit_data
	if unit.owner_player == null:
		return UIThemeTokens.COLOR_CRITICAL
	if data.v2_magic_school != "":
		return V2MagicContent.school_color(data.v2_magic_school)
	if data.retinue_school != "":
		return V2MagicContent.school_color(data.retinue_school)
	if data.has_trait(UnitData.TRAIT_LEGENDARY):
		return UIThemeTokens.COLOR_ACCENT
	return UIThemeTokens.COLOR_INFO

static func _badges(unit: Unit) -> Array:
	var data := unit.unit_data
	var badges: Array = []
	if unit.owner_player == null:
		if unit.is_camp_boss:
			badges.append({"text": "Chefe", "tone": AEStatusChip.Tone.NEGATIVE, "tooltip": "Guarda o covil e não o abandona."})
		if unit.world_event_managed:
			badges.append({"text": "Evento Mundial", "tone": AEStatusChip.Tone.NEGATIVE, "tooltip": "Criatura controlada por um evento mundial."})
		return badges
	if V2LegendarySystem.is_legendary_unit(unit):
		badges.append({"text": "LENDÁRIA", "tone": AEStatusChip.Tone.WARNING, "tooltip": AETooltip.compose("Unidade Lendária", "Única por civilização, ativa ou em treinamento.")})
	if V2ManifestationSystem.is_manifestation_unit(unit):
		var school := V2ManifestationSystem.school_of_kind(data.visual_kind)
		badges.append({"text": "GRANDE MANIFESTAÇÃO · %s" % V2MagicContent.school_title(school).trim_prefix("Escola ").to_upper(), "tone": AEStatusChip.Tone.WARNING, "tooltip": AETooltip.compose("Grande Manifestação", V2MagicContent.MANIFESTATION_RULE)})
	if data.is_v2_caster() and not V2ManifestationSystem.is_manifestation_unit(unit):
		badges.append({"text": "Conjurador", "tone": AEStatusChip.Tone.NEUTRAL, "tooltip": AETooltip.compose("Conjurador", V2MagicContent.school_title(data.v2_magic_school))})
	if data.is_retinue():
		badges.append({"text": "Hoste", "tone": AEStatusChip.Tone.NEUTRAL, "tooltip": AETooltip.compose("Hoste", "Custo de comando %d." % data.retinue_command_cost)})
	if data.is_flying():
		badges.append({"text": "Voadora", "tone": AEStatusChip.Tone.TRAIT, "tooltip": AETooltip.compose("Voadora", UnitAbilities.flight_text(data))})
	if data.has_trait(UnitData.TRAIT_SIEGE):
		badges.append({"text": "Cerco", "tone": AEStatusChip.Tone.TRAIT, "tooltip": AETooltip.compose("Unidade de Cerco", "Bônus contra cidades e fortificações.")})
	if UnitAbilities.is_mounted(data):
		badges.append({"text": "Montada", "tone": AEStatusChip.Tone.TRAIT, "tooltip": AETooltip.compose("Montada", "Alvo de bônus contra unidades montadas.")})
	if data.has_trait(UnitData.TRAIT_UNDEAD):
		badges.append({"text": "Morto-vivo", "tone": AEStatusChip.Tone.TRAIT, "tooltip": AETooltip.compose("Morto-vivo", "Traço público da unidade.")})
	return badges

# --- Stats ---------------------------------------------------------------------

static func _stats(unit: Unit, own: bool) -> Array:
	var data := unit.unit_data
	var stats: Array = []
	var veterancy_details: Array = []
	if unit.veterancy_level > 0:
		veterancy_details.append("Veterania %s: +%d%%" % [unit.veterancy_title(), int(unit.veterancy_level * Unit.VETERANCY_BONUS_PER_LEVEL * 100)])
	if own and data.supply_cost > 0 and V2LogisticsRuntime.is_logistically_strained(unit.owner_player):
		veterancy_details.append("Tensão Logística: -15%")
	if data.can_basic_attack and data.attack > 0.0:
		stats.append({"key": "attack", "caption": "Ataque", "value": _number(data.attack), "glyph": "▲", "tooltip": AETooltip.compose("Ataque", "Valor base do ataque básico.", veterancy_details)})
	elif not data.can_basic_attack:
		stats.append({"key": "attack", "caption": "Ataque", "value": "—", "glyph": "▲", "color": UIThemeTokens.COLOR_TEXT_MUTED, "tooltip": AETooltip.compose("Ataque", "Sem ataque básico.", ["Age por feitiços ou habilidades."] if data.is_v2_caster() else [])})
	else:
		stats.append({"key": "attack", "caption": "Ataque", "value": "—", "glyph": "▲", "color": UIThemeTokens.COLOR_TEXT_MUTED, "tooltip": AETooltip.compose("Ataque", "Unidade de apoio, sem ataque.")})
	stats.append({"key": "defense", "caption": "Defesa", "value": _number(data.defense), "glyph": "■", "tooltip": AETooltip.compose("Defesa", "Valor base de defesa.", veterancy_details)})
	if own:
		var consumed := unit.movement_left <= 0.0
		stats.append({"key": "movement", "caption": "Movimento", "value": "%s/%s" % [_number(unit.movement_left), _number(data.movement_points)], "glyph": "➤", "color": UIThemeTokens.COLOR_TEXT_MUTED if consumed else UIThemeTokens.COLOR_TEXT, "tooltip": AETooltip.compose("Movimento", "Restante neste turno / máximo.", [], "Movimento consumido neste turno." if consumed else "")})
	else:
		stats.append({"key": "movement", "caption": "Movimento", "value": _number(data.movement_points), "glyph": "➤", "tooltip": AETooltip.compose("Movimento", "Pontos de movimento por turno.")})
	if data.attack_range > 1 and data.can_basic_attack:
		stats.append({"key": "range", "caption": "Alcance", "value": str(data.attack_range), "glyph": "◎", "tooltip": AETooltip.compose("Alcance do ataque", "Ataque básico à distância, sem revide corpo a corpo.")})
	return stats

# --- Aviso de comando ----------------------------------------------------------

static func _warning(unit: Unit, own: bool) -> Dictionary:
	if unit.owner_player == null or not unit.unit_data.is_retinue():
		return {}
	if unit.can_receive_orders():
		return {}
	return {
		"title": "SEM COMANDO",
		"body": unit.order_block_reason() if own else "Hoste sem comando: não recebe ordens.",
		"hint": "Mover e atacar estão bloqueados. Dissolver continua disponível." if own else "",
	}

# --- Comandos básicos -----------------------------------------------------------

static func commands_for(unit: Unit, grid: HexGrid) -> Array[UnitAbilityViewData]:
	var result: Array[UnitAbilityViewData] = []
	var data := unit.unit_data
	var processing := GameManager.is_turn_processing
	var locked_reason := ""
	if processing:
		locked_reason = "Aguarde o fim do processamento do turno."
	elif not unit.can_receive_orders():
		locked_reason = unit.order_block_reason()
	var move := UnitAbilityViewData.create("move", "Mover", UnitAbilityViewData.Category.COMMAND)
	move.glyph = "➤"
	move.action_kind = "move"
	move.description = "Liga o modo de movimento: clique no mapa para mover ou dar uma ordem de vários turnos."
	move.target_type = "Tile"
	if not locked_reason.is_empty():
		move.state = UnitAbilityViewData.State.BLOCKED
		move.blocked_reason = locked_reason
	elif SelectionManager.move_mode and SelectionManager.selected_unit == unit:
		move.state = UnitAbilityViewData.State.TARGETING
	if unit.movement_left <= 0.0 and move.state == UnitAbilityViewData.State.READY:
		move.cost_text = "Ordem futura"
		move.details.append("Sem movimento neste turno: a ordem continua nos próximos turnos.")
	result.append(move)
	var fortify := UnitAbilityViewData.create("fortify", "Fortificar", UnitAbilityViewData.Category.COMMAND)
	fortify.glyph = "▣"
	fortify.action_kind = "fortify"
	fortify.is_toggle = true
	fortify.toggled = unit.fortified
	fortify.description = "+%d%% defesa e cura passiva até receber outra ordem." % int(CombatResolver.FORTIFY_DEFENSE_BONUS * 100)
	if unit.embarked:
		fortify.state = UnitAbilityViewData.State.BLOCKED
		fortify.blocked_reason = "Unidade embarcada não fortifica."
	elif not locked_reason.is_empty():
		fortify.state = UnitAbilityViewData.State.BLOCKED
		fortify.blocked_reason = locked_reason
	result.append(fortify)
	var explore := UnitAbilityViewData.create("explore", "Explorar", UnitAbilityViewData.Category.COMMAND)
	explore.glyph = "◌"
	explore.action_kind = "explore"
	explore.is_toggle = true
	explore.toggled = unit.exploring
	explore.description = "Anda sozinha por territórios inexplorados a cada turno."
	if unit.embarked:
		explore.state = UnitAbilityViewData.State.BLOCKED
		explore.blocked_reason = "Unidade embarcada não explora."
	elif not locked_reason.is_empty():
		explore.state = UnitAbilityViewData.State.BLOCKED
		explore.blocked_reason = locked_reason
	result.append(explore)
	if data.can_found_city and not unit.embarked:
		var found := UnitAbilityViewData.create("found_city", "Fundar Cidade", UnitAbilityViewData.Category.COMMAND)
		found.glyph = "⌂"
		found.action_kind = "found_city"
		found.description = "Consome o Colonizador e funda uma cidade neste tile."
		var reason := CitySite.rejection_reason(grid, unit.coord, unit.owner_player) if grid != null else ""
		if reason != "" or not locked_reason.is_empty():
			found.state = UnitAbilityViewData.State.BLOCKED
			found.blocked_reason = CitySite.reason_text(reason) if reason != "" else locked_reason
		result.append(found)
	if V2ConstructorRuntime.is_builder_unit(unit):
		var tile := grid.get_tile(unit.coord) if grid != null else null
		var resource_id := tile.resource if tile != null else ""
		var improvement_name := V2ResourceImprovementData.display_name_for_resource(resource_id) if V2ResourceImprovementData.has_resource(resource_id) else ""
		var improve := UnitAbilityViewData.create("improve_resource", "Construir %s" % improvement_name if improvement_name != "" else "Melhorar recurso", UnitAbilityViewData.Category.BUILDER)
		improve.glyph = "■"
		improve.action_kind = "improve_resource"
		improve.cost_text = "1 carga"
		improve.description = "Instantâneo: consome uma carga e a ação. Sem Ouro, Mana ou Suprimentos."
		improve.details.append("Cargas restantes: %d" % unit.work_charges_remaining)
		var reason := V2ConstructorRuntime.unavailable_reason(unit, grid)
		if processing:
			reason = locked_reason
		if reason != "":
			improve.state = UnitAbilityViewData.State.BLOCKED
			improve.blocked_reason = reason
		result.append(improve)
	if V2PortalSystem.is_owned_endpoint(unit, grid):
		var portal := UnitAbilityViewData.create("traverse_portal", "Atravessar Portal", UnitAbilityViewData.Category.PORTAL)
		portal.glyph = "◎"
		portal.action_kind = "traverse_portal"
		portal.cost_text = "Todo o movimento"
		portal.description = "Teleporta esta unidade pela saída pareada e consome todo o movimento."
		var reason := V2PortalSystem.traversal_reason(unit, grid)
		if processing:
			reason = locked_reason
		if reason != "":
			portal.state = UnitAbilityViewData.State.BLOCKED
			portal.blocked_reason = reason
		result.append(portal)
	return result

# --- Habilidades ---------------------------------------------------------------

static func abilities_for(unit: Unit, grid: HexGrid) -> Array[UnitAbilityViewData]:
	var result: Array[UnitAbilityViewData] = []
	var processing := GameManager.is_turn_processing
	if V2MagicRuntime.is_v2_caster(unit):
		for spell in V2MagicRuntime.spells_for_unit(unit):
			result.append(spell_view(unit, spell, grid))
	for technique in V2TechniqueRuntime.active_techniques_for_unit(unit):
		result.append(technique_view(unit, technique, grid))
	var target := V2UnitUpgrade.get_upgrade_target(unit)
	if target != "" and V2UnlockSystem.is_unlocked(unit.owner_player, target):
		var line_node := V2UnitLine.node_for(target)
		var upgrade := UnitAbilityViewData.create("upgrade", "Evoluir para %s" % (line_node.display_name if line_node != null else target), UnitAbilityViewData.Category.UPGRADE)
		upgrade.action_kind = "upgrade"
		upgrade.cost_text = "%d Ouro" % int(ceil(V2UnitUpgrade.upgrade_cost(unit)))
		upgrade.description = "Moderniza esta unidade na cidade (instantâneo; mantém veterania, HP proporcional e recargas)."
		var reason := V2UnitUpgrade.unavailable_upgrade_reason(unit.owner_player, unit, grid)
		if processing:
			reason = "Aguarde o fim do processamento do turno."
		if reason != "":
			upgrade.state = UnitAbilityViewData.State.BLOCKED
			upgrade.blocked_reason = reason
		result.append(upgrade)
	if V2RetinueSystem.is_retinue_unit(unit):
		var dissolve := UnitAbilityViewData.create("dissolve", "Dissolver Hoste", UnitAbilityViewData.Category.RETINUE)
		dissolve.action_kind = "dissolve"
		dissolve.description = "Remove esta Hoste e libera sua capacidade de Comando. Não concede recompensa."
		if processing:
			dissolve.state = UnitAbilityViewData.State.BLOCKED
			dissolve.blocked_reason = "Aguarde o fim do processamento do turno."
		result.append(dissolve)
	return result

static func spell_view(unit: Unit, spell: V2SpellData, grid: HexGrid) -> UnitAbilityViewData:
	var view := UnitAbilityViewData.create(spell.id, spell.display_name, UnitAbilityViewData.Category.SPELL)
	view.action_kind = "spell"
	view.action_arg = spell.id
	view.accent_color = V2MagicContent.school_color(spell.school_branch)
	view.cost_text = "%d Mana" % int(spell.mana_cost)
	view.target_type = String(SPELL_TARGET_LABELS.get(spell.target_mode, ""))
	view.range_value = V2MagicRuntime.effective_range(unit, spell)
	view.cooldown_max = V2MagicRuntime.effective_cooldown(unit, spell)
	view.description = V2SpellDatabase.effect_text(spell)
	var command_line := V2MagicRuntime.command_tooltip_line(unit, spell)
	if command_line != "":
		view.details.append(command_line.trim_suffix("."))
	var remaining := V2MagicRuntime.cooldown_remaining(unit, spell.id)
	var reason := V2MagicRuntime.unavailable_reason(unit, spell.id, grid)
	if GameManager.is_turn_processing:
		reason = "Aguarde o fim do processamento do turno."
	view.blocked_reason = reason
	if SelectionManager.v2_spell_targeting_id == spell.id and SelectionManager.v2_spell_targeting_unit == unit:
		view.state = UnitAbilityViewData.State.TARGETING
	elif remaining > 0:
		view.state = UnitAbilityViewData.State.COOLDOWN
		view.cooldown_current = remaining
	elif reason != "":
		view.state = UnitAbilityViewData.State.BLOCKED
	return view

static func technique_view(unit: Unit, technique: V2DoctrineTechniqueData, grid: HexGrid) -> UnitAbilityViewData:
	var view := UnitAbilityViewData.create(technique.id, technique.display_name, UnitAbilityViewData.Category.TECHNIQUE)
	view.action_kind = "technique"
	view.action_arg = technique.id
	view.cooldown_max = technique.cooldown_turns
	view.description = technique.description
	view.cost_text = "1 ação" if technique.consumes_action else ""
	var suffix := V2DoctrineTechniqueDatabase.button_suffix(technique)
	if suffix != "":
		view.details.append("Multiplicador de Ataque %s" % suffix)
	view.target_type = technique_target_label(technique)
	if technique.is_strike():
		view.range_value = V2TechniqueRuntime.strike_range_of(unit, technique)
	elif technique.is_relocation():
		view.range_value = technique.relocate_range
	var remaining := V2TechniqueRuntime.cooldown_remaining(unit, technique.id)
	var reason := V2TechniqueRuntime.unavailable_reason(unit, technique.id, grid)
	if GameManager.is_turn_processing:
		reason = "Aguarde o fim do processamento do turno."
	elif not unit.can_receive_orders():
		reason = unit.order_block_reason()
	view.blocked_reason = reason
	if SelectionManager.technique_targeting_id == technique.id and SelectionManager.technique_targeting_unit == unit:
		view.state = UnitAbilityViewData.State.TARGETING
	elif V2TechniqueRuntime.is_active(unit, technique.id):
		view.state = UnitAbilityViewData.State.ACTIVE
	elif remaining > 0:
		view.state = UnitAbilityViewData.State.COOLDOWN
		view.cooldown_current = remaining
	elif reason != "":
		view.state = UnitAbilityViewData.State.BLOCKED
	return view

static func technique_target_label(technique: V2DoctrineTechniqueData) -> String:
	if technique.needs_target():
		match technique.target_mode:
			V2DoctrineTechniqueData.TargetMode.TILE:
				return "Tile livre"
			V2DoctrineTechniqueData.TargetMode.CITY:
				return "Cidade hostil"
		return "Unidade hostil"
	if technique.is_strike():
		return "Inimigos adjacentes"
	return "Própria unidade"

# --- Passivas e traços ------------------------------------------------------------

static func _passives(unit: Unit, own: bool) -> Array:
	var data := unit.unit_data
	var result: Array = []
	if own:
		for technique in V2TechniqueRuntime.passive_techniques_for_unit(unit):
			result.append({"title": technique.display_name, "source": "Técnica passiva", "tooltip": AETooltip.compose(technique.display_name, "%s." % V2DoctrineTechniqueDatabase.passive_effect_text(technique), ["Técnica passiva de Doutrina: age sozinha, sem ativação."])})
	var prefix := _passive_prefix(unit)
	if data.has_aura():
		result.append({"title": data.aura_name, "source": prefix, "tooltip": AETooltip.compose(data.aura_name, V2UnitAuras.effect_text(data), [prefix])})
	if data.has_low_hp_attack_bonus():
		result.append({"title": data.low_hp_attack_name, "source": prefix, "tooltip": AETooltip.compose(data.low_hp_attack_name, UnitAbilities.low_hp_attack_effect_text(data), [prefix])})
	if data.has_trait_attack_bonus():
		result.append({"title": data.trait_attack_name, "source": prefix, "tooltip": AETooltip.compose(data.trait_attack_name, UnitAbilities.trait_attack_effect_text(data), [prefix])})
	if data.ignores_technique_stationary_requirement:
		result.append({"title": "Artilharia Andante", "source": prefix, "tooltip": AETooltip.compose("Artilharia Andante", "Pode usar Bombardeio Preparado mesmo depois de se mover.", [prefix])})
	if data.spell_damage_multiplier > 1.0:
		var title := data.spell_damage_multiplier_name if data.spell_damage_multiplier_name != "" else "Potência Mágica"
		result.append({"title": title, "source": prefix, "tooltip": AETooltip.compose(title, "+%d%% de dano de feitiços." % int(round((data.spell_damage_multiplier - 1.0) * 100.0)), [prefix])})
	if data.spell_cooldown_reduction > 0:
		var title := data.spell_cooldown_reduction_name if data.spell_cooldown_reduction_name != "" else "Fluxo Mágico"
		result.append({"title": title, "source": prefix, "tooltip": AETooltip.compose(title, "-%d turno(s) na recarga aplicada por feitiços." % data.spell_cooldown_reduction, [prefix])})
	if data.environmental_zone_duration_bonus > 0:
		var title := data.environmental_zone_duration_bonus_name if data.environmental_zone_duration_bonus_name != "" else "Domínio Ambiental"
		result.append({"title": title, "source": prefix, "tooltip": AETooltip.compose(title, "+%d rodada(s) na duração das zonas ambientais criadas." % data.environmental_zone_duration_bonus, [prefix])})
	if data.spell_range_bonus > 0 and data.is_v2_caster():
		var title := data.spell_range_bonus_name if data.spell_range_bonus_name != "" else "Alcance Mágico"
		result.append({"title": title, "source": prefix, "tooltip": AETooltip.compose(title, "+%d alcance de feitiços (já incluído no alcance de cada feitiço)." % data.spell_range_bonus, [prefix])})
	if data.retinue_command_capacity_name != "" and data.is_retinue_commander():
		var title := data.retinue_command_capacity_name
		result.append({"title": title, "source": prefix, "tooltip": AETooltip.compose(title, "Concede +%d de capacidade de %s." % [data.retinue_command_capacity, V2MagicContent.command_label(data.v2_magic_school)], [prefix])})
	var flight := UnitAbilities.flight_text(data)
	if flight != "":
		result.append({"title": "Voo tático", "source": "Traço", "tooltip": AETooltip.compose("Voo tático", flight)})
	var infiltration := UnitAbilities.infiltration_text(data)
	if infiltration != "":
		result.append({"title": "Passo Sombrio", "source": "Traço", "tooltip": AETooltip.compose("Passo Sombrio", infiltration)})
	var vulnerability := UnitAbilities.ranged_vulnerability_text(data)
	if vulnerability != "":
		result.append({"title": "Vulnerável à distância", "source": "Traço", "tooltip": AETooltip.compose("Vulnerável à distância", vulnerability)})
	if data.ignores_terrain_defense:
		result.append({"title": "Ignora terreno", "source": "Traço", "tooltip": AETooltip.compose("Ignora defesa de terreno", "O bônus de terreno do defensor não se aplica.")})
	if data.regen_fraction > 0.0:
		result.append({"title": "Regeneração", "source": "Traço", "tooltip": AETooltip.compose("Regeneração", "Regenera %d%% da vida por turno." % int(round(data.regen_fraction * 100.0)))})
	return result

static func _passive_prefix(unit: Unit) -> String:
	if unit.unit_data.has_trait(UnitData.TRAIT_LEGENDARY):
		return "Passiva Lendária"
	if V2ManifestationSystem.is_manifestation_unit(unit):
		return "Passiva da Manifestação"
	return "Passiva"

# --- Status temporários ---------------------------------------------------------

## Estados PÚBLICOS com duração (Técnica ativa, Égide, Silêncio, buffs/debuffs de
## feitiço), fortificação e ambiente. Recarga nunca entra aqui (só no botão).
static func _statuses(unit: Unit, own: bool, grid: HexGrid) -> Array:
	var result: Array = []
	for status_id in unit.magic_status.keys():
		var id := String(status_id)
		if not V2OwnerTurnEffect.is_active(unit.magic_status, id):
			continue
		var turns := maxi(1, int(unit.magic_status[id]) - TurnManager.turn_number - (V2OwnerTurnEffect.SPAN_TURNS - 1))
		var technique := V2DoctrineTechniqueDatabase.get_technique(id)
		if technique != null:
			result.append({"title": technique.display_name, "tone": AEStatusChip.Tone.POSITIVE, "turns": turns, "tooltip": AETooltip.compose(technique.display_name, technique.description, ["Origem: Técnica Militar", "Até o início do próximo turno do dono."])})
			continue
		var spell := V2SpellDatabase.get_spell(id)
		if spell == null:
			continue
		var harmful := spell.silences_spellcasting or spell.status_polarity == V2SpellData.StatusPolarity.HARMFUL
		var effect := "Não pode conjurar feitiços." if spell.silences_spellcasting else _spell_status_effect(spell)
		result.append({"title": spell.display_name, "tone": AEStatusChip.Tone.NEGATIVE if harmful else AEStatusChip.Tone.POSITIVE, "turns": turns, "tooltip": AETooltip.compose(spell.display_name, effect, ["Origem: %s" % V2MagicContent.school_title(spell.school_branch), "Até o início do próximo turno do dono."])})
	if unit.fortified:
		result.append({"title": "Fortificada", "tone": AEStatusChip.Tone.POSITIVE, "turns": -1, "tooltip": AETooltip.compose("Fortificada", "+%d%% defesa e cura passiva." % int(CombatResolver.FORTIFY_DEFENSE_BONUS * 100), ["Dura até a unidade receber outra ordem."])})
	var environment := V2EnvironmentalZoneSystem.unit_lines(unit, grid) if grid != null and _coord_visible(unit, grid, own) else []
	if not environment.is_empty():
		var zone := V2EnvironmentalZoneSystem.zone_at(unit.coord, grid)
		var entry := V2EnvironmentalZoneSystem.zone_entry_at(unit.coord, grid)
		var effects: Array = environment.slice(1)
		result.append({"title": zone.display_name if zone != null else "Ambiente", "tone": AEStatusChip.Tone.NEUTRAL, "turns": int(entry.get("remaining_rounds", -1)), "tooltip": AETooltip.compose(zone.display_name if zone != null else "Ambiente", "Zona ambiental temporária sob a unidade.", effects)})
	if own and unit.unit_data.supply_cost > 0 and V2LogisticsRuntime.is_logistically_strained(unit.owner_player):
		result.append({"title": "Tensão Logística", "tone": AEStatusChip.Tone.WARNING, "turns": -1, "tooltip": AETooltip.compose("Tensão Logística", "-15% Ataque e Defesa enquanto os Suprimentos excederem a capacidade.")})
	return result

static func _spell_status_effect(spell: V2SpellData) -> String:
	var parts: Array[String] = []
	if spell.defense_bonus > 0.0:
		parts.append("+%d%% Defesa" % int(round(spell.defense_bonus * 100.0)))
	if spell.attack_bonus > 0.0:
		parts.append("+%d%% Ataque" % int(round(spell.attack_bonus * 100.0)))
	return ", ".join(parts) + "." if not parts.is_empty() else V2SpellDatabase.effect_text(spell)

static func _coord_visible(unit: Unit, grid: HexGrid, own: bool) -> bool:
	return own or grid.visibility.get(unit.coord, HexGrid.Visibility.UNSEEN) == HexGrid.Visibility.VISIBLE

# --- Rodapé ---------------------------------------------------------------------

static func _footer(unit: Unit, own: bool, viewer: PlayerData, grid: HexGrid) -> Array:
	var data := unit.unit_data
	var result: Array = []
	if unit.owner_player == null:
		if not unit.is_camp_boss and not unit.world_event_managed:
			result.append({"caption": "Comportamento", "text": String(TileInspector.BEHAVIOR_LABELS.get(MonsterAI._effective_behavior(unit), "Desconhecido"))})
		if data.gold_reward > 0.0:
			result.append({"caption": "Recompensa", "text": "%d Ouro ao derrotar" % int(data.gold_reward)})
		return result
	if not own:
		result.append({"caption": "Facção", "text": "%s · %s" % [_owner_name(unit.owner_player), _relation(unit.owner_player, viewer)]})
		return result
	if data.supply_cost > 0:
		var strained := V2LogisticsRuntime.is_logistically_strained(unit.owner_player)
		result.append({"caption": "Suprimentos", "text": "%d%s" % [data.supply_cost, " · Tensão Logística" if strained else ""], "tone": "warning" if strained else ""})
	var next_index := unit.veterancy_level + 1
	var veterancy := "%s · %d abate%s" % [unit.veterancy_title(), unit.kills, "" if unit.kills == 1 else "s"]
	if next_index < Unit.VETERANCY_KILL_THRESHOLDS.size():
		veterancy += " · %s com %d" % [Unit.VETERANCY_TITLES[next_index], Unit.VETERANCY_KILL_THRESHOLDS[next_index]]
	result.append({"caption": "Veterania", "text": veterancy})
	if V2ConstructorRuntime.is_builder_unit(unit):
		result.append({"caption": "Cargas", "text": "%d restante%s" % [unit.work_charges_remaining, "" if unit.work_charges_remaining == 1 else "s"]})
	for line in V2RetinueSystem.summary_lines(unit):
		var split := String(line).split(":", true, 1)
		if split.size() == 2:
			result.append({"caption": split[0].strip_edges(), "text": split[1].strip_edges()})
		else:
			result.append({"caption": "Comando", "text": String(line), "tone": "warning"})
	var order := _order_text(unit)
	if order != "":
		result.append({"caption": "Ordem", "text": order})
	if grid != null:
		var here := TileInspector.inspect(grid, unit.coord, viewer)
		result.append({"caption": "Tile", "text": TileInspector.summary_line(here)})
	return result

static func _order_text(unit: Unit) -> String:
	if unit.embarked:
		return "Embarcada — em trânsito pelo mar"
	if unit.exploring:
		return "Explorando automaticamente"
	if unit.move_order_target != Unit.NO_MOVE_ORDER:
		return "Em marcha até (%d, %d)" % [unit.move_order_target.x, unit.move_order_target.y]
	return ""

static func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
