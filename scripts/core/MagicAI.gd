class_name MagicAI
extends RefCounted

static func public_threat_target(other: PlayerData, observer: PlayerData, grid: HexGrid) -> Vector2i:
	if other.arcane_ritual_active:
		return other.arcane_ritual_city_coord
	for ritual in other.rituals:
		if ritual.status != "channeling" or not ritual.effect in ["lich", "archdemon", "cataclysm"]:
			continue
		var target := MagicRuntime.coord_of(ritual.target)
		for city in observer.cities:
			if HexMetrics.axial_distance(city.coord, target) <= 4:
				return MagicRuntime.coord_of(ritual.seat)
	return MagicRuntime.INVALID

static func counter_ritual_target(player: PlayerData, opponent: PlayerData, grid: HexGrid):
	if not player.is_at_war_with(opponent):
		return null
	var target := public_threat_target(opponent, player, grid)
	if target != MagicRuntime.INVALID:
		var seat := grid.get_city_at(target)
		if seat and seat.owner_player == opponent:
			return target
	for ritual in opponent.rituals:
		if ritual.status == "channeling":
			return MagicRuntime.coord_of(ritual.seat)
	return null

static func protect_caster(unit: Unit, player: PlayerData, grid: HexGrid, visible: Dictionary) -> bool:
	if unit.unit_data.magic_school == "":
		return false
	var threats: Array[Vector2i] = []
	for coord in grid.tiles_in_range(unit.coord, 2):
		var enemy := grid.get_unit_at(coord)
		if visible.has(coord) and MagicRuntime.hostile(player, enemy) and enemy.unit_data.attack > 0 and not MagicRuntime.concealed(enemy, player, grid):
			threats.append(coord)
	if threats.is_empty():
		return false
	var best := unit.coord
	var best_score := -INF
	var reachable := grid.compute_reachable(unit.coord, unit.movement_left, player)
	for coord in [unit.coord] + reachable.keys():
		var distance := 20
		for enemy_coord in threats:
			distance = mini(distance, HexMetrics.axial_distance(coord, enemy_coord))
		var score := float(distance)
		for ally in player.units:
			if ally != unit and ally.unit_data.attack_range == 1 and HexMetrics.axial_distance(ally.coord, coord) <= 1:
				score += 0.3
		if score > best_score:
			best_score = score
			best = coord
	if best != unit.coord:
		grid.move_unit(unit, best, reachable[best])
		return true
	return false

static func preferred_school(player: PlayerData) -> String:
	var race := player.civ.race if player.civ else "human"
	return {"human": "sagrada", "elf": "druidismo", "dwarf": "arcanismo", "orc": "infernal"}.get(race, "necromancia")

static func research_score(player: PlayerData, tech: TechData) -> float:
	var school := tech.id.get_slice("_", 0)
	if not MagicContent.SCHOOLS.has(school):
		return 0
	var focused := StrategicAI.strategy(player) == CityIdentity.AXIS_ARCANA
	var primary := preferred_school(player)
	var secondary := "necromancia" if float(player.personality.get(CityIdentity.AXIS_MILITAR, 0)) > 0.5 else "elementalismo"
	if school != primary and school != secondary:
		return -1.5
	var level := MagicDatabase.school_level(primary, player.researched_magic)
	if school == secondary and level < (7 if focused else 4):
		return -1.0
	if not focused and tech.tier > 5 and player.researched_techs.size() < 16:
		return -2.0
	return 1.5 if focused else (0.5 if tech.tier <= 4 else 0.1)

static func production_score(player: PlayerData, _city: City, kind: String) -> float:
	var building := BuildingDatabase.get_building(kind)
	if building:
		if kind == VictoryConditions.SANCTUARY_BUILDING_ID:
			return 6.0
		for school in MagicContent.SCHOOLS:
			var info: Dictionary = MagicContent.SCHOOLS[school]
			if kind == info.building:
				return 3.0 if not player.cities.any(func(c): return c.buildings.has(kind)) else 0.4
			if kind == info.ritual_building:
				return 4.0 if not player.cities.any(func(c): return c.buildings.has(kind)) else -1.0
		return 0
	if not kind in MagicContent.TRAINABLE:
		return 0
	var data := UnitDatabase.create_unit(kind)
	if data.magic_school == "":
		return 1.0 if player.mana > 80 and player.units.filter(func(u): return u.unit_data.visual_kind == kind).size() < 2 else -6.0
	var school := data.magic_school
	var preparing := player.researched_magic.has(school + "_8") and not player.completed_rituals.has(MagicContent.EFFECTS[school][4])
	var desired := (5 if school == "necromancia" else 4) if preparing else maxi(1, player.cities.size() / 2)
	if player.researched_magic.has("transcendencia_arcana") and player.completed_rituals.size() >= 2:
		desired = maxi(desired, 3)
	var count := player.units.filter(func(u): return u.unit_data.magic_school == school).size()
	count += player.cities.filter(func(c): return c.production_item in MagicContent.TRAINABLE and UnitDatabase.create_unit(c.production_item).magic_school == school).size()
	return 5.0 if count < desired and player.mana_income_per_turn > count + 2 else -8.0

static func prepare_ritualists(unit: Unit, player: PlayerData, grid: HexGrid) -> bool:
	var school := unit.unit_data.magic_school
	if school != "" and player.researched_magic.has("transcendencia_arcana") and player.completed_rituals.size() >= 2:
		var sanctuary := VictoryCampaign.sanctuary(player)
		if sanctuary:
			if HexMetrics.axial_distance(unit.coord, sanctuary.coord) > 2:
				RivalAI.move_unit_toward(unit, grid, sanctuary.coord)
			return true
	if school == "" or not player.researched_magic.has(school + "_8") or player.completed_rituals.has(MagicContent.EFFECTS[school][4]):
		return false
	var spell := SpellDatabase.get_spell(MagicContent.SCHOOLS[school].names[8])
	var seat := MagicRuntime.ritual_seat(player, spell)
	if seat == null:
		return false
	if HexMetrics.axial_distance(unit.coord, seat.coord) > 2:
		RivalAI.move_unit_toward(unit, grid, seat.coord)
	return true

static func take_turn(player: PlayerData, grid: HexGrid) -> void:
	if GameManager.victory_rules_version >= 2:
		VictoryCampaign.start(player, grid)
	var spells := MagicDatabase.unlocked_spells_for(player.researched_magic)
	var visible := grid.compute_visible_tiles(player)
	for name in spells:
		var spell := SpellDatabase.get_spell(name)
		if spell == null or spell.category != "ritual" or MagicRuntime.reason(player, spell, grid) != "":
			continue
		var seat := MagicRuntime.ritual_seat(player, spell)
		var target := seat.coord
		if spell.effect == "convergence":
			var farthest := 3
			for coord in player.explored_tiles:
				if MagicRuntime.anchor_valid(player, coord, grid) and HexMetrics.axial_distance(seat.coord, coord) > farthest:
					farthest = HexMetrics.axial_distance(seat.coord, coord)
					target = coord
			if target == seat.coord:
				continue
		elif spell.effect in ["lich", "archdemon", "cataclysm"]:
			var best := INF
			for coord in player.known_enemy_cities:
				var enemy_city := grid.get_city_at(coord)
				if enemy_city and player.is_at_war_with(enemy_city.owner_player):
					var distance := HexMetrics.axial_distance(seat.coord, coord)
					if distance < best:
						best = distance
						target = coord
			if target == seat.coord:
				continue
		MagicRuntime.cast(player, spell, target, grid)
	for caster in player.units.duplicate():
		if caster.unit_data.magic_school == "" or caster.ritual_id != "":
			continue
		if prepare_ritualists(caster, player, grid):
			continue
		var best_score := 0.0
		var best_spell: SpellData = null
		var best_target: Vector2i = caster.coord
		for name in spells:
			var spell := SpellDatabase.get_spell(name)
			if spell == null or spell.category == "ritual" or not MagicRuntime.eligible_caster(caster, spell) or player.mana < spell.mana_cost:
				continue
			for coord in [caster.coord] + grid.tiles_in_range(caster.coord, spell.cast_range):
				if not MagicRuntime.valid_target(player, spell, coord, grid, caster, visible):
					continue
				var score := _target_score(player, caster, spell, coord, grid)
				if score > best_score:
					best_score = score
					best_spell = spell
					best_target = coord
		if best_spell:
			MagicRuntime.cast(player, best_spell, best_target, grid, caster)

static func _target_score(player: PlayerData, caster: Unit, spell: SpellData, coord: Vector2i, grid: HexGrid) -> float:
	var target := grid.get_unit_at(coord)
	match spell.effect:
		"heal": return (target.unit_data.max_hp - target.hp) * 2.0
		"purify": return 12.0 if not target.magic_status.is_empty() else 0.0
		"hellfire", "chain_lightning", "ice_wave": return 10.0 + (5.0 if target.hp < 10 else 0.0)
		"silence": return 20.0 if target.ritual_id != "" else 8.0
		"blood_pact": return 3.0 if caster.hp > caster.unit_data.max_hp * 0.7 and not MagicRuntime.status_active(caster, "blood_pact") and not player.enemies.is_empty() else 0.0
		"skeleton", "guardian", "beast", "legion": return 5.0 if player.mana > spell.mana_cost + 30 else 0.0
		"blink": return float(HexMetrics.axial_distance(caster.coord, coord)) if caster.hp < caster.unit_data.max_hp * 0.4 and grid.city_owning_tile(coord) != null else 0.0
		"portal": return 1.0 if HexMetrics.axial_distance(caster.coord, coord) >= 3 else 0.0
	var score := 0.0
	for near in grid.tiles_in_range(coord, 1):
		var unit := grid.get_unit_at(near)
		if unit == null:
			continue
		if spell.effect in ["consecrate", "veil"]:
			if unit.owner_player == player and unit.hp < unit.unit_data.max_hp:
				score += 3.0
		elif MagicRuntime.hostile(player, unit):
			score += 3.0
		elif unit.owner_player == player:
			score -= 4.0
	return score
