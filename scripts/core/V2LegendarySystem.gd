class_name V2LegendarySystem
extends RefCounted

## SISTEMA GLOBAL DE UNIDADE LENDÁRIA (Aetherlands V2, Fase 6). Cada civilização pode ter no
## máximo V2ResearchDatabase.MAX_ACTIVE_LEGENDARY_UNITS (1) Unidade Lendária ATIVA **ou em
## treinamento** por vez — de QUALQUER Doutrina: o slot é da civilização, não do Campeão Guardião.
## As outras cinco Lendárias (Herói da Lâmina, Caçador de Lendas, Cavaleiro de Grifo, Mestre das
## Sombras, Colosso de Cerco) entram só criando a unidade e conectando o id: nada aqui as conhece.
##
## RECONHECIMENTO por dado, nunca por nome/id específico:
##   * um KIND (id de produção) é lendário se o nó de pesquisa que o libera é `legendary_candidate`
##     (V2ResearchNode.unlock_type) — os seis N9 já estão na metadata;
##   * uma UNIDADE viva é lendária se o seu UnitData tem o traço `legendary`
##     (UnitData.TRAIT_LEGENDARY, semeado por UnitDatabase.create_unit a partir da metadata acima;
##     uma unidade de teste pode declarar o traço com qualquer id).
##
## O SLOT É DERIVADO, NUNCA GUARDADO: `ativas + em produção` sai das unidades reais
## (`player.units`) e das ordens de produção reais (`city.production_item`, que o save já persiste).
## Por isso não há boolean que possa dessincronizar: morte, remoção, captura de cidade, troca ou
## cancelamento de produção e load liberam/reservam o slot sozinhos. A reserva por produção impede
## duas cidades de iniciarem uma Lendária no mesmo turno. Consultas sob demanda (abrir produção,
## iniciar, concluir) — nada roda por frame.
##
## FAIL-CLOSED: na conclusão da produção, spawn_allowed() confere de novo (jamais duas Lendárias
## ativas, mesmo num estado inconsistente); ver GameManager.

const SLOT_TAKEN_REASON := "Já existe uma Unidade Lendária ativa ou em treinamento nesta civilização."

## O limite lido da constante global (V2ResearchDatabase), não de nenhuma Doutrina.
static func max_active() -> int:
	return V2ResearchDatabase.MAX_ACTIVE_LEGENDARY_UNITS

# --- Reconhecimento ----------------------------------------------------------------------------

## `kind` (id de produção/unlock) é de uma Unidade Lendária? Metadata: o nó que o libera é
## `legendary_candidate`. Vale mesmo para ids ainda sem unidade criada.
static func is_legendary_kind(kind: String) -> bool:
	if not V2ResearchDatabase.is_v2_id(kind):
		return false
	var node := V2ResearchDatabase.node_for_unlock_id(kind)
	return node != null and node.unlock_type == "legendary_candidate"

## A unidade viva `unit` é Lendária (traço `legendary` no dado)?
static func is_legendary_unit(unit) -> bool:
	return unit != null and is_instance_valid(unit) and unit.unit_data != null and unit.unit_data.has_trait(UnitData.TRAIT_LEGENDARY)

# --- Slot (derivado) ----------------------------------------------------------------------------

## As Lendárias ATIVAS (vivas) da civilização.
static func active_legendary_units(player) -> Array[Unit]:
	var result: Array[Unit] = []
	if player == null:
		return result
	for unit in player.units:
		if is_instance_valid(unit) and unit.hp > 0.0 and is_legendary_unit(unit):
			result.append(unit)
	return result

## A primeira Lendária ativa, ou null.
static func active_legendary(player) -> Unit:
	var units := active_legendary_units(player)
	return units[0] if not units.is_empty() else null

static func has_active_legendary(player) -> bool:
	return not active_legendary_units(player).is_empty()

## As cidades da civilização que estão PRODUZINDO uma Lendária agora (menos `excluding`: a cidade que
## está perguntando não conta contra si mesma — trocar o item dela cancela a própria ordem).
static func cities_producing_legendary(player, excluding: City = null) -> Array[City]:
	var result: Array[City] = []
	if player == null:
		return result
	for city in player.cities:
		if city != excluding and is_instance_valid(city) and is_legendary_kind(city.production_item):
			result.append(city)
	return result

static func has_legendary_in_production(player, excluding: City = null) -> bool:
	return not cities_producing_legendary(player, excluding).is_empty()

## Slots ocupados: Lendárias ativas + cidades produzindo uma (menos `excluding_city`).
static func slots_used(player, excluding_city: City = null) -> int:
	return active_legendary_units(player).size() + cities_producing_legendary(player, excluding_city).size()

## Há slot livre para `city` iniciar uma Lendária? (A própria produção de `city` não conta.)
static func legendary_slot_available(player, city: City = null) -> bool:
	return slots_used(player, city) < max_active()

# --- Treino -------------------------------------------------------------------------------------

## "" se `city` pode iniciar `unit_id` agora (Lendária: pesquisa + prédio de treino na cidade + slot),
## senão o motivo em uma frase. Para um id que não é Lendária devolve "" (nada a dizer por aqui).
static func unavailable_reason(player, city: City, unit_id: String) -> String:
	if not is_legendary_kind(unit_id):
		return ""
	if player == null or not V2UnlockSystem.is_unlocked(player, unit_id):
		var node := V2ResearchDatabase.node_for_unlock_id(unit_id)
		return "Requer pesquisa: %s." % (node.display_name if node != null else unit_id)
	var required: BuildingData = BuildingDatabase.building_that_trains(unit_id)
	if required != null and (city == null or not city.buildings.has(required.id)):
		return "Requer %s na cidade." % required.display_name
	if not legendary_slot_available(player, city):
		return SLOT_TAKEN_REASON
	return ""

static func can_train_legendary(player, city: City, unit_id: String) -> bool:
	return is_legendary_kind(unit_id) and unavailable_reason(player, city, unit_id) == ""

## O motivo do slot SE for o ÚNICO impedimento (pesquisa e prédio ok, slot ocupado); "" senão. A HUD
## usa pra mostrar o botão da Lendária desabilitado, explicando, em vez de sumir sem dizer por quê.
static func slot_only_reason(player, city: City, unit_id: String) -> String:
	if unavailable_reason(player, city, unit_id) == SLOT_TAKEN_REASON:
		return SLOT_TAKEN_REASON
	return ""

# --- Conclusão (fail-closed) -----------------------------------------------------------------------

## Pode nascer uma unidade `kind` pra `player` AGORA? Uma Lendária só nasce se a civilização não tem
## nenhuma ativa — defesa final contra qualquer inconsistência (duas cidades terminando no mesmo
## turno, save editado...). Não-Lendária: sempre true.
static func spawn_allowed(player, kind: String) -> bool:
	if not is_legendary_kind(kind):
		return true
	return active_legendary_units(player).size() < max_active()

## Recusa o nascimento: erro claro no log, devolve o custo pago à cidade (nada se perde, nada é
## duplicado) e avisa o humano. A cidade fica ociosa (o item de produção já foi consumido).
static func refuse_spawn(city: City, kind: String, notify_human: bool) -> void:
	var cost := UnitDatabase.create_unit(kind).production_cost
	city.stored_production += cost
	push_error("V2LegendarySystem: '%s' não nasceu em %s — a civilização já tem uma Unidade Lendária ativa (limite %d)." % [kind, city.city_name, max_active()])
	if notify_human:
		EventBus.notify.emit("Produção Lendária bloqueada: já existe uma Unidade Lendária ativa.", "")
