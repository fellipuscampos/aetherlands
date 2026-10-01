class_name MonsterAbilitySystem
extends RefCounted

## V3 / Etapa 2 — runtime COMUM das habilidades de monstro da Combat Ecology (dados em MonsterAbilityData).
## Responsável por: disponibilidade/recarga (`unit.magic_cooldowns`, o mesmo dicionário de feitiços/Técnicas),
## legalidade de alvo, execução, estados (UnitStatusEffects), perigos espaciais (MonsterHazardSystem) e
## telemetria. A MonsterAI DECIDE quando agir (MonsterAI._take_ecology_turn); dano físico continua saindo de
## CombatResolver.predict/resolve/apply_direct_unit_damage — nenhuma fórmula de combate nova.
##
## Só monstros de sítio ecológico usam habilidades: ameaça regional, Guardião Troll e guardiões de evento
## mantêm as regras próprias dos papéis (D2/D3) sem alteração.
##
## O Verme Colossal subterrâneo é o único estado estrutural: sai de HexGrid.units_by_coord (não bloqueia o
## tile nem pode ser alvo), fica nesta lista com destino gravado (telegraph público) e emerge na fase dos
## monstros do turno seguinte, sem redirecionar para onde o alvo foi. Salvo à parte no bloco combat_ecology.

static var burrowed: Array[Unit] = []

static func reset() -> void:
	burrowed = []

# ---------------------------------------------------------------------------
# Consultas comuns
# ---------------------------------------------------------------------------

static func has(unit: Unit, id: String) -> bool:
	return MonsterEcologySystem.is_ecology_unit(unit) and MonsterAbilityData.species_has(unit.unit_data.visual_kind, id)

static func cooldown_remaining(unit: Unit, id: String) -> int:
	return maxi(0, int(unit.magic_cooldowns.get(id, 0)) - TurnManager.turn_number)

static func is_ready(unit: Unit, id: String) -> bool:
	return has(unit, id) and cooldown_remaining(unit, id) == 0

static func _start_cooldown(unit: Unit, id: String) -> void:
	var turns := int(MonsterAbilityData.param(id, "cooldown", 0))
	if turns > 0:
		unit.magic_cooldowns[id] = TurnManager.turn_number + turns

static func is_burrowed(unit: Unit) -> bool:
	return unit != null and bool(unit.ability_state.get("burrowed", false))

## Destinos dos Vermes subterrâneos (telegraph público).
static func telegraph_coords() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for worm in burrowed:
		if is_instance_valid(worm):
			result.append(_coord(worm.ability_state.get("dest")))
	return result

## Alvo de habilidade legítimo: unidade de civilização viva, fora de cidade (nunca cerco automático).
static func is_target(unit: Unit, grid: HexGrid) -> bool:
	return unit != null and is_instance_valid(unit) and unit.owner_player != null and unit.hp > 0.0 and grid.get_city_at(unit.coord) == null

static func _civ_units_near(grid: HexGrid, center: Vector2i, radius: int) -> Array[Unit]:
	var result: Array[Unit] = []
	for coord in [center] + HexMetrics.coords_within(center, radius):
		var other := grid.get_unit_at(coord)
		if is_target(other, grid):
			result.append(other)
	result.sort_custom(func(a: Unit, b: Unit) -> bool: return a.coord.x < b.coord.x if a.coord.x != b.coord.x else a.coord.y < b.coord.y)
	return result

static func _emit(action: String, unit: Unit, extra: Dictionary) -> void:
	MonsterEcologySystem.emit_unit_event(action, unit, extra)

static func _damage(source: Unit, victim: Unit, grid: HexGrid, multiplier: float) -> Dictionary:
	var prediction := CombatResolver.predict(source, victim, grid)
	var damage := float(prediction.damage_to_defender) * multiplier
	var applied := minf(damage, victim.hp)
	var killed := CombatResolver.apply_direct_unit_damage(source, victim, damage, grid)
	return {"damage": applied, "killed": killed}

# ---------------------------------------------------------------------------
# Início do turno do monstro (passivas)
# ---------------------------------------------------------------------------

## Regeneração Monstruosa (Troll): sem dano real desde a checagem anterior → +10% da Vida máxima.
static func on_turn_start(unit: Unit, grid: HexGrid) -> void:
	if not has(unit, MonsterAbilityData.MONSTROUS_REGENERATION):
		return
	if not unit.took_damage_since_regen and unit.hp < unit.unit_data.max_hp:
		var amount := minf(unit.unit_data.max_hp * float(MonsterAbilityData.param(MonsterAbilityData.MONSTROUS_REGENERATION, "fraction", 0.1)), unit.unit_data.max_hp - unit.hp)
		unit.hp += amount
		grid.spawn_heal_popup(unit.coord, amount)
		_emit("ability", unit, {"ability": MonsterAbilityData.MONSTROUS_REGENERATION, "healed": amount})
	unit.took_damage_since_regen = false

## O monstro já agiu neste turno por fora da fila normal (emergiu do subsolo) ou está subterrâneo.
static func skips_turn(unit: Unit, turn: int) -> bool:
	return is_burrowed(unit) or int(unit.ability_state.get("emerged_turn", -1)) == turn

# ---------------------------------------------------------------------------
# Ativas (MonsterAI: uma ação por turno)
# ---------------------------------------------------------------------------

## Tenta a habilidade ativa da espécie. `zone` = raio da âncora em que o monstro pode agir nesta era (alvos fora
## dele nunca são escolhidos). true = usou a ação do turno.
static func try_active(unit: Unit, grid: HexGrid, anchor: Vector2i, zone: int) -> bool:
	if not MonsterEcologySystem.is_ecology_unit(unit):
		return false
	for id in MonsterAbilityData.for_species(unit.unit_data.visual_kind):
		if MonsterAbilityData.param(id, "passive", true) or not is_ready(unit, id):
			continue
		var used := false
		match id:
			MonsterAbilityData.FLAME_BREATH:
				used = _try_breath(unit, grid, anchor, zone)
			MonsterAbilityData.CHARGE:
				used = _try_charge(unit, grid, anchor, zone)
			MonsterAbilityData.PETRIFYING_GAZE:
				used = _try_gaze(unit, grid, anchor, zone)
			MonsterAbilityData.BURROW:
				used = _try_burrow(unit, grid, anchor, zone)
			MonsterAbilityData.ROOTS_OF_THE_WORLD:
				used = _try_roots(unit, grid, anchor, zone)
			MonsterAbilityData.AETHER_RUPTURE:
				used = _try_rupture(unit, grid, anchor, zone)
		if used:
			_start_cooldown(unit, id)
			unit.movement_left = 0.0
			return true
	return false

static func _in_ability_range(unit: Unit, target: Unit, id: String, anchor: Vector2i, zone: int) -> bool:
	var distance := HexMetrics.axial_distance(unit.coord, target.coord)
	return distance >= int(MonsterAbilityData.param(id, "min_range", 1)) and distance <= int(MonsterAbilityData.param(id, "max_range", 1)) and HexMetrics.axial_distance(anchor, target.coord) <= zone

static func _is_high_value(target: Unit) -> bool:
	return target.unit_data.can_found_city or V2MagicRuntime.is_v2_caster(target) or target.unit_data.is_caster() or target.unit_data.max_hp >= 20.0

## Sopro Incendiário (Wyvern): alvo a ≤ 2 + até 2 tiles ATRÁS dele (vizinhos do alvo um passo mais longe da Wyvern),
## cone determinístico. Usa com 2+ atingidos, ou 1 de alto valor.
static func breath_area(unit: Unit, primary: Vector2i, grid: HexGrid) -> Array[Vector2i]:
	var distance := HexMetrics.axial_distance(unit.coord, primary)
	var behind: Array[Vector2i] = []
	for neighbor in MonsterEcologyPlanner.sorted_coords(grid.get_neighbors(primary)):
		if HexMetrics.axial_distance(unit.coord, neighbor) == distance + 1:
			behind.append(neighbor)
	# Linha reta tem 3 tiles atrás: fica com os 2 do lado mais próximo da linha central (descarta o último na ordem estável).
	return behind.slice(0, 2)

static func _try_breath(unit: Unit, grid: HexGrid, anchor: Vector2i, zone: int) -> bool:
	var id := MonsterAbilityData.FLAME_BREATH
	var best: Dictionary = {}
	for target in _civ_units_near(grid, unit.coord, int(MonsterAbilityData.param(id, "max_range", 2))):
		if not _in_ability_range(unit, target, id, anchor, zone):
			continue
		var secondary: Array[Unit] = []
		for coord in breath_area(unit, target.coord, grid):
			var other := grid.get_unit_at(coord)
			if is_target(other, grid):
				secondary.append(other)
		var hits := 1 + secondary.size()
		if best.is_empty() or hits > int(best.hits) or (hits == int(best.hits) and target.hp < (best.primary as Unit).hp):
			best = {"primary": target, "secondary": secondary, "hits": hits}
	if best.is_empty() or (int(best.hits) < 2 and not _is_high_value(best.primary)):
		return false
	var total := 0.0
	var kills := 0
	var statuses := 0
	var victims: Array[Unit] = [best.primary]
	victims.append_array(best.secondary)
	for i in victims.size():
		var victim: Unit = victims[i]
		if not is_instance_valid(victim) or victim.hp <= 0.0:
			continue
		var result := _damage(unit, victim, grid, float(MonsterAbilityData.param(id, "primary" if i == 0 else "secondary", 0.6)))
		total += float(result.damage)
		if bool(result.killed):
			kills += 1
		elif UnitStatusEffects.apply(victim, UnitStatusEffects.BURNING, int(MonsterAbilityData.param(id, "turns", 2))):
			statuses += 1
	_emit("ability", unit, {"ability": id, "hits": victims.size(), "damage": total, "kills": kills, "statuses": statuses, "target": GameManager.players.find((best.primary as Unit).owner_player) if is_instance_valid(best.primary) else -1})
	return true

## Investida (Minotauro): alvo a 2–4 em linha hexagonal reta LIVRE (terreno atravessável, sem unidade/cidade/covil
## no caminho — nunca atravessa unidade, nunca teleporta por cima de nada); termina colado e golpeia com 150%;
## empurra 1 tile para longe ou, se o tile está bloqueado, deixa Abalado.
static func charge_landing(unit: Unit, target: Unit, grid: HexGrid) -> Vector2i:
	var line := HexMetrics.axial_line(unit.coord, target.coord)
	if line.size() < 2:
		return HexGrid.NO_LAIR
	for i in range(0, line.size() - 1):
		var coord: Vector2i = line[i]
		var tile := grid.get_tile(coord)
		if tile == null or tile.blocks_land_units() or grid.get_unit_at(coord) != null or grid.get_city_at(coord) != null or grid.lairs_by_coord.has(coord):
			return HexGrid.NO_LAIR
	return line[line.size() - 2]

static func knockback_destination(source: Vector2i, victim: Unit, grid: HexGrid) -> Vector2i:
	var dest := victim.coord + (victim.coord - source)
	var tile := grid.get_tile(dest)
	if HexMetrics.axial_distance(source, victim.coord) != 1 or tile == null or grid.get_unit_at(dest) != null or grid.get_city_at(dest) != null or grid.lairs_by_coord.has(dest):
		return HexGrid.NO_LAIR
	if tile.blocks_land_units() and not victim.unit_data.flies:
		return HexGrid.NO_LAIR
	if victim.embarked:
		return HexGrid.NO_LAIR
	return dest

static func _try_charge(unit: Unit, grid: HexGrid, anchor: Vector2i, zone: int) -> bool:
	var id := MonsterAbilityData.CHARGE
	var best: Unit = null
	var best_landing := HexGrid.NO_LAIR
	var best_score := -INF
	for target in _civ_units_near(grid, unit.coord, int(MonsterAbilityData.param(id, "max_range", 4))):
		if not _in_ability_range(unit, target, id, anchor, zone):
			continue
		var landing := charge_landing(unit, target, grid)
		if landing == HexGrid.NO_LAIR:
			continue
		var score := -target.hp / maxf(target.unit_data.max_hp, 0.001)
		if score > best_score:
			best_score = score
			best = target
			best_landing = landing
	if best == null:
		return false
	grid.teleport_unit(unit, best_landing)
	var owner_index := GameManager.players.find(best.owner_player)
	var hp_before := best.hp
	CombatResolver.resolve(unit, best, grid, float(MonsterAbilityData.param(id, "multiplier", 1.5)))
	var killed := not is_instance_valid(best) or best.hp <= 0.0 or grid.get_unit_at(best.coord) != best
	var outcome := "killed" if killed else ""
	if not killed and is_instance_valid(unit) and unit.hp > 0.0:
		var dest := knockback_destination(unit.coord, best, grid)
		if dest != HexGrid.NO_LAIR:
			grid.teleport_unit(best, dest)
			outcome = "knockback"
		else:
			UnitStatusEffects.apply(best, UnitStatusEffects.STAGGERED, int(MonsterAbilityData.param(id, "turns", 1)))
			outcome = "blocked"
	_emit("ability", unit, {"ability": id, "hits": 1, "damage": hp_before - (best.hp if is_instance_valid(best) and not killed else 0.0), "kills": 1 if killed else 0, "statuses": 1 if outcome == "blocked" else 0, "outcome": outcome, "target": owner_index})
	return true

## Olhar Petrificante (Basilisco): o alvo de maior Ataque a ≤ 2 (de preferência ainda não petrificado).
static func _try_gaze(unit: Unit, grid: HexGrid, anchor: Vector2i, zone: int) -> bool:
	var id := MonsterAbilityData.PETRIFYING_GAZE
	var best: Unit = null
	for target in _civ_units_near(grid, unit.coord, int(MonsterAbilityData.param(id, "max_range", 2))):
		if not _in_ability_range(unit, target, id, anchor, zone):
			continue
		var petrified := UnitStatusEffects.is_active(target, UnitStatusEffects.PETRIFIED)
		if best == null or (not petrified and UnitStatusEffects.is_active(best, UnitStatusEffects.PETRIFIED)) or (petrified == UnitStatusEffects.is_active(best, UnitStatusEffects.PETRIFIED) and target.unit_data.attack > best.unit_data.attack):
			best = target
	if best == null or UnitStatusEffects.is_active(best, UnitStatusEffects.PETRIFIED):
		return false
	UnitStatusEffects.apply(best, UnitStatusEffects.PETRIFIED, int(MonsterAbilityData.param(id, "turns", 1)))
	_emit("ability", unit, {"ability": id, "hits": 1, "statuses": 1, "target": GameManager.players.find(best.owner_player)})
	return true

## Ruptura Etérea (Devorador de Mana): só contra conjurador a ≤ 2 — dano mágico de 80% do Ataque (ignora Defesa) e
## Silenciado por 1 turno. Sem conjurador, o Devorador usa o ataque normal.
static func _is_caster(target: Unit) -> bool:
	return V2MagicRuntime.is_v2_caster(target) or target.unit_data.is_caster()

static func _try_rupture(unit: Unit, grid: HexGrid, anchor: Vector2i, zone: int) -> bool:
	var id := MonsterAbilityData.AETHER_RUPTURE
	var best: Unit = null
	for target in _civ_units_near(grid, unit.coord, int(MonsterAbilityData.param(id, "max_range", 2))):
		if _is_caster(target) and _in_ability_range(unit, target, id, anchor, zone) and (best == null or target.hp < best.hp):
			best = target
	if best == null:
		return false
	var owner_index := GameManager.players.find(best.owner_player)
	var damage := unit.unit_data.attack * float(MonsterAbilityData.param(id, "multiplier", 0.8))
	var applied := minf(damage, best.hp)
	var killed := CombatResolver.apply_direct_unit_damage(unit, best, damage, grid)
	var silenced := not killed and UnitStatusEffects.apply(best, UnitStatusEffects.SILENCED, int(MonsterAbilityData.param(id, "turns", 1)))
	_emit("ability", unit, {"ability": id, "hits": 1, "damage": applied, "kills": 1 if killed else 0, "statuses": 1 if silenced else 0, "target": owner_index})
	return true

## Raízes do Mundo (Ancião Arbóreo): com unidade de civilização a ≤ 2, ergue até 4 tiles de raízes a ≤ 2 do Ancião
## (primeiro os ocupados por unidades de civilização, depois os mais próximos delas) por 3 rodadas; quem estiver
## em cima fica Enraizado. Nunca em cidade nem água.
static func _try_roots(unit: Unit, grid: HexGrid, anchor: Vector2i, zone: int) -> bool:
	var id := MonsterAbilityData.ROOTS_OF_THE_WORLD
	var radius := int(MonsterAbilityData.param(id, "max_range", 2))
	var targets: Array[Unit] = []
	for target in _civ_units_near(grid, unit.coord, radius):
		if HexMetrics.axial_distance(anchor, target.coord) <= zone:
			targets.append(target)
	if targets.is_empty():
		return false
	var candidates: Array[Vector2i] = []
	for coord in HexMetrics.coords_within(unit.coord, radius):
		var tile := grid.get_tile(coord)
		if tile == null or tile.blocks_land_units() or grid.get_city_at(coord) != null:
			continue
		candidates.append(coord)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := _nearest_distance(a, targets)
		var db := _nearest_distance(b, targets)
		if da != db:
			return da < db
		return a.x < b.x if a.x != b.x else a.y < b.y)
	var chosen := candidates.slice(0, int(MonsterAbilityData.param(id, "zones", 4)))
	var zones: Array[Vector2i] = []
	for coord in chosen:
		zones.append(coord)
	MonsterHazardSystem.add_roots(grid, zones, int(MonsterAbilityData.param(id, "rounds", 3)))
	var rooted := 0
	for coord in zones:
		var victim := grid.get_unit_at(coord)
		if is_target(victim, grid) and UnitStatusEffects.apply(victim, UnitStatusEffects.ROOTED, int(MonsterAbilityData.param(id, "turns", 1))):
			rooted += 1
	_emit("ability", unit, {"ability": id, "hits": rooted, "zones": zones.size(), "statuses": rooted, "target": GameManager.players.find(targets[0].owner_player)})
	return true

static func _nearest_distance(coord: Vector2i, units: Array[Unit]) -> int:
	var best := 999999
	for other in units:
		best = mini(best, HexMetrics.axial_distance(coord, other.coord))
	return best

## Escavar (Verme Colossal): com alvo a ≤ 6 (preferindo o tile com mais unidades de civilização ao redor), mergulha:
## sai do mapa de unidades (não bloqueia o tile, não é alvo), grava o destino = posição ATUAL do alvo e mostra o
## Rastro Subterrâneo ali. Emerge na fase dos monstros do turno seguinte (process_round).
static func _try_burrow(unit: Unit, grid: HexGrid, anchor: Vector2i, zone: int) -> bool:
	var id := MonsterAbilityData.BURROW
	var best: Unit = null
	var best_cluster := 0
	for target in _civ_units_near(grid, unit.coord, int(MonsterAbilityData.param(id, "max_range", 6))):
		if not _in_ability_range(unit, target, id, anchor, zone):
			continue
		var cluster := _civ_units_near(grid, target.coord, 1).size()
		if best == null or cluster > best_cluster or (cluster == best_cluster and HexMetrics.axial_distance(unit.coord, target.coord) < HexMetrics.axial_distance(unit.coord, best.coord)):
			best = target
			best_cluster = cluster
	if best == null:
		return false
	var dest := best.coord
	if grid.get_unit_at(unit.coord) == unit:
		grid.units_by_coord.erase(unit.coord)
	unit.visible = false
	unit.ability_state = {"burrowed": true, "dest": [dest.x, dest.y], "burrow_turn": TurnManager.turn_number}
	if not unit in burrowed:
		burrowed.append(unit)
	MonsterHazardSystem.set_telegraph(grid, dest, true)
	_emit("ability", unit, {"ability": id, "stage": "burrow", "cluster": best_cluster, "target": GameManager.players.find(best.owner_player)})
	return true

## Fase dos monstros (MonsterEcologySystem.process_round): todo Verme que mergulhou num turno ANTERIOR emerge no destino
## gravado (ou no tile livre mais próximo, raio ≤ 2); sem tile legal, espera mais uma rodada. Impacto: 120% em quem
## está NO destino, 80% em quem está colado ao Verme; sobreviventes colados são empurrados 1 tile quando legal.
static func process_round(grid: HexGrid, turn: int) -> void:
	for worm in burrowed.duplicate():
		if not is_instance_valid(worm):
			burrowed.erase(worm)
			continue
		if int(worm.ability_state.get("burrow_turn", turn)) < turn:
			_emerge(worm, grid, turn)

static func _emerge_tile(grid: HexGrid, dest: Vector2i) -> Vector2i:
	var rings: Array = [[dest]]
	rings.append(MonsterEcologyPlanner.sorted_coords(grid.get_neighbors(dest)))
	var second: Array[Vector2i] = []
	for coord in HexMetrics.coords_within(dest, 2):
		if HexMetrics.axial_distance(dest, coord) == 2:
			second.append(coord)
	rings.append(MonsterEcologyPlanner.sorted_coords(second))
	for ring in rings:
		for coord in ring:
			var tile := grid.get_tile(coord)
			if tile != null and not tile.blocks_land_units() and grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null and not grid.lairs_by_coord.has(coord):
				return coord
	return HexGrid.NO_LAIR

static func _emerge(worm: Unit, grid: HexGrid, turn: int) -> void:
	var id := MonsterAbilityData.BURROW
	var dest := _coord(worm.ability_state.get("dest"))
	var tile := _emerge_tile(grid, dest)
	if tile == HexGrid.NO_LAIR:
		return
	burrowed.erase(worm)
	MonsterHazardSystem.set_telegraph(grid, dest, false)
	worm.coord = tile
	worm.position = grid.world_surface_for_coord(tile)
	grid.units_by_coord[tile] = worm
	worm.visible = grid.visibility.is_empty() or grid.visibility.get(tile, HexGrid.Visibility.UNSEEN) == HexGrid.Visibility.VISIBLE
	worm.ability_state = {"emerged_turn": turn}
	worm.movement_left = 0.0
	_start_cooldown(worm, id)
	var hits := 0
	var total := 0.0
	var kills := 0
	var impact := grid.get_unit_at(dest) if tile != dest else null
	var victims: Array[Unit] = []
	if is_target(impact, grid):
		victims.append(impact)
	for neighbor in MonsterEcologyPlanner.sorted_coords(grid.get_neighbors(tile)):
		var other := grid.get_unit_at(neighbor)
		if is_target(other, grid) and not other in victims:
			victims.append(other)
	var owner_index := GameManager.players.find(victims[0].owner_player) if not victims.is_empty() else -1
	for victim in victims:
		if not is_instance_valid(victim) or victim.hp <= 0.0:
			continue
		var result := _damage(worm, victim, grid, float(MonsterAbilityData.param(id, "impact" if victim == impact else "splash", 0.8)))
		hits += 1
		total += float(result.damage)
		if bool(result.killed):
			kills += 1
		elif HexMetrics.axial_distance(tile, victim.coord) == 1:
			var push := knockback_destination(tile, victim, grid)
			if push != HexGrid.NO_LAIR:
				grid.teleport_unit(victim, push)
	_emit("ability", worm, {"ability": id, "stage": "emerge", "hits": hits, "damage": total, "kills": kills, "target": owner_index})

# ---------------------------------------------------------------------------
# Passivas disparadas por eventos
# ---------------------------------------------------------------------------

## Depois de um ataque comum do monstro (MonsterAI): Picada Venenosa envenena quem levou dano e sobreviveu.
static func after_attack(unit: Unit, target: Unit, target_hp_before: float) -> void:
	if not has(unit, MonsterAbilityData.VENOMOUS_BITE) or target == null or not is_instance_valid(target) or target.hp <= 0.0 or target.hp >= target_hp_before:
		return
	var id := MonsterAbilityData.VENOMOUS_BITE
	if UnitStatusEffects.apply(target, UnitStatusEffects.POISON, int(MonsterAbilityData.param(id, "turns", 3))):
		_emit("ability", unit, {"ability": id, "hits": 1, "statuses": 1, "target": GameManager.players.find(target.owner_player)})

## Saque Rápido (Goblin): golpe numa cidade durante um raide rouba até 8 Ouro (nunca negativo; o Ouro some).
static func on_city_hit(unit: Unit, city: City) -> float:
	if not has(unit, MonsterAbilityData.QUICK_PLUNDER) or city == null or city.owner_player == null:
		return 0.0
	var stolen := minf(float(MonsterAbilityData.param(MonsterAbilityData.QUICK_PLUNDER, "gold", 8.0)), maxf(city.owner_player.gold, 0.0))
	city.owner_player.gold -= stolen
	_emit("ability", unit, {"ability": MonsterAbilityData.QUICK_PLUNDER, "hits": 1, "gold_stolen": stolen, "target": GameManager.players.find(city.owner_player)})
	if city.owner_player == GameManager.human_player and stolen > 0.0:
		EventBus.notify.emit("Goblins saquearam %d Ouro de %s!" % [int(stolen), city.city_name], "combat")
	return stolen

## Horda Crescente (Esqueleto): ao matar uma unidade de civilização, ergue 1 Esqueleto num vizinho livre do
## matador — no máximo 1 por sítio por rodada e 6 vivos por sítio; nunca em cidade/unidade; sem cadeia.
static func on_civ_unit_killed(killer: Unit, grid: HexGrid) -> void:
	if grid == null or not has(killer, MonsterAbilityData.RISING_HORDE):
		return
	var id := MonsterAbilityData.RISING_HORDE
	var site := MonsterEcologySystem.site_for_unit(killer)
	var turn := TurnManager.turn_number
	if site.is_empty() or int(site.get("raised_turn", -1)) == turn:
		return
	if MonsterEcologySystem.site_population(grid, int(site.id)) >= int(MonsterAbilityData.param(id, "site_cap", 6)):
		return
	for coord in MonsterEcologyPlanner.sorted_coords(grid.get_neighbors(killer.coord)):
		var tile := grid.get_tile(coord)
		if tile == null or tile.blocks_land_units() or grid.get_unit_at(coord) != null or grid.get_city_at(coord) != null or grid.lairs_by_coord.has(coord):
			continue
		var raised := grid.spawn_monster_at(coord, "skeleton")
		raised.ecology_site_id = int(site.id)
		raised.movement_left = 0.0
		if site.lair != HexGrid.NO_LAIR:
			raised.source_lair_coord = site.lair
		site.raised_turn = turn
		_emit("ability", killer, {"ability": id, "hits": 1, "raised": 1, "site_population": MonsterEcologySystem.site_population(grid, int(site.id))})
		return

## Fome Arcana (Devorador de Mana): depois que um feitiço de civilização RESOLVE (V2MagicRuntime.cast), cada
## Devorador a ≤ 3 do conjurador que ainda não reagiu nesta rodada drena até 6 Mana do reino do conjurador (nunca
## negativo; nunca Ouro/Conhecimento) e ganha Barreira Arcana do mesmo valor (teto 15% da Vida máxima).
static func on_spell_cast(caster: Unit, grid: HexGrid) -> void:
	if caster == null or caster.owner_player == null or grid == null:
		return
	var id := MonsterAbilityData.ARCANE_HUNGER
	var aura := int(MonsterAbilityData.param(id, "max_range", 3))
	var turn := TurnManager.turn_number
	var devourers: Array[Unit] = []
	for coord in [caster.coord] + HexMetrics.coords_within(caster.coord, aura):
		var other := grid.get_unit_at(coord)
		if other != null and has(other, id) and int(other.ability_state.get("hunger_turn", -1)) != turn:
			devourers.append(other)
	devourers.sort_custom(func(a: Unit, b: Unit) -> bool: return a.serial_id < b.serial_id)
	for devourer in devourers:
		devourer.ability_state["hunger_turn"] = turn
		var player := caster.owner_player
		var drained := minf(float(MonsterAbilityData.param(id, "mana", 6.0)), maxf(player.mana, 0.0))
		player.mana -= drained
		var cap := devourer.unit_data.max_hp * float(MonsterAbilityData.param(id, "barrier_cap", 0.15))
		var gained := minf(drained, maxf(cap - devourer.arcane_barrier, 0.0))
		devourer.arcane_barrier += gained
		_emit("ability", devourer, {"ability": id, "hits": 1, "mana_drained": drained, "barrier": gained, "target": GameManager.players.find(player)})

# ---------------------------------------------------------------------------
# Persistência dos Vermes subterrâneos (o resto do estado viaja com a unidade)
# ---------------------------------------------------------------------------

static func to_save_array() -> Array:
	var result: Array = []
	for worm in burrowed:
		if not is_instance_valid(worm):
			continue
		result.append({
			"kind": worm.unit_data.visual_kind, "serial_id": worm.serial_id, "coord": [worm.coord.x, worm.coord.y], "hp": worm.hp,
			"site": worm.ecology_site_id, "state": worm.ability_state.duplicate(true), "cooldowns": worm.magic_cooldowns.duplicate(),
			"barrier": worm.arcane_barrier, "kills": worm.kills, "veterancy_level": worm.veterancy_level,
		})
	return result

## Load: recria cada Verme subterrâneo FORA do mapa de unidades (nunca emerge no load) e o telegraph.
static func load_save_array(data: Variant, grid: HexGrid) -> void:
	reset()
	if typeof(data) != TYPE_ARRAY or grid == null:
		return
	for entry in data:
		if typeof(entry) != TYPE_DICTIONARY or not MonsterEcologyData.is_ecology_species(String(entry.get("kind", ""))):
			continue
		var worm := grid.spawn_monster_detached(_coord(entry.get("coord")), String(entry.kind))
		worm.set_hp_silent(float(entry.get("hp", worm.unit_data.max_hp)))
		worm.ecology_site_id = int(entry.get("site", -1))
		worm.kills = int(entry.get("kills", 0))
		worm.veterancy_level = int(entry.get("veterancy_level", 0))
		worm.arcane_barrier = float(entry.get("barrier", 0.0))
		if typeof(entry.get("state")) == TYPE_DICTIONARY:
			worm.ability_state = (entry.state as Dictionary).duplicate(true)
		if typeof(entry.get("cooldowns")) == TYPE_DICTIONARY:
			for key in entry.cooldowns:
				worm.magic_cooldowns[String(key)] = int(entry.cooldowns[key])
		worm.ability_state["burrowed"] = true
		worm.visible = false
		burrowed.append(worm)

static func _coord(value: Variant) -> Vector2i:
	if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return HexGrid.NO_LAIR
