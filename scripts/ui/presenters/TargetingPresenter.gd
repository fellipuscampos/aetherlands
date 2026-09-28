class_name TargetingPresenter
extends RefCounted

## Estado de mira ATUAL, lido do SelectionManager (a única autoridade). Devolve {}
## quando não há mira. Nenhum alvo é recalculado: alcance e custo vêm dos mesmos
## helpers que a mira usa.

static func current() -> Dictionary:
	if SelectionManager.technique_targeting_id != "":
		var unit := SelectionManager.technique_targeting_unit
		var technique := V2DoctrineTechniqueDatabase.get_technique(SelectionManager.technique_targeting_id)
		if technique == null:
			return {}
		var range_value := V2TechniqueRuntime.strike_range_of(unit, technique) if technique.is_strike() and unit != null else technique.relocate_range
		return {
			"kind": "technique",
			"title": technique.display_name,
			"target": UnitPresenter.technique_target_label(technique),
			"range": range_value,
			"cost": "1 ação · recarga %d" % technique.cooldown_turns if technique.consumes_action else "recarga %d" % technique.cooldown_turns,
			"instruction": "Clique num %s destacado." % ("tile" if technique.target_mode == V2DoctrineTechniqueData.TargetMode.TILE else "alvo"),
			"targets": SelectionManager.technique_target_coords.size(),
			"color": UIThemeTokens.COLOR_ACCENT,
		}
	if SelectionManager.v2_spell_targeting_id != "":
		var caster := SelectionManager.v2_spell_targeting_unit
		var spell := V2SpellDatabase.get_spell(SelectionManager.v2_spell_targeting_id)
		if spell == null:
			return {}
		return {
			"kind": "spell",
			"title": spell.display_name,
			"target": String(UnitPresenter.SPELL_TARGET_LABELS.get(spell.target_mode, "Alvo")),
			"range": V2MagicRuntime.effective_range(caster, spell) if caster != null else spell.cast_range,
			"cost": "%d Mana" % int(spell.mana_cost),
			"instruction": V2MagicRuntime.targeting_hint(spell).trim_suffix(" (ESC cancela)") + ".",
			"targets": SelectionManager.v2_spell_target_coords.size(),
			"color": V2MagicContent.school_color(spell.school_branch),
		}
	if SelectionManager.placing_city != null:
		var building := BuildingDatabase.get_building(SelectionManager.placing_building_id)
		return {
			"kind": "placement",
			"title": "Posicionar %s" % (building.display_name if building != null else "prédio"),
			"target": "Tile livre do território",
			"range": 0,
			"cost": "%d PP" % int(building.production_cost) if building != null else "",
			"instruction": "Clique num tile azul para iniciar a construção em %s." % SelectionManager.placing_city.city_name,
			"targets": SelectionManager.placeable_coords.size(),
			"color": UIThemeTokens.COLOR_INFO,
		}
	if SelectionManager.annexing_city != null:
		var city := SelectionManager.annexing_city
		return {
			"kind": "annex",
			"title": "Anexar território",
			"target": "Tile elegível adjacente ao território",
			"range": V2CityLevelData.max_territory_radius(city.city_level),
			"cost": "1 Ponto de Anexação (restam %d)" % city.annexation_points,
			"instruction": "Clique num tile destacado. O modo continua enquanto houver pontos.",
			"targets": SelectionManager.annexable_coords.size(),
			"color": UIThemeTokens.COLOR_SUCCESS,
		}
	if SelectionManager.city_attack_city != null:
		var attacking := SelectionManager.city_attack_city
		return {
			"kind": "city_attack",
			"title": "Ataque da Cidade — %s" % attacking.city_name,
			"target": "Unidade hostil visível",
			"range": CityDefense.city_attack_range(attacking),
			"cost": "1 disparo por turno · poder %s" % TileInspector._format_power(CityDefense.city_attack_power(attacking)),
			"instruction": "Clique num alvo destacado. Sem revide.",
			"targets": SelectionManager.city_attack_coords.size(),
			"color": UIThemeTokens.COLOR_CRITICAL,
		}
	return {}
