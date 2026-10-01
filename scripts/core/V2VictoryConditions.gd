class_name V2VictoryConditions
extends RefCounted

## Aetherlands V2, Fase 16 — fundação GENÉRICA das vitórias V2 (a Transcendência futura mora aqui
## também). Tudo DERIVADO a cada chamada (nada de "2/3" salvo): acesso vem da pesquisa, o crédito
## territorial vem de City.v2_supremacy_captured_from das cidades que o jogador POSSUI agora, e a
## eliminação usa a MESMA definição da Dominação (VictoryConditions: sem unidades e sem cidades —
## um Colonizador vivo mantém a civilização viva). A Fase 23 acrescenta a Transcendência pelo Ritual
## Final. Fase 25: as vitórias V1/V1.5 (Territorial, Arcana, VictoryCampaign) foram removidas; a ordem
## de avaliação é Dominação -> Supremacia Militar -> Transcendência (GameManager.check_victories).

const VICTORY_TYPE_MILITARY_SUPREMACY := "v2_military_supremacy"
const MILITARY_SUPREMACY_ACCESS := "v2_military_supremacy_access"
const VICTORY_TYPE_TRANSCENDENCE := "v2_transcendence"
const TRANSCENDENCE_ACCESS := "v2_transcendence_access"

const REASON_CAPTURED := "captured_developed_city"
const REASON_ELIMINATED := "eliminated"
const REASON_PENDING := "pending"

## Civilizações MAJOR da partida (humano + rivais normais; monstros/neutros nunca estão aqui).
static func major_players() -> Array[PlayerData]:
	return GameManager.players

## Id estável de um jogador: o índice em GameManager.players (a ordem que o save preserva — a mesma
## identidade de City.original_owner_index). -1 se não for um jogador major.
static func stable_id(player: PlayerData) -> int:
	return major_players().find(player)

static func is_eliminated(player: PlayerData) -> bool:
	return player.units.is_empty() and player.cities.is_empty()

## Fase 33D3 — REGRA TERRITORIAL DA SUPREMACIA (fonte canônica). Uma captura de cidade de `owner` qualifica
## quando, NO INSTANTE DA CAPTURA, o City Level dela é igual ao MAIOR City Level que `owner` possui (a própria
## cidade incluída). Empate: todas as empatadas qualificam; a capital nunca é a única válida. Um rival só de
## Cidades I é satisfeito capturando qualquer uma delas. O crédito é gravado na cidade
## (City.v2_supremacy_captured_from, em HexGrid.capture_city) e nunca reavaliado depois: o rival desenvolver
## outra cidade mais tarde não invalida uma captura já feita.
## Semântica de posse PRESERVADA da Fase 16: o rival conta como satisfeito enquanto o jogador MANTÉM uma
## cidade com o crédito; perdê-la (inclusive recaptura) remove o crédito — a cidade recapturada recebe o
## crédito do novo captor só se ela qualificar pela mesma regra naquele instante; eliminação satisfaz.
static func max_city_level(player: PlayerData, including: City = null) -> int:
	var best := 0
	if player != null:
		for city in player.cities:
			best = maxi(best, int(city.city_level))
	if including != null:
		best = maxi(best, int(including.city_level))
	return best

static func is_supremacy_qualifying_city(city: City, owner: PlayerData) -> bool:
	if city == null or owner == null or stable_id(owner) < 0:
		return false
	return int(city.city_level) >= max_city_level(owner, city)

## Capital pública de uma civilização: a primeira cidade que ela mesma fundou e ainda possui.
static func capital_of(player: PlayerData) -> City:
	if player == null:
		return null
	var index := stable_id(player)
	for city in player.cities:
		if city.original_owner_index == index:
			return city
	return null

## Alvos de Supremacia SUGERIDOS a `player` contra `rival` — só cidades que `player` CONHECE, com o nível
## que ele OBSERVOU (PlayerData.known_enemy_city_levels). Nunca a lista real do rival: uma cidade escondida
## mais desenvolvida não aparece. Ordem: maior nível conhecido, capital conhecida, mais perto do núcleo do
## jogador, coordenada. {coord, name, level, capital}.
static func known_supremacy_targets(player: PlayerData, rival: PlayerData, grid: HexGrid = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	grid = GameManager.hex_grid if grid == null else grid
	if player == null or rival == null or grid == null:
		return result
	var capital := capital_of(rival)
	var home := capital_of(player)
	var anchor: Vector2i = home.coord if home != null else (player.cities[0].coord if not player.cities.is_empty() else Vector2i.ZERO)
	for coord in player.known_enemy_cities:
		var city: City = grid.get_city_at(coord)
		if city == null or city.owner_player != rival:
			continue
		result.append({"coord": coord, "name": city.city_name, "level": int(player.known_enemy_city_levels.get(coord, 0)), "capital": city == capital, "distance": HexMetrics.axial_distance(anchor, coord)})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.level) != int(b.level):
			return int(a.level) > int(b.level)
		if bool(a.capital) != bool(b.capital):
			return bool(a.capital)
		if int(a.distance) != int(b.distance):
			return int(a.distance) < int(b.distance)
		return a.coord.x < b.coord.x if a.coord.x != b.coord.x else a.coord.y < b.coord.y)
	return result

## `player` mantém agora alguma cidade conquistada QUALIFICADA (regra acima, no momento da captura)
## de `rival`?
static func rival_satisfied_by_conquest(player: PlayerData, rival: PlayerData) -> bool:
	var rival_id := stable_id(rival)
	if player == null or rival_id < 0:
		return false
	for city in player.cities:
		if city.v2_supremacy_captured_from == rival_id:
			return true
	return false

## {access, rival_count, satisfied_count, rivals: [{player_id, name, satisfied, reason}]} — a UI só
## formata isto, nunca reimplementa a regra.
static func military_supremacy_status(player: PlayerData) -> Dictionary:
	var rivals: Array = []
	var satisfied := 0
	for other in major_players():
		if other == player:
			continue
		var reason := REASON_PENDING
		if is_eliminated(other):
			reason = REASON_ELIMINATED
		elif rival_satisfied_by_conquest(player, other):
			reason = REASON_CAPTURED
		var ok := reason != REASON_PENDING
		if ok:
			satisfied += 1
		rivals.append({"player_id": stable_id(other), "name": other.civ.civ_name if other.civ else "", "satisfied": ok, "reason": reason})
	return {
		"access": player != null and player.has_unlocked(MILITARY_SUPREMACY_ACCESS),
		"rival_count": rivals.size(),
		"satisfied_count": satisfied,
		"rivals": rivals,
	}

## Vitória só com o acesso (Exército Supremo), pelo menos um rival major (nunca verdade vazia) e
## todos satisfeitos.
static func military_supremacy_achieved(player: PlayerData) -> bool:
	if player == null or stable_id(player) < 0:
		return false
	var status := military_supremacy_status(player)
	return status.access and status.rival_count > 0 and status.satisfied_count == status.rival_count

## Linhas curtas pra tooltip/rodapé do Exército Supremo.
static func military_supremacy_lines(player: PlayerData) -> Array[String]:
	var status := military_supremacy_status(player)
	var lines: Array[String] = ["Supremacia Militar: %d / %d rivais satisfeitos" % [status.satisfied_count, status.rival_count]]
	for rival in status.rivals:
		var label := "Pendente"
		if rival.reason == REASON_CAPTURED:
			label = "Conquista mantida"
		elif rival.reason == REASON_ELIMINATED:
			label = "Eliminado"
		lines.append("%s — %s" % [rival.name, label])
	return lines

## Contraparte mágica: V2TranscendenceSystem é a fonte da condição temporal;
## esta classe mantém a interface única consumida pelo GameManager/UI.
static func transcendence_achieved(player: PlayerData) -> bool:
	return player != null and stable_id(player) >= 0 and V2TranscendenceSystem.victory_ready(player)

static func transcendence_status(player: PlayerData) -> Dictionary:
	var active := V2TranscendenceSystem.has_active_ritual(player)
	var count := V2TranscendenceSystem.active_manifestation_count(player)
	return {
		"access": player != null and player.has_unlocked(TRANSCENDENCE_ACCESS),
		"active": active,
		"manifestation_count": count,
		"manifestation_required": V2TranscendenceSystem.MANIFESTATIONS_REQUIRED,
		"site_coord": V2TranscendenceSystem.ritual_site_coord(player),
		"remaining_rounds": V2TranscendenceSystem.ritual_rounds_remaining(player),
		"ready": transcendence_achieved(player),
	}

static func transcendence_lines(player: PlayerData) -> Array[String]:
	var status := transcendence_status(player)
	var shown := mini(status.manifestation_count, status.manifestation_required)
	var lines: Array[String] = ["Grandes Manifestações ativas: %d / %d" % [shown, status.manifestation_required]]
	if status.active:
		lines.append("Ritual Final: %d rodada(s) restante(s)" % status.remaining_rounds)
	else:
		lines.append("Ritual Final: não iniciado")
	return lines
