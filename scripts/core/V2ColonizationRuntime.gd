class_name V2ColonizationRuntime
extends RefCounted

## Limite de Colonos treinados na partida (linha de Infraestrutura "Colonização", V2ColonizationData). Mesmo molde
## do slot de Unidade Lendária (V2LegendarySystem): checagem ao INICIAR a produção, reserva pelas ordens de produção
## de OUTRAS cidades e recusa fail-closed no nascimento — sem estado paralelo além do contador da civilização.
##
## O LIMITE é derivado da pesquisa (maior nível concluído da linha); o USO é `PlayerData.settlers_trained` (Colonos que
## já nasceram de produção — persistido no save) + cidades que estão produzindo um Colono agora. O Colono inicial da
## partida não passa por produção e nunca conta. Reconhecimento por DADO: Colono = `UnitData.can_found_city`, nunca
## o id "settler" no código.

const REASON_NEEDS_RESEARCH := "Requer pesquisa: %s (linha de Colonização)."
const REASON_LIMIT_REACHED := "Limite de Colonos atingido (%d/%d). Pesquise %s para treinar mais."

static var _settler_kinds: Dictionary = {} # kind -> bool (cache: create_unit é caro para checar a cada refresh)

## `kind` (id de produção) é um Colono? Por dado (`can_found_city`), em cache.
static func is_settler_kind(kind: String) -> bool:
	if kind == "":
		return false
	if not _settler_kinds.has(kind):
		_settler_kinds[kind] = UnitDatabase.create_unit(kind).can_found_city if UnitDatabase.is_known_kind(kind) else false
	return _settler_kinds[kind]

## Limite atual: 0 sem pesquisa, o valor do maior nível concluído, ou V2ColonizationData.UNLIMITED.
static func settler_limit(player) -> int:
	if player == null:
		return 0
	var best := 0
	for unlock_id in V2ColonizationData.SETTLER_LIMIT_BY_UNLOCK:
		if not V2UnlockSystem.is_unlocked(player, unlock_id):
			continue
		var limit: int = V2ColonizationData.SETTLER_LIMIT_BY_UNLOCK[unlock_id]
		if limit == V2ColonizationData.UNLIMITED:
			return V2ColonizationData.UNLIMITED
		best = maxi(best, limit)
	return best

## Cidades da civilização produzindo um Colono agora (menos `excluding`: a cidade que pergunta não conta contra si).
static func settlers_in_production(player, excluding: City = null) -> int:
	if player == null:
		return 0
	var count := 0
	for city in player.cities:
		if city != excluding and is_instance_valid(city) and is_settler_kind(city.production_item):
			count += 1
	return count

## Colonos já treinados + reservados por produção em outras cidades.
static func settlers_used(player, excluding_city: City = null) -> int:
	return (int(player.settlers_trained) if player != null else 0) + settlers_in_production(player, excluding_city)

## "" se `city` pode INICIAR um Colono agora, senão o motivo. Para kind que não é Colono: "" (nada a dizer aqui).
static func training_unavailable_reason(player, city: City, kind: String) -> String:
	if not is_settler_kind(kind):
		return ""
	var limit := settler_limit(player)
	if limit == V2ColonizationData.UNLIMITED:
		return ""
	if limit == 0:
		return REASON_NEEDS_RESEARCH % _node_name_for_next_limit(0)
	var used := settlers_used(player, city)
	if used >= limit:
		return REASON_LIMIT_REACHED % [mini(used, limit), limit, _node_name_for_next_limit(limit)]
	return ""

static func can_start_settler(player, city: City, kind: String) -> bool:
	return training_unavailable_reason(player, city, kind) == ""

## Mesmo contrato dos outros `training_soft_reason` (Logística, Manifestação): a HUD mostra o Colono DESABILITADO
## com este motivo, em vez de escondê-lo sem explicar.
static func training_soft_reason(player, city: City, kind: String) -> String:
	return training_unavailable_reason(player, city, kind)

## Conclusão (fail-closed): o Colono só nasce se, contando os já treinados, o limite ainda comporta mais um.
static func spawn_allowed(player, kind: String) -> bool:
	if not is_settler_kind(kind):
		return true
	var limit := settler_limit(player)
	return limit == V2ColonizationData.UNLIMITED or int(player.settlers_trained) < limit

## Registra um Colono nascido de produção (único ponto que incrementa o contador).
static func record_trained(player, kind: String) -> void:
	if player != null and is_settler_kind(kind):
		player.settlers_trained += 1

## Recusa o nascimento: devolve o custo à cidade (nada se perde) e avisa o humano.
static func refuse_spawn(city: City, kind: String, notify_human: bool) -> void:
	city.stored_production += UnitDatabase.create_unit(kind).production_cost
	push_warning("V2ColonizationRuntime: '%s' não nasceu em %s — limite de Colonos atingido." % [kind, city.city_name])
	if notify_human:
		EventBus.notify.emit("Colono não concluído em %s: limite de Colonos atingido." % city.city_name, "")

## Nome do nó que eleva o limite atual (o próximo nível da linha), para o motivo player-facing.
static func _node_name_for_next_limit(current_limit: int) -> String:
	var best_id := ""
	var best_limit := 1 << 30
	for unlock_id in V2ColonizationData.SETTLER_LIMIT_BY_UNLOCK:
		var limit: int = V2ColonizationData.SETTLER_LIMIT_BY_UNLOCK[unlock_id]
		var effective := (1 << 29) if limit == V2ColonizationData.UNLIMITED else limit
		if effective > current_limit and effective < best_limit:
			best_limit = effective
			best_id = unlock_id
	var node := V2ResearchDatabase.node_for_unlock_id(best_id)
	return node.display_name if node != null else best_id
