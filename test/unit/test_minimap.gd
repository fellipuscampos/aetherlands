extends GutTest

## Cobre Minimap.gd — bug reportado pelo usuario: "quando tiro a neblina
## crasha o jogo ele travou". Guardiao de Covil de Monstro (Unit sem
## owner_player, ver MonsterDatabase) virava visivel de uma vez ao
## desligar a neblina de guerra (Debug > Revelar Mapa), e _draw() lia
## `unit.owner_player.civ.color` sem checar null — um guardiao visivel no
## minimapa derrubava o redesenho inteiro (rodando pelo editor, isso pausa
## o jogo no debugger de erro de script, sensacao de "travou").

var hud: Control
var _units: Array[Unit] = []

func before_each():
	_units = []
	var hud_scene: PackedScene = load("res://scenes/ui/HUD.tscn")
	hud = hud_scene.instantiate()
	add_child_autofree(hud)

func after_each():
	for unit in _units:
		if is_instance_valid(unit):
			unit.queue_free()

func _make_unit(kind: String, player: PlayerData) -> Unit:
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit(kind) if player else MonsterDatabase.create_monster(kind), player, Vector2i(0, 0))
	_units.append(unit)
	return unit

func test_unit_dot_color_falls_back_to_monster_color_without_an_owner():
	var monster := _make_unit("goblin", null)

	var minimap: Control = hud.get_node("Minimap")
	var color = minimap._unit_dot_color(monster)

	assert_eq(color, Unit.MONSTER_COLOR)

func test_unit_dot_color_uses_civilization_color_when_owned():
	var human := PlayerData.new(CivilizationData.new())
	human.civ.color = Color(0.1, 0.2, 0.3)
	var warrior := _make_unit("warrior", human)

	var minimap: Control = hud.get_node("Minimap")
	var color = minimap._unit_dot_color(warrior)

	assert_eq(color, Color(0.1, 0.2, 0.3))
