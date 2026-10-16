class_name AIWarTactics
extends RefCounted

## TÁTICA DE GUERRA DA IA (2026-10-15) — relato do usuário depois de jogar: "as unidades fogem com pouca vida e
## ficam vagando", "não sabem se defender, não sabem atacar", "o foco dos arqueiros parecia acidental". Camada de
## decisão por unidade chamada por RivalAI (act_for_unit/_handle_attacker); toda AÇÃO continua passando pelas mesmas
## APIs do jogador (CombatResolver, HexGrid.move_unit, RivalAI.move_unit_toward) — nenhuma regra nova de combate.
##
## O que muda:
##  1. ESCOLHA DO GOLPE (best_strike): entre TODOS os alvos atacáveis do tile atual, o de maior utilidade — matar
##     vale muito, alvo já ferido vale mais (foco de fogo DE PROPÓSITO: as unidades de um mesmo turno convergem no
##     inimigo mais fácil de abater), tropas valiosas (à distância, conjuradores, lendárias) valem mais, revide
##     custa. Antes: a unidade só batia no alvo que o "alvo de marcha" apontava, e ignorava o resto.
##  2. ANDAR E ATACAR (strike_after_move): depois de se mover, se sobrou movimento, ataca no mesmo turno (o jogador
##     sempre pôde; a IA só andava e parava).
##  3. DEFESA DAS CIDADES CONTRA EXÉRCITOS (defend_against_invaders): CityDefense só reagia a MONSTROS — tropa
##     inimiga de outra civilização podia sitiar uma cidade da IA sem resposta. Agora quem está perto volta e luta.
##  4. RECUO COM HISTERESE (retreat): ferida abaixo de RivalAI.RETREAT_HP_FRACTION recua para a cidade própria mais
##     segura e SÓ volta à luta com RECOVER_HP_FRACTION — antes ela saía da cidade com 36% de vida, levava um golpe,
##     fugia de novo ("vagando"). Quem guarnece uma cidade atacada não foge dela, e um abate garantido vem antes.
##  5. EXÉRCITO AGRUPADO (should_hold_for_group): em campanha, a vanguarda espera o grupo em vez de chegar sozinha.
##  6. POSICIONAMENTO À DISTÂNCIA (move_ranged): arqueiros/conjuradores param no alcance, longe de corpo-a-corpo
##     inimigo e perto da própria linha; sem escolta, recuam até ela em vez de ficarem parados.

## Utilidade mínima para um golpe valer a pena (abaixo disso a unidade prefere marchar/posicionar).
const MIN_STRIKE_UTILITY := 4.0
## Pesos da utilidade de um golpe.
const KILL_BONUS := 60.0
const DAMAGE_WEIGHT := 60.0
const COUNTER_WEIGHT := 75.0
const WOUNDED_TARGET_WEIGHT := 25.0
const PRIORITY_TARGET_BONUS := 30.0
const CITY_CAPTURE_BONUS := 220.0
const CITY_DAMAGE_WEIGHT := 45.0
## Golpe que deixaria a própria unidade abaixo do limiar de recuo custa isto a mais.
const SELF_ENDANGER_PENALTY := 30.0
## Recuo: volta a lutar só com esta fração de Vida.
const RECOVER_HP_FRACTION := 0.75
const RECOVERING_META := &"ai_recovering"
## Defesa contra exércitos: inimigo em guerra a até THREAT_RADIUS de uma cidade própria = cidade atacada; tropas a
## até RECALL_RADIUS dela voltam para defendê-la.
const INVADER_THREAT_RADIUS := 3
const INVADER_RECALL_RADIUS := 7
## Grupo: a vanguarda espera quando está mais de GROUP_SPREAD casas à frente da GROUP_SIZE-ésima unidade do exército.
const GROUP_SIZE := 3
const GROUP_SPREAD := 2

# --- 1. escolha do golpe ---------------------------------------------------------------------------------------

## Valor de um alvo: poder dele + bônus de prioridade (à distância, conjurador, lendária, manifestação).
static func target_value(target: Unit) -> float:
	var data := target.unit_data
	var value := data.attack + data.defense * 0.5
	if data.attack_range > 1 or data.is_v2_caster() or V2LegendarySystem.is_legendary_unit(target) or V2ManifestationSystem.is_manifestation_unit(target):
		value += PRIORITY_TARGET_BONUS
	return value

## Utilidade de `unit` atacar a tropa `target` agora (−INF = nunca: morreria no golpe).
static func unit_strike_utility(unit: Unit, target: Unit, grid: HexGrid) -> float:
	var p := CombatResolver.predict(unit, target, grid)
	if bool(p.attacker_dies):
		return -INF
	var target_max := maxf(target.unit_data.max_hp, 1.0)
	var own_max := maxf(unit.unit_data.max_hp, 1.0)
	var dealt := minf(float(p.damage_to_defender), target.hp) / target_max
	var taken := float(p.damage_to_attacker) / own_max
	var value := target_value(target)
	var utility := dealt * DAMAGE_WEIGHT - taken * COUNTER_WEIGHT + (1.0 - target.hp / target_max) * WOUNDED_TARGET_WEIGHT
	if bool(p.defender_dies):
		utility += KILL_BONUS + value
	else:
		utility += value * dealt
		# Troca ruim (leva mais do que causa, em fração de Vida) só se fosse um abate — mesma regra de is_favorable_attack.
		if taken > dealt:
			utility -= 40.0
	if (unit.hp - float(p.damage_to_attacker)) < own_max * RivalAI.RETREAT_HP_FRACTION and not bool(p.defender_dies):
		utility -= SELF_ENDANGER_PENALTY
	return utility

## Utilidade de `unit` atacar a cidade `city` (sem revide; captura vale quase tudo).
static func city_strike_utility(unit: Unit, city: City) -> float:
	var prediction := CombatResolver.predict_city_attack(unit, city)
	if bool(prediction.get("captures", false)):
		return CITY_CAPTURE_BONUS
	var durability := maxf(city.max_hp() + city.max_shield(), 1.0)
	return 8.0 + float(prediction.damage) / durability * CITY_DAMAGE_WEIGHT * 4.0

## Melhor golpe disponível do tile atual: {kind: "unit"/"city", target, coord, utility} ou {} se nenhum vale.
## `preferred` (alvo de marcha da campanha/ritual) ganha um bônus — empate fica com o objetivo estratégico.
static func best_strike(unit: Unit, player: PlayerData, grid: HexGrid, visible: Dictionary, preferred: Variant = null) -> Dictionary:
	if unit == null or not is_instance_valid(unit) or unit.movement_left <= 0.0 or unit.embarked or not unit.unit_data.can_basic_attack:
		return {}
	var best := {}
	var best_utility := MIN_STRIKE_UTILITY
	for coord in grid.tiles_in_range(unit.coord, unit.unit_data.attack_range):
		if coord == unit.coord:
			continue
		var bonus := 25.0 if preferred != null and coord == preferred else 0.0
		var city := grid.get_city_at(coord)
		var defender := grid.get_unit_at(coord)
		if defender != null and is_instance_valid(defender) and defender.owner_player != null and (visible.is_empty() or visible.has(coord) or HexMetrics.axial_distance(unit.coord, coord) <= 1) and CombatResolver.can_attack_unit(unit, defender, grid):
			var utility := unit_strike_utility(unit, defender, grid) + bonus
			if utility > best_utility:
				best_utility = utility
				best = {"kind": "unit", "target": defender, "coord": coord, "utility": utility}
		if city != null and CombatResolver.can_attack_city(unit, city):
			var city_utility := city_strike_utility(unit, city) + bonus
			# Guarnição forte na cidade: bater na cidade continua valendo (ela não revida), só a captura exige o tile.
			if city_utility > best_utility:
				best_utility = city_utility
				best = {"kind": "city", "target": city, "coord": coord, "utility": city_utility}
	return best

## Executa um golpe escolhido por best_strike. true se atacou.
static func execute_strike(unit: Unit, strike: Dictionary, grid: HexGrid) -> bool:
	if strike.is_empty() or not is_instance_valid(unit):
		return false
	unit.fortified = false # atacar desfaz o Fortificar (mesma regra do jogador, SelectionManager)
	if strike.kind == "unit":
		var target: Unit = strike.target
		if not is_instance_valid(target) or target.hp <= 0.0:
			return false
		CombatResolver.resolve(unit, target, grid)
		return true
	var city: City = strike.target
	if city == null or not CombatResolver.can_attack_city(unit, city):
		return false
	CombatResolver.resolve_city_attack(unit, city, grid)
	return true

## Tenta o melhor golpe; true se atacou (a unidade gastou a ação).
static func try_strike(unit: Unit, player: PlayerData, grid: HexGrid, visible: Dictionary, preferred: Variant = null) -> bool:
	return execute_strike(unit, best_strike(unit, player, grid, visible, preferred), grid)

# --- 2. andar e atacar -----------------------------------------------------------------------------------------

## Depois de um movimento: se sobrou movimento e há golpe que valha, ataca no mesmo turno.
static func strike_after_move(unit: Unit, player: PlayerData, grid: HexGrid, visible: Dictionary, preferred: Variant = null) -> bool:
	if not is_instance_valid(unit) or unit.hp <= 0.0 or unit.movement_left <= 0.0:
		return false
	return try_strike(unit, player, grid, visible, preferred)

# --- 3. defesa das cidades contra exércitos --------------------------------------------------------------------

## Inimigos de civilização em guerra (visíveis) a até INVADER_THREAT_RADIUS de `city`.
static func invaders_near(city: City, player: PlayerData, grid: HexGrid, visible: Dictionary) -> Array[Unit]:
	var result: Array[Unit] = []
	for other in player.enemies:
		for enemy in other.units:
			if not is_instance_valid(enemy) or enemy.hp <= 0.0 or (not visible.is_empty() and not visible.has(enemy.coord)):
				continue
			if HexMetrics.axial_distance(enemy.coord, city.coord) <= INVADER_THREAT_RADIUS:
				result.append(enemy)
	return result

## A cidade própria atacada mais urgente perto de `unit` (null = nenhuma). Urgência = poder invasor − distância.
static func threatened_city_for(unit: Unit, player: PlayerData, grid: HexGrid, visible: Dictionary) -> Dictionary:
	if player.enemies.is_empty():
		return {}
	var best := {}
	var best_score := -INF
	for city in player.cities:
		var distance := HexMetrics.axial_distance(unit.coord, city.coord)
		if distance > INVADER_RECALL_RADIUS:
			continue
		var invaders := invaders_near(city, player, grid, visible)
		if invaders.is_empty():
			continue
		var power := 0.0
		for enemy in invaders:
			power += CityDefense.unit_power(enemy)
		var score := power - float(distance) * 2.0
		if score > best_score:
			best_score = score
			best = {"city": city, "invaders": invaders}
	return best

## Um turno de defesa contra exército inimigo. true = a unidade usou o turno nisso.
static func defend_against_invaders(unit: Unit, player: PlayerData, grid: HexGrid, visible: Dictionary) -> bool:
	if unit.unit_data.attack <= 0.0 or not unit.unit_data.can_basic_attack or unit.unit_data.can_found_city:
		return false
	var threat := threatened_city_for(unit, player, grid, visible)
	if threat.is_empty():
		return false
	var city: City = threat.city
	var invaders: Array[Unit] = threat.invaders
	# Golpe disponível já daqui (inclusive de dentro da cidade): o mais útil, com bônus para quem está colado na cidade.
	var closest := _closest_to(invaders, city.coord)
	if try_strike(unit, player, grid, visible, closest.coord if closest != null else null):
		return true
	var on_city := unit.coord == city.coord
	var garrison_alone := on_city and _defenders_near(player, city, unit) == 0
	# A guarnição solitária não sai da cidade (sairia e a cidade cairia vazia); só bate de dentro.
	if garrison_alone or (on_city and is_recovering(unit)):
		return true
	if is_recovering(unit) or unit.hp < unit.unit_data.max_hp * RivalAI.RETREAT_HP_FRACTION:
		# Ferida: entra na cidade (cura e defesa urbana) em vez de enfrentar o cerco a céu aberto.
		if not on_city and grid.get_unit_at(city.coord) == null:
			RivalAI.move_unit_toward(unit, grid, city.coord)
		return true
	# Cidade vazia: alguém ocupa o tile da cidade primeiro.
	if grid.get_unit_at(city.coord) == null and HexMetrics.axial_distance(unit.coord, city.coord) <= 2:
		RivalAI.move_unit_toward(unit, grid, city.coord)
		strike_after_move(unit, player, grid, visible)
		return true
	if closest == null:
		return true
	# Sem suicídio: uma tropa sozinha não corre contra um bando muito mais forte — junta-se na cidade, onde a Defesa
	# urbana e as outras tropas lutam com ela.
	var local_enemy := 0.0
	for enemy in invaders:
		if HexMetrics.axial_distance(enemy.coord, closest.coord) <= 2:
			local_enemy += CityDefense.unit_power(enemy)
	if CityDefense.unit_power(unit) * 2.0 < local_enemy and HexMetrics.axial_distance(unit.coord, city.coord) > 1:
		RivalAI.move_unit_toward(unit, grid, city.coord)
		strike_after_move(unit, player, grid, visible)
		return true
	if unit.unit_data.attack_range > 1:
		move_ranged(unit, player, grid, visible, closest.coord)
	else:
		RivalAI.move_unit_toward(unit, grid, closest.coord)
	strike_after_move(unit, player, grid, visible, closest.coord)
	return true

static func _defenders_near(player: PlayerData, city: City, exclude: Unit) -> int:
	var count := 0
	for ally in player.units:
		if ally != exclude and is_instance_valid(ally) and ally.unit_data.attack > 0.0 and ally.unit_data.can_basic_attack and HexMetrics.axial_distance(ally.coord, city.coord) <= 1:
			count += 1
	return count

static func _closest_to(units: Array[Unit], coord: Vector2i) -> Unit:
	var best: Unit = null
	var best_distance := 999999
	for enemy in units:
		var distance := HexMetrics.axial_distance(enemy.coord, coord)
		if distance < best_distance or (distance == best_distance and best != null and enemy.hp < best.hp):
			best_distance = distance
			best = enemy
	return best

# --- 4. recuo com histerese ------------------------------------------------------------------------------------

static func is_recovering(unit: Unit) -> bool:
	return is_instance_valid(unit) and bool(unit.get_meta(RECOVERING_META, false))

## Atualiza o estado de recuo: entra abaixo de RETREAT_HP_FRACTION, sai só com RECOVER_HP_FRACTION.
static func update_recovery(unit: Unit) -> bool:
	var fraction := unit.hp / maxf(unit.unit_data.max_hp, 1.0)
	if fraction < RivalAI.RETREAT_HP_FRACTION:
		unit.set_meta(RECOVERING_META, true)
	elif fraction >= RECOVER_HP_FRACTION and unit.has_meta(RECOVERING_META):
		unit.remove_meta(RECOVERING_META)
	return is_recovering(unit)

## Recua para curar: abate garantido e sem risco primeiro; senão a cidade própria mais segura (perto e longe de
## inimigos); já dentro de uma cidade, fica (lá ela cura). true = usou o turno.
static func retreat(unit: Unit, player: PlayerData, grid: HexGrid, visible: Dictionary) -> bool:
	var strike := best_strike(unit, player, grid, visible)
	if not strike.is_empty() and strike.kind == "unit":
		var p := CombatResolver.predict(unit, strike.target, grid)
		if bool(p.defender_dies) and float(p.damage_to_attacker) <= 0.0:
			return execute_strike(unit, strike, grid)
	var view := V2AITacticalAI.view_for(player, grid)
	if grid.get_city_at(unit.coord) != null and grid.get_city_at(unit.coord).owner_player == player:
		return true
	var best: City = null
	var best_score := INF
	for city in player.cities:
		var score := float(HexMetrics.axial_distance(unit.coord, city.coord)) + V2AITacticalAI._local_risk(city.coord, unit, view) * 12.0
		var occupant := grid.get_unit_at(city.coord)
		if occupant != null and occupant != unit:
			score += 3.0 # já guarnecida: ainda cura perto, mas pior que uma livre
		if score < best_score:
			best_score = score
			best = city
	if best == null:
		return false
	if grid.get_unit_at(best.coord) == null:
		RivalAI.move_unit_toward(unit, grid, best.coord)
	else:
		_move_to_safest_near(unit, grid, view, best.coord)
	return true

## Casa alcançável perto de `anchor` com o menor risco (ver V2AITacticalAI._local_risk).
static func _move_to_safest_near(unit: Unit, grid: HexGrid, view: V2AIWorldView, anchor: Vector2i) -> void:
	var reachable := grid.unit_landing_reachable(unit)
	var best := unit.coord
	var best_score := _safety_score(unit.coord, unit, view, anchor)
	for coord in reachable.keys():
		if grid.get_unit_at(coord) != null:
			continue
		var score := _safety_score(coord, unit, view, anchor)
		if score > best_score:
			best_score = score
			best = coord
	if best != unit.coord:
		unit.fortified = false
		grid.move_unit(unit, best, reachable[best])

static func _safety_score(coord: Vector2i, unit: Unit, view: V2AIWorldView, anchor: Vector2i) -> float:
	return -V2AITacticalAI._local_risk(coord, unit, view) * 30.0 - float(HexMetrics.axial_distance(coord, anchor)) * 2.0

# --- 5. exército agrupado ----------------------------------------------------------------------------------------

## Unidades de combate aptas a marchar (fora as feridas em recuo e quem não ataca).
static func field_army(player: PlayerData) -> Array[Unit]:
	var result: Array[Unit] = []
	for ally in player.units:
		if V2StrategicAI.is_lair_responder(ally) and not is_recovering(ally):
			result.append(ally)
	return result

## Em campanha: `unit` está tão à frente do grupo que deve esperar? Compara com a GROUP_SIZE-ésima unidade mais
## próxima do alvo (exército de 1–2 unidades nunca espera ninguém).
static func should_hold_for_group(unit: Unit, player: PlayerData, target: Vector2i) -> bool:
	var army := field_army(player)
	if army.size() < 2:
		return false
	var distances: Array[int] = []
	for ally in army:
		distances.append(HexMetrics.axial_distance(ally.coord, target))
	distances.sort()
	var k := mini(GROUP_SIZE, army.size()) - 1
	var own := HexMetrics.axial_distance(unit.coord, target)
	return own < distances[k] - GROUP_SPREAD

# --- 5b. postura sem alvo ----------------------------------------------------------------------------------------

## Sem alvo, só MAX_SCOUTS tropas exploram (as de menor serial_id entre as aptas); as outras guarnecem as cidades —
## antes TODO o exército saía explorando o mapa em paz ("ficam vagando") e a cidade ficava vazia quando a guerra vinha.
const MAX_SCOUTS := 2
const POST_DEFENDER_WEIGHT := 6.0

static func is_designated_scout(unit: Unit, player: PlayerData) -> bool:
	var army := field_army(player)
	# Desempate pela ordem em player.units (ordem de nascimento): sort_custom não é estável.
	army.sort_custom(func(a: Unit, b: Unit) -> bool: return a.serial_id < b.serial_id if a.serial_id != b.serial_id else player.units.find(a) < player.units.find(b))
	return army.slice(0, MAX_SCOUTS).has(unit)

## Vai para a cidade própria que mais precisa de guarnição (menos defensores colados nela, depois a mais perto) e,
## chegando, fortifica. true = usou o turno.
static func take_post(unit: Unit, player: PlayerData, grid: HexGrid) -> bool:
	if player.cities.is_empty():
		return false
	var best: City = null
	var best_score := INF
	for city in player.cities:
		var defenders := _defenders_near(player, city, unit)
		var score := float(defenders) * POST_DEFENDER_WEIGHT + float(HexMetrics.axial_distance(unit.coord, city.coord))
		if score < best_score:
			best_score = score
			best = city
	if HexMetrics.axial_distance(unit.coord, best.coord) <= 1:
		RivalAI._hold_position(unit, grid)
		return true
	RivalAI.move_unit_toward(unit, grid, best.coord)
	return true

# --- 6. posicionamento à distância -------------------------------------------------------------------------------

## Move uma unidade à distância para uma casa de onde alcance `target`, longe de corpo-a-corpo inimigo e perto da
## própria linha. Sem casa no alcance, aproxima-se o quanto der mantendo a mesma preferência.
static func move_ranged(unit: Unit, player: PlayerData, grid: HexGrid, visible: Dictionary, target: Vector2i) -> void:
	if unit.movement_left <= 0.0:
		return
	var view := V2AITacticalAI.view_for(player, grid)
	var reachable := grid.unit_landing_reachable(unit)
	var best := unit.coord
	var best_score := _ranged_tile_score(unit.coord, unit, player, grid, view, target)
	for coord in reachable.keys():
		if grid.get_unit_at(coord) != null or grid.get_city_at(coord) != null and grid.get_city_at(coord).owner_player != player:
			continue
		var score := _ranged_tile_score(coord, unit, player, grid, view, target)
		if score > best_score:
			best_score = score
			best = coord
	if best != unit.coord:
		unit.fortified = false
		grid.move_unit(unit, best, reachable[best])

static func _ranged_tile_score(coord: Vector2i, unit: Unit, player: PlayerData, grid: HexGrid, view: V2AIWorldView, target: Vector2i) -> float:
	var distance := HexMetrics.axial_distance(coord, target)
	var reach := unit.unit_data.attack_range
	var score := 0.0
	if distance <= reach:
		score += 40.0
		if distance >= 2:
			score += 10.0
	else:
		score -= float(distance - reach) * 8.0
	for enemy in view.visible_enemy_units:
		if enemy.owner_player != null and not player.is_at_war_with(enemy.owner_player):
			continue
		var d := HexMetrics.axial_distance(coord, enemy.coord)
		if d <= 1:
			score -= 35.0
		elif enemy.unit_data.attack_range <= 1 and d <= int(enemy.unit_data.movement_points) + 1:
			score -= 8.0
	for ally in player.units:
		if ally != unit and is_instance_valid(ally) and ally.unit_data.attack > 0.0 and ally.unit_data.attack_range <= 1 and HexMetrics.axial_distance(coord, ally.coord) <= 1:
			score += 6.0
			break
	return score

## Unidade à distância sem escolta: recua até a tropa corpo-a-corpo mais próxima (ou a cidade) em vez de ficar parada
## na linha de frente. true se andou.
static func fall_back_to_line(unit: Unit, player: PlayerData, grid: HexGrid) -> bool:
	var anchor = null
	var best := 999999
	for ally in player.units:
		if ally == unit or not is_instance_valid(ally) or ally.unit_data.attack <= 0.0 or ally.unit_data.attack_range > 1:
			continue
		var d := HexMetrics.axial_distance(unit.coord, ally.coord)
		if d < best:
			best = d
			anchor = ally.coord
	if anchor == null:
		for city in player.cities:
			var d := HexMetrics.axial_distance(unit.coord, city.coord)
			if d < best:
				best = d
				anchor = city.coord
	if anchor == null or best <= 1:
		return false
	var before := unit.coord
	RivalAI.move_unit_toward(unit, grid, anchor)
	return unit.coord != before
