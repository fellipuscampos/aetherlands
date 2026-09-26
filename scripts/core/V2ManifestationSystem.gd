class_name V2ManifestationSystem
extends RefCounted

## SLOT DE GRANDE MANIFESTAÇÃO (Aetherlands V2, Fase 17) — irmão de V2LegendarySystem, mas com outra regra:
## no máximo MAX_PER_SCHOOL Manifestação ATIVA OU EM PRODUÇÃO **por Escola** por civilização (a Lendária
## Militar é 1 no TOTAL). Assim, no futuro, uma civilização pode ter o Serafim e a Manifestação de outra
## Escola ao mesmo tempo — a Transcendência exigirá duas Manifestações de Escolas diferentes.
##
## RECONHECIMENTO por dado, nunca por id: um KIND é Manifestação se o nó de pesquisa que o libera é
## `grand_manifestation`; uma UNIDADE viva é Manifestação se tem o traço `grand_manifestation`. A ESCOLA vem
## de UnitData.v2_magic_school.
##
## O SLOT É DERIVADO, NUNCA GUARDADO: unidades vivas com o traço + `city.production_item` (que o save já
## persiste). Morte, cancelamento, troca de produção, captura e load liberam/reservam o slot sozinhos.
## Consultas sob demanda (produção, UI, nascimento) — nada por frame. Independente do slot Lendário.

const MAX_PER_SCHOOL := 1
const SLOT_TAKEN_REASON := "Já existe uma Grande Manifestação desta Escola ativa ou em produção nesta civilização."

static var _school_by_kind: Dictionary = {}

# --- Reconhecimento ----------------------------------------------------------------------------

static func is_manifestation_kind(kind: String) -> bool:
	if not V2ResearchDatabase.is_v2_id(kind):
		return false
	var node := V2ResearchDatabase.node_for_unlock_id(kind)
	return node != null and node.unlock_type == "grand_manifestation"

static func is_manifestation_unit(unit) -> bool:
	return unit != null and is_instance_valid(unit) and unit.unit_data != null and unit.unit_data.has_trait(UnitData.TRAIT_GRAND_MANIFESTATION)

## A Escola de um kind de Manifestação (UnitData.v2_magic_school), em cache.
static func school_of_kind(kind: String) -> String:
	if not _school_by_kind.has(kind):
		_school_by_kind[kind] = UnitDatabase.create_unit(kind).v2_magic_school if is_manifestation_kind(kind) else ""
	return _school_by_kind[kind]

# --- Slot (derivado) ----------------------------------------------------------------------------

static func active_units(player, school: String) -> Array[Unit]:
	var result: Array[Unit] = []
	if player == null:
		return result
	for unit in player.units:
		if is_instance_valid(unit) and unit.hp > 0.0 and is_manifestation_unit(unit) and unit.unit_data.v2_magic_school == school:
			result.append(unit)
	return result

## Escolas distintas com uma Grande Manifestação viva no roster e no mapa. Uma
## duplicata corrompida da mesma Escola conta uma vez; produção nunca entra aqui.
static func active_manifestation_schools(player) -> Array[String]:
	var result: Array[String] = []
	if player == null:
		return result
	var grid := GameManager.hex_grid
	for unit in player.units:
		if not is_instance_valid(unit) or unit.hp <= 0.0 or not is_manifestation_unit(unit):
			continue
		var school: String = unit.unit_data.v2_magic_school
		if school == "" or school in result:
			continue
		# Em runtime real, a unidade precisa ser o ocupante canônico do tile. Em
		# fixtures sem grid, o roster continua sendo a fonte disponível.
		if grid != null and grid.get_unit_at(unit.coord) != unit:
			continue
		result.append(school)
	result.sort()
	return result

static func active_manifestation_count(player) -> int:
	return active_manifestation_schools(player).size()

static func cities_producing(player, school: String, excluding: City = null) -> Array[City]:
	var result: Array[City] = []
	if player == null:
		return result
	for city in player.cities:
		if city != excluding and is_instance_valid(city) and is_manifestation_kind(city.production_item) and school_of_kind(city.production_item) == school:
			result.append(city)
	return result

static func slots_used(player, school: String, excluding_city: City = null) -> int:
	return active_units(player, school).size() + cities_producing(player, school, excluding_city).size()

static func slot_available(player, school: String, city: City = null) -> bool:
	return slots_used(player, school, city) < MAX_PER_SCHOOL

# --- Treino -------------------------------------------------------------------------------------

## Mana exigida para INICIAR a produção de `kind` (UnitData.production_mana_cost; nunca reservada nem
## descontada aqui). "" se não há exigência ou já basta; a cidade que JÁ produz o kind não é barrada.
static func production_mana_reason(player, city: City, kind: String) -> String:
	var cost := UnitDatabase.create_unit(kind).production_mana_cost if V2ResearchDatabase.is_v2_id(kind) else 0.0
	if cost <= 0.0 or player == null or (city != null and city.production_item == kind):
		return ""
	if player.mana < cost:
		return "Requer %d Mana." % int(cost)
	return ""

## O motivo de `city` não poder INICIAR a Manifestação `kind` quando pesquisa e prédio já estão ok: slot da
## Escola ocupado ou Mana insuficiente pra iniciar. "" se pode (ou se não é Manifestação). A HUD usa isto pra
## manter o botão visível e desabilitado com o motivo.
static func training_soft_reason(player, city: City, kind: String) -> String:
	if player == null or city == null or not is_manifestation_kind(kind):
		return ""
	if not V2UnlockSystem.is_unit_unlocked(player, kind):
		return ""
	var required: BuildingData = BuildingDatabase.building_that_trains(kind)
	if required != null and not city.buildings.has(required.id):
		return ""
	if not slot_available(player, school_of_kind(kind), city):
		return SLOT_TAKEN_REASON
	return production_mana_reason(player, city, kind)

# --- Conclusão (fail-closed) -----------------------------------------------------------------------

## Pode nascer uma Manifestação `kind` pra `player` AGORA? Defesa final contra duas cidades concluindo a
## mesma Escola no mesmo ciclo (ou save editado). Não-Manifestação: sempre true.
static func spawn_allowed(player, kind: String) -> bool:
	if not is_manifestation_kind(kind):
		return true
	return active_units(player, school_of_kind(kind)).size() < MAX_PER_SCHOOL

## Recusa o nascimento: erro claro, devolve os PP à cidade (nada perdido nem duplicado; a Mana nunca foi
## cobrada) e avisa o humano. Mesmo comportamento de V2LegendarySystem.refuse_spawn.
static func refuse_spawn(city: City, kind: String, notify_human: bool) -> void:
	city.stored_production += UnitDatabase.create_unit(kind).production_cost
	push_error("V2ManifestationSystem: '%s' não nasceu em %s — a civilização já tem uma Grande Manifestação desta Escola." % [kind, city.city_name])
	if notify_human:
		EventBus.notify.emit("Grande Manifestação bloqueada: já existe uma desta Escola ativa.", "")
