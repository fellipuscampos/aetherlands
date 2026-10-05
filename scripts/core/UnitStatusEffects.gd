class_name UnitStatusEffects
extends RefCounted

## V3 / Etapa 2 — estados temporários GENÉRICOS de unidade aplicados por criaturas da Combat Ecology
## (Veneno, Queimando, Abalado, Petrificação Parcial, Enraizado, Silenciado). Data-driven: nenhum id de
## monstro aqui — quem aplica é o MonsterAbilitySystem; quem lê são as regras de combate/movimento/feitiço.
##
## REUSO: o registro vive no MESMO `unit.magic_status` dos feitiços/Técnicas (id -> turno de expiração
## EXCLUSIVO, já salvo para toda unidade, ver SaveManager._sanitize_magic_dict), com ids próprios "eco_*". Os
## pipelines de feitiço ignoram estes ids (só iteram V2SpellDatabase), e vice-versa.
##
## DURAÇÃO EM TURNOS DA VÍTIMA, igual para humano e IA (fairness): nesta base de turnos a fase da IA vem ANTES
## dos monstros e o humano joga DEPOIS do _finish_turn. Um estado aplicado na fase dos monstros do turno N com
## duração k cobre exatamente k turnos próprios da vítima:
##   * humano: turnos N .. N+k-1  → expiração N+k (o reset de movimento do turno N+k já não o vê);
##   * IA:     turnos N+1 .. N+k  → expiração N+k+1.
## Dano periódico: no INÍCIO de cada um desses turnos (GameManager._finish_turn dos turnos N .. N+k-1, antes da
## fase humana e da próxima fase da IA) — mesma contagem de ticks para os dois. Reaplicar só RENOVA a duração.

const POISON := "eco_poison"
const BURNING := "eco_burning"
const STAGGERED := "eco_staggered"
const PETRIFIED := "eco_petrified"
const ROOTED := "eco_rooted"
const SILENCED := "eco_silenced"

## Campos: name, description (UI), dot_fraction/dot_min/dot_max (dano por tick, % do HP máximo), movement_delta,
## movement_zero, defense_multiplier, silences_spells, source_species (telemetria de abate por status).
## V3 COMBAT ECOLOGY PLACEHOLDER — TUNE LATER.
const DEFS := {
	POISON: {"name": "Envenenado", "description": "perde Vida no início do turno", "dot_fraction": 0.04, "dot_min": 1.0, "dot_max": 4.0, "source_species": "giant_spider"},
	BURNING: {"name": "Em Chamas", "description": "perde Vida no início do turno", "dot_fraction": 0.03, "dot_min": 1.0, "dot_max": 4.0, "source_species": "wyvern"},
	STAGGERED: {"name": "Abalado", "description": "−1 Movimento e −15% Defesa", "movement_delta": -1.0, "defense_multiplier": 0.85, "source_species": "minotaur"},
	PETRIFIED: {"name": "Petrificação Parcial", "description": "Movimento 0 e −20% Defesa; ainda pode atacar", "movement_zero": true, "defense_multiplier": 0.8, "source_species": "basilisk"},
	ROOTED: {"name": "Enraizado", "description": "Movimento 0; ainda pode atacar e conjurar", "movement_zero": true, "source_species": "arboreal_ancient"},
	SILENCED: {"name": "Silenciado", "description": "não pode conjurar feitiços", "silences_spells": true, "source_species": "mana_devourer"},
}

static func is_status_id(id: String) -> bool:
	return DEFS.has(id)

## Turno-limite de dano periódico/efeito para quem é humano vs IA (ver cabeçalho).
static func _owner_offset(unit: Unit) -> int:
	return 0 if unit != null and unit.owner_player != null and GameManager.is_human_controlled(unit.owner_player) else 1

## Aplica (ou renova) `id` por `turns` turnos próprios da vítima. Só em unidade de civilização viva (nunca cidade,
## estrutura ou monstro). Efeitos de movimento valem já no turno em curso. true = aplicado.
static func apply(unit: Unit, id: String, turns: int) -> bool:
	if unit == null or not is_instance_valid(unit) or unit.hp <= 0.0 or unit.owner_player == null or not DEFS.has(id) or turns <= 0:
		return false
	var expiry := TurnManager.turn_number + turns + _owner_offset(unit)
	unit.magic_status[id] = maxi(int(unit.magic_status.get(id, 0)), expiry)
	var def: Dictionary = DEFS[id]
	if bool(def.get("movement_zero", false)):
		unit.movement_left = 0.0
	elif float(def.get("movement_delta", 0.0)) != 0.0:
		unit.movement_left = maxf(0.0, unit.movement_left + float(def.movement_delta))
	unit.refresh_technique_marker()
	unit.refresh_status_overlay() # Etapa 3: tinta temporária reconhecível (render-only)
	return true

static func is_active(unit: Unit, id: String) -> bool:
	return unit != null and int(unit.magic_status.get(id, 0)) > TurnManager.turn_number

static func turns_left(unit: Unit, id: String) -> int:
	if not is_active(unit, id):
		return 0
	return int(unit.magic_status[id]) - TurnManager.turn_number - _owner_offset(unit)

static func active_ids(unit: Unit) -> Array[String]:
	var result: Array[String] = []
	if unit == null or unit.magic_status.is_empty():
		return result
	for id in DEFS:
		if is_active(unit, id):
			result.append(id)
	return result

## Fator de Defesa (UM fator em CombatResolver.predict). Caminho rápido sem estado.
static func defense_multiplier(unit: Unit) -> float:
	if unit == null or unit.magic_status.is_empty():
		return 1.0
	var result := 1.0
	for id in DEFS:
		if DEFS[id].has("defense_multiplier") and is_active(unit, id):
			result *= float(DEFS[id].defense_multiplier)
	return result

## Movimento do turno depois dos estados (Unit.reset_movement).
static func adjusted_movement(unit: Unit, base: float) -> float:
	if unit == null or unit.magic_status.is_empty():
		return base
	var result := base
	for id in DEFS:
		if not is_active(unit, id):
			continue
		if bool(DEFS[id].get("movement_zero", false)):
			return 0.0
		result += float(DEFS[id].get("movement_delta", 0.0))
	return maxf(0.0, result)

static func silences_spells(unit: Unit) -> bool:
	if unit == null or unit.magic_status.is_empty():
		return false
	for id in DEFS:
		if bool(DEFS[id].get("silences_spells", false)) and is_active(unit, id):
			return true
	return false

static func dot_amount(unit: Unit, id: String) -> float:
	var def: Dictionary = DEFS.get(id, {})
	if not def.has("dot_fraction"):
		return 0.0
	return clampf(unit.unit_data.max_hp * float(def.dot_fraction), float(def.dot_min), float(def.dot_max))

## Uma vez por rodada global (GameManager._finish_turn): dano periódico no início do próximo turno da vítima e
## limpeza dos estados encerrados. Sem crédito de abate (CombatResolver.apply_environmental_unit_damage); a
## telemetria registra a espécie de origem. Só unidades de civilização carregam estes estados.
static func process_round(players: Array, grid: HexGrid, turn: int) -> void:
	for player in players:
		if player == null:
			continue
		for unit in player.units.duplicate():
			if not is_instance_valid(unit) or unit.magic_status.is_empty():
				continue
			var offset := _owner_offset(unit)
			for id in DEFS:
				if not unit.magic_status.has(id):
					continue
				var expiry := int(unit.magic_status[id])
				if DEFS[id].has("dot_fraction") and turn < expiry - offset and is_instance_valid(unit) and unit.hp > 0.0:
					var damage := dot_amount(unit, id)
					var owner: PlayerData = unit.owner_player
					var killed := CombatResolver.apply_environmental_unit_damage(unit, damage, grid)
					MonsterEcologySystem.emit_event("status_tick", String(DEFS[id].source_species), {"status": id, "damage": damage, "killed": killed, "target": GameManager.players.find(owner), "target_coord": [unit.coord.x, unit.coord.y]})
					if killed:
						break
					EventBus.unit_status_changed.emit(unit) # Etapa 4: chip do card atualiza no tick (Vida/turnos)
				if is_instance_valid(unit) and expiry <= turn:
					unit.magic_status.erase(id)
					unit.refresh_status_overlay()

## V3 / Etapa 4 — ordem de importância dos estados (mesma do anel no mundo, Unit.STATUS_MARKER_ORDER) para o chip.
const PRIORITY: Array[String] = [PETRIFIED, ROOTED, SILENCED, BURNING, POISON, STAGGERED]

## Estados ativos na ordem de importância (chips do card da unidade).
static func active_ids_by_priority(unit: Unit) -> Array[String]:
	var result: Array[String] = []
	for id in PRIORITY:
		if is_active(unit, id):
			result.append(id)
	return result

## Efeito mecânico REAL de `id` em `unit`, montado dos campos de DEFS (a UI nunca repete número à mão).
static func effect_text(unit: Unit, id: String) -> String:
	var def: Dictionary = DEFS.get(id, {})
	var parts: Array[String] = []
	if def.has("dot_fraction"):
		parts.append("Perde %s de Vida no início de cada turno (%d%% da Vida máxima, %d–%d)" % [_amount(dot_amount(unit, id)), roundi(float(def.dot_fraction) * 100.0), int(def.dot_min), int(def.dot_max)])
	if bool(def.get("movement_zero", false)):
		parts.append("Movimento 0")
	elif float(def.get("movement_delta", 0.0)) != 0.0:
		parts.append("%+d Movimento" % int(def.movement_delta))
	if def.has("defense_multiplier"):
		parts.append("Defesa −%d%%" % roundi((1.0 - float(def.defense_multiplier)) * 100.0))
	if bool(def.get("silences_spells", false)):
		parts.append("Não pode conjurar feitiços")
	elif bool(def.get("movement_zero", false)):
		parts.append("Ainda pode atacar")
	return ". ".join(parts) + "." if not parts.is_empty() else String(def.get("description", ""))

static func _amount(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value

## Turnos restantes exibíveis (mínimo 1 enquanto ativo).
static func display_turns(unit: Unit, id: String) -> int:
	return maxi(turns_left(unit, id), 1)

## Linhas de UI (fato público: qualquer observador vê) com a duração em turnos da vítima.
static func status_lines(unit: Unit) -> Array[String]:
	var lines: Array[String] = []
	for id in active_ids(unit):
		var left := maxi(turns_left(unit, id), 1)
		lines.append("%s — %s (%d turno%s)" % [String(DEFS[id].name), String(DEFS[id].description), left, "" if left == 1 else "s"])
	return lines
