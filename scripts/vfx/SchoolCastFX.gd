extends Node3D

## Shared charge, receipts, fog, accessibility and cleanup; school subclasses supply shapes.
const Art := preload("res://scripts/vfx/SacredVFXGeometry.gd")
const Shapes := preload("res://scripts/vfx/SchoolVFXArt.gd")
const Natural := preload("res://scripts/vfx/NaturalVFX.gd")
const Focus := preload("res://scripts/vfx/FocusGlowFX.gd")
var grid: Node3D
var caster_ref: WeakRef
var focus_anchor: Dictionary
var caster_body: Dictionary
var spell: Resource
var center := Vector2i.ZERO
var origin := Vector2i.ZERO
var outcomes: Array[Dictionary] = []
var age := 0.0
var release := 1.1
var arrival := 1.48
var duration := 3.3
var primary := Color.WHITE
var accent := Color.WHITE
var charge: Node3D
var charge_seal: Node3D
var light: OmniLight3D
var focus_glow: Node3D
var projectile: Node3D
var motes: Array[MeshInstance3D] = []
var trail: Array[MeshInstance3D] = []
var events: Array[Dictionary] = []
var bodies: Array[Dictionary] = []
var path_cells: Array[Vector2i] = []

func palette() -> Array[Color]: return [Color.WHITE,Color.WHITE]
func focus_kind() -> String: return "rune"
func build_spell() -> void: pass

func setup(caster: Node3D, data: Resource, coord: Vector2i, map: Node3D, receipts: Array[Dictionary]) -> void:
	grid = map
	spell = data
	center = coord
	origin = get_meta("origin_coord",caster.coord)
	outcomes = receipts
	age = -float(get_meta("start_delay", 0.0))
	caster_ref = weakref(caster)
	focus_anchor = Art.anchor(caster,true)
	release = float(get_meta("release_seconds", focus_anchor.release))
	arrival = release+.38
	duration = arrival+1.7
	primary = palette()[0]
	accent = palette()[1]
	caster_body = Shapes.body(caster,primary,accent)
	charge = Node3D.new()
	add_child(charge)
	focus_glow = Focus.acquire(caster,grid,get_instance_id(),spell.school_branch,primary)
	light = focus_glow.light
	charge_seal = Art.seal(self,grid,origin,.43,false,primary,accent)
	for i in (3 if Settings.reduced_motion else 6): motes.append(Natural.sprite(self,Vector2.ONE*.06,accent if i%3==0 else primary))
	projectile = Shapes.glyph(self,focus_kind(),primary,accent,.5)
	for i in (4 if Settings.reduced_motion else 10): trail.append(Natural.sprite(self,Vector2.ONE*.10,primary if i%2 else accent))
	path_cells = HexMetrics.axial_line(origin,center)
	build_spell()
	_update_visuals()

func add_seal(coord: Vector2i, delay: float = 0.0, radius: float = .80) -> Dictionary:
	var node: Node3D = Art.seal(self,grid,coord,radius,true,primary,accent)
	var event := {"coord":coord,"node":node,"delay":delay,"kind":"seal","particles":null,"started":false,"glyph":null,"base":Vector3.ONE}
	events.append(event)
	return event

func add_burst(coord: Vector2i, kind: String, count: int = 24, delay: float = 0.0, size: float = 1.0) -> Dictionary:
	var node := Node3D.new()
	add_child(node)
	node.global_position = grid.world_surface_for_coord(coord)
	var glyph: Node3D = Shapes.glyph(node,kind,primary,accent,size)
	glyph.position.y = .7
	var sparks: GPUParticles3D = Art.particles(node,10 if Settings.reduced_motion else count,primary,.35,.9)
	var event := {"coord":coord,"node":node,"delay":delay,"kind":kind,"particles":sparks,"started":false,"glyph":glyph,"base":Vector3.ONE*size}
	events.append(event)
	return event

func add_body(receipt: Dictionary, color: Color, bright: Color) -> void:
	var unit: Node3D = receipt.unit.get_ref() if receipt.has("unit") else null
	if not is_instance_valid(unit): return
	var info := Shapes.body(unit,color,bright)
	info.heal = receipt.get("heal",0.0)
	info.started = false
	bodies.append(info)

func affected_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for receipt in outcomes:
		if receipt.has("tile") and not cells.has(receipt.tile): cells.append(receipt.tile)
	if cells.is_empty(): cells.append(center)
	return cells

func _process(delta: float) -> void:
	age += delta
	_update_visuals()
	if age>=duration: queue_free()

func _update_visuals() -> void:
	var caster: Node3D = caster_ref.get_ref()
	var shown := SpellVFX.unit_visible(caster,grid)
	var charging := age<arrival and shown
	var focus_pos := Art.anchor_position(focus_anchor)
	charge.visible = charging
	charge.global_position = focus_pos
	var progress := clampf(age/release,0,1)
	var alpha := smoothstep(0,.18,age)*(1-smoothstep(release,arrival,age))
	charge.scale = Vector3.ONE*(.58+progress*.42)
	var camera := get_viewport().get_camera_3d()
	if camera!=null: charge.global_rotation.y = camera.global_rotation.y
	Art.opacity(charge,alpha)
	charge_seal.visible = charging and SpellVFX.tile_visible(grid,origin)
	Art.opacity(charge_seal,alpha*.65)
	if is_instance_valid(focus_glow): focus_glow.update_lease(get_instance_id(),alpha,charging)
	Shapes.body_update(caster_body,alpha*.38 if shown else 0.0,progress)
	for i in motes.size():
		var phase := fposmod(age*.8+float(i)/motes.size(),1)
		var angle := TAU*(float(i)/motes.size()+age*.20)
		motes[i].visible = charging
		motes[i].global_position = focus_pos+Vector3(cos(angle),-.9,sin(angle))*(1-phase)*.48
		Art.opacity(motes[i],alpha*sin(phase*PI))
	var link: bool = shown and SpellVFX.tile_visible(grid,center) and not spell.teleport_caster
	for cell in path_cells: link = link and SpellVFX.tile_visible(grid,cell)
	var destination: Vector3 = grid.world_surface_for_coord(center)+Vector3.UP*.8
	var phase := (age-release)/.38
	projectile.visible = link and phase>=0 and phase<=1
	if projectile.visible:
		projectile.global_position = _arc(focus_pos,destination,phase)
		if camera!=null: projectile.global_rotation.y = camera.global_rotation.y
	for i in trail.size():
		var t := (age-release-i*.018)/.38
		trail[i].visible = link and t>=0 and t<=1
		if trail[i].visible: trail[i].global_position = _arc(focus_pos,destination,t)
	for event in events:
		var t: float = age-arrival-float(event.delay)
		var visible_now := t>=0 and SpellVFX.tile_visible(grid,event.coord)
		event.node.visible = visible_now
		if visible_now and not event.started:
			event.started = true
			if event.particles!=null:
				event.particles.restart()
				event.particles.emitting = true
		var opacity := smoothstep(0,.10,maxf(t,0))*(1-smoothstep(.9,1.6,t))
		Art.opacity(event.node,opacity)
		if event.glyph!=null:
			if camera!=null: event.glyph.global_rotation.y = camera.global_rotation.y
			if not Settings.reduced_motion:
				event.glyph.position.y = .7+clampf(t,0,1)*.25
				event.glyph.scale = event.base*(.8+smoothstep(0,.2,maxf(t,0))*.2)
		animate_event(event,t)
	var impact := age-arrival
	for info in bodies:
		var unit: Node3D = info.unit.get_ref()
		var body_visible := SpellVFX.unit_visible(unit,grid)
		var strength := smoothstep(0,.12,impact)*(1-smoothstep(.7,1.4,impact)) if impact>=0 and body_visible else 0.0
		Shapes.body_update(info,strength,clampf(impact/1.2,0,1))
		if impact>=0 and not info.started:
			info.started = true
			if body_visible and float(info.heal)>0 and not get_meta("synchronized_feedback",false): grid.spawn_heal_popup(unit.coord,info.heal)

func animate_event(_event: Dictionary, _time: float) -> void: pass

func _arc(from: Vector3, to: Vector3, t: float) -> Vector3:
	var control := (from+to)*.5+Vector3.UP*.35
	return from.lerp(control,t).lerp(control.lerp(to,t),t)

func _exit_tree() -> void:
	if is_instance_valid(focus_glow): focus_glow.release(get_instance_id())
	if not caster_body.is_empty(): Shapes.body_clear(caster_body)
	for info in bodies: Shapes.body_clear(info)
