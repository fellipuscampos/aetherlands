class_name ReliquaryEvent
extends WorldEvent

## Fase 33D3 — RELICÁRIO DESPERTO (docs/AETHERLANDS_STRATEGIC_PACING_OBJECTIVES_DESIGN.md §8): oportunidade
## territorial competitiva da Era da Ascensão. Cria MOVIMENTO, não economia passiva: um local físico público,
## guardiões reais (Esqueletos existentes, stats intactos) e posse por 2 rodadas globais consecutivas.
## Opcional: ignorar não tem penalidade além de outro reino poder ganhar a recompensa.
##
## Fases (WorldEvent): DORMANT → ANNOUNCED (local público; preparação de PREPARATION_ROUNDS) → ACTIVE (guardiões
## nascem; disputa avaliada uma vez por rodada global) → RESOLUTION (recompensa escolhida pelo vencedor) →
## COMPLETED. Não usa PHASE_PREPARATION de propósito: essa fase é a "decisão de participar" do Dragão
## (painel/Attention do humano); aqui ninguém precisa se inscrever — basta ir.
##
## Agendamento, exclusividade com o Dragão e supersessão pela Convergência: WorldEventManager.
## Nada aqui distingue humano de IA como regra; só a ESCOLHA da recompensa pergunta a quem controla o assento.

const EVENT_TYPE := "reliquary"
const NO_COORD := Vector2i(999999, 999999)
const PREPARATION_ROUNDS := 5
const CONTROL_ROUNDS_REQUIRED := 2
const GUARDIAN_KIND := "skeleton"
const GUARDIAN_COUNT := 3
## Recompensa: o vencedor escolhe UMA. PROVISÓRIAS (F33E calibra). Nunca Conhecimento.
const REWARD_GOLD := 90.0
const REWARD_MANA := 60.0
const CHOICE_GOLD := "gold"
const CHOICE_MANA := "mana"
## Vencedor controlado por pessoa: rodadas para escolher antes de o padrão (Ouro) ser aplicado — a escolha
## nunca bloqueia o fim de turno.
const REWARD_CHOICE_ROUNDS := 3
## Rodadas de disputa depois que os guardiões se erguem; sem vencedor, o Relicário se apaga (os guardiões dele
## somem com ele). Garante que o Relicário nunca ocupe a janela de garantia do Dragão (WorldEventManager).
const ACTIVE_ROUNDS_LIMIT := 10
const MAX_DURATION := PREPARATION_ROUNDS + ACTIVE_ROUNDS_LIMIT + REWARD_CHOICE_ROUNDS
## Local: longe de qualquer cidade (nunca no interior imediato de um reino) e das áreas de covis.
const SITE_MIN_CITY_DISTANCE := 6
const SITE_MAX_CITY_DISTANCE := 22
const SITE_LAIR_CLEARANCE := 3
const SITE_RNG_SALT := 8200

var site_coord: Vector2i = NO_COORD
var control_owner: int = -1
var control_rounds: int = 0
var max_control_rounds: int = 0
var contested_rounds: int = 0
var guardians_cleared_turn: int = -1
var winner_index: int = -1
var reward_choice: String = ""
var choice_deadline: int = -1
var _marker: Node3D = null

func _init() -> void:
	event_type = EVENT_TYPE

func display_name() -> String:
	return "Relicário Desperto"

func public_summary() -> String:
	return "Um Relicário antigo despertou. Em %d rodadas seus guardiões se erguem; o reino que controlar o local por %d rodadas seguidas o reivindica." % [PREPARATION_ROUNDS, CONTROL_ROUNDS_REQUIRED]

func is_open() -> bool:
	return phase in [WorldEvent.PHASE_DORMANT, WorldEvent.PHASE_ANNOUNCED, WorldEvent.PHASE_ACTIVE]

func awaiting_choice_from(player_index: int) -> bool:
	return phase == WorldEvent.PHASE_RESOLUTION and winner_index == player_index and reward_choice == ""

func advance_turn(hex_grid: HexGrid, players: Array[PlayerData]) -> void:
	var turn := TurnManager.turn_number
	match phase:
		WorldEvent.PHASE_DORMANT:
			phase = WorldEvent.PHASE_ANNOUNCED
			turn_started = turn
			turn_deadline = turn + PREPARATION_ROUNDS
			_build_marker(hex_grid)
		WorldEvent.PHASE_ANNOUNCED:
			if turn >= turn_deadline:
				_spawn_guardians(hex_grid)
				phase = WorldEvent.PHASE_ACTIVE
				turn_deadline = turn + ACTIVE_ROUNDS_LIMIT
		WorldEvent.PHASE_ACTIVE:
			evaluate_control(hex_grid, players, turn)
			if phase == WorldEvent.PHASE_ACTIVE and turn >= turn_deadline:
				_expire(hex_grid, turn)
		WorldEvent.PHASE_RESOLUTION:
			if reward_choice == "" and turn >= choice_deadline:
				apply_reward(players, CHOICE_GOLD)
			if reward_choice != "":
				_remove_marker()
				phase = WorldEvent.PHASE_COMPLETED

## Uma avaliação por rodada global. Progresso só sem guardião vivo do evento; controlador = dono da unidade
## no tile do Relicário; unidade HOSTIL adjacente (monstro ou civ em guerra com ele) contesta e zera; a mesma
## civ precisa de CONTROL_ROUNDS_REQUIRED rodadas consecutivas (mais unidades não aceleram); troca de
## controlador zera o anterior e o novo começa em 1.
func evaluate_control(hex_grid: HexGrid, players: Array[PlayerData], turn: int) -> void:
	if live_guardian_count(hex_grid) > 0:
		control_owner = -1
		control_rounds = 0
		return
	if guardians_cleared_turn < 0:
		guardians_cleared_turn = turn
	var occupant := hex_grid.get_unit_at(site_coord)
	var controller := players.find(occupant.owner_player) if occupant != null and occupant.owner_player != null and not occupant.embarked else -1
	if controller < 0:
		control_owner = -1
		control_rounds = 0
		return
	if _hostile_adjacent(hex_grid, players[controller]):
		contested_rounds += 1
		control_owner = -1
		control_rounds = 0
		return
	if controller == control_owner:
		control_rounds += 1
	else:
		control_owner = controller
		control_rounds = 1
	max_control_rounds = maxi(max_control_rounds, control_rounds)
	if control_rounds >= CONTROL_ROUNDS_REQUIRED:
		_resolve_winner(controller, players, turn)

func _expire(hex_grid: HexGrid, turn: int) -> void:
	for unit in hex_grid.units_by_coord.values().duplicate():
		if unit.owner_player == null and unit.source_event_id == event_id:
			hex_grid.remove_unit(unit)
	result = {"outcome": "expired", "winner_index": -1, "resolved_turn": turn, "rewards_applied": true}
	_remove_marker()
	phase = WorldEvent.PHASE_COMPLETED

func _hostile_adjacent(hex_grid: HexGrid, controller: PlayerData) -> bool:
	for neighbor in hex_grid.get_neighbors(site_coord):
		var unit := hex_grid.get_unit_at(neighbor)
		if unit == null or unit.owner_player == controller:
			continue
		if unit.owner_player == null or controller.is_at_war_with(unit.owner_player):
			return true
	return false

func _resolve_winner(index: int, players: Array[PlayerData], turn: int) -> void:
	winner_index = index
	result = {"outcome": "claimed", "winner_index": index, "resolved_turn": turn}
	phase = WorldEvent.PHASE_RESOLUTION
	var winner: PlayerData = players[index]
	if GameManager.is_human_controlled(winner):
		choice_deadline = turn + REWARD_CHOICE_ROUNDS
	else:
		apply_reward(players, ai_reward_choice(winner))

## IA escolhe só pelo PRÓPRIO estado: Mana para a orientação Arcana ou com Mana abaixo da reserva dos
## próprios planos (V2StrategicAI.strategic_mana_reserve); senão Ouro.
static func ai_reward_choice(player: PlayerData) -> String:
	if player.v2_ai_strategy.orientation == V2AIStrategyState.Orientation.ARCANE or player.mana < V2StrategicAI.strategic_mana_reserve(player):
		return CHOICE_MANA
	return CHOICE_GOLD

## Aplica a recompensa EXATAMENTE uma vez (result.rewards_applied sobrevive ao save/load).
func apply_reward(players: Array[PlayerData], choice: String) -> bool:
	if bool(result.get("rewards_applied", false)) or winner_index < 0 or winner_index >= players.size():
		return false
	choice = CHOICE_MANA if choice == CHOICE_MANA else CHOICE_GOLD
	var winner: PlayerData = players[winner_index]
	if choice == CHOICE_MANA:
		winner.mana += REWARD_MANA
	else:
		winner.gold += REWARD_GOLD
	reward_choice = choice
	result["rewards_applied"] = true
	result["reward"] = {"choice": choice, "amount": REWARD_MANA if choice == CHOICE_MANA else REWARD_GOLD}
	return true

func live_guardian_count(hex_grid: HexGrid) -> int:
	var count := 0
	for unit in hex_grid.units_by_coord.values():
		if unit.owner_player == null and unit.source_event_id == event_id:
			count += 1
	return count

func _spawn_guardians(hex_grid: HexGrid) -> void:
	var tiles: Array[Vector2i] = [site_coord]
	tiles.append_array(RegionalThreatPlanner._sorted(hex_grid.get_neighbors(site_coord)))
	var spawned := 0
	for coord in tiles:
		if spawned >= GUARDIAN_COUNT:
			break
		var tile := hex_grid.get_tile(coord)
		if tile == null or tile.blocks_land_units() or hex_grid.get_unit_at(coord) != null or hex_grid.get_city_at(coord) != null or hex_grid.lairs_by_coord.has(coord):
			continue
		var guardian := hex_grid.spawn_monster_at(coord, GUARDIAN_KIND)
		guardian.source_event_id = event_id
		spawned += 1

## Local do Relicário (anúncio): continente Principal, terra livre (sem cidade, território, covil e área de
## covil, construção, melhoria, unidade), a SITE_MIN..SITE_MAX de cidades, no componente terrestre de pelo
## menos DUAS civilizações ativas. Fairness: minimiza |dist(A) − dist(B)| entre as duas civs ativas mais
## próximas (dist = cidade mais próxima de cada uma), depois a distância média, desempate pelo RNG dedicado.
static func choose_site(hex_grid: HexGrid, players: Array[PlayerData]) -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = hex_grid.map_seed + SITE_RNG_SALT
	hex_grid._ensure_land_components()
	var active: Array[PlayerData] = []
	for player in players:
		if not player.cities.is_empty():
			active.append(player)
	if active.size() < 2:
		return NO_COORD
	var best := NO_COORD
	var best_key: Array = []
	for coord in RegionalThreatPlanner._sorted(hex_grid.tiles.keys()):
		if not is_valid_site(hex_grid, coord):
			continue
		var component: int = hex_grid._land_components.get(coord, -1)
		var distances: Array = []
		for player in active:
			var nearest := 999999
			var reachable := false
			for city in player.cities:
				nearest = mini(nearest, HexMetrics.axial_distance(city.coord, coord))
				reachable = reachable or hex_grid._land_components.get(city.coord, -2) == component
			if reachable:
				distances.append(nearest)
		if distances.size() < 2:
			continue
		distances.sort()
		var closest := int(distances[0])
		if closest < SITE_MIN_CITY_DISTANCE or closest > SITE_MAX_CITY_DISTANCE:
			continue
		var key := [absi(int(distances[1]) - closest), int(distances[1]) + closest, rng.randf()]
		if best_key.is_empty() or _key_less(key, best_key):
			best_key = key
			best = coord
	return best

static func is_valid_site(hex_grid: HexGrid, coord: Vector2i) -> bool:
	var tile := hex_grid.get_tile(coord)
	if tile == null or tile.blocks_land_units() or hex_grid._zone_for(coord) != HexGrid._Zone.MAIN:
		return false
	if hex_grid.get_city_at(coord) != null or hex_grid.city_owning_tile(coord) != null or hex_grid.get_unit_at(coord) != null:
		return false
	if hex_grid.buildings_by_coord.has(coord) or hex_grid.lairs_by_coord.has(coord):
		return false
	for city in hex_grid.cities_by_coord.values():
		if (city as City).resource_improvements.has(coord):
			return false
	for lair in hex_grid.lair_coords:
		if HexMetrics.axial_distance(lair, coord) <= SITE_LAIR_CLEARANCE:
			return false
	return true

static func _key_less(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] < b[i]
	return false

# --- Marcador público (visual, nunca salvo; reconstruído no load) -------------------------------

func _build_marker(hex_grid: HexGrid) -> void:
	if hex_grid == null or site_coord == NO_COORD or (_marker != null and is_instance_valid(_marker)):
		return
	var marker := MeshInstance3D.new()
	marker.name = "ReliquaryMarker"
	# Fase 33D-R: HexGrid._clear_entities (novo jogo, load, volta ao menu) remove este grupo — o evento é
	# descartado no reset sem passar por _remove_marker, e o pilar não pode sobreviver à partida seguinte.
	marker.add_to_group(HexGrid.WORLD_EVENT_MARKER_GROUP)
	var mesh := CylinderMesh.new()
	mesh.top_radius = hex_grid.hex_size * 0.18
	mesh.bottom_radius = hex_grid.hex_size * 0.3
	mesh.height = hex_grid.hex_size * 1.1
	marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.8, 0.35)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.75, 0.25)
	material.emission_energy_multiplier = 1.4
	marker.material_override = material
	hex_grid.add_child(marker)
	var tile := hex_grid.get_tile(site_coord)
	marker.position = HexMetrics.axial_to_world(site_coord.x, site_coord.y, hex_grid.hex_size) + Vector3(0.0, (tile.base_height if tile != null else 0.0) + mesh.height * 0.5, 0.0)
	_marker = marker

func _remove_marker() -> void:
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null

func relink(hex_grid: HexGrid) -> void:
	if phase in [WorldEvent.PHASE_ANNOUNCED, WorldEvent.PHASE_ACTIVE, WorldEvent.PHASE_RESOLUTION]:
		_build_marker(hex_grid)

# --- Save ---------------------------------------------------------------------------------------

func to_save_dict() -> Dictionary:
	var data := super.to_save_dict()
	data["site_coord"] = [site_coord.x, site_coord.y]
	data["control_owner"] = control_owner
	data["control_rounds"] = control_rounds
	data["max_control_rounds"] = max_control_rounds
	data["contested_rounds"] = contested_rounds
	data["guardians_cleared_turn"] = guardians_cleared_turn
	data["winner_index"] = winner_index
	data["reward_choice"] = reward_choice
	data["choice_deadline"] = choice_deadline
	return data

func from_save_dict(data: Dictionary) -> void:
	super.from_save_dict(data)
	var site: Variant = data.get("site_coord", [])
	site_coord = Vector2i(int(site[0]), int(site[1])) if typeof(site) == TYPE_ARRAY and site.size() >= 2 else NO_COORD
	control_owner = int(data.get("control_owner", -1))
	control_rounds = int(data.get("control_rounds", 0))
	max_control_rounds = int(data.get("max_control_rounds", 0))
	contested_rounds = int(data.get("contested_rounds", 0))
	guardians_cleared_turn = int(data.get("guardians_cleared_turn", -1))
	winner_index = int(data.get("winner_index", -1))
	reward_choice = String(data.get("reward_choice", ""))
	choice_deadline = int(data.get("choice_deadline", -1))
