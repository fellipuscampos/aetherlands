extends Node

## Régua de atributos ATUAIS, usando CombatResolver.predict. Não simula encontros: sem técnica,
## habilidade, formação, veterania, terreno mágico ou movimento. Complementa testes reais de IA/feitiços.
## godot --headless --path . res://tools/balance/MonsterPressureProbe.tscn -- --out=user://monster_pressure.json
const LINES := {
	"frontline": ["v2_unit_warrior", "v2_unit_swordsman", "v2_unit_weapon_master", "v2_legendary_blade_hero"],
	"ranged": ["v2_unit_archer", "v2_unit_hunter", "v2_unit_elite_marksman", "v2_legendary_legend_hunter"],
	"tank": ["v2_unit_shieldbearer", "v2_unit_guardian", "v2_unit_sentinel", "v2_legendary_guardian_champion"],
}

func _ready() -> void:
	_run.call_deferred()

func _stats(data: UnitData) -> Dictionary:
	return {"hp": data.max_hp, "attack": data.attack, "defense": data.defense, "movement": data.movement_points, "range": data.attack_range}

func _run() -> void:
	var grid := HexGrid.new()
	add_child(grid)
	for coord in HexMetrics.coords_within(Vector2i.ZERO, 3):
		grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var player := PlayerData.new(CivilizationData.new())
	var rows: Array = []
	for kind in MonsterEcologyData.SPECIES_ORDER:
		var monster := Unit.new()
		monster.unit_data = MonsterDatabase.create_monster(kind)
		monster.set_hp_silent(monster.unit_data.max_hp)
		monster.coord = Vector2i.ZERO
		var row := {"species": kind, "tier": MonsterEcologyData.tier_of(kind), "group_size": MonsterEcologyData.group_size(kind), "stats": _stats(monster.unit_data), "comparisons": []}
		for role in LINES:
			for i in 4:
				var soldier := Unit.new()
				soldier.owner_player = player
				soldier.unit_data = UnitDatabase.create_unit(LINES[role][i])
				soldier.set_hp_silent(soldier.unit_data.max_hp)
				soldier.coord = Vector2i(-2 if soldier.unit_data.attack_range > 1 else -1, 0)
				var outbound := CombatResolver.predict(soldier, monster, grid)
				soldier.coord = Vector2i(-1, 0)
				var inbound := CombatResolver.predict(monster, soldier, grid)
				row.comparisons.append({"tier": [3, 5, 7, 9][i], "role": role, "unit": LINES[role][i], "stats": _stats(soldier.unit_data), "damage_to_monster": outbound.damage_to_defender, "counter_to_soldier": outbound.damage_to_attacker, "hits_to_kill_monster": ceili(monster.unit_data.max_hp / float(outbound.damage_to_defender)), "damage_to_soldier": inbound.damage_to_defender, "counter_to_monster": inbound.damage_to_attacker, "hits_to_kill_soldier": ceili(soldier.unit_data.max_hp / float(inbound.damage_to_defender))})
				soldier.free()
		rows.append(row)
		monster.free()
	var path := "user://monster_pressure.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			path = arg.substr(6)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"method": "CombatResolver.predict; base attributes only; not a battle simulation", "monsters": rows}, "  "))
	file.close()
	print("MONSTER_PRESSURE_PROBE ", ProjectSettings.globalize_path(path), " (12 species, 144 comparisons)")
	player.release_relations()
	get_tree().quit()
