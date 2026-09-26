class_name V2TranscendenceSystem
extends RefCounted

## Fase 23 — via de vitória mágica V2. O capstone concede ACESSO; este
## sistema mantém o Ritual Final público, temporal e interrompível. Requisitos
## são sempre derivados de pesquisa, unidades e cidade atuais.

const ACCESS_ID := "v2_transcendence_access"
const RESEARCH_ID := "v2_transcendence"
const MANA_COST := 120.0
const ROUNDS_REQUIRED := 4
const MANIFESTATIONS_REQUIRED := 2
const INVALID_COORD := Vector2i(999999, 999999)

const INTERRUPT_ACCESS := "access_lost"
const INTERRUPT_MANIFESTATIONS := "manifestations_lost"
const INTERRUPT_SITE := "site_lost"
const INTERRUPT_STRUCTURE := "structure_lost"
const INTERRUPT_ELIMINATED := "eliminated"
const INTERRUPT_CANCELLED := "cancelled"

static var _loading := false

static func has_access(player) -> bool:
	return player != null and player.has_unlocked(ACCESS_ID)

static func active_manifestation_count(player) -> int:
	return V2ManifestationSystem.active_manifestation_count(player)

## N8 de Magia cujo prédio existe fisicamente e cujo unlock o dono atual possui.
## A lista é derivada do banco: nenhum id concreto das seis Escolas vive aqui.
static func eligible_ritual_structures(city: City, player) -> Array[String]:
	var result: Array[String] = []
	if city == null or not is_instance_valid(city) or player == null:
		return result
	for node in V2ResearchDatabase.nodes_for_tree(V2ResearchNode.TreeType.MAGIC_SCHOOL):
		if node.tier_role != "ritual_structure" or node.unlock_type != "ritual_building":
			continue
		if city.buildings.has(node.unlock_id) and player.has_unlocked(node.unlock_id):
			result.append(node.unlock_id)
	return result

static func city_has_usable_magic_ritual_structure(city: City, player) -> bool:
	return not eligible_ritual_structures(city, player).is_empty()

static func has_active_ritual(player) -> bool:
	return player != null and typeof(player.v2_transcendence_ritual) == TYPE_DICTIONARY and not player.v2_transcendence_ritual.is_empty()

static func ritual_site_coord(player) -> Vector2i:
	if not has_active_ritual(player):
		return INVALID_COORD
	return player.v2_transcendence_ritual.get("site_coord", INVALID_COORD)

static func ritual_site(player, grid: HexGrid = null) -> City:
	grid = GameManager.hex_grid if grid == null else grid
	return grid.get_city_at(ritual_site_coord(player)) if grid != null and has_active_ritual(player) else null

static func ritual_rounds_remaining(player) -> int:
	return int(player.v2_transcendence_ritual.get("remaining_rounds", 0)) if has_active_ritual(player) else 0

static func ritual_progress(player) -> float:
	if not has_active_ritual(player):
		return 0.0
	return clampf(float(ROUNDS_REQUIRED - ritual_rounds_remaining(player)) / float(ROUNDS_REQUIRED), 0.0, 1.0)

## Ordem canônica de validação; a primeira falha é o motivo apresentado pela UI.
static func start_unavailable_reason(player, city: City) -> String:
	if GameManager.state == GameManager.GameState.GAME_OVER:
		return "A partida já terminou."
	if player == null or V2VictoryConditions.stable_id(player) < 0 or V2VictoryConditions.is_eliminated(player):
		return "Civilização inválida ou eliminada."
	if not has_access(player):
		return "Requer a pesquisa Transcendência."
	if has_active_ritual(player):
		var active_city := ritual_site(player)
		var active_name := active_city.city_name if active_city != null else "outra cidade"
		return "Já existe um Ritual de Transcendência ativo em %s." % active_name
	if city == null or not is_instance_valid(city):
		return "Cidade inválida."
	if city.owner_player != player:
		return "A cidade precisa pertencer à civilização."
	if not city_has_usable_magic_ritual_structure(city, player):
		return "Esta cidade precisa de uma Estrutura Ritual pesquisada."
	var count := active_manifestation_count(player)
	if count < MANIFESTATIONS_REQUIRED:
		return "Requer %d Grandes Manifestações ativas (%d / %d)." % [MANIFESTATIONS_REQUIRED, count, MANIFESTATIONS_REQUIRED]
	if player.mana < MANA_COST:
		return "Mana insuficiente: requer %d, disponível %d." % [int(MANA_COST), int(player.mana)]
	return ""

static func can_start_ritual(player, city: City) -> bool:
	return start_unavailable_reason(player, city) == ""

static func start_ritual(player, city: City) -> bool:
	if not can_start_ritual(player, city):
		return false
	player.mana -= MANA_COST
	player.v2_transcendence_ritual = {
		"site_coord": city.coord,
		"remaining_rounds": ROUNDS_REQUIRED,
		"last_progress_turn": TurnManager.turn_number,
	}
	_refresh_marker(player)
	EventBus.v2_transcendence_started.emit(player, city.coord, ROUNDS_REQUIRED)
	EventBus.notify.emit("%s iniciou o Ritual de Transcendência em %s. Restam %d rodadas." % [_player_name(player), city.city_name, ROUNDS_REQUIRED], "confirm")
	return true

static func cancel_ritual(player) -> bool:
	return interrupt_ritual(player, INTERRUPT_CANCELLED)

static func interrupt_ritual(player, reason: String, announce: bool = true) -> bool:
	if not has_active_ritual(player):
		return false
	var coord := ritual_site_coord(player)
	var city := ritual_site(player)
	var city_name := city.city_name if city != null else "(%d, %d)" % [coord.x, coord.y]
	player.v2_transcendence_ritual.clear()
	_remove_marker(player)
	if announce and not _loading:
		EventBus.v2_transcendence_interrupted.emit(player, coord, reason)
		EventBus.notify.emit("O Ritual de Transcendência de %s em %s foi interrompido." % [_player_name(player), city_name], "")
	return true

## Retorna "" se continua válido ou a razão interna que o interrompeu.
static func active_invalid_reason(player, grid: HexGrid = null) -> String:
	if player == null or not has_active_ritual(player):
		return ""
	grid = GameManager.hex_grid if grid == null else grid
	if V2VictoryConditions.is_eliminated(player):
		return INTERRUPT_ELIMINATED
	if not has_access(player):
		return INTERRUPT_ACCESS
	var city := ritual_site(player, grid)
	if city == null or city.owner_player != player:
		return INTERRUPT_SITE
	if not city_has_usable_magic_ritual_structure(city, player):
		return INTERRUPT_STRUCTURE
	if active_manifestation_count(player) < MANIFESTATIONS_REQUIRED:
		return INTERRUPT_MANIFESTATIONS
	return ""

static func validate_active_ritual(player, announce: bool = true, grid: HexGrid = null) -> bool:
	if not has_active_ritual(player):
		return false
	var reason := active_invalid_reason(player, grid)
	if reason != "":
		interrupt_ritual(player, reason, announce)
		return false
	return true

static func interrupt_if_site(player, coord: Vector2i) -> bool:
	return has_active_ritual(player) and ritual_site_coord(player) == coord and interrupt_ritual(player, INTERRUPT_SITE)

## Um único tick global. Valida antes de avançar e usa last_progress_turn para
## tornar chamadas duplicadas e load no mesmo turno idempotentes.
static func process_global_round(grid: HexGrid = null) -> void:
	if GameManager.state == GameManager.GameState.GAME_OVER:
		return
	grid = GameManager.hex_grid if grid == null else grid
	for player in GameManager.players:
		if not has_active_ritual(player) or not validate_active_ritual(player, true, grid):
			continue
		var state: Dictionary = player.v2_transcendence_ritual
		var last_turn := int(state.get("last_progress_turn", -1))
		if TurnManager.turn_number <= last_turn or int(state.get("remaining_rounds", 0)) <= 0:
			continue
		state.remaining_rounds = maxi(0, int(state.remaining_rounds) - 1)
		state.last_progress_turn = TurnManager.turn_number
		EventBus.v2_transcendence_progressed.emit(player, state.site_coord, state.remaining_rounds)
		if state.remaining_rounds == 1:
			var city := ritual_site(player, grid)
			EventBus.notify.emit("Alerta: o Ritual de Transcendência de %s em %s termina em 1 rodada." % [_player_name(player), city.city_name if city else "seu local ritual"], "")

static func victory_ready(player, grid: HexGrid = null) -> bool:
	return has_active_ritual(player) and ritual_rounds_remaining(player) <= 0 and active_invalid_reason(player, grid) == ""

## Informação deliberadamente pública: dono/site/countdown, nada sobre fog ou tropas.
static func public_rituals() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player in GameManager.players:
		if has_active_ritual(player):
			result.append({
				"owner_index": V2VictoryConditions.stable_id(player),
				"owner_name": _player_name(player),
				"site_coord": ritual_site_coord(player),
				"remaining_rounds": ritual_rounds_remaining(player),
			})
	return result

static func to_save_array() -> Array:
	var result: Array = []
	for info in public_rituals():
		# O zero só existe por alguns microssegundos entre o tick final e
		# GameManager.check_victories(); o formato persistido aceita 1..4.
		if info.remaining_rounds < 1 or info.remaining_rounds > ROUNDS_REQUIRED:
			continue
		var player: PlayerData = GameManager.players[info.owner_index]
		result.append({
			"owner_index": info.owner_index,
			"site": [info.site_coord.x, info.site_coord.y],
			"remaining_rounds": info.remaining_rounds,
			"last_progress_turn": int(player.v2_transcendence_ritual.last_progress_turn),
		})
	return result

static func clear_all(grid: HexGrid = null) -> void:
	_loading = true
	for player in GameManager.players:
		player.v2_transcendence_ritual.clear()
	grid = GameManager.hex_grid if grid == null else grid
	if grid != null:
		grid.clear_v2_transcendence_markers()
	_loading = false

## Fail-safe: só o primeiro registro íntegro por dono é aceito e nenhuma rejeição
## de save produz evento/toast. Chamado depois de cidades/unidades/prédios.
static func load_save_array(value: Variant, grid: HexGrid) -> void:
	clear_all(grid)
	if typeof(value) != TYPE_ARRAY:
		return
	_loading = true
	var loaded_owners: Dictionary = {}
	for entry in value:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var owner_value: Variant = entry.get("owner_index", null)
		var site = entry.get("site", null)
		var remaining_value: Variant = entry.get("remaining_rounds", null)
		var last_turn_value: Variant = entry.get("last_progress_turn", null)
		if not _is_integral_number(owner_value) or not _is_integral_number(remaining_value) or not _is_integral_number(last_turn_value):
			continue
		if typeof(site) != TYPE_ARRAY or site.size() != 2 or not _is_integral_number(site[0]) or not _is_integral_number(site[1]):
			continue
		var owner_index := int(owner_value)
		var remaining := int(remaining_value)
		var last_turn := int(last_turn_value)
		if owner_index < 0 or owner_index >= GameManager.players.size() or loaded_owners.has(owner_index):
			continue
		if remaining < 1 or remaining > ROUNDS_REQUIRED or last_turn < -1 or last_turn > TurnManager.turn_number:
			continue
		var player: PlayerData = GameManager.players[owner_index]
		player.v2_transcendence_ritual = {
			"site_coord": Vector2i(int(site[0]), int(site[1])),
			"remaining_rounds": remaining,
			"last_progress_turn": last_turn,
		}
		if active_invalid_reason(player, grid) != "":
			player.v2_transcendence_ritual.clear()
			continue
		loaded_owners[owner_index] = true
		_refresh_marker(player, grid)
	_loading = false

static func _is_integral_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and number == floor(number)

static func _refresh_marker(player, grid: HexGrid = null) -> void:
	grid = GameManager.hex_grid if grid == null else grid
	if grid != null and has_active_ritual(player):
		grid.refresh_v2_transcendence_marker(V2VictoryConditions.stable_id(player), ritual_site_coord(player))

static func _remove_marker(player, grid: HexGrid = null) -> void:
	grid = GameManager.hex_grid if grid == null else grid
	if grid != null:
		grid.remove_v2_transcendence_marker(V2VictoryConditions.stable_id(player))

static func _player_name(player) -> String:
	return player.civ.civ_name if player != null and player.civ != null else "Civilização"
