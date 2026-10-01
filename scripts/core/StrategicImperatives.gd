class_name StrategicImperatives
extends RefCounted

## Fase 33D3 — IMPERATIVOS ESTRATÉGICOS (docs/AETHERLANDS_STRATEGIC_PACING_OBJECTIVES_DESIGN.md §9): responde
## "o que falta AGORA para esta rota?", nunca uma tarefa arbitrária. DERIVADO a cada chamada: sem estado salvo,
## sem efeito colateral, sem regra própria — lê só as fontes canônicas (V2VictoryConditions,
## V2TranscendenceSystem, V2ResearchDatabase, VictoryConditions). O alvo de Supremacia sugerido vem só do que
## o jogador CONHECE (V2VictoryConditions.known_supremacy_targets): uma cidade escondida nunca aparece.
##
## Cada imperativo: {route, title, next, step, lines, target_coord (opcional)}. Não é Attention e nunca
## bloqueia o fim de turno.

const DOMINATION := "domination"
const SUPREMACY := "supremacy"
const TRANSCENDENCE := "transcendence"

static func for_player(player: PlayerData, grid: HexGrid = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if player == null:
		return result
	result.append(domination(player))
	result.append(supremacy(player, grid))
	result.append(transcendence(player, grid))
	return result

static func domination(player: PlayerData) -> Dictionary:
	var remaining := 0
	for other in V2VictoryConditions.major_players():
		if other != player and not V2VictoryConditions.is_eliminated(other):
			remaining += 1
	return {
		"route": DOMINATION, "title": "Dominação", "step": "eliminate" if remaining > 0 else "done",
		"next": "Restam %d reino(s) rival(is)." % remaining if remaining > 0 else "Nenhum reino rival restante.",
		"lines": [],
	}

static func supremacy(player: PlayerData, grid: HexGrid = null) -> Dictionary:
	var status := V2VictoryConditions.military_supremacy_status(player)
	var capstone := V2ResearchDatabase.get_node(V2ResearchDatabase.SUPREME_ARMY_ID)
	var doctrines := V2ResearchDatabase.capstone_progress(capstone.id, player.v2_research.completed_ids) if capstone != null else Vector2i.ZERO
	var result := {"route": SUPREMACY, "title": "Prove sua supremacia", "lines": [], "step": "", "next": ""}
	var lines: Array[String] = []
	var first_pending: PlayerData = null
	for rival in status.rivals:
		var label := "alvo militar pendente"
		if String(rival.reason) == V2VictoryConditions.REASON_CAPTURED:
			label = "satisfeito"
		elif String(rival.reason) == V2VictoryConditions.REASON_ELIMINATED:
			label = "eliminado"
		elif first_pending == null:
			first_pending = V2VictoryConditions.major_players()[int(rival.player_id)]
		lines.append("%s — %s" % [String(rival.name), label])
	result.lines = lines
	if not status.access:
		result.step = "research"
		result.next = "Pesquise Exército Supremo (Doutrinas completas: %d / %d)." % [doctrines.x, doctrines.y]
		return result
	if first_pending == null:
		result.step = "done"
		result.next = "Todas as condições de Supremacia cumpridas."
		return result
	result.step = "capture"
	var targets := V2VictoryConditions.known_supremacy_targets(player, first_pending, grid)
	if targets.is_empty():
		result.next = "Explore o território de %s para identificar um centro estratégico." % first_pending.civ.civ_name
	else:
		result.next = "Alvo relevante conhecido: %s (%s)." % [String(targets[0].name), first_pending.civ.civ_name]
		result["target_coord"] = targets[0].coord
	return result

## Primeiro requisito ainda não cumprido, na ORDEM REAL do runtime (V2TranscendenceSystem.start_unavailable_
## reason: acesso → Ritual ativo → Estrutura Ritual → Manifestações → Mana).
static func transcendence(player: PlayerData, grid: HexGrid = null) -> Dictionary:
	var capstone := V2ResearchDatabase.get_node(V2ResearchDatabase.TRANSCENDENCE_ID)
	var schools := V2ResearchDatabase.capstone_progress(capstone.id, player.v2_research.completed_ids) if capstone != null else Vector2i.ZERO
	var result := {"route": TRANSCENDENCE, "title": "Transcendência", "lines": [], "step": "", "next": ""}
	if not V2TranscendenceSystem.has_access(player):
		if schools.x < schools.y:
			result.step = "schools"
			result.next = "Complete duas Escolas de Magia (N9): %d / %d." % [schools.x, schools.y]
		else:
			result.step = "research"
			result.next = "Pesquise Transcendência."
		return result
	if V2TranscendenceSystem.has_active_ritual(player):
		var invalid := V2TranscendenceSystem.active_invalid_reason(player, grid)
		result.step = "maintain"
		result.next = "Mantenha o Ritual por mais %d rodada(s)." % V2TranscendenceSystem.ritual_rounds_remaining(player) if invalid == "" else "Restaure os requisitos do Ritual."
		return result
	var site := _ritual_candidate(player)
	var count := V2TranscendenceSystem.active_manifestation_count(player)
	if site == null:
		result.step = "structure"
		result.next = "Construa uma Estrutura Ritual pesquisada numa cidade."
	elif count < 1:
		result.step = "first_manifestation"
		result.next = "Produza a primeira Grande Manifestação."
	elif count < V2TranscendenceSystem.MANIFESTATIONS_REQUIRED:
		result.step = "second_manifestation"
		result.next = "Produza uma segunda Grande Manifestação de outra Escola (%d / %d)." % [count, V2TranscendenceSystem.MANIFESTATIONS_REQUIRED]
	elif player.mana < V2TranscendenceSystem.MANA_COST:
		result.step = "mana"
		result.next = "Acumule Mana para o Ritual: %d / %d." % [int(player.mana), int(V2TranscendenceSystem.MANA_COST)]
	elif V2TranscendenceSystem.start_unavailable_reason(player, site) == "":
		result.step = "start"
		result.next = "Inicie o Ritual Final em %s." % site.city_name
	else:
		result.step = "blocked"
		result.next = V2TranscendenceSystem.start_unavailable_reason(player, site)
	return result

static func _ritual_candidate(player: PlayerData) -> City:
	for city in player.cities:
		if V2TranscendenceSystem.city_has_usable_magic_ritual_structure(city, player):
			return city
	return null

## A rota que o jogador mais avançou (para o chip da Convergência): com acesso primeiro; empate → Supremacia.
static func headline(player: PlayerData, grid: HexGrid = null) -> Dictionary:
	if player == null:
		return {}
	if V2TranscendenceSystem.has_active_ritual(player) or (V2TranscendenceSystem.has_access(player) and not player.has_unlocked(V2VictoryConditions.MILITARY_SUPREMACY_ACCESS)):
		return transcendence(player, grid)
	if player.has_unlocked(V2VictoryConditions.MILITARY_SUPREMACY_ACCESS):
		return supremacy(player, grid)
	return domination(player)
