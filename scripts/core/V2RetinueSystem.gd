class_name V2RetinueSystem
extends RefCounted

## RETINUES / HOSTES (Aetherlands V2, Fase 19) — fundação GENÉRICA de unidades persistentes que ocupam capacidade
## de COMANDO mágico. Nenhuma Escola, feitiço ou unidade concreta é citada aqui: tudo vem de UnitData
## (`retinue_school`, `retinue_command_cost`, `retinue_command_capacity`, `v2_magic_school`).
##
## MODELO: capacidade GLOBAL por civilização e por Escola. Uma retinue nunca é vinculada a um conjurador
## específico — vários comandantes somam capacidade, a morte de um não destrói unidades escolhidas
## arbitrariamente, e não existe referência caster->summon para salvar.
##
## TUDO DERIVADO, NADA SALVO: capacidade, uso e "quem está comandada" saem das unidades VIVAS do dono a cada
## consulta (sem cache: medido barato, ver docs Fase 19). Save/load re-deriva o mesmo resultado porque a ordem
## usa `Unit.serial_id`, que o SaveManager persiste e restaura (nunca o instance id do objeto).
##
## OVERLOAD (uso > capacidade, só por PERDA posterior de capacidade — um feitiço nunca cria uma retinue que já
## estoure): as retinues são percorridas por `serial_id` crescente; cada uma fica comandada se o custo dela cabe
## na capacidade restante, senão fica SEM COMANDO e a avaliação continua nas seguintes (greedy determinístico).
## Retinue sem comando continua no mapa inteira (HP, dono, veterania, estados) e defende/retalia normalmente;
## só não recebe ORDENS (mover, iniciar ataque, agir) — ver Unit.can_receive_orders.
##
## Consultado sob demanda (UI, movimento, ataque, feitiço, nascimento/morte) — nunca por frame, nunca varre o mapa:
## só `player.units`.

# --- Reconhecimento ----------------------------------------------------------------------------------

static func _alive(unit) -> bool:
	return unit != null and is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.hp > 0.0 and unit.unit_data != null

static func is_retinue_unit(unit) -> bool:
	return unit != null and is_instance_valid(unit) and unit.unit_data != null and unit.unit_data.is_retinue()

## A unidade participa do comando de alguma Escola (retinue OU comandante)? "" se não.
static func school_of(unit) -> String:
	if unit == null or not is_instance_valid(unit) or unit.unit_data == null:
		return ""
	if unit.unit_data.is_retinue():
		return unit.unit_data.retinue_school
	if unit.unit_data.is_retinue_commander():
		return unit.unit_data.v2_magic_school
	return ""

# --- Estado derivado ------------------------------------------------------------------------------------

## Uma passada em `player.units`: capacidade, retinues ordenadas por serial, as comandadas e os totais.
static func command_state(player, school: String) -> Dictionary:
	var capacity := 0
	var retinues: Array[Unit] = []
	if player != null and school != "":
		for unit in player.units:
			if not _alive(unit):
				continue
			var data: UnitData = unit.unit_data
			if data.retinue_command_capacity > 0 and data.v2_magic_school == school:
				capacity += data.retinue_command_capacity
			if data.retinue_command_cost > 0 and data.retinue_school == school:
				retinues.append(unit)
	retinues.sort_custom(func(a: Unit, b: Unit) -> bool: return a.serial_id < b.serial_id)
	var remaining := capacity
	var total := 0
	var commanded := {}
	for unit in retinues:
		var cost: int = unit.unit_data.retinue_command_cost
		total += cost
		if cost <= remaining:
			remaining -= cost
			commanded[unit] = true
	return {"capacity": capacity, "retinues": retinues, "commanded": commanded, "total_cost": total, "commanded_cost": capacity - remaining}

static func command_capacity(player, school: String) -> int:
	var capacity := 0
	if player == null:
		return capacity
	for unit in player.units:
		if _alive(unit) and unit.unit_data.retinue_command_capacity > 0 and unit.unit_data.v2_magic_school == school:
			capacity += unit.unit_data.retinue_command_capacity
	return capacity

## Custo TOTAL de todas as retinues vivas da Escola (comandadas ou não) — o número "5" de "5 / 4".
static func command_used(player, school: String) -> int:
	var used := 0
	if player == null:
		return used
	for unit in player.units:
		if _alive(unit) and unit.unit_data.retinue_command_cost > 0 and unit.unit_data.retinue_school == school:
			used += unit.unit_data.retinue_command_cost
	return used

## Capacidade livre para uma retinue NOVA (nunca negativa; em overload é 0).
static func command_available(player, school: String) -> int:
	return maxi(0, command_capacity(player, school) - command_used(player, school))

static func can_add_retinue(player, school: String, command_cost: int) -> bool:
	return command_cost <= 0 or command_cost <= command_available(player, school)

## As retinues vivas da Escola, por serial_id crescente.
static func retinues_for(player, school: String) -> Array[Unit]:
	return command_state(player, school).retinues

static func commanded_retinues(player, school: String) -> Array[Unit]:
	var state := command_state(player, school)
	var result: Array[Unit] = []
	for unit in state.retinues:
		if state.commanded.has(unit):
			result.append(unit)
	return result

static func uncommanded_retinues(player, school: String) -> Array[Unit]:
	var state := command_state(player, school)
	var result: Array[Unit] = []
	for unit in state.retinues:
		if not state.commanded.has(unit):
			result.append(unit)
	return result

## CAMINHO RÁPIDO: quem não é retinue (toda unidade normal, V1, casters, Manifestações) devolve true sem varrer nada.
static func is_commanded(unit) -> bool:
	if unit == null or not is_instance_valid(unit) or unit.unit_data == null or not unit.unit_data.is_retinue():
		return true
	if unit.owner_player == null:
		return false
	return command_state(unit.owner_player, unit.unit_data.retinue_school).commanded.has(unit)

static func uncommanded_reason(unit) -> String:
	return V2MagicContent.uncommanded_reason(unit.unit_data.retinue_school) if is_retinue_unit(unit) else ""

## "" se `player` pode trazer AGORA uma retinue de `data` ao mapa; senão o motivo com os números.
static func summon_reason(player, data: UnitData) -> String:
	if data == null or not data.is_retinue():
		return ""
	var available := command_available(player, data.retinue_school)
	if data.retinue_command_cost <= available:
		return ""
	var label := V2MagicContent.command_label(data.retinue_school)
	return "%s insuficiente: requer %d, disponível %d." % [label.substr(0, 1) + label.substr(1).to_lower(), data.retinue_command_cost, available]

# --- Ações ----------------------------------------------------------------------------------------------

## DISSOLVER: remove a retinue voluntariamente. Não é morte: sem abate, XP, saque, Mana nem evento de combate;
## a capacidade volta sozinha (derivação). false se `unit` não é retinue viva.
static func dissolve(unit, hex_grid: HexGrid) -> bool:
	if not is_retinue_unit(unit) or not _alive(unit) or hex_grid == null:
		return false
	hex_grid.remove_unit(unit) # remove_unit já re-deriva os marcadores (notify_roster_changed)
	return true

# --- Marcadores e ganchos ---------------------------------------------------------------------------------

## Atualiza o anel "sem comando" das retinues de `player` na Escola `school`.
static func refresh_markers(player, school: String) -> void:
	if player == null or school == "":
		return
	var state := command_state(player, school)
	for unit in state.retinues:
		unit.refresh_command_marker(not state.commanded.has(unit))

## Todas as Escolas com retinue de `player` (load, testes).
static func refresh_all_markers(player) -> void:
	if player == null:
		return
	var schools := {}
	for unit in player.units:
		if _alive(unit) and unit.unit_data.is_retinue():
			schools[unit.unit_data.retinue_school] = true
	for school in schools:
		refresh_markers(player, school)

## Gancho de HexGrid.spawn_unit/remove_unit: só age se `unit` participa de comando (caminho rápido para o resto).
static func notify_roster_changed(unit, player) -> void:
	if unit == null or unit.unit_data == null:
		return
	var school := ""
	if unit.unit_data.is_retinue():
		school = unit.unit_data.retinue_school
	elif unit.unit_data.is_retinue_commander():
		school = unit.unit_data.v2_magic_school
	if school != "":
		refresh_markers(player, school)

# --- Texto de UI ------------------------------------------------------------------------------------------

## Seção compacta do painel (Necromante, Lich, Hoste): "Comando Necromântico: 3 / 4" (+ "1 Hoste sem comando").
static func summary_lines(unit) -> Array[String]:
	var lines: Array[String] = []
	var school := school_of(unit)
	if school == "" or unit.owner_player == null:
		return lines
	var state := command_state(unit.owner_player, school)
	lines.append("%s: %d / %d" % [V2MagicContent.command_label(school), state.total_cost, state.capacity])
	var uncommanded: int = state.retinues.size() - state.commanded.size()
	if uncommanded == 1:
		lines.append("1 Hoste sem comando")
	elif uncommanded > 1:
		lines.append("%d Hostes sem comando" % uncommanded)
	return lines
