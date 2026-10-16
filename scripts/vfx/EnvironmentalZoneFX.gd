extends Node3D

const Art := preload("res://scripts/vfx/SacredVFXGeometry.gd")
const Natural := preload("res://scripts/vfx/NaturalVFX.gd")
const COLORS := {"mist":Color("b3cedd"),"gale":Color("8bd9d0"),"storm":Color("98b7ec"),"cataclysm":Color("b6a4c7")}
var grid: Node3D
var coord := Vector2i.ZERO
var kind := ""
var age := 0.0
var cloud: Node3D
var rain: GPUParticles3D
var atmosphere: Node3D
var ambient_arc: Node3D
var storm_height := 3.8

func setup(map: Node3D, cell: Vector2i, visual_kind: String) -> void:
	name = "ZoneVFX"
	grid = map
	coord = cell
	kind = visual_kind
	var color: Color = COLORS.get(kind,Color.WHITE)
	atmosphere = Node3D.new()
	add_child(atmosphere)
	if kind in ["storm","cataclysm"]:
		# A tempestade pertence ao local, não ao ocupante. Altura fixa com pequena variação determinística;
		# trocar de tropa não faz nuvens, gotas e raios pularem para cima/baixo.
		storm_height = 3.8+float(posmod(coord.x*13+coord.y*7,5))*.045
		cloud = Natural.storm_cloud_bank(atmosphere,coord,grid.hex_size)
		cloud.position.y = storm_height
		rain = Natural.rain(atmosphere,storm_height-.12)
		rain.position.y = storm_height-.12
		rain.amount = 12 if Settings.reduced_motion else 24
		ambient_arc = preload("res://scripts/vfx/LightningArcFX.gd").new()
		atmosphere.add_child(ambient_arc)
		ambient_arc.setup(.65,Color("a5cafa"))
		ambient_arc.rotation.z = PI*.5
		ambient_arc.position = Vector3(-.3,storm_height,0)
		ambient_arc.visible = false
	if kind=="mist":
		cloud = Natural.cloud_bank(atmosphere,Color(.65,.74,.80,.18),1.4)
		cloud.position.y = .38
		var mist: GPUParticles3D = Natural.particles(atmosphere,10,Color(.70,.79,.85,.24),.55,.35,2,true)
		mist.position.y = .15
	if kind in ["gale","cataclysm"]:
		for i in 2:
			var wind: Node3D = Natural.spiral(atmosphere,.65,.55,Color(color,.20),.8)
			wind.rotation.y = i*PI
			wind.position.y = .15+i*.18
	if kind=="cataclysm":
		var dust: GPUParticles3D = Natural.particles(atmosphere,8,Color(.58,.46,.34,.22),.5,.18,2,true)
		dust.position.y = .05
	var border := PackedVector3Array()
	for i in 49:
		var side := mini(5,i/8)
		var point := HexMetrics.corner(grid.hex_size*.82,side).lerp(HexMetrics.corner(grid.hex_size*.82,(side+1)%6),float(i-side*8)/8)
		point.y = float(grid.surface_height_at(coord,Vector2(point.x,point.z)))-float(grid.world_surface_for_coord(coord).y)+.01
		border.append(point)
	Natural.ribbon(self,border,.035,Color(color,.16))

func _process(delta: float) -> void:
	visible = SpellVFX.tile_visible(grid,coord)
	if not is_visible_in_tree():
		if rain!=null: rain.emitting = false
		return
	age += delta
	if rain!=null:
		rain.emitting = true
		ambient_arc.visible = not Settings.reduced_motion and fposmod(age+abs(coord.x*.37+coord.y*.17),3.8)<.22
	var fade := smoothstep(0,1.0,age)
	Natural.opacity(atmosphere,fade)
