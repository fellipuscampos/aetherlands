class_name V2UnlockSystem
extends RefCounted

## Aetherlands V2, Fase 3 — a ponte entre a PESQUISA V2 e o GAMEPLAY.
##
## Concluir um nó V2 emite `V2ResearchState.research_completed(id)`; esta classe
## reage a esse sinal (sem polling, sem _process) e, para os nós cujo
## `gameplay_connected` é true, usa o `unlock_type`/`unlock_id` do PRÓPRIO nó pra
## saber o que foi liberado: nunca há um `if node_id == "guardian_2"` aqui. Um
## unlock novo (Fase 4+) entra acrescentando o id em V2DoctrineContent.
## CONNECTED_UNLOCK_IDS e criando o objeto real (BuildingDatabase/UnitDatabase).
##
## A DISPONIBILIDADE é DERIVADA, não guardada: "esta civilização pode construir o
## Salão dos Guardiões?" é `player.v2_research.is_completed(<nó do unlock>)`
## (ver `is_unlocked`). Por isso:
##   * não existe um segundo estado pra ficar dessincronizado — o save/load do
##     bloco "v2_research" já restaura tudo (save antigo, sem o bloco, = nada
##     liberado);
##   * aplicar duas vezes é inofensivo por construção (`apply_unlock` só emite
##     `unlock_applied` na PRIMEIRA vez por nó — reset/load limpam isso);
##   * a IA (que ainda não pesquisa V2) simplesmente nunca vê os unlocks.
##
## Um objeto por PlayerData (`player.v2_unlocks`). As consultas são `static` e
## barradas por prefixo (`v2_`), então o gameplay V1 nunca paga nada por elas.

## Um nó conectado foi aplicado pela primeira vez nesta sessão do estado.
## `unlock_type`: um de CONNECTED_TYPES.
signal unlock_applied(node_id: String, unlock_type: String, unlock_id: String)

## Tipos de unlock que o jogo sabe conectar (Fase 3: doctrine/building/unit; Fase 4:
## technique/unit_upgrade; Fase 12: victory_capstone — o Exército Supremo entra pelo
## MESMO pipeline, sem sistema paralelo; serve também à futura Transcendência; Fase 13:
## city_level — a Urbanização entra pelo MESMO pipeline; PERMITE o nível, nunca sobe
## uma cidade sozinha, ver City.gd; Fase 14: infrastructure_upgrade — N2/N3 das cinco
## linhas econômicas de Infraestrutura, melhora prédios EXISTENTES, nunca cria um novo).
## Fase 17: os seis tipos da Magia (school/school_building/caster/spell/ritual_building/grand_manifestation) entram
## pelo MESMO pipeline — nenhum "MagicUnlockSystem".
const CONNECTED_TYPES: Array[String] = ["doctrine", "building", "unit", "technique", "unit_upgrade", "mastery_building", "legendary_candidate", "victory_capstone", "city_level", "infrastructure_upgrade", "school", "school_building", "caster", "spell", "ritual_building", "grand_manifestation"]

## node_id -> true: só pra `unlock_applied` sair uma vez por nó (não é estado de
## jogo, não é salvo).
var _announced: Dictionary = {}

func _init(state: V2ResearchState = null) -> void:
	if state != null:
		bind(state)

## Passa a reagir a `state`. O estado não guarda referência forte a este objeto
## além da conexão de sinal, e este não guarda o estado — sem ciclo.
func bind(state: V2ResearchState) -> void:
	state.research_completed.connect(_on_research_completed)
	state.state_reset.connect(_on_state_reset)

func _on_research_completed(node_id: String) -> void:
	apply_unlock(node_id)

func _on_state_reset() -> void:
	_announced.clear()

## Aplica o unlock do nó `node_id`. true só quando é um nó conectado ainda não
## aplicado (emite `unlock_applied`); false pra nó desconhecido, não conectado ou
## já aplicado. Chamar de novo nunca muda nada — a disponibilidade já é derivada.
func apply_unlock(node_id: String) -> bool:
	var node := V2ResearchDatabase.get_node(node_id)
	if node == null or not node.gameplay_connected or not (node.unlock_type in CONNECTED_TYPES):
		return false
	if _announced.has(node_id):
		return false
	_announced[node_id] = true
	unlock_applied.emit(node.id, node.unlock_type, node.unlock_id)
	return true

# --- Consultas (estáticas, derivadas) ---------------------------------------------------

## O nó de pesquisa que libera `unlock_id`, ou null se não é um id V2.
static func node_for_unlock(unlock_id: String) -> V2ResearchNode:
	if not V2ResearchDatabase.is_v2_id(unlock_id):
		return null
	return V2ResearchDatabase.node_for_unlock_id(unlock_id)

## `player` (PlayerData) já pesquisou o nó que libera `unlock_id`? Id que não é V2
## não tem gate V2 -> true. Id V2 sem jogador -> false (fail-closed, ao contrário
## do fail-open V1: um id V2 só existe no jogo por causa desta pesquisa).
static func is_unlocked(player, unlock_id: String) -> bool:
	if not V2ResearchDatabase.is_v2_id(unlock_id):
		return true
	var node := V2ResearchDatabase.node_for_unlock_id(unlock_id)
	if node == null:
		return false
	return player != null and player.v2_research.is_completed(node.id)

## Aetherlands V2, Fase 15 — resolve o gate de pesquisa de uma UNIDADE, considerando
## `UnitData.required_v2_unlock_id` (o Construtor: pesquisar Oficinas libera treiná-lo, sem um
## segundo unlock artificial no mesmo nó de pesquisa, §53 do pedido). "" (padrão do campo) = usa o
## próprio `kind` como sempre — comportamento idêntico a antes deste campo existir, pra toda
## unidade V2 já conectada (nenhuma delas declara o campo). Fonte ÚNICA: `PlayerData.has_unlocked`
## e `City.can_train` chamam esta função, nunca duplicam a lógica de redirecionamento.
static func is_unit_unlocked(player, kind: String) -> bool:
	var required := UnitDatabase.create_unit(kind).required_v2_unlock_id
	return is_unlocked(player, required if required != "" else kind)

## Todos os unlock_ids CONECTADOS que `player` já pode usar (pra HUD/diagnóstico).
static func unlocked_ids(player) -> Array[String]:
	var result: Array[String] = []
	if player == null:
		return result
	for unlock_id in V2DoctrineContent.CONNECTED_UNLOCK_IDS + V2MagicContent.CONNECTED_UNLOCK_IDS:
		if is_unlocked(player, unlock_id):
			result.append(unlock_id)
	return result

## Frase curta pro toast de "desbloqueado". `unlock_id` (Fase 13, opcional) só é usado pelo tipo
## "city_level": o toast precisa nomear o NÍVEL desbloqueado ("Cidade II"), nunca o nó de
## pesquisa ("Planejamento Urbano") — mesmo cuidado da Fase 12 com "Exército Supremo" x
## "Supremacia Militar". Todo chamador antigo continua válido (parâmetro tem default).
static func announcement_text(unlock_type: String, display_name: String, unlock_id: String = "") -> String:
	match unlock_type:
		"doctrine":
			return "Doutrina desbloqueada: %s" % display_name
		"building":
			# Fase 14: as cinco linhas econômicas de Infraestrutura têm um nome de PESQUISA
			# diferente do nome do PRÉDIO (ex.: nó "Mercados Locais" desbloqueia o prédio
			# "Mercado") — resolve pelo prédio real quando `unlock_id` aponta pra um
			# (BuildingDatabase é a fonte de verdade do nome exibido); Doutrinas continuam
			# batendo os dois nomes, então o fallback pra `display_name` nunca muda nada nelas.
			var building := BuildingDatabase.get_building(unlock_id)
			return "Novo prédio disponível: %s" % (building.display_name if building else display_name)
		"infrastructure_upgrade":
			# Fase 14 (§67 do pedido): toast genérico pra N2/N3 das linhas econômicas — usa o
			# nome do NÓ de pesquisa (ex.: "Contabilidade"), nunca o do prédio.
			return "Melhoria de infraestrutura desbloqueada: %s" % display_name
		"unit":
			return "Nova unidade disponível: %s" % display_name
		"technique":
			return "Nova técnica disponível: %s" % display_name
		"unit_upgrade":
			return "Nova evolução disponível: %s" % display_name
		"mastery_building":
			return "Novo prédio disponível: %s" % display_name
		"legendary_candidate":
			return "Unidade Lendária disponível: %s" % display_name
		"victory_capstone":
			# Fase 12: mesma frase generica pra qualquer capstone de vitoria (Exercito
			# Supremo hoje, Transcendencia no futuro) -- sem citar o nome da via aqui.
			return "Via de vitória desbloqueada: %s" % display_name
		"city_level":
			return "Desenvolvimento urbano disponível: %s." % V2ResearchDatabase.urbanization_unlock_label(unlock_id)
		# Fase 17 — Magia, frases genéricas por TIPO (nenhuma Escola citada aqui).
		"school":
			return "Escola desbloqueada: %s." % display_name
		"school_building":
			return "Novo prédio mágico disponível: %s." % display_name
		"caster":
			return "Novo conjurador disponível: %s." % display_name
		"spell":
			return "Novo feitiço disponível: %s." % display_name
		"ritual_building":
			return "Nova estrutura ritual disponível: %s." % display_name
		"grand_manifestation":
			return "Grande Manifestação disponível: %s." % display_name
	return display_name
