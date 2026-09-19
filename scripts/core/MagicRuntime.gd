class_name MagicRuntime
extends RefCounted

const INVALID := Vector2i(999999, 999999)
const UNDEAD := ["bound_skeleton", "grave_guardian", "elder_lich"]
const DEMONS := ["archdemon", "lesser_demon"]

static func coord_of(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))

static func packed(coord: Vector2i) -> Array:
	return [coord.x, coord.y]

static func status_active(unit: Unit, effect: String) -> bool:
	return int(unit.magic_status.get(effect, 0)) > TurnManager.turn_number

static func unit_by_id(player: PlayerData, id: int) -> Unit:
	for unit in player.units:
		if is_instance_valid(unit) and unit.serial_id == id and unit.hp > 0:
			return unit
	return null

static func eligible_caster(unit: Unit, spell: SpellData) -> bool:
	return unit.hp > 0 and unit.unit_data.magic_school == spell.school and unit.ritual_id == "" and not status_active(unit, "silence") and int(unit.magic_cooldowns.get(spell.name, 0)) <= TurnManager.turn_number and unit.movement_left > 0

static func caster_for(player: PlayerData, spell: SpellData, target: Vector2i = INVALID, preferred: Unit = null) -> Unit:
	if preferred and preferred.owner_player == player and eligible_caster(preferred, spell):
		if target == INVALID or HexMetrics.axial_distance(preferred.coord, target) <= spell.cast_range:
			return preferred
	if preferred != null:
		return null
	for unit in player.units:
		if eligible_caster(unit, spell) and (target == INVALID or HexMetrics.axial_distance(unit.coord, target) <= spell.cast_range):
			return unit
	return null

static func reason(player: PlayerData, spell: SpellData, grid: HexGrid, preferred: Unit = null) -> String:
	if not spell.name in MagicDatabase.unlocked_spells_for(player.researched_magic):
		return "Pesquisa necessária"
	if spell.category == "ritual":
		return ritual_reason(player, spell, grid)
	if player.mana < SpellManager.effective_mana_cost(spell, player, grid):
		return "Mana insuficiente"
	if caster_for(player, spell, INVALID, preferred) == null:
		return "Requer conjurador %s livre, com ação e sem recarga" % MagicContent.SCHOOLS[spell.school].name
	return ""

static func hostile(player: PlayerData, unit: Unit) -> bool:
	return unit != null and unit.owner_player != player and (unit.owner_player == null or player.is_at_war_with(unit.owner_player))

static func anchor_valid(player: PlayerData, coord: Vector2i, grid: HexGrid) -> bool:
	var city := grid.city_owning_tile(coord)
	if city == null or city.owner_player != player:
		return false
	var tile := grid.get_tile(coord)
	return (tile != null and tile.resource == "mana_node") or (city.buildings.has("convergence_obelisk") and HexMetrics.axial_distance(coord, city.coord) <= 1)

static func valid_terrain(coord: Vector2i, grid: HexGrid) -> bool:
	var tile := grid.get_tile(coord)
	if tile == null or tile.blocks_land_units() or grid.get_city_at(coord) or grid.get_building_at(coord):
		return false
	for player in GameManager.players:
		for region in player.magic_effects:
			for changed in region.get("changes", []):
				if coord_of(changed) == coord:
					return false
	return true

static func valid_target(player: PlayerData, spell: SpellData, coord: Vector2i, grid: HexGrid, caster: Unit = null, visible: Dictionary = {}) -> bool:
	if grid.get_tile(coord) == null:
		return false
	if spell.category == "ritual":
		if spell.effect == "convergence":
			return anchor_valid(player, coord, grid)
		return grid.compute_visible_tiles(player).has(coord) or player.explored_tiles.has(coord) or (player == GameManager.human_player and grid.visibility.get(coord, 0) >= HexGrid.Visibility.EXPLORED)
	if caster == null:
		caster = caster_for(player, spell, coord)
	if visible.is_empty():
		visible = grid.compute_visible_tiles(player)
	if caster == null or HexMetrics.axial_distance(caster.coord, coord) > spell.cast_range or not visible.has(coord):
		return false
	var target := grid.get_unit_at(coord)
	if target and MagicRuntime.concealed(target, player, grid):
		return false
	match spell.effect:
		"heal", "purify": return target != null and target.owner_player == player
		"hellfire", "chain_lightning", "ice_wave": return hostile(player, target)
		"silence": return hostile(player, target) and target.unit_data.magic_school != ""
		"blood_pact": return target == caster
		"blink": return target == null and not grid.get_tile(coord).blocks_land_units() and (grid.get_city_at(coord) == null or grid.get_city_at(coord).owner_player == player)
		"portal": return anchor_valid(player, coord, grid) and coord != caster.coord
		"forest", "mountains": return valid_terrain(coord, grid) and target == null
		"skeleton", "guardian", "beast", "legion":
			if target != null or grid.get_tile(coord).blocks_land_units() or HexMetrics.axial_distance(caster.coord, coord) > 1:
				return false
			var city := grid.get_city_at(coord)
			if city and city.owner_player != player:
				return false
			var kind: String = {"skeleton": "bound_skeleton", "guardian": "grave_guardian", "beast": "woodland_beast", "legion": "bound_skeleton"}[spell.effect]
			var cap := 3 if spell.effect == "skeleton" else 1
			return spell.effect == "legion" or player.units.filter(func(u): return u.summoner_id == caster.serial_id and u.unit_data.visual_kind == kind).size() < cap
	return true

static func cast(player: PlayerData, spell: SpellData, coord: Vector2i, grid: HexGrid, preferred: Unit = null) -> String:
	var blocked := reason(player, spell, grid, preferred)
	if blocked != "":
		return blocked
	if spell.category == "ritual":
		return start_ritual(player, spell, coord, grid)
	var caster := caster_for(player, spell, coord, preferred)
	if not valid_target(player, spell, coord, grid, caster):
		return "Alvo inválido ou fora do alcance do conjurador."
	player.mana -= SpellManager.effective_mana_cost(spell, player, grid)
	caster.magic_cooldowns[spell.name] = TurnManager.turn_number + spell.cooldown_turns
	caster.movement_left = 0
	caster.magic_status["revealed"] = TurnManager.turn_number + 2
	var target := grid.get_unit_at(coord)
	match spell.effect:
		"heal": target.hp = minf(target.unit_data.max_hp, target.hp + target.unit_data.max_hp * 0.3)
		"purify":
			purify(target)
			dispel_hostile_at(player, coord, grid)
		"hellfire":
			var damage := 12.0 * (1.6 if status_active(caster, "blood_pact") else 1.0)
			caster.magic_status.erase("blood_pact")
			for c in [coord] + grid.tiles_in_range(coord, 1):
				var victim := grid.get_unit_at(c)
				if hostile(player, victim):
					deal_damage(player, victim, damage if c == coord else damage / 3.0, grid)
		"blood_pact":
			caster.hp *= 0.7
			caster.magic_status["blood_pact"] = TurnManager.turn_number + 4
		"chain_lightning":
			var victims: Array[Unit] = [target]
			for c in grid.tiles_in_range(coord, 2):
				var victim := grid.get_unit_at(c)
				if hostile(player, victim) and victim != target and victims.size() < 3:
					victims.append(victim)
			for i in range(victims.size()):
				deal_damage(player, victims[i], [9.0, 6.0, 4.0][i], grid)
		"ice_wave":
			for c in [coord] + grid.tiles_in_range(coord, 1):
				var victim := grid.get_unit_at(c)
				if hostile(player, victim):
					victim.magic_status["slow"] = TurnManager.turn_number + 3
					victim.movement_left *= 0.5
					deal_damage(player, victim, 5, grid)
		"silence": target.magic_status["silence"] = TurnManager.turn_number + 3
		"blink": grid.move_unit(caster, coord, 0)
		"skeleton", "guardian", "beast", "legion":
			var kind: String = {"skeleton": "bound_skeleton", "guardian": "grave_guardian", "beast": "woodland_beast", "legion": "bound_skeleton"}[spell.effect]
			var candidates := [coord] + grid.get_neighbors(coord)
			var remaining := 4 if spell.effect == "legion" else 1
			for c in candidates:
				var summoned := summon(player, kind, c, grid, caster.serial_id, TurnManager.turn_number + 8 if spell.effect == "legion" else 0)
				if summoned:
					remaining -= 1
				if remaining == 0:
					break
		_: add_region(player, spell.effect, coord, grid, caster.coord)
	return "%s conjurado por %s." % [spell.name, caster.unit_data.unit_name]

static func summon(player: PlayerData, kind: String, coord: Vector2i, grid: HexGrid, summoner: int = 0, expiration: int = 0) -> Unit:
	var tile := grid.get_tile(coord)
	var city := grid.get_city_at(coord)
	if tile == null or tile.blocks_land_units() or grid.get_unit_at(coord) or (city and city.owner_player != player):
		return null
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), player)
	if unit:
		unit.summoner_id = summoner
		unit.expires_turn = expiration
		unit.movement_left = 0
	return unit

static func deal_damage(player: PlayerData, unit: Unit, damage: float, grid: HexGrid) -> void:
	DragonEvent.record_damage_if_target_is_the_active_dragon(unit, GameManager.players.find(player), minf(unit.hp, damage))
	grid.spawn_damage_popup(unit.coord, damage)
	unit.hp -= damage
	if unit.hp <= 0:
		grid.remove_unit(unit)

static func purify(unit: Unit) -> void:
	for key in ["curse", "slow", "silence", "storm"]:
		unit.magic_status.erase(key)

static func add_region(player: PlayerData, effect: String, center: Vector2i, grid: HexGrid, origin: Vector2i = INVALID) -> void:
	var radius: int = {"consecrate": 2, "aurora": 4, "storm": 2, "cataclysm": 3, "living_land": 4}.get(effect, 1)
	if effect in ["forest", "portal"]:
		radius = 0
	var duration: int = {"curse": 4, "brimstone": 4, "mountains": 4, "aurora": 9, "living_land": 9, "cataclysm": 7}.get(effect, 5)
	var region := {"effect": effect, "center": packed(center), "origin": packed(origin), "radius": radius, "expires": TurnManager.turn_number + duration, "changes": []}
	if effect in ["forest", "mountains", "living_land"]:
		var count := 0
		for c in [center] + grid.tiles_in_range(center, radius):
			if not valid_terrain(c, grid) or grid.get_unit_at(c):
				continue
			if effect == "mountains" and count >= 3:
				break
			if region.changes.any(func(change): return coord_of(change) == c):
				continue
			var old := grid.get_tile(c)
			region.changes.append([c.x, c.y, old.terrain_type, old.resource])
			var mountain: bool = effect == "mountains" or (effect == "living_land" and HexMetrics.axial_distance(center, c) == radius and (c.x + c.y) % 3 == 0)
			grid.transform_tile_terrain(c, HexTileData.TerrainType.MOUNTAINS if mountain else HexTileData.TerrainType.FOREST)
			grid.get_tile(c).resource = old.resource
			count += 1
	player.magic_effects.append(region)
	grid.refresh_magic_overlay(GameManager.human_player)

static func restore_region(region: Dictionary, grid: HexGrid) -> void:
	for changed in region.get("changes", []):
		var coord := coord_of(changed)
		grid.transform_tile_terrain(coord, int(changed[2]))
		grid.get_tile(coord).resource = changed[3]

static func dispel_hostile_at(player: PlayerData, coord: Vector2i, grid: HexGrid) -> void:
	for other in GameManager.players:
		if other == player or not player.is_at_war_with(other):
			continue
		for region in other.magic_effects.duplicate():
			if HexMetrics.axial_distance(coord_of(region.center), coord) <= int(region.radius):
				restore_region(region, grid)
				other.magic_effects.erase(region)

static func ritual_seat(player: PlayerData, spell: SpellData) -> City:
	var required: String = MagicContent.SCHOOLS[spell.school].ritual_building
	var best: City = null
	var best_count := -1
	for city in player.cities:
		if city.buildings.has(required):
			var count := ritualists(player, spell, city).size()
			if count > best_count:
				best = city
				best_count = count
	return best

static func ritualists(player: PlayerData, spell: SpellData, seat: City) -> Array[Unit]:
	var result: Array[Unit] = []
	if seat:
		for unit in player.units:
			if unit.unit_data.magic_school == spell.school and unit.ritual_id == "" and unit.hp > 0 and not status_active(unit, "silence") and HexMetrics.axial_distance(unit.coord, seat.coord) <= 2:
				result.append(unit)
	return result

static func ritual_reason(player: PlayerData, spell: SpellData, _grid: HexGrid) -> String:
	if player.rituals.any(func(r): return r.status == "channeling"):
		return "Já existe um Grande Ritual em canalização"
	if int(player.spell_cooldowns.get(spell.name, 0)) > TurnManager.turn_number:
		return "Grande Ritual em recarga"
	var seat := ritual_seat(player, spell)
	if seat == null:
		return "Requer %s" % MagicContent.SCHOOLS[spell.school].names[7]
	var required := 5 if spell.school == "necromancia" else 4
	if ritualists(player, spell, seat).size() < required:
		return "Requer %d conjuradores da escola a até 2 hexágonos de %s" % [required, seat.city_name]
	if player.mana < spell.mana_cost:
		return "Requer %d mana inicial e 20 mana por turno" % spell.mana_cost
	return ""

static func start_ritual(player: PlayerData, spell: SpellData, target: Vector2i, grid: HexGrid) -> String:
	if not spell.name in MagicDatabase.unlocked_spells_for(player.researched_magic):
		return "Pesquisa necessária."
	var blocked := ritual_reason(player, spell, grid)
	if blocked != "":
		return blocked
	if not valid_target(player, spell, target, grid):
		return "Objetivo ritual inválido ou desconhecido."
	var seat := ritual_seat(player, spell)
	var id := "%s:%d:%d" % [spell.effect, TurnManager.turn_number, player.rituals.size()]
	var participants := ritualists(player, spell, seat)
	var required := 5 if spell.school == "necromancia" else 4
	var ids := []
	for unit in participants.slice(0, required):
		unit.ritual_id = id
		unit.movement_left = 0
		unit.exploring = false
		unit.move_order_target = Unit.NO_MOVE_ORDER
		ids.append(unit.serial_id)
	player.mana -= spell.mana_cost
	player.rituals.append({"id": id, "spell": spell.name, "effect": spell.effect, "school": spell.school, "seat": packed(seat.coord), "target": packed(target), "units": ids, "progress": 0, "turns": 9 if spell.effect == "lich" else (8 if spell.effect == "cataclysm" else 7), "status": "channeling", "started": TurnManager.turn_number, "last_tick": TurnManager.turn_number})
	EventBus.notify.emit("%s iniciou %s em %s (%d, %d). Ataque a sede ou os ritualistas para interromper." % [player.civ.civ_name, spell.name, seat.city_name, seat.coord.x, seat.coord.y], "magic")
	return "%s: ritualistas comprometidos; custo de 20 mana por turno." % spell.name

static func interrupt_ritual(player: PlayerData, ritual: Dictionary, cause: String) -> void:
	ritual.status = "interrupted"
	ritual["reason"] = cause
	for unit in player.units:
		if unit.ritual_id == ritual.id:
			unit.ritual_id = ""
	EventBus.notify.emit("%s: %s interrompido — %s." % [player.civ.civ_name, ritual.spell, cause], "magic")

static func process_turn(player: PlayerData, grid: HexGrid) -> void:
	var turn := TurnManager.turn_number
	for unit in player.units.duplicate():
		if (unit.expires_turn > 0 and turn >= unit.expires_turn) or (unit.summoner_id > 0 and unit_by_id(player, unit.summoner_id) == null):
			grid.remove_unit(unit)
			continue
		if unit.unit_data.mana_upkeep > 0:
			if player.mana >= unit.unit_data.mana_upkeep:
				player.mana -= unit.unit_data.mana_upkeep
			elif unit.unit_data.magic_school == "":
				grid.remove_unit(unit)
				continue
			else:
				unit.magic_status["silence"] = turn + 1
		if unit.ritual_id != "":
			unit.movement_left = 0
		elif status_active(unit, "slow"):
			unit.movement_left *= 0.5
	for region in player.magic_effects.duplicate():
		if turn >= int(region.expires):
			restore_region(region, grid)
			player.magic_effects.erase(region)
		else:
			_process_region(player, region, grid)
	for ritual in player.rituals:
		if ritual.status != "channeling" or int(ritual.last_tick) >= turn:
			continue
		ritual.last_tick = turn
		var seat := grid.get_city_at(coord_of(ritual.seat))
		var required: String = MagicContent.SCHOOLS[ritual.school].ritual_building
		if seat == null or seat.owner_player != player or not seat.buildings.has(required):
			interrupt_ritual(player, ritual, "sede ou estrutura perdida")
			continue
		var intact := true
		for id in ritual.units:
			var unit := unit_by_id(player, int(id))
			if unit == null or HexMetrics.axial_distance(unit.coord, seat.coord) > 2 or status_active(unit, "silence"):
				intact = false
		if not intact or player.mana < 20:
			interrupt_ritual(player, ritual, "ritualista perdido/silenciado" if not intact else "mana insuficiente")
			continue
		if ritual.effect == "convergence" and not anchor_valid(player, coord_of(ritual.target), grid):
			interrupt_ritual(player, ritual, "âncora perdida")
			continue
		player.mana -= 20
		ritual.progress += 1
		if int(ritual.progress) >= int(ritual.turns):
			_complete_ritual(player, ritual, grid)
	for unit in player.units.duplicate():
		if unit.unit_data.visual_kind in ["elder_lich", "archdemon"]:
			_act_boss(unit, player, grid)

static func _process_region(player: PlayerData, region: Dictionary, grid: HexGrid) -> void:
	var center := coord_of(region.center)
	if region.effect == "portal":
		if not anchor_valid(player, center, grid):
			region.expires = TurnManager.turn_number
			return
		transport(player, coord_of(region.origin), center, 2, grid)
		return
	for coord in [center] + grid.tiles_in_range(center, int(region.radius)):
		var unit := grid.get_unit_at(coord)
		var city := grid.get_city_at(coord)
		if region.effect == "cataclysm":
			var owner := grid.city_owning_tile(coord)
			if owner == null or owner.owner_player == player or player.is_at_war_with(owner.owner_player):
				grid.pillage_tile(coord, TurnManager.turn_number, 2)
		if region.effect == "cataclysm" and city and city.owner_player != player and player.is_at_war_with(city.owner_player):
			city.hp = maxf(1, city.hp - 8)
		if unit == null:
			continue
		var friendly := unit.owner_player == player
		var enemy := hostile(player, unit)
		match region.effect:
			"consecrate", "aurora":
				if friendly:
					purify(unit)
					unit.hp = minf(unit.unit_data.max_hp, unit.hp + unit.unit_data.max_hp * (0.15 if region.effect == "aurora" else 0.08))
					unit.magic_status["blessing"] = TurnManager.turn_number + 2
				elif enemy and unit.unit_data.visual_kind in UNDEAD + DEMONS:
					unit.magic_status["curse"] = TurnManager.turn_number + 2
			"curse":
				if enemy and not unit.unit_data.visual_kind in UNDEAD and not status_active(unit, "blessing"):
					unit.magic_status["curse"] = TurnManager.turn_number + 2
					deal_damage(player, unit, 3, grid)
			"brimstone", "storm", "cataclysm":
				if friendly or enemy:
					if region.effect != "brimstone":
						unit.magic_status["slow"] = TurnManager.turn_number + 2
						unit.magic_status["storm"] = TurnManager.turn_number + 2
						unit.movement_left *= 0.5
					deal_damage(player, unit, {"brimstone": 5.0, "storm": 3.0, "cataclysm": 6.0}[region.effect], grid)
					if region.effect == "cataclysm":
						grid.pillage_tile(coord, TurnManager.turn_number, 2)

static func transport(player: PlayerData, origin: Vector2i, destination: Vector2i, limit: int, grid: HexGrid) -> int:
	var moved := 0
	for unit in player.units.duplicate():
		if unit.ritual_id != "" or HexMetrics.axial_distance(unit.coord, origin) > 1:
			continue
		for target in [destination] + grid.tiles_in_range(destination, 2):
			var tile := grid.get_tile(target)
			var city := grid.get_city_at(target)
			if tile and not tile.blocks_land_units() and grid.get_unit_at(target) == null and (city == null or city.owner_player == player):
				grid.move_unit(unit, target, unit.movement_left)
				moved += 1
				break
		if moved >= limit:
			break
	return moved

static func _complete_ritual(player: PlayerData, ritual: Dictionary, grid: HexGrid) -> void:
	var target := coord_of(ritual.target)
	var seat := coord_of(ritual.seat)
	if ritual.effect in ["lich", "archdemon"]:
		var boss: Unit = null
		for coord in grid.tiles_in_range(seat, 3):
			boss = summon(player, "elder_lich" if ritual.effect == "lich" else "archdemon", coord, grid)
			if boss:
				boss.boss_target = target
				break
		if boss == null:
			interrupt_ritual(player, ritual, "sem espaço para a manifestação")
			return
	elif ritual.effect == "convergence":
		transport(player, seat, target, 8, grid)
	else:
		if ritual.effect == "aurora":
			for coord in [target] + grid.tiles_in_range(target, 4):
				dispel_hostile_at(player, coord, grid)
		add_region(player, ritual.effect, target, grid)
	ritual.status = "completed"
	player.completed_rituals[ritual.effect] = true
	player.spell_cooldowns[ritual.spell] = TurnManager.turn_number + 25
	for unit in player.units:
		if unit.ritual_id == ritual.id:
			unit.ritual_id = ""
	EventBus.notify.emit("%s concluiu %s! Objetivo: (%d, %d)." % [player.civ.civ_name, ritual.spell, target.x, target.y], "magic")

static func _act_boss(boss: Unit, player: PlayerData, grid: HexGrid) -> void:
	if boss.hp <= 0 or boss.movement_left <= 0:
		return
	var lich := boss.unit_data.visual_kind == "elder_lich"
	var limit := 10 if lich else 4
	var followers := player.units.filter(func(u): return u.summoner_id == boss.serial_id)
	if TurnManager.turn_number % 2 == 0 and followers.size() < limit:
		for coord in grid.get_neighbors(boss.coord):
			var reinforcement := summon(player, "bound_skeleton" if lich else "lesser_demon", coord, grid, boss.serial_id)
			if reinforcement:
				break
	var visible := grid.compute_visible_tiles(player)
	if lich and protect_boss_distance(boss, player, grid, visible):
		return
	var acted := false
	for coord in grid.tiles_in_range(boss.coord, boss.unit_data.attack_range):
		var enemy := grid.get_unit_at(coord)
		if hostile(player, enemy) and visible.has(coord) and not concealed(enemy, player, grid):
			CombatResolver.resolve_with_splash(boss, enemy, grid, 1, 0.4)
			acted = true
			break
	if not acted:
		var city := grid.get_city_at(boss.boss_target)
		if city == null or city.owner_player == player or not player.is_at_war_with(city.owner_player):
			var best_distance := 2147483647
			for coord in player.known_enemy_cities:
				var candidate := grid.get_city_at(coord)
				if candidate and player.is_at_war_with(candidate.owner_player):
					var distance := HexMetrics.axial_distance(boss.coord, coord)
					if distance < best_distance:
						best_distance = distance
						city = candidate
						boss.boss_target = coord
		if city and city.owner_player != player and player.is_at_war_with(city.owner_player) and HexMetrics.axial_distance(boss.coord, city.coord) <= boss.unit_data.attack_range:
			CombatResolver.resolve_city_attack(boss, city, grid)
		elif city and player.is_at_war_with(city.owner_player):
			RivalAI.move_unit_toward(boss, grid, boss.boss_target)
	for follower in followers:
		if follower.movement_left <= 0:
			continue
		var attacked := false
		for coord in grid.get_neighbors(follower.coord):
			var enemy := grid.get_unit_at(coord)
			if hostile(player, enemy):
				CombatResolver.resolve(follower, enemy, grid)
				attacked = true
				break
		if attacked:
			continue
		var target := boss.coord if lich and followers.find(follower) < 2 else boss.boss_target
		RivalAI.move_unit_toward(follower, grid, target)

static func attack_multiplier(unit: Unit) -> float:
	var result := 0.8 if status_active(unit, "curse") else 1.0
	if unit.unit_data.attack_range > 1 and status_active(unit, "storm"):
		result *= 0.75
	return result

static func protect_boss_distance(boss: Unit, player: PlayerData, grid: HexGrid, visible: Dictionary) -> bool:
	var threats: Array[Vector2i] = []
	for coord in grid.get_neighbors(boss.coord):
		var enemy := grid.get_unit_at(coord)
		if visible.has(coord) and hostile(player, enemy) and enemy.unit_data.attack > 0:
			threats.append(coord)
	if threats.is_empty():
		return false
	var reachable := grid.compute_reachable(boss.coord, boss.movement_left, player)
	for coord in reachable:
		if threats.all(func(t): return HexMetrics.axial_distance(t, coord) >= 2):
			grid.move_unit(boss, coord, boss.movement_left)
			return true
	return false

static func concealed(unit: Unit, observer: PlayerData, grid: HexGrid) -> bool:
	if unit.owner_player == observer or unit.owner_player == null or status_active(unit, "revealed"):
		return false
	var veiled := false
	for region in unit.owner_player.magic_effects:
		if region.effect in ["veil", "living_land"] and int(region.expires) > TurnManager.turn_number and HexMetrics.axial_distance(coord_of(region.center), unit.coord) <= int(region.radius):
			veiled = true
	if not veiled:
		return false
	for coord in grid.tiles_in_range(unit.coord, 1):
		var scout := grid.get_unit_at(coord)
		if scout and scout.owner_player == observer:
			return false
		var city := grid.get_city_at(coord)
		if city and city.owner_player == observer:
			return false
	return true
