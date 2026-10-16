extends GutTest

## NADA NO CHÃO EMBAIXO DA UNIDADE (pedido do usuário 2026-10-10: "tem um prato que fica embaixo de todo personagem...
## retire de todos"). O disco colorido sob os pés (o antigo Unit._build_base_disc, um CylinderMesh achatado na cor do
## dono, criado por script em toda unidade) saiu. Fora do corpo (_visual_root), a unidade só tem o que flutua ACIMA
## dela — barra de vida, ícone, emblema — e os aros de estado, que só existem enquanto o estado dura.

const RACES := ["human", "dwarf", "elf", "orc"]

var _players: Array[PlayerData] = []
var _units: Array[Unit] = []

func after_each():
	for unit in _units:
		if is_instance_valid(unit):
			unit.free()
	_units.clear()
	for player in _players:
		player.release_relations()
	_players.clear()

func _player(race: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.race = race
	var player := PlayerData.new(civ)
	_players.append(player)
	return player

func _unit(data: UnitData, owner: PlayerData) -> Unit:
	var unit := Unit.new()
	unit.setup(data, owner, Vector2i(0, 0))
	_units.append(unit)
	return unit

## Uma malha é "um prato no chão" se for baixa, larga e estiver deitada rente ao solo: mais larga que 0,4 nos dois
## eixos do chão, mais baixa que 0,12 e com o topo abaixo de 0,15.
func _is_ground_plate(node: Node3D, to_unit: Transform3D) -> bool:
	if not (node is MeshInstance3D) or node.mesh == null or not node.visible:
		return false
	var box: AABB = to_unit * node.mesh.get_aabb()
	return box.size.x > 0.4 and box.size.z > 0.4 and box.size.y < 0.12 and box.end.y < 0.15

## Tudo que a unidade desenha FORA do corpo: os filhos diretos dela, menos o _visual_root (modelo/barco).
func _ground_plates(unit: Unit) -> Array[String]:
	var found: Array[String] = []
	for child in unit.get_children():
		if child == unit._visual_root or not (child is Node3D):
			continue
		if _is_ground_plate(child, child.transform):
			found.append(String(child.name))
	return found

func test_the_base_disc_builder_is_gone():
	var probe := Unit.new()
	assert_false(probe.has_method("_build_base_disc"), "ninguém consegue recriar o disco por engano")
	probe.free()
	assert_false(FileAccess.get_file_as_string("res://scripts/units/Unit.gd").contains("base_disc"))

func test_no_trainable_troop_of_any_race_has_a_plate_under_its_feet():
	for race in RACES:
		var owner := _player(race)
		for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
			var unit := _unit(UnitDatabase.create_unit(kind), owner)
			assert_eq(_ground_plates(unit), [] as Array[String], "%s (%s)" % [kind, race])
			unit.free()

func test_no_monster_has_a_plate_under_its_feet():
	for kind in MonsterDatabase.KIND_DATA.keys():
		var unit := _unit(MonsterDatabase.create_monster(kind), null)
		assert_eq(_ground_plates(unit), [] as Array[String], kind)
		unit.free()
	var boss := Unit.new()
	boss.setup(MonsterDatabase.create_monster("troll", true), null, Vector2i(0, 0), true)
	_units.append(boss)
	assert_eq(_ground_plates(boss), [] as Array[String], "chefe de covil")

func test_changing_form_and_boarding_a_boat_do_not_bring_it_back():
	var unit := _unit(UnitDatabase.create_unit("v2_unit_warrior"), _player("elf"))
	unit.apply_form(UnitDatabase.create_unit("v2_unit_swordsman"))
	assert_eq(_ground_plates(unit), [] as Array[String], "depois de evoluir")
	unit.set_boat_visual(true, false)
	assert_true(unit.is_boat_visual(), "pré-condição: de barco")
	assert_eq(_ground_plates(unit), [] as Array[String], "embarcada")

## O detector enxerga o disco antigo (mesmas medidas) — o teste acima não passa por cegueira.
func test_the_detector_sees_a_disc_like_the_old_one():
	var unit := _unit(UnitDatabase.create_unit("v2_unit_warrior"), _player("human"))
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.35
	mesh.bottom_radius = 0.35
	mesh.height = 0.06
	disc.mesh = mesh
	disc.position.y = 0.03
	disc.name = "Disco"
	unit.add_child(disc)
	assert_eq(_ground_plates(unit), ["Disco"] as Array[String])
