class_name V2ResearchState
extends RefCounted

## Estado de pesquisa V2 de UMA civilização (Fase 1 — runtime de pesquisa).
##
## V2ResearchDatabase diz O QUE EXISTE (estático, compartilhado); esta classe diz
## O QUE UMA CIVILIZAÇÃO PESQUISOU. Cada PlayerData tem a sua (`player.v2_research`),
## humana ou rival — a IA de uma fase futura usa exatamente a mesma API. Nada aqui
## conhece HUD, TurnManager ou GameManager: é um RefCounted puro, testável sem cena.
##
## REGRA CENTRAL: um ÚNICO projeto ativo por civilização (`active_id`). Doutrina,
## Magia e Infraestrutura competem pelo mesmo slot. Trocar de projeto NÃO perde
## progresso: cada nó guarda o seu em `progress_by_id`, entre árvores inclusive.
##
## CONHECIMENTO: a economia de Conhecimento ainda não existe. A única entrada é
## add_knowledge(amount) — Academias, debug ou qualquer sistema futuro alimentam
## por ela. Sem projeto ativo, o valor NÃO se perde: fica em `research_overflow` e
## é aplicado ao próximo projeto escolhido. Ao concluir, o excedente também vai pro
## overflow e NENHUM projeto novo é escolhido sozinho.
##
## FASE 1 NÃO TEM EFEITO DE GAMEPLAY: concluir um nó só o registra em
## `completed_ids` e emite `research_completed`. `unlock_type`/`unlock_id` seguem
## metadata. Fases futuras aplicam unidades/prédios/feitiços conectando-se a esse
## sinal — é o ponto de integração (sem polling).
##
## Fase 25: este é o ÚNICO estado de pesquisa do jogo (a pesquisa V1 e a Ciência
## foram removidas; saves antigos com pesquisa V1 carregam sem convertê-la).

## Um projeto passou a ser o ativo (`previous_id` = "" se não havia).
signal research_selected(id: String, previous_id: String)
## O projeto ativo foi pausado (progresso mantido).
signal research_cancelled(id: String)
## Progresso de um projeto mudou SEM concluí-lo (conclusão emite só research_completed).
signal research_progress_changed(id: String, progress: float, cost: float)
## Nó concluído. Ponto de integração dos unlocks futuros.
signal research_completed(id: String)
## O conjunto de nós selecionáveis mudou (emitido após research_completed, com os
## ids que passaram a estar disponíveis — pode ser vazio).
signal research_availability_changed(newly_available: Array)
## O Conhecimento guardado (sem projeto ativo) mudou.
signal research_overflow_changed(amount: float)
## O estado inteiro foi substituído (reset ou load).
signal state_reset

var active_id: String = ""
## id -> true. Set (não Array) pra consulta O(1); ver get_completed_ids().
var completed_ids: Dictionary = {}
## id -> float, só de nós NÃO concluídos com progresso > 0 (inclui o ativo).
var progress_by_id: Dictionary = {}
var research_overflow: float = 0.0

# --- Acesso por civilização ------------------------------------------------------

## O estado da civilização `player` (PlayerData). Sem tipagem no parâmetro de
## propósito: evita dependência cíclica de tipos com PlayerData.
static func for_player(player) -> V2ResearchState:
	return player.v2_research if player != null else null

## Estado da civilização de índice `index` em GameManager.players (a mesma ordem
## de TurnManager.current_player_index). null se o índice não existe.
static func for_index(index: int) -> V2ResearchState:
	if index < 0 or index >= GameManager.players.size():
		return null
	return for_player(GameManager.players[index])

# --- Consultas ---------------------------------------------------------------------

func is_completed(id: String) -> bool:
	return completed_ids.has(id)

## Pesquisável agora? (nó existente, não concluído, pré-requisitos e capstone ok.)
## Vale também para o projeto ativo.
func is_available(id: String) -> bool:
	return V2ResearchDatabase.is_available(id, completed_ids)

func can_research(id: String) -> bool:
	return is_available(id)

## "" se pode pesquisar; senão a razão em uma frase (pra UI/tooltip).
func unavailable_reason(id: String) -> String:
	return V2ResearchDatabase.unavailable_reason(id, completed_ids)

func get_progress(id: String) -> float:
	return float(progress_by_id.get(id, 0.0))

## 0.0–1.0. Concluído = 1.0; id inexistente = 0.0.
func get_progress_ratio(id: String) -> float:
	if completed_ids.has(id):
		return 1.0
	var node := V2ResearchDatabase.get_node(id)
	if node == null or node.cost <= 0.0:
		return 0.0
	return clampf(get_progress(id) / node.cost, 0.0, 1.0)

func get_completed_ids() -> Array[String]:
	var result: Array[String] = []
	for id in completed_ids:
		result.append(id)
	result.sort()
	return result

func node_state(id: String) -> int:
	return V2ResearchDatabase.node_state(id, completed_ids, active_id, progress_by_id)

## Texto de estado pra tooltip/rodapé: "Estado: …", "Progresso: 31 / 50 (62%)" e,
## se bloqueado e `include_reason`, por quê.
func status_text(id: String, include_reason: bool = true) -> String:
	var node := V2ResearchDatabase.get_node(id)
	if node == null:
		return ""
	var state := node_state(id)
	var lines: Array[String] = ["Estado: %s" % V2ResearchDatabase.state_label(state)]
	if state == V2ResearchDatabase.NodeState.RESEARCHING or state == V2ResearchDatabase.NodeState.PARTIAL:
		lines.append("Progresso: %s / %s (%d%%)" % [format_amount(get_progress(id)), format_amount(node.cost), int(round(get_progress_ratio(id) * 100.0))])
	elif state == V2ResearchDatabase.NodeState.LOCKED and include_reason:
		lines.append(unavailable_reason(id))
	return "\n".join(lines)

# --- Ações --------------------------------------------------------------------------

## Torna `id` o projeto ativo (o anterior mantém o progresso). Falha SEM alterar
## nada se o id não existe, já foi concluído ou está bloqueado. Aplica na hora o
## Conhecimento guardado em `research_overflow`.
func select_research(id: String) -> bool:
	if not can_research(id):
		return false
	if id == active_id:
		return true
	var previous := active_id
	active_id = id
	research_selected.emit(id, previous)
	_apply_banked_knowledge()
	return true

## Pausa o projeto ativo. O progresso fica guardado; ficar sem projeto é válido.
func cancel_active_research() -> void:
	if active_id == "":
		return
	var previous := active_id
	active_id = ""
	research_cancelled.emit(previous)

## Única entrada de Conhecimento. Valores não positivos/inválidos são ignorados.
## Com projeto ativo soma nele; sem projeto, guarda em `research_overflow`.
func add_knowledge(amount: float) -> void:
	if not is_finite(amount) or amount <= 0.0:
		return
	if active_id == "":
		research_overflow += amount
		research_overflow_changed.emit(research_overflow)
	else:
		_advance(amount)

## Conclui `id` na hora (sem gastar Conhecimento). Só se estiver disponível —
## nunca deixa o estado incoerente (ex.: N5 sem N4). Concluir o ativo o limpa.
func complete_research(id: String) -> bool:
	if not can_research(id):
		return false
	_finish(id, 0.0)
	return true

## Volta ao estado vazio (ferramenta de desenvolvimento e testes).
func reset() -> void:
	_clear()
	state_reset.emit()

## DEBUG: conclui, em ordem, todos os níveis ainda pendentes de uma linha. Devolve
## quantos concluiu. Para no primeiro que não estiver disponível.
func debug_complete_branch(tree_type: int, branch: String) -> int:
	var done := 0
	for node in V2ResearchDatabase.nodes_for_branch(tree_type, branch):
		if completed_ids.has(node.id):
			continue
		if not complete_research(node.id):
			break
		done += 1
	return done

## DEBUG: conclui o projeto ativo na hora.
func debug_complete_active() -> bool:
	return active_id != "" and complete_research(active_id)

# --- Núcleo interno -------------------------------------------------------------------

func _apply_banked_knowledge() -> void:
	var banked := research_overflow
	research_overflow = 0.0
	if banked > 0.0:
		research_overflow_changed.emit(0.0)
	# Também "assenta" um nó cujo progresso guardado já está no custo (save antigo/editado).
	_advance(banked)

## Soma `amount` ao projeto ativo (pré-condição: active_id != ""). Atingiu o custo
## -> conclui; o excedente vai pro overflow e nenhum projeto novo é escolhido.
func _advance(amount: float) -> void:
	var node := V2ResearchDatabase.get_node(active_id)
	var total := get_progress(active_id) + amount
	if total >= node.cost:
		_finish(active_id, total - node.cost)
	elif amount > 0.0:
		progress_by_id[active_id] = total
		research_progress_changed.emit(active_id, total, node.cost)

## Registra a conclusão. Tudo é atualizado ANTES de emitir, então quem escuta vê o
## estado final; a lista de "novos disponíveis" é a diferença antes/depois.
func _finish(id: String, excess: float) -> void:
	var before := _available_set()
	completed_ids[id] = true
	progress_by_id.erase(id)
	if active_id == id:
		active_id = ""
	if excess > 0.0:
		research_overflow += excess
	var newly: Array = []
	for candidate in _available_set():
		if not before.has(candidate):
			newly.append(candidate)
	research_completed.emit(id)
	research_availability_changed.emit(newly)
	if excess > 0.0:
		research_overflow_changed.emit(research_overflow)

func _available_set() -> Dictionary:
	var result := {}
	for node in V2ResearchDatabase.all_nodes():
		if V2ResearchDatabase.is_available(node.id, completed_ids):
			result[node.id] = true
	return result

func _clear() -> void:
	active_id = ""
	completed_ids = {}
	progress_by_id = {}
	research_overflow = 0.0

## "31" ou "7.5": inteiro sem casas, senão uma casa decimal (texto de UI).
static func format_amount(value: float) -> String:
	return "%d" % int(round(value)) if is_equal_approx(value, round(value)) else "%.1f" % value

# --- Persistência ------------------------------------------------------------------------

## Formato do save (JSON-friendly), por civilização.
func to_dict() -> Dictionary:
	return {
		"active_id": active_id,
		"completed_ids": get_completed_ids(),
		"progress_by_id": progress_by_id.duplicate(),
		"research_overflow": research_overflow,
	}

## Substitui o estado NO LUGAR (quem escuta sinais continua conectado) a partir de
## `data` — que pode ser QUALQUER coisa (save antigo sem o bloco, tipos errados,
## ids que não existem mais). Nunca falha: o que não é confiável vira estado vazio.
##  - ids inexistentes são ignorados;
##  - progresso é limitado a [0, custo] e só vale pra nó existente e não concluído;
##  - Conhecimento guardado negativo/inválido vira 0;
##  - `active_id` só vale se existir, não estiver concluído e estiver disponível;
##  - com projeto ativo o Conhecimento guardado é aplicado a ele (invariante: só
##    existe overflow sem projeto ativo) e um ativo já no custo é concluído.
## Os pré-requisitos dos concluídos NÃO são "consertados": não destruir progresso
## por causa de uma mudança futura de estrutura.
func load_dict(data: Variant) -> void:
	set_block_signals(true)
	_clear()
	if typeof(data) == TYPE_DICTIONARY:
		_read_completed(data.get("completed_ids"))
		_read_progress(data.get("progress_by_id"))
		_read_overflow(data.get("research_overflow"))
		_read_active(data.get("active_id"))
	if active_id != "":
		_apply_banked_knowledge()
	set_block_signals(false)
	state_reset.emit()

static func from_variant(data: Variant) -> V2ResearchState:
	var state := V2ResearchState.new()
	state.load_dict(data)
	return state

func _read_completed(value: Variant) -> void:
	if typeof(value) != TYPE_ARRAY:
		return
	for entry in value:
		if typeof(entry) == TYPE_STRING and V2ResearchDatabase.get_node(entry) != null:
			completed_ids[entry] = true

func _read_progress(value: Variant) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		return
	for key in value:
		var node: V2ResearchNode = V2ResearchDatabase.get_node(key) if typeof(key) == TYPE_STRING else null
		if node == null or completed_ids.has(key) or not _is_number(value[key]):
			continue
		var clamped := clampf(float(value[key]), 0.0, node.cost)
		if clamped > 0.0:
			progress_by_id[key] = clamped

func _read_overflow(value: Variant) -> void:
	if _is_number(value):
		research_overflow = maxf(float(value), 0.0)

func _read_active(value: Variant) -> void:
	if typeof(value) == TYPE_STRING and value != "" and can_research(value):
		active_id = value

static func _is_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))
