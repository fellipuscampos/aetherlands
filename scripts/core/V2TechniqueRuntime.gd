class_name V2TechniqueRuntime
extends RefCounted

## Runtime das Técnicas Militares de Doutrina V2 (Fase 4) — ver V2DoctrineTechniqueData /
## V2DoctrineTechniqueDatabase. Técnica NÃO é feitiço: sem Mana, sem conjurador, fora do
## Grimório. Tudo é consulta/evento (nada de _process): o efeito de defesa é lido por
## CombatResolver.predict na hora do combate e a expiração roda uma vez por turno.
##
## ESTADO POR UNIDADE — reaproveita o que o save já persiste, sem campo novo:
##   unit.magic_cooldowns[id] = turno em que a técnica volta a poder ser usada
##   unit.magic_status[id]    = turno EXCLUSIVO em que o efeito deixa de valer
## (as duas chaves só ganham o id da técnica; o nome "magic_" é herança do V1). Como o
## estado fica na unidade e não no tipo dela, evoluir Escudeiro -> Guardião mantém a
## recarga (não dá pra "resetar" a técnica evoluindo).
##
## DURAÇÃO: "até o início do próximo turno do dono". Nesta base de turnos o mundo age
## (IA, monstros) DENTRO da troca de turno, já com turn_number+1, antes de o dono voltar a
## jogar. Por isso o efeito é gravado com expiração em ACTIVE_TURNS (= T+2) — que cobre a
## fase de IA — e expire_finished() o encerra no início do turno seguinte do dono (chamado
## por GameManager._finish_turn). O limite T+2 é só uma rede de segurança.

## Turnos (contando o de ativação) que o registro de `magic_status` cobre. Fase 17: a regra mora em
## V2OwnerTurnEffect (compartilhada com os feitiços V2); este nome continua por compatibilidade.
const ACTIVE_TURNS := V2OwnerTurnEffect.SPAN_TURNS

## Técnicas ATIVAS (botão, ação, recarga, duração) e PASSIVAS (valem sozinhas, sem estado)
## coexistem: o modo vem de V2DoctrineTechniqueData.activation_mode. PASSIVAS nunca tocam em
## `magic_status`/`magic_cooldowns` — o efeito é DERIVADO de pesquisa da civilização + linha da
## unidade, então não há o que salvar nem expirar (ver attack_multiplier).

# --- Consultas -------------------------------------------------------------------------------

## As técnicas que `unit` PODE ter neste momento: da linha de Doutrina dela e com o nó
## de pesquisa concluído pela civilização. É o que a UI lista. Elegibilidade por LINHA
## (V2UnitLine), nunca pelo id do Escudeiro.
static func techniques_for_unit(unit: Unit) -> Array[V2DoctrineTechniqueData]:
	var result: Array[V2DoctrineTechniqueData] = []
	if unit == null or unit.unit_data == null:
		return result
	var branch := V2UnitLine.doctrine_branch_of(unit.unit_data.visual_kind)
	if branch == "":
		return result
	for technique in V2DoctrineTechniqueDatabase.for_branch(branch):
		if V2UnlockSystem.is_unlocked(unit.owner_player, technique.id):
			result.append(technique)
	return result

## Só as técnicas ATIVAS da unidade (as que ganham botão no painel).
static func active_techniques_for_unit(unit: Unit) -> Array[V2DoctrineTechniqueData]:
	var result: Array[V2DoctrineTechniqueData] = []
	for technique in techniques_for_unit(unit):
		if not technique.is_passive():
			result.append(technique)
	return result

## Só as técnicas PASSIVAS que a unidade tem agora (linha + nó pesquisado) — sem botão.
static func passive_techniques_for_unit(unit: Unit) -> Array[V2DoctrineTechniqueData]:
	var result: Array[V2DoctrineTechniqueData] = []
	for technique in techniques_for_unit(unit):
		if technique.is_passive():
			result.append(technique)
	return result

static func is_active(unit: Unit, technique_id: String) -> bool:
	return V2OwnerTurnEffect.is_active(unit.magic_status, technique_id)

## Turnos que faltam pra a técnica voltar (0 = pronta).
static func cooldown_remaining(unit: Unit, technique_id: String) -> int:
	return maxi(0, int(unit.magic_cooldowns.get(technique_id, 0)) - TurnManager.turn_number)

## O nome da primeira técnica ativa em `unit` ("" se nenhuma) — pra bloquear o upgrade.
static func active_technique_name(unit: Unit) -> String:
	if unit == null or unit.magic_status.is_empty():
		return ""
	for technique in V2DoctrineTechniqueDatabase.all_techniques():
		if is_active(unit, technique.id):
			return technique.display_name
	return ""

## O motivo (uma frase) de `unit` não poder usar a técnica agora, ou "" se pode. `hex_grid` só importa para as
## técnicas de ATAQUE (precisam de um inimigo adjacente); nulo = GameManager.hex_grid.
static func unavailable_reason(unit: Unit, technique_id: String, hex_grid: HexGrid = null) -> String:
	var technique := V2DoctrineTechniqueDatabase.get_technique(technique_id)
	if technique == null or unit == null or unit.unit_data == null:
		return "Técnica desconhecida."
	if V2UnitLine.doctrine_branch_of(unit.unit_data.visual_kind) != technique.doctrine_branch:
		return "Esta unidade não pertence à linha da Doutrina."
	if technique.is_passive():
		return "%s é passiva: age sozinha, sem ativação." % technique.display_name
	if not V2UnlockSystem.is_unlocked(unit.owner_player, technique.id):
		return "Requer pesquisa: %s." % technique.display_name
	if unit.hp <= 0.0:
		return "A unidade caiu."
	if is_active(unit, technique.id):
		return "%s já está ativa." % technique.display_name
	var remaining := cooldown_remaining(unit, technique.id)
	if remaining > 0:
		return "Em recarga: %d turno(s)." % remaining
	if technique.consumes_action and (unit.movement_left <= 0.0 or unit.embarked):
		return "A unidade já agiu neste turno."
	# REQUISITO DE PREPARAÇÃO (Fase 11, Bombardeio Preparado): só chega aqui com ALGUM movimento restante (o `if` acima já
	# barrou movement_left <= 0) — então esta checagem só distingue "moveu uma parte" de "não se moveu nada ainda". A
	# exceção (Colosso — Artilharia Andante) é um campo de UnitData, nunca um id concreto aqui.
	if technique.strike_requires_undisturbed and not unit.unit_data.ignores_technique_stationary_requirement and not is_equal_approx(unit.movement_left, unit.unit_data.movement_points):
		return "%s exige que a unidade não tenha se movido neste turno." % technique.display_name
	if technique.is_city_strike():
		if city_strike_targets(unit, technique, hex_grid).is_empty():
			return "Nenhuma cidade hostil ao alcance."
	elif technique.is_strike() and strike_targets(unit, technique, hex_grid).is_empty():
		return _no_target_reason(unit, technique, hex_grid)
	if technique.is_relocation() and relocation_tiles(unit, technique, hex_grid).is_empty():
		return "Nenhum tile livre ao alcance."
	return ""

static func can_use(unit: Unit, technique_id: String, hex_grid: HexGrid = null) -> bool:
	return unavailable_reason(unit, technique_id, hex_grid) == ""

# --- Ativação e expiração ---------------------------------------------------------------------

## Ativa a técnica em `unit`: grava efeito e recarga, gasta a ação (zera o movimento
## restante) e cancela ordens automáticas de movimento. false, sem alterar nada, se não
## puder. Zero Mana, zero Ouro.
static func activate(unit: Unit, technique_id: String) -> bool:
	if not can_use(unit, technique_id):
		return false
	var technique := V2DoctrineTechniqueDatabase.get_technique(technique_id)
	if technique.is_strike() or technique.is_relocation():
		return false # ataque e reposicionamento precisam de alvo (perform_strike / relocate): não há "ativar" sem escolher
	_commit_activation(unit, technique)
	return true

## Grava o efeito e a recarga, gasta a ação (zera o movimento restante) e cancela ordens automáticas. Comum à postura (activate) e ao
## reposicionamento (relocate): o efeito temporário é o MESMO estado (`magic_status`), então expira, aparece no painel e trava o upgrade igual.
static func _commit_activation(unit: Unit, technique: V2DoctrineTechniqueData) -> void:
	var turn := TurnManager.turn_number
	unit.magic_status[technique.id] = V2OwnerTurnEffect.expiry_for_now()
	unit.magic_cooldowns[technique.id] = turn + technique.cooldown_turns
	if technique.consumes_action:
		unit.movement_left = 0.0
	unit.fortified = false
	unit.exploring = false
	unit.move_order_target = Unit.NO_MOVE_ORDER
	unit.refresh_technique_marker()

## Encerra, nas unidades de `player`, as técnicas ativadas em turnos ANTERIORES ao atual
## — o "início do próximo turno do dono". A recarga não é tocada (continua contando).
## Devolve quantos efeitos encerrou. Chamado uma vez por turno (GameManager._finish_turn).
static func expire_finished(player: PlayerData) -> int:
	var expired := 0
	for unit in player.units:
		if unit.magic_status.is_empty():
			continue
		var changed := false
		for technique in V2DoctrineTechniqueDatabase.all_techniques():
			if technique.is_passive() or not unit.magic_status.has(technique.id):
				continue
			if V2OwnerTurnEffect.has_ended(int(unit.magic_status[technique.id])):
				unit.magic_status.erase(technique.id)
				expired += 1
				changed = true
		if changed:
			unit.refresh_technique_marker()
	return expired

# --- Ataque ativo (Golpe Poderoso, Ataque em Arco — Fase 7; Disparo Preciso, Saraivada — Fase 8) ------------------------

## Alcance efetivo (tiles) de `technique` para `unit`: fixo ou alcance básico da unidade + bônus (dado da técnica).
static func strike_range_of(unit: Unit, technique: V2DoctrineTechniqueData) -> int:
	return technique.resolved_range(unit.unit_data)

## O tile `coord` pode ser mirado por `unit`? Só importa para o HUMANO com neblina calculada e alcance > 1 (um alvo
## adjacente sempre é visível): o alvo precisa estar VISÍVEL — o Disparo Preciso de um Atirador de Elite chega a 4 tiles,
## além da visão 3. Sem neblina calculada (partida de teste) ou para a IA, sem restrição.
static func _visible_to_owner(unit: Unit, coord: Vector2i, grid: HexGrid) -> bool:
	if unit.owner_player != GameManager.human_player or grid.visibility.is_empty():
		return true
	return grid.visibility.get(coord, HexGrid.Visibility.UNSEEN) == HexGrid.Visibility.VISIBLE

## Os inimigos que a técnica de ATAQUE `technique` pode mirar a partir de `unit` AGORA, já na ordem em que seriam
## atingidos: (1) menor HP percentual primeiro, (2) menor `serial_id` no empate — nunca a ordem incidental de
## Dictionary/Array. Em ADJACENT_ENEMIES a lista é cortada em `strike_max_targets` (são as próprias vítimas); nos modos com
## mira (SINGLE_TARGET, TARGET_AND_NEIGHBORS) traz todos os candidatos a PRIMÁRIO (o jogador escolhe). Só olha os tiles ao
## alcance da técnica (1 = os 6 vizinhos; mais = `HexMetrics.coords_within`, sem BFS nem varredura do mapa), só UNIDADES
## hostis pela MESMA regra do ataque comum (CombatResolver.can_attack_unit): nunca aliado, civilização em paz, cidade ou covil.
static func strike_targets(unit: Unit, technique: V2DoctrineTechniqueData, hex_grid: HexGrid = null) -> Array[Unit]:
	var result: Array[Unit] = []
	var grid: HexGrid = hex_grid if hex_grid != null else GameManager.hex_grid
	if unit == null or grid == null or technique == null or not technique.is_strike() or technique.is_city_strike():
		return result
	var reach := strike_range_of(unit, technique)
	var coords: Array[Vector2i] = grid.get_neighbors(unit.coord) if reach <= 1 else HexMetrics.coords_within(unit.coord, reach)
	var min_range := technique.strike_min_range
	var movable: Dictionary = {}
	var movable_ready := false
	for coord in coords:
		if min_range > 1 and HexMetrics.axial_distance(unit.coord, coord) < min_range:
			continue
		var target := grid.get_unit_at(coord)
		if target != null and target.hp > 0.0 and CombatResolver.can_attack_unit(unit, target, grid) and (reach <= 1 or _visible_to_owner(unit, coord, grid)):
			if technique.repositions():
				# Mover-e-atacar: o alvo só vale se existe um tile adjacente alcançável (o alcance de movimento da unidade é calculado UMA vez por consulta).
				if not movable_ready:
					movable = grid.unit_reachable(unit)
					movable_ready = true
				if _approach_tile(unit, target, movable, grid) == NO_TILE:
					continue
			result.append(target)
	result.sort_custom(_strike_order)
	if technique.strike_targeting == V2DoctrineTechniqueData.StrikeTargeting.ADJACENT_ENEMIES and result.size() > technique.strike_max_targets:
		result.resize(technique.strike_max_targets)
	return result

static func _strike_order(a: Unit, b: Unit) -> bool:
	var ratio_a := a.hp / maxf(1.0, a.unit_data.max_hp)
	var ratio_b := b.hp / maxf(1.0, b.unit_data.max_hp)
	if not is_equal_approx(ratio_a, ratio_b):
		return ratio_a < ratio_b
	return a.serial_id < b.serial_id

## Todas as vítimas (na ordem de resolução) de um golpe de `technique` com o alvo escolhido `primary`; [] se ele não é um
## alvo válido. SINGLE_TARGET: só o primário. ADJACENT_ENEMIES: ignora `primary` e traz os adjacentes (até o teto).
## TARGET_AND_NEIGHBORS: o primário PRIMEIRO (sempre entra) e depois os inimigos hostis a `strike_splash_radius` tiles dele
## (mesma regra de alvo hostil; nunca o próprio atacante), os de menor HP% primeiro (serial no empate), até completar
## `strike_max_targets` no total. Só olha os tiles do raio ao redor do primário (no máximo os 6 vizinhos com raio 1).
static func strike_victims(unit: Unit, technique: V2DoctrineTechniqueData, primary: Unit, hex_grid: HexGrid = null) -> Array[Unit]:
	var grid: HexGrid = hex_grid if hex_grid != null else GameManager.hex_grid
	var victims: Array[Unit] = []
	if unit == null or grid == null or technique == null or not technique.is_strike() or technique.is_city_strike():
		return victims
	if technique.strike_targeting == V2DoctrineTechniqueData.StrikeTargeting.ADJACENT_ENEMIES:
		return strike_targets(unit, technique, grid)
	if primary == null or not (primary in strike_targets(unit, technique, grid)):
		return victims
	victims.append(primary)
	if technique.strike_targeting == V2DoctrineTechniqueData.StrikeTargeting.TARGET_AND_NEIGHBORS:
		var around: Array[Vector2i] = grid.get_neighbors(primary.coord) if technique.strike_splash_radius <= 1 else HexMetrics.coords_within(primary.coord, technique.strike_splash_radius)
		var secondaries: Array[Unit] = []
		for coord in around:
			var other := grid.get_unit_at(coord)
			if other != null and other != primary and other.hp > 0.0 and CombatResolver.can_attack_unit(unit, other, grid):
				secondaries.append(other)
		secondaries.sort_custom(_strike_order)
		if secondaries.size() > technique.strike_max_targets - 1:
			secondaries.resize(maxi(0, technique.strike_max_targets - 1))
		victims.append_array(secondaries)
	return victims

## Executa a técnica de ATAQUE `technique_id` de `unit`: NÃO há efeito guardado — o golpe é resolvido AGORA, alvo por
## alvo, pelo combate normal (CombatResolver.resolve com o multiplicador da técnica), então guerra, terreno, defesas,
## Muralha, aura, Execução, Caçada, contra-ataque (só a distância <= 1), morte, abates/veterania e recompensas são os de
## sempre. `target` é o alvo escolhido nos modos com mira (precisa ser um dos strike_targets; ADJACENT_ENEMIES o ignora).
## Grava a recarga e gasta a ação ANTES de resolver (a unidade pode morrer no contra-ataque); para de atacar se o
## atacante cai. false, sem alterar nada, se não puder (motivo em unavailable_reason) ou se o alvo for inválido.
static func perform_strike(unit: Unit, technique_id: String, target: Unit = null, hex_grid: HexGrid = null) -> bool:
	var technique := V2DoctrineTechniqueDatabase.get_technique(technique_id)
	if technique == null or not technique.is_strike() or not can_use(unit, technique_id, hex_grid):
		return false
	var grid: HexGrid = hex_grid if hex_grid != null else GameManager.hex_grid
	var victims := strike_victims(unit, technique, target, grid)
	if victims.is_empty():
		return false
	var approach := NO_TILE
	var approach_cost := 0.0
	if technique.repositions():
		var movable := grid.unit_reachable(unit)
		approach = _approach_tile(unit, victims[0], movable, grid)
		if approach == NO_TILE:
			return false
		approach_cost = float(movable[approach])
	unit.magic_cooldowns[technique.id] = TurnManager.turn_number + technique.cooldown_turns
	unit.fortified = false
	unit.exploring = false
	unit.move_order_target = Unit.NO_MOVE_ORDER
	if approach != NO_TILE:
		grid.move_unit(unit, approach, approach_cost) # a unidade REALMENTE percorre a rota e termina adjacente ao alvo
	for victim in victims:
		if unit.hp <= 0.0:
			break # caiu no contra-ataque de um alvo anterior
		if victim.hp <= 0.0:
			continue
		CombatResolver.resolve(unit, victim, grid, technique.strike_multiplier, technique.strike_defense_penetration, technique.strike_prevents_counterattack)
	unit.movement_left = 0.0
	return true

## Tile "sem coordenada" (nenhum tile escolhido / nenhuma aproximação possível).
const NO_TILE := Vector2i(999999, 999999)

## O tile adjacente a `target` de onde `unit` o ataca depois de se mover (Carga), dentro do alcance de movimento `movable` (unit_reachable, pelo perfil da unidade):
## o de menor CUSTO real; no empate de custo, o de menos passos (a rota de verdade); depois a coordenada (q, depois r) — nunca a ordem de Dictionary.
## NO_TILE se nenhum vizinho livre do alvo é alcançável (o alvo, ocupado, nunca está em `movable`).
static func _approach_tile(unit: Unit, target: Unit, movable: Dictionary, grid: HexGrid) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for coord in grid.get_neighbors(target.coord):
		if movable.has(coord):
			candidates.append(coord)
	if candidates.is_empty():
		return NO_TILE
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if not is_equal_approx(float(movable[a]), float(movable[b])):
			return float(movable[a]) < float(movable[b])
		return a.x < b.x if a.x != b.x else a.y < b.y)
	var best_cost := float(movable[candidates[0]])
	var tied: Array[Vector2i] = []
	for coord in candidates:
		if is_equal_approx(float(movable[coord]), best_cost):
			tied.append(coord)
	if tied.size() > 1 and unit.unit_data.movement_profile != UnitData.MovementProfile.FLYING:
		var steps: Dictionary = {}
		for coord in tied:
			steps[coord] = grid.compute_path(unit.coord, coord, unit.owner_player, unit.unit_data.flies, unit.embarked).size()
		tied.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			if steps[a] != steps[b]:
				return steps[a] < steps[b]
			return a.x < b.x if a.x != b.x else a.y < b.y)
	return tied[0]

## Por que um golpe sem alvo válido não pode ser usado: sem rota até o alvo, sem espaço (o inimigo já está colado) ou nenhum inimigo ao alcance.
static func _no_target_reason(unit: Unit, technique: V2DoctrineTechniqueData, hex_grid: HexGrid) -> String:
	var grid: HexGrid = hex_grid if hex_grid != null else GameManager.hex_grid # nulo = a partida atual (como em strike_targets): a HUD chama sem grid
	var reach := strike_range_of(unit, technique)
	if technique.repositions() and grid != null:
		var in_reach := false
		for coord in HexMetrics.coords_within(unit.coord, reach):
			if HexMetrics.axial_distance(unit.coord, coord) >= technique.strike_min_range:
				var other := grid.get_unit_at(coord)
				if other != null and other.hp > 0.0 and CombatResolver.can_attack_unit(unit, other, grid):
					in_reach = true
					break
		if in_reach:
			return "Sem rota até um tile adjacente ao alvo."
		if technique.strike_min_range > 1:
			for coord in grid.get_neighbors(unit.coord):
				var adjacent := grid.get_unit_at(coord)
				if adjacent != null and adjacent.hp > 0.0 and CombatResolver.can_attack_unit(unit, adjacent, grid):
					return "Requer espaço para realizar a %s." % technique.display_name
	return "Nenhum inimigo adjacente." if reach <= 1 else "Nenhum inimigo ao alcance."

# --- Ataque de Cerco contra CIDADE/FORTIFICAÇÃO (Bombardeio Preparado — Fase 11) -----------------------------------------------------

## As cidades HOSTIS que a técnica de ATAQUE DE CERCO `technique` pode mirar a partir de `unit` AGORA: dentro do alcance dela
## (mesmo `strike_range_of`/ATTACK_RANGE_PLUS reutilizado dos golpes unidade-contra-unidade), pela MESMA regra de hostilidade
## de cidade que o ataque comum já usa (CombatResolver.can_attack_city — dono diferente + guerra) e visível ao dono humano
## nas mesmas condições de qualquer técnica de alcance > 1 (_visible_to_owner). Nunca unidade, aliado, cidade em paz nem
## covil (get_city_at só resolve tile de CENTRO de cidade — a mesma semântica do ataque básico contra cidade).
static func city_strike_targets(unit: Unit, technique: V2DoctrineTechniqueData, hex_grid: HexGrid = null) -> Array[City]:
	var result: Array[City] = []
	var grid: HexGrid = hex_grid if hex_grid != null else GameManager.hex_grid
	if unit == null or grid == null or technique == null or not technique.is_city_strike():
		return result
	var reach := strike_range_of(unit, technique)
	var coords: Array[Vector2i] = grid.get_neighbors(unit.coord) if reach <= 1 else HexMetrics.coords_within(unit.coord, reach)
	for coord in coords:
		var city := grid.get_city_at(coord)
		if city != null and CombatResolver.can_attack_city(unit, city) and (reach <= 1 or _visible_to_owner(unit, coord, grid)):
			result.append(city)
	result.sort_custom(func(a: City, b: City) -> bool:
		return a.coord.x < b.coord.x if a.coord.x != b.coord.x else a.coord.y < b.coord.y)
	return result

## Executa a técnica de ATAQUE DE CERCO `technique_id` de `unit` contra `target_city`: usa o MESMO CombatResolver.
## resolve_city_attack de sempre (escudo, vida, captura, resposta, Munição Demolidora) com o multiplicador do golpe da
## técnica (strike_multiplier) por cima do bônus inato de Cerco — nunca uma segunda fórmula. Grava a recarga e gasta a
## ação ANTES de resolver (mesmo padrão de perform_strike). false, sem alterar nada, se não puder ou o alvo for inválido.
static func perform_city_strike(unit: Unit, technique_id: String, target_city: City, hex_grid: HexGrid = null) -> bool:
	var technique := V2DoctrineTechniqueDatabase.get_technique(technique_id)
	if technique == null or not technique.is_city_strike() or not can_use(unit, technique_id, hex_grid):
		return false
	var grid: HexGrid = hex_grid if hex_grid != null else GameManager.hex_grid
	if target_city == null or not (target_city in city_strike_targets(unit, technique, grid)):
		return false
	unit.magic_cooldowns[technique.id] = TurnManager.turn_number + technique.cooldown_turns
	unit.fortified = false
	unit.exploring = false
	unit.move_order_target = Unit.NO_MOVE_ORDER
	CombatResolver.resolve_city_attack(unit, target_city, grid, 1.0, technique.strike_multiplier)
	unit.movement_left = 0.0
	return true

## Multiplicador de ataque de CERCO contra CIDADE/FORTIFICAÇÃO vindo de Técnicas PASSIVAS (Fase 11, Munição Demolidora), 1.0
## se nenhuma. Mesmo princípio do attack_multiplier unidade-contra-unidade (mais abaixo neste arquivo), mas só entra em
## CombatResolver.resolve_city_attack — NUNCA em resolve_lair_attack (covil não é cidade, ver auditoria da Fase 11 seção 61)
## nem em combate unidade-contra-unidade. DERIVADO: vale se o dono pesquisou o nó e a unidade é da linha da técnica — nada
## guardado, nunca duplicado (mesma técnica conta uma vez; técnicas diferentes multiplicariam entre si).
static func city_attack_multiplier(unit: Unit) -> float:
	if unit == null or unit.owner_player == null or unit.unit_data == null:
		return 1.0
	if not V2ResearchDatabase.is_v2_id(unit.unit_data.visual_kind):
		return 1.0
	var branch := V2UnitLine.doctrine_branch_of(unit.unit_data.visual_kind)
	if branch == "":
		return 1.0
	var result := 1.0
	for technique in V2DoctrineTechniqueDatabase.city_attack_bonus_techniques():
		if technique.doctrine_branch == branch and V2UnlockSystem.is_unlocked(unit.owner_player, technique.id):
			result *= 1.0 + technique.city_attack_bonus
	return result

# --- Reposicionamento por tile (Retirada Tática — Fase 9) -------------------------------------------------------------------------------

## Os tiles onde `technique` (reposicionamento) pode levar `unit` AGORA: livres, alcançáveis em até `relocate_range` passos pelo PERFIL de movimento da
## unidade (terrestre: custo plano por passo se `relocate_flat_cost`, terreno impassável e ocupação valendo; voo: distância geométrica, sobre qualquer
## terreno) e legais para terminar. Ordem estável (custo, q, r). Só o raio da técnica é examinado.
static func relocation_tiles(unit: Unit, technique: V2DoctrineTechniqueData, hex_grid: HexGrid = null) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var grid: HexGrid = hex_grid if hex_grid != null else GameManager.hex_grid
	if unit == null or grid == null or technique == null or not technique.is_relocation():
		return result
	var reach := grid.unit_reachable(unit, float(technique.relocate_range), technique.relocate_flat_cost)
	for coord in reach.keys():
		result.append(coord)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if not is_equal_approx(float(reach[a]), float(reach[b])):
			return float(reach[a]) < float(reach[b])
		return a.x < b.x if a.x != b.x else a.y < b.y)
	return result

## Executa o reposicionamento: leva `unit` a `dest` (precisa estar em relocation_tiles) e aplica o efeito de postura da técnica (o mesmo `magic_status` da
## Muralha), a recarga e o gasto da ação. false, sem alterar nada, se não puder ou se o destino for inválido.
static func relocate(unit: Unit, technique_id: String, dest: Vector2i, hex_grid: HexGrid = null) -> bool:
	var technique := V2DoctrineTechniqueDatabase.get_technique(technique_id)
	if technique == null or not technique.is_relocation() or not can_use(unit, technique_id, hex_grid):
		return false
	var grid: HexGrid = hex_grid if hex_grid != null else GameManager.hex_grid
	if not (dest in relocation_tiles(unit, technique, grid)):
		return false
	grid.move_unit(unit, dest, 0.0) # deslocamento real (o custo é a ação da técnica, gasta em _commit_activation)
	_commit_activation(unit, technique)
	return true

## Os tiles que a mira da técnica destaca para `unit` AGORA: os alvos de um golpe (unidade OU cidade — Fase 11) ou os tiles de um reposicionamento.
static func target_coords(unit: Unit, technique: V2DoctrineTechniqueData, hex_grid: HexGrid = null) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if technique == null:
		return result
	if technique.is_relocation():
		return relocation_tiles(unit, technique, hex_grid)
	if technique.is_city_strike():
		for city in city_strike_targets(unit, technique, hex_grid):
			result.append(city.coord)
		return result
	for target in strike_targets(unit, technique, hex_grid):
		result.append(target.coord)
	return result

## O ponto de entrada único da confirmação da mira: `coord` é o tile escolhido (a unidade/cidade-alvo está nele nos golpes; ele próprio no reposicionamento).
## NO_TILE nas técnicas sem mira. false, sem alterar nada, se a técnica ou o alvo forem inválidos.
static func perform_targeted(unit: Unit, technique_id: String, coord: Vector2i, hex_grid: HexGrid = null) -> bool:
	var technique := V2DoctrineTechniqueDatabase.get_technique(technique_id)
	if technique == null:
		return false
	var grid: HexGrid = hex_grid if hex_grid != null else GameManager.hex_grid
	if technique.is_relocation():
		return relocate(unit, technique_id, coord, grid)
	if technique.is_city_strike():
		var target_city: City = grid.get_city_at(coord) if (grid != null and coord != NO_TILE) else null
		return perform_city_strike(unit, technique_id, target_city, grid)
	if technique.is_strike():
		var target: Unit = grid.get_unit_at(coord) if (grid != null and coord != NO_TILE) else null
		return perform_strike(unit, technique_id, target, grid)
	return false

# --- Defesa (chamado por CombatResolver.predict) ------------------------------------------------

## Multiplicador de Defesa de `defender` vindo de Técnicas Militares, 1.0 se nenhum.
## Por formação: consulta a unidade e os vizinhos NA HORA (no máximo 6 tiles) — o aliado
## que se afasta perde o bônus sozinho. NÃO acumula dentro da mesma técnica: vale só o
## maior bônus aplicável (o próprio +35% OU o +15% de aliado adjacente, nunca a soma nem
## dois +15%). Técnicas diferentes multiplicariam entre si (só existe uma hoje).
## Caminho quente (roda em toda previsão de combate): a busca por aliado adjacente só
## acontece se o DONO tem a técnica pesquisada — sem isso ninguém dele pode estar com ela
## ativa, então a partida V1 (e a V2 antes do N4) não paga o scan de vizinhos.
static func defense_multiplier(defender: Unit, hex_grid: HexGrid) -> float:
	if defender == null or defender.owner_player == null:
		return 1.0
	var result := 1.0
	for technique in V2DoctrineTechniqueDatabase.defensive_techniques():
		var best := 0.0
		if is_active(defender, technique.id):
			best = maxf(best, technique.self_defense_bonus)
		if technique.adjacent_ally_defense_bonus > best and hex_grid != null and V2UnlockSystem.is_unlocked(defender.owner_player, technique.id) and _ally_projects(defender, technique, hex_grid):
			best = technique.adjacent_ally_defense_bonus
		result *= 1.0 + best
	return result

## Algum ALIADO (mesmo dono, outra unidade viva) num tile a até `adjacent_radius` de
## `defender` está com `technique` ativa?
static func _ally_projects(defender: Unit, technique: V2DoctrineTechniqueData, hex_grid: HexGrid) -> bool:
	var neighbors: Array = hex_grid.get_neighbors(defender.coord) if technique.adjacent_radius <= 1 else hex_grid.tiles_in_range(defender.coord, technique.adjacent_radius)
	for coord in neighbors:
		var ally := hex_grid.get_unit_at(coord)
		if ally != null and ally != defender and ally.hp > 0.0 and ally.owner_player == defender.owner_player and is_active(ally, technique.id):
			return true
	return false

# --- Ataque (chamado por UnitAbilities.attack_multiplier) ----------------------------------------------------

## Multiplicador do ATAQUE BÁSICO de `attacker` contra `defender` vindo de Técnicas PASSIVAS, 1.0 se
## nenhum. DERIVADO: vale se o dono do atacante pesquisou o nó da técnica, a unidade é da linha e o
## alvo tem QUALQUER UM dos traços declarados pela técnica (UnitData.traits; Fase 10: uma lista, não
## mais um único traço — "caster" OU "siege" contam UMA vez, nunca a soma) — nada é guardado, então
## save/load, unidades antigas e a IA funcionam sem passo extra, e resetar a pesquisa remove o efeito.
## Por técnica vale UMA vez; técnicas diferentes multiplicariam entre si. Só o ataque básico: dano de
## cidade, feitiço e efeito de mapa não passam por aqui.
## Caminho quente (toda previsão de combate): a unidade que não é V2 sai na 1ª comparação.
static func attack_multiplier(attacker: Unit, defender: Unit) -> float:
	if attacker == null or defender == null or attacker.owner_player == null or attacker.unit_data == null or defender.unit_data == null:
		return 1.0
	if not V2ResearchDatabase.is_v2_id(attacker.unit_data.visual_kind):
		return 1.0
	var branch := V2UnitLine.doctrine_branch_of(attacker.unit_data.visual_kind)
	if branch == "":
		return 1.0
	var result := 1.0
	for technique in V2DoctrineTechniqueDatabase.attack_bonus_techniques():
		if technique.doctrine_branch == branch and V2UnlockSystem.is_unlocked(attacker.owner_player, technique.id) and _has_any_trait(defender.unit_data, technique.basic_attack_target_traits):
			result *= 1.0 + technique.basic_attack_bonus
	return result

## O alvo tem QUALQUER UM dos traços da lista? (Uma única checagem "OR" reutilizada por attack_multiplier.)
static func _has_any_trait(data: UnitData, target_traits: Array[String]) -> bool:
	for trait_id in target_traits:
		if data.has_trait(trait_id):
			return true
	return false

# --- Texto de UI (painel da unidade / inspeção) -----------------------------------------------------

## Linhas de técnicas ATIVAS em `unit` (visíveis a qualquer observador).
static func status_lines(unit: Unit) -> Array[String]:
	var lines: Array[String] = []
	if unit == null or unit.magic_status.is_empty():
		return lines
	for technique in V2DoctrineTechniqueDatabase.all_techniques():
		if is_active(unit, technique.id):
			lines.append("%s — Ativa (até o início do próximo turno)" % technique.display_name)
	return lines

## Linhas das técnicas PASSIVAS de `unit` (só o dono vê: revelar a pesquisa de um rival não faz
## parte do que a unidade mostra). Duas linhas por técnica, como no painel: "Passiva — Preparar
## Lanças" e, abaixo, "+50% de dano de ataque básico contra unidades montadas." (curtas: cabem
## na largura do painel da unidade).
static func passive_lines(unit: Unit) -> Array[String]:
	var lines: Array[String] = []
	for technique in passive_techniques_for_unit(unit):
		lines.append("Passiva — %s" % technique.display_name)
		lines.append("%s." % V2DoctrineTechniqueDatabase.passive_effect_text(technique))
	return lines

## Linhas de RECARGA das técnicas de `unit` (só o dono vê).
static func cooldown_lines(unit: Unit) -> Array[String]:
	var lines: Array[String] = []
	if unit == null or unit.magic_cooldowns.is_empty():
		return lines
	for technique in V2DoctrineTechniqueDatabase.all_techniques():
		var remaining := cooldown_remaining(unit, technique.id)
		if remaining > 0:
			lines.append("%s — recarga: %d turno(s)" % [technique.display_name, remaining])
	return lines
