class_name VictoryPresenter
extends RefCounted

## View model da tela de VITÓRIA (Fase 30 / UI-3) em duas camadas: SUMMARY (três
## rotas comparáveis em poucos segundos) e DETAIL (requisitos, rivais, regras).
## Toda condição vem de VictoryConditions / V2VictoryConditions /
## V2TranscendenceSystem — nenhuma regra é reimplementada. Rival só aparece com
## informação pública (eliminação, conquista mantida pelo humano, Ritual público).

const DOMINATION := "domination"
const SUPREMACY := "supremacy"
const TRANSCENDENCE := "transcendence"
const ROUTES := [DOMINATION, SUPREMACY, TRANSCENDENCE]

static func summary(player: PlayerData) -> Array:
	if player == null:
		return []
	return [domination_card(player), supremacy_card(player), transcendence_card(player)]

static func _rivals(player: PlayerData) -> Array[PlayerData]:
	var result: Array[PlayerData] = []
	for other in V2VictoryConditions.major_players():
		if other != player:
			result.append(other)
	return result

# --- Dominação -----------------------------------------------------------------------

static func domination_card(player: PlayerData) -> Dictionary:
	var rivals := _rivals(player)
	var segments: Array = []
	var eliminated := 0
	for rival in rivals:
		var done := V2VictoryConditions.is_eliminated(rival)
		if done:
			eliminated += 1
		segments.append({"filled": done, "color": UIThemeTokens.COLOR_CRITICAL, "tooltip": "%s — %s" % [_name(rival), "eliminada" if done else "ativa"]})
	var remaining := rivals.size() - eliminated
	return {
		"key": DOMINATION,
		"title": "Dominação",
		"state": "Concluída" if remaining == 0 and not rivals.is_empty() else "Em andamento",
		"progress_text": "%d / %d rivais eliminados" % [eliminated, rivals.size()],
		"segments": segments,
		"next": String(StrategicImperatives.domination(player).next), # Fase 33D3: imperativo = fonte única
		"threat": "",
		"ratio": VictoryConditions.dominance_progress(player, V2VictoryConditions.major_players()),
	}

static func domination_detail(player: PlayerData) -> Dictionary:
	var rows: Array = []
	for rival in _rivals(player):
		var done := V2VictoryConditions.is_eliminated(rival)
		rows.append({"label": _name(rival), "done": done, "status": "Eliminada" if done else "Ativa"})
	return {
		"key": DOMINATION,
		"title": "Dominação",
		"checklist": rows,
		"sections": [],
		"how_to": ["Vence quem for a última civilização restante.", "Uma civilização é eliminada ao perder todas as cidades e unidades.", "Civilizações restantes agora: %d." % VictoryConditions.civilizations_remaining(V2VictoryConditions.major_players())],
	}

# --- Supremacia Militar --------------------------------------------------------------------

static func _supremacy_capstone() -> V2ResearchNode:
	return V2ResearchDatabase.get_node(V2ResearchDatabase.SUPREME_ARMY_ID)

static func supremacy_card(player: PlayerData) -> Dictionary:
	var status := V2VictoryConditions.military_supremacy_status(player)
	var segments: Array = []
	for rival in status.rivals:
		segments.append({"filled": status.access and rival.satisfied, "color": UIThemeTokens.COLOR_SUCCESS, "tooltip": "%s — %s" % [rival.name, _supremacy_reason_label(String(rival.reason))]})
	var capstone := _supremacy_capstone()
	var doctrines := V2ResearchDatabase.capstone_progress(capstone.id, player.v2_research.completed_ids) if capstone != null else Vector2i.ZERO
	var next := String(StrategicImperatives.supremacy(player).next) # Fase 33D3: imperativo = fonte única
	return {
		"key": SUPREMACY,
		"title": "Supremacia Militar",
		"state": "Acesso liberado" if status.access else "Sem acesso",
		"progress_text": "%d / %d rivais satisfeitos" % [status.satisfied_count, status.rival_count] if status.access else "Doutrinas completas: %d / %d" % [doctrines.x, doctrines.y],
		"segments": segments,
		"next": next,
		"threat": "",
		"access": status.access,
	}

static func _supremacy_reason_label(reason: String) -> String:
	match reason:
		V2VictoryConditions.REASON_CAPTURED:
			return "Satisfeito — cidade de maior nível conquistada e mantida"
		V2VictoryConditions.REASON_ELIMINATED:
			return "Eliminado — satisfeito"
	return "Pendente"

static func supremacy_detail(player: PlayerData) -> Dictionary:
	var status := V2VictoryConditions.military_supremacy_status(player)
	var capstone := _supremacy_capstone()
	var doctrines := V2ResearchDatabase.capstone_progress(capstone.id, player.v2_research.completed_ids) if capstone != null else Vector2i.ZERO
	var checklist: Array = [
		{"label": "Duas Doutrinas completas", "done": doctrines.x >= doctrines.y and doctrines.y > 0, "status": "%d / %d" % [doctrines.x, doctrines.y]},
		{"label": "Exército Supremo pesquisado", "done": status.access, "status": "Pesquisado" if status.access else "Pendente"},
	]
	var rivals: Array = []
	for rival in status.rivals:
		rivals.append({"label": String(rival.name), "done": bool(rival.satisfied), "status": _supremacy_reason_label(String(rival.reason))})
	return {
		"key": SUPREMACY,
		"title": "Supremacia Militar",
		"checklist": checklist,
		"sections": [{"title": "Cada rival", "rows": rivals}],
		"how_to": ["Requer a pesquisa Exército Supremo (duas Doutrinas completas).", "Para cada rival: conquiste e mantenha uma cidade dele do MAIOR nível que ele possui no momento da captura (empate: qualquer uma delas), ou elimine-o.", "Perder a cidade conquistada desfaz a condição daquele rival.", String(StrategicImperatives.supremacy(player).next)],
	}

# --- Transcendência ------------------------------------------------------------------

static func _transcendence_capstone() -> V2ResearchNode:
	return V2ResearchDatabase.get_node(V2ResearchDatabase.TRANSCENDENCE_ID)

static func _ritual_ready_cities(player: PlayerData) -> Array[String]:
	var names: Array[String] = []
	for city in player.cities:
		if city != null and is_instance_valid(city) and V2TranscendenceSystem.city_has_usable_magic_ritual_structure(city, player):
			names.append(city.city_name)
	return names

static func rival_public_rituals(player: PlayerData) -> Array:
	var result: Array = []
	for ritual in V2TranscendenceSystem.public_rituals():
		if int(ritual.owner_index) != V2VictoryConditions.stable_id(player):
			result.append(ritual)
	return result

static func transcendence_card(player: PlayerData) -> Dictionary:
	var status := V2VictoryConditions.transcendence_status(player)
	var capstone := _transcendence_capstone()
	var schools := V2ResearchDatabase.capstone_progress(capstone.id, player.v2_research.completed_ids) if capstone != null else Vector2i.ZERO
	var segments: Array = []
	var required := V2TranscendenceSystem.ROUNDS_REQUIRED
	var done_rounds := required - int(status.remaining_rounds) if status.active else 0
	for index in required:
		segments.append({"filled": index < done_rounds, "color": UIThemeTokens.COLOR_TARGETING, "tooltip": "Rodada %d do Ritual" % (index + 1)})
	var next := String(StrategicImperatives.transcendence(player).next) # Fase 33D3: imperativo = fonte única
	var threat := ""
	var rivals := rival_public_rituals(player)
	if not rivals.is_empty():
		var nearest: Dictionary = rivals[0]
		for ritual in rivals:
			if int(ritual.remaining_rounds) < int(nearest.remaining_rounds):
				nearest = ritual
		threat = "%s conduz um Ritual: %d rodada(s)." % [nearest.owner_name, int(nearest.remaining_rounds)]
	return {
		"key": TRANSCENDENCE,
		"title": "Transcendência",
		"state": "Ritual ativo" if status.active else ("Acesso liberado" if status.access else "Sem acesso"),
		"progress_text": "Ritual: %d / %d rodadas" % [done_rounds, required] if status.active else "Manifestações: %d / %d" % [mini(status.manifestation_count, status.manifestation_required), status.manifestation_required] if status.access else "Escolas completas: %d / %d" % [schools.x, schools.y],
		"segments": segments,
		"next": next,
		"threat": threat,
		"access": status.access,
	}

static func transcendence_detail(player: PlayerData) -> Dictionary:
	var status := V2VictoryConditions.transcendence_status(player)
	var capstone := _transcendence_capstone()
	var schools := V2ResearchDatabase.capstone_progress(capstone.id, player.v2_research.completed_ids) if capstone != null else Vector2i.ZERO
	var ready_cities := _ritual_ready_cities(player)
	var ritual_text := "Não iniciado"
	if status.active:
		var site := V2TranscendenceSystem.ritual_site(player, GameManager.hex_grid)
		ritual_text = "Ativo em %s — %d rodada(s) restante(s)" % [site.city_name if site != null else "?", int(status.remaining_rounds)]
	var checklist: Array = [
		{"label": "Duas Escolas completas (N9)", "done": schools.x >= schools.y and schools.y > 0, "status": "%d / %d" % [schools.x, schools.y]},
		{"label": "Transcendência pesquisada", "done": status.access, "status": "Pesquisada" if status.access else "Pendente"},
		{"label": "Grandes Manifestações ativas", "done": int(status.manifestation_count) >= int(status.manifestation_required), "status": "%d / %d" % [mini(status.manifestation_count, status.manifestation_required), status.manifestation_required]},
		{"label": "Estrutura Ritual utilizável", "done": not ready_cities.is_empty(), "status": ", ".join(ready_cities) if not ready_cities.is_empty() else "Nenhuma cidade"},
		{"label": "Mana para iniciar (%d)" % int(V2TranscendenceSystem.MANA_COST), "done": status.active or player.mana >= V2TranscendenceSystem.MANA_COST, "status": "Pago" if status.active else "%d disponível" % int(player.mana)},
		{"label": "Ritual Final", "done": status.active, "status": ritual_text},
	]
	var rivals: Array = []
	for ritual in rival_public_rituals(player):
		rivals.append({"label": String(ritual.owner_name), "done": false, "status": "Ritual público em (%d, %d): %d rodada(s)" % [ritual.site_coord.x, ritual.site_coord.y, int(ritual.remaining_rounds)], "tone": "critical", "coord": ritual.site_coord})
	var sections: Array = []
	if not rivals.is_empty():
		sections.append({"title": "Ameaças públicas", "rows": rivals})
	return {
		"key": TRANSCENDENCE,
		"title": "Transcendência",
		"checklist": checklist,
		"sections": sections,
		"how_to": ["Requer a pesquisa Transcendência (duas Escolas completas).", "Mantenha duas Grandes Manifestações ativas e uma cidade com Estrutura Ritual.", "O Ritual custa %d Mana, é público e dura %d rodadas; perder um requisito o interrompe." % [int(V2TranscendenceSystem.MANA_COST), V2TranscendenceSystem.ROUNDS_REQUIRED]],
	}

static func detail(player: PlayerData, key: String) -> Dictionary:
	match key:
		SUPREMACY:
			return supremacy_detail(player)
		TRANSCENDENCE:
			return transcendence_detail(player)
	return domination_detail(player)

static func _name(player: PlayerData) -> String:
	return player.civ.civ_name if player != null and player.civ != null else "Civilização"
