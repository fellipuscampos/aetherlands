class_name DiplomaticMemory
extends RefCounted

## MEMÓRIA DIPLOMÁTICA (2026-10-15) — pedido do usuário: "um sistema de inimizade: se tu já entrou em guerra com
## aquela civ ela vai ficar com um nível de inimizade... ela considera te atacar e não aceita paz tão fácil", "tornar
## a IA estratégica e não aleatória" e "sistemas onde o jogador possa sentir que a interação com as civilizações
## realmente importa".
##
## Cada civilização (`holder`) guarda o que pensa de cada outra (`other`) em PlayerData.diplomatic_memory: um
## punhado de componentes NOMEADOS, cada um com um motivo legível (a tela de Diplomacia mostra todos):
##   rancores (negativos) — agressão (guerras declaradas contra mim), conquista (cidades que me tomou), sangue
##     (ataques às minhas tropas/cidades), traição (guerra declarada com fronteiras abertas), recusas (pedidos de
##     paz que recusou), belicismo (guerras e conquistas contra OUTROS — a fama corre o mapa);
##   boa vontade (positivos) — paz duradoura, fronteiras abertas, inimigo em comum.
## Atitude = boa vontade − rancores → um rótulo (Amistoso … Inimigo jurado). Os rancores esfriam devagar em paz
## (a conquista quase nunca); a boa vontade só cresce em paz e zera numa guerra.
##
## Quem LÊ: RivalAI.decide_war (atitude soma/subtrai do desejo de guerra; amistoso nunca declara), RivalAI.
## decide_peace e Diplomacy._accepts_peace (rancor segura a guerra; boa vontade facilita a paz), Diplomacy.
## open_borders_refusal_reason (desconfiado recusa). Sem RNG: os mesmos fatos dão a mesma decisão.
## Quem ESCREVE: Diplomacy (guerra, paz, recusa, fronteiras), os sinais city_captured/combat_engagement do EventBus
## (ligados em GameManager._ready) e process_turn (esfriar/crescer, chamado pelo fim de turno de cada civilização).

const AGGRESSION := "aggression"
const CONQUEST := "conquest"
const BLOODSHED := "bloodshed"
const BETRAYAL := "betrayal"
const REFUSALS := "refusals"
const WARMONGER := "warmonger"
const PEACE := "peace"
const BORDERS := "borders"
const COMMON_ENEMY := "common_enemy"

const GRIEVANCES: Array[String] = [AGGRESSION, CONQUEST, BLOODSHED, BETRAYAL, REFUSALS, WARMONGER]
const GOODWILL: Array[String] = [PEACE, BORDERS, COMMON_ENEMY]

## Teto de cada componente — nenhum fato isolado domina para sempre. Paz + fronteiras juntas chegam no máximo a
## "Cordial" (18 < 25): só ficar sem brigar não torna ninguém Amistoso — isso exige um inimigo em comum. Com tetos
## 20/12, no laboratório de 2026-10-15 todos viravam Amistosos lá pelo T100 e as guerras caíram de 4,25 para 1,6 por
## partida (IA pacífica demais também é IA fácil).
const CAPS := {
	AGGRESSION: 60.0, CONQUEST: 90.0, BLOODSHED: 30.0, BETRAYAL: 40.0, REFUSALS: 16.0, WARMONGER: 30.0,
	PEACE: 10.0, BORDERS: 8.0, COMMON_ENEMY: 15.0,
}
## Quanto cada fato pesa quando acontece.
const WAR_DECLARED_ON_ME := 30.0
const BETRAYAL_OPEN_BORDERS := 20.0
const CITY_TAKEN_FROM_ME := 30.0
const BLOOD_PER_UNIT_ATTACK := 1.0
const BLOOD_PER_CITY_ATTACK := 2.0
const PEACE_REFUSED := 4.0
const WARMONGER_PER_WAR := 5.0
const WARMONGER_PER_CONQUEST := 4.0
## Crescimento da boa vontade por turno em paz.
const PEACE_GAIN := 0.25
const BORDERS_GAIN := 0.3
const COMMON_ENEMY_GAIN := 0.5
## Esfriamento por turno em paz (multiplicador). Meia-vida ≈ ln(0.5)/ln(x): agressão ~34 t, sangue ~23 t,
## recusas ~14 t, traição ~69 t, belicismo ~46 t, conquista ~138 t (cidade tomada é memória longa).
const PEACE_DECAY := {
	AGGRESSION: 0.98, CONQUEST: 0.995, BLOODSHED: 0.97, BETRAYAL: 0.99, REFUSALS: 0.95, WARMONGER: 0.985,
	BORDERS: 0.95, COMMON_ENEMY: 0.95,
}

## Faixas de atitude, da melhor para a pior (limite inferior inclusivo).
const LEVEL_FRIENDLY := "friendly"
const LEVEL_CORDIAL := "cordial"
const LEVEL_NEUTRAL := "neutral"
const LEVEL_WARY := "wary"
const LEVEL_HOSTILE := "hostile"
const LEVEL_SWORN := "sworn_enemy"
const LEVEL_BOUNDS := [[LEVEL_FRIENDLY, 25.0], [LEVEL_CORDIAL, 8.0], [LEVEL_NEUTRAL, -8.0], [LEVEL_WARY, -30.0], [LEVEL_HOSTILE, -60.0]]
const LEVEL_LABELS := {
	LEVEL_FRIENDLY: "Amistoso", LEVEL_CORDIAL: "Cordial", LEVEL_NEUTRAL: "Neutro",
	LEVEL_WARY: "Desconfiado", LEVEL_HOSTILE: "Hostil", LEVEL_SWORN: "Inimigo jurado",
}
const COMPONENT_LABELS := {
	AGGRESSION: "Guerras declaradas contra eles",
	CONQUEST: "Cidades tomadas deles",
	BLOODSHED: "Ataques às tropas e cidades deles",
	BETRAYAL: "Guerra declarada com fronteiras abertas",
	REFUSALS: "Propostas de paz deles recusadas",
	WARMONGER: "Fama de belicista (guerras e conquistas contra outros)",
	PEACE: "Paz duradoura",
	BORDERS: "Fronteiras abertas",
	COMMON_ENEMY: "Inimigo em comum",
}

# --- leitura -----------------------------------------------------------------------------------------------------

## O registro que `holder` guarda sobre `other` (criado vazio na primeira consulta).
static func record(holder: PlayerData, other: PlayerData) -> Dictionary:
	if not holder.diplomatic_memory.has(other):
		holder.diplomatic_memory[other] = _empty_record()
	return holder.diplomatic_memory[other]

static func _empty_record() -> Dictionary:
	var result := {"war_start": -1, "last_peace": -1, "wars": 0, "war_plan": 0, "war_warned": -999}
	for key in GRIEVANCES + GOODWILL:
		result[key] = 0.0
	return result

static func value(holder: PlayerData, other: PlayerData, key: String) -> float:
	if holder == null or other == null or not holder.diplomatic_memory.has(other):
		return 0.0
	return float(holder.diplomatic_memory[other].get(key, 0.0))

static func grievance(holder: PlayerData, other: PlayerData) -> float:
	var total := 0.0
	for key in GRIEVANCES:
		total += value(holder, other, key)
	return total

static func goodwill(holder: PlayerData, other: PlayerData) -> float:
	var total := 0.0
	for key in GOODWILL:
		total += value(holder, other, key)
	return total

## Atitude de `holder` com `other`: boa vontade − rancores (0 = nada aconteceu ainda).
static func attitude(holder: PlayerData, other: PlayerData) -> float:
	return goodwill(holder, other) - grievance(holder, other)

static func level_for(attitude_value: float) -> String:
	for bound in LEVEL_BOUNDS:
		if attitude_value >= float(bound[1]):
			return String(bound[0])
	return LEVEL_SWORN

static func level(holder: PlayerData, other: PlayerData) -> String:
	return level_for(attitude(holder, other))

static func level_label(holder: PlayerData, other: PlayerData) -> String:
	return String(LEVEL_LABELS[level(holder, other)])

## −1 (amistoso no teto) … +1 (rancor de −40 ou pior): o quanto a memória empurra `holder` PARA a guerra.
static func hostility(holder: PlayerData, other: PlayerData) -> float:
	return clampf(-attitude(holder, other) / 40.0, -1.0, 1.0)

## Componentes não desprezíveis, do maior impacto para o menor: [{key, label, value}] — value com sinal (rancor < 0).
static func breakdown(holder: PlayerData, other: PlayerData) -> Array:
	var result: Array = []
	for key in GRIEVANCES + GOODWILL:
		var amount := value(holder, other, key)
		if amount < 0.5:
			continue
		var signed := amount if key in GOODWILL else -amount
		result.append({"key": key, "label": String(COMPONENT_LABELS[key]), "value": signed})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a.value)) > absf(float(b.value)) if not is_equal_approx(absf(float(a.value)), absf(float(b.value))) else String(a.key) < String(b.key))
	return result

## Turnos desde o início da guerra atual entre os dois (0 se não estão em guerra ou o início não foi registrado).
static func turns_at_war(holder: PlayerData, other: PlayerData) -> int:
	if holder == null or other == null or not holder.is_at_war_with(other):
		return 0
	var start := int(record(holder, other).get("war_start", -1))
	return maxi(0, TurnManager.turn_number - start) if start >= 0 else 0

## Turnos desde a última paz entre os dois (999 se nunca houve uma).
static func turns_since_peace(holder: PlayerData, other: PlayerData) -> int:
	if holder == null or other == null or not holder.diplomatic_memory.has(other):
		return 999
	var last := int(holder.diplomatic_memory[other].get("last_peace", -1))
	return TurnManager.turn_number - last if last >= 0 else 999

# --- escrita -----------------------------------------------------------------------------------------------------

static func add(holder: PlayerData, other: PlayerData, key: String, amount: float) -> void:
	if holder == null or other == null or holder == other:
		return
	var rec := record(holder, other)
	rec[key] = clampf(float(rec.get(key, 0.0)) + amount, 0.0, float(CAPS.get(key, 100.0)))

## `aggressor` declarou guerra a `victim`. `had_open_borders` = havia acordo de fronteiras abertas até agora.
static func on_war_declared(aggressor: PlayerData, victim: PlayerData, had_open_borders: bool) -> void:
	if aggressor == null or victim == null or aggressor == victim:
		return
	add(victim, aggressor, AGGRESSION, WAR_DECLARED_ON_ME)
	if had_open_borders:
		add(victim, aggressor, BETRAYAL, BETRAYAL_OPEN_BORDERS)
	for pair in [[aggressor, victim], [victim, aggressor]]:
		var rec := record(pair[0], pair[1])
		rec.war_start = TurnManager.turn_number
		rec.wars = int(rec.wars) + 1
		rec.war_plan = 0
		rec[PEACE] = 0.0
		rec[BORDERS] = 0.0
	for witness in _witnesses(aggressor, victim):
		add(witness, aggressor, WARMONGER, WARMONGER_PER_WAR)

static func on_peace(a: PlayerData, b: PlayerData) -> void:
	if a == null or b == null or a == b:
		return
	for pair in [[a, b], [b, a]]:
		var rec := record(pair[0], pair[1])
		rec.last_peace = TurnManager.turn_number
		rec.war_start = -1
		rec.war_plan = 0

## `refuser` recusou a proposta de paz de `proposer`: quem propôs guarda a recusa.
static func on_peace_refused(proposer: PlayerData, refuser: PlayerData) -> void:
	add(proposer, refuser, REFUSALS, PEACE_REFUSED)

## Sinal EventBus.city_captured.
static func on_city_captured(old_owner: PlayerData, new_owner: PlayerData) -> void:
	if old_owner == null or new_owner == null or old_owner == new_owner:
		return
	add(old_owner, new_owner, CONQUEST, CITY_TAKEN_FROM_ME)
	for witness in _witnesses(new_owner, old_owner):
		add(witness, new_owner, WARMONGER, WARMONGER_PER_CONQUEST)

## Sinal EventBus.combat_engagement — só entre civilizações em guerra (monstro e covil não contam).
static func on_combat(attacker_owner: PlayerData, defender_owner: PlayerData, target_kind: String) -> void:
	if attacker_owner == null or defender_owner == null or attacker_owner == defender_owner or not attacker_owner.is_at_war_with(defender_owner):
		return
	add(defender_owner, attacker_owner, BLOODSHED, BLOOD_PER_CITY_ATTACK if target_kind == "city" else BLOOD_PER_UNIT_ATTACK)

## Um turno de `holder`: em paz a boa vontade cresce e os rancores esfriam; em guerra nada esfria e a boa vontade
## da paz/fronteira zera. Inimigo em comum cresce para os dois lados de qualquer guerra contra o mesmo terceiro.
static func process_turn(holder: PlayerData) -> void:
	if holder == null:
		return
	for other in _others(holder):
		var rec := record(holder, other)
		if holder.is_at_war_with(other):
			rec[PEACE] = 0.0
			rec[BORDERS] = 0.0
		else:
			for key in PEACE_DECAY:
				if key != COMMON_ENEMY:
					rec[key] = float(rec.get(key, 0.0)) * float(PEACE_DECAY[key])
			rec[PEACE] = minf(float(CAPS[PEACE]), float(rec.get(PEACE, 0.0)) + PEACE_GAIN)
			if holder.has_open_borders_with(other):
				rec[BORDERS] = minf(float(CAPS[BORDERS]), float(rec.get(BORDERS, 0.0)) + BORDERS_GAIN)
		if _share_an_enemy(holder, other):
			rec[COMMON_ENEMY] = minf(float(CAPS[COMMON_ENEMY]), float(rec.get(COMMON_ENEMY, 0.0)) + COMMON_ENEMY_GAIN)
		else:
			rec[COMMON_ENEMY] = float(rec.get(COMMON_ENEMY, 0.0)) * float(PEACE_DECAY[COMMON_ENEMY])

static func _share_an_enemy(a: PlayerData, b: PlayerData) -> bool:
	if a.is_at_war_with(b):
		return false
	for enemy in a.enemies:
		if enemy != b and b.is_at_war_with(enemy):
			return true
	return false

## Civilizações vivas da partida além de `holder`.
static func _others(holder: PlayerData) -> Array[PlayerData]:
	var result: Array[PlayerData] = []
	for other in GameManager.players:
		if other != null and other != holder and not V2VictoryConditions.is_eliminated(other):
			result.append(other)
	return result

## Quem fica sabendo de uma agressão de `actor` contra `target`: todas as outras civilizações vivas da partida.
static func _witnesses(actor: PlayerData, target: PlayerData) -> Array[PlayerData]:
	var result: Array[PlayerData] = []
	for other in _others(actor):
		if other != target:
			result.append(other)
	return result

# --- save --------------------------------------------------------------------------------------------------------

## [[índice do outro, {componentes}]] — chave opcional "memory" do bloco de relações (save sem ela = memória vazia).
static func serialize(holder: PlayerData, players: Array) -> Array:
	var out: Array = []
	for other in holder.diplomatic_memory:
		var index := players.find(other)
		if index < 0:
			continue
		var rec: Dictionary = holder.diplomatic_memory[other]
		var data := {}
		for key in rec:
			data[key] = rec[key]
		out.append([index, data])
	return out

static func restore(holder: PlayerData, saved: Array, players: Array) -> void:
	holder.diplomatic_memory.clear()
	for entry in saved:
		if typeof(entry) != TYPE_ARRAY or entry.size() < 2 or typeof(entry[1]) != TYPE_DICTIONARY:
			continue
		var index := int(entry[0])
		if index < 0 or index >= players.size() or players[index] == holder:
			continue
		var rec := _empty_record()
		for key in rec:
			if entry[1].has(key):
				rec[key] = int(entry[1][key]) if typeof(rec[key]) == TYPE_INT else float(entry[1][key])
		holder.diplomatic_memory[players[index]] = rec
