extends Node3D

const Art := preload("res://scripts/vfx/SacredVFXGeometry.gd")
const Natural := preload("res://scripts/vfx/NaturalVFX.gd")
const Focus := preload("res://scripts/vfx/FocusGlowFX.gd")
const LIGHT := "v2_spell_restoring_light"
const AEGIS := "v2_spell_sacred_aegis"
const WAVE := "v2_spell_healing_wave"
const MIRACLE := "v2_spell_miracle"
var grid: Node3D
var caster_ref: WeakRef
var caster_anchor: Dictionary
var caster_body: Dictionary
var target_anchor: Dictionary = {}
var spell_id := ""
var center := Vector2i.ZERO
var age := 0.0
var release := 1.1
var arrival := 1.48
var duration := 3.2
var impacted := false
var charge: Node3D
var focus: Node3D
var light: OmniLight3D
var focus_glow: Node3D
var charge_seal: Node3D
var motes: Array[MeshInstance3D] = []
var stream: Array[MeshInstance3D] = []
var ground: Array[Dictionary] = []
var recipients: Array[Dictionary] = []

func setup(caster: Node3D, spell: Resource, target_coord: Vector2i, map: Node3D, outcomes: Array[Dictionary]) -> void:
	name = "SacredCast"
	grid = map
	age = -float(get_meta("start_delay", 0.0))
	caster_ref = weakref(caster)
	caster_anchor = Art.anchor(caster,true)
	var caster_meshes: Array[WeakRef] = []
	if is_instance_valid(caster._visual_root):
		for mesh in caster._visual_root.find_children("*","MeshInstance3D",true,false): caster_meshes.append(weakref(mesh))
	var caster_overlay := ShaderMaterial.new()
	caster_overlay.shader = Art.BODY_SHADER
	caster_overlay.set_shader_parameter("body_height",caster_anchor.height)
	caster_body = {"meshes":caster_meshes,"overlay":caster_overlay}
	spell_id = spell.id
	center = target_coord
	var primary: Node3D = grid.get_unit_at(center)
	if is_instance_valid(primary): target_anchor = Art.anchor(primary)
	release = float(get_meta("release_seconds", caster_anchor.release))
	arrival = release + .38
	duration = arrival + 1.65
	charge = Node3D.new()
	add_child(charge)
	focus = Node3D.new()
	charge.add_child(focus)
	focus_glow = Focus.acquire(caster,grid,get_instance_id(),"sacred",Art.GOLD)
	light = focus_glow.light
	for i in (3 if Settings.reduced_motion else 6):
		motes.append(Natural.sprite(charge,Vector2.ONE*.06,Art.MANA if i%3==0 else Art.GOLD))
	charge_seal = Art.seal(self,grid,caster.coord,.44)
	for i in (4 if Settings.reduced_motion else 10):
		stream.append(Natural.sprite(self,Vector2.ONE*.08,Art.IVORY if i%3==0 else Art.GOLD))
	var cells: Array[Vector2i] = [center]
	if spell_id == WAVE: cells.append_array(HexMetrics.coords_within(center,spell.splash_radius))
	for cell in cells:
		if not grid.tiles.has(cell): continue
		var seal: Node3D = Art.seal(self,grid,cell,grid.hex_size*.86 if spell_id==WAVE else .55,spell_id==WAVE)
		seal.visible = false
		ground.append({"coord":cell,"node":seal,"delay":0.0 if cell==center else .14})
	for outcome in outcomes:
		var target: Node3D = outcome.unit.get_ref()
		if not is_instance_valid(target) or (float(outcome.heal) <= 0 and spell_id != AEGIS): continue
		var info: Dictionary = Art.anchor(target)
		var reaction := Node3D.new()
		add_child(reaction)
		reaction.visible = false
		var glyph: Node3D = Natural.sprite(reaction,Vector2.ONE*(1.0 if spell_id==MIRACLE else .6),Color(1,.88,.55,.4),7)
		glyph.position.y = float(info.height)*.60
		var healing_flow: Node3D = Natural.spiral(reaction,.58,float(info.height)*.85,Color(.75,1,.87,.62),1.4)
		if spell_id==AEGIS: healing_flow.visible = false
		var count := 40 if spell_id==MIRACLE else 22
		if Settings.reduced_motion: count = 10
		var sparks: GPUParticles3D = Art.particles(reaction,count,Art.IVORY if spell_id==MIRACLE else Art.MANA,.30,float(info.height))
		sparks.position.y = float(info.height)*.28
		var columns: Array[MeshInstance3D] = []
		if spell_id == MIRACLE:
			for side in 4:
				var angle := TAU*side/4.0
				var ray := Natural.sprite(reaction,Vector2(.20,2.2),Color(1,.90,.67,.75))
				ray.position = Vector3(sin(angle)*.26,.95,cos(angle)*.26)
				columns.append(ray)
		var overlay := ShaderMaterial.new()
		overlay.shader = Art.BODY_SHADER
		overlay.set_shader_parameter("body_height",info.height)
		var meshes: Array[WeakRef] = []
		var body: Node3D = target._visual_root
		if is_instance_valid(body):
			for mesh in body.find_children("*","MeshInstance3D",true,false): meshes.append(weakref(mesh))
		recipients.append({"unit":outcome.unit,"heal":outcome.heal,"anchor":info,"node":reaction,"glyph":glyph,"flow":healing_flow,"particles":sparks,"overlay":overlay,"meshes":meshes,"columns":columns,"started":false})
	_update_visuals(0)

func _process(delta: float) -> void:
	age += delta
	_update_visuals(delta)
	if age >= duration: queue_free()

func _update_visuals(_delta: float) -> void:
	var caster: Node3D = caster_ref.get_ref()
	var caster_visible := SpellVFX.unit_visible(caster,grid)
	var focus_pos := Art.anchor_position(caster_anchor)
	charge.visible = caster_visible and age < arrival
	charge.global_position = focus_pos
	if caster_visible:
		charge_seal.global_position = grid.world_surface_for_coord(caster.coord) + Vector3.UP*.035
	charge_seal.visible = caster_visible and age < arrival
	var charge_progress := clampf(age/release,0,1)
	var charge_alpha := smoothstep(0,.2,age) * (1.0-smoothstep(release,arrival,age))
	var breathing := 1.0 if Settings.reduced_motion else 1.0+sin(age*5.0)*.045
	focus.scale = Vector3.ONE*(.5+charge_progress*.65)*breathing
	focus.global_rotation.y = get_viewport().get_camera_3d().global_rotation.y if get_viewport().get_camera_3d()!=null else 0.0
	Art.opacity(focus,charge_alpha)
	Art.opacity(charge_seal,charge_alpha*.7)
	if is_instance_valid(focus_glow): focus_glow.update_lease(get_instance_id(),charge_alpha*breathing,caster_visible and age<arrival)
	var caster_strength: float = charge_alpha*.48 if caster_visible else 0.0
	caster_body.overlay.set_shader_parameter("floor_y",caster.global_position.y if is_instance_valid(caster) else 0.0)
	caster_body.overlay.set_shader_parameter("progress",charge_progress)
	caster_body.overlay.set_shader_parameter("strength",caster_strength)
	_apply_overlay(caster_body,caster_strength)
	for i in motes.size():
		var phase := age*.60 + float(i)/motes.size()
		var fraction := fposmod(phase,1.0)
		var angle := TAU*(float(i)/motes.size()+age*.22)
		var radius := (1-fraction)*.42
		motes[i].position = Vector3(cos(angle)*radius,-.65*(1-fraction),sin(angle)*radius)
		Art.opacity(motes[i],charge_alpha*sin(fraction*PI))
	var destination: Vector3 = grid.world_surface_for_coord(center) + Vector3.UP*.80
	if not target_anchor.is_empty() and is_instance_valid(target_anchor.unit.get_ref()): destination = Art.anchor_position(target_anchor)
	var link_visible := caster_visible and SpellVFX.tile_visible(grid,center)
	for i in stream.size():
		var t := (age-release-float(i)*.020)/.38
		stream[i].visible = link_visible and t>=0 and t<=1
		if stream[i].visible:
			var control: Vector3 = (focus_pos+destination)*.5 + Vector3.UP*.40
			stream[i].global_position = focus_pos.lerp(control,t).lerp(control.lerp(destination,t),t)
	var impact_age := age-arrival
	impacted = impact_age>=0
	for item in ground:
		var elapsed: float = impact_age-float(item.delay)
		item.node.visible = elapsed>=0 and SpellVFX.tile_visible(grid,item.coord)
		if item.node.visible:
			Art.opacity(item.node,smoothstep(0,.15,elapsed)*(1-smoothstep(.7,1.5,elapsed))*.8)
	for recipient in recipients:
		var target: Node3D = recipient.unit.get_ref()
		var shown: bool = SpellVFX.unit_visible(target,grid)
		recipient.node.visible = shown and impact_age>=0
		if not is_instance_valid(target):
			_clear_overlay(recipient)
			continue
		recipient.node.global_position = target.global_position
		if impact_age>=0 and not recipient.started:
			recipient.started = true
			if shown:
				recipient.particles.restart()
				recipient.particles.emitting = true
				if float(recipient.heal)>0 and not get_meta("synchronized_feedback",false): grid.spawn_heal_popup(target.coord,recipient.heal)
		var strength := smoothstep(0,.10,impact_age)*(1-smoothstep(.65,1.25,impact_age)) if impact_age>=0 and shown else 0.0
		recipient.overlay.set_shader_parameter("floor_y",target.global_position.y)
		recipient.overlay.set_shader_parameter("progress",clampf(impact_age/1.1,0,1))
		recipient.overlay.set_shader_parameter("strength",strength)
		_apply_overlay(recipient,strength)
		var glyph: Node3D = recipient.glyph
		glyph.global_rotation.y = get_viewport().get_camera_3d().global_rotation.y if get_viewport().get_camera_3d()!=null else 0.0
		glyph.position = Vector3(0,float(recipient.anchor.height)*.60 + (clampf(impact_age,0,1)*.18 if not Settings.reduced_motion else 0.0),0)
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			var toward_camera := camera.global_position-target.global_position
			toward_camera.y = 0
			glyph.global_position += toward_camera.normalized()*.42
		glyph.scale = Vector3.ONE*(.82+smoothstep(0,.25,maxf(0,impact_age))*.18)
		Art.opacity(glyph,strength*.8)
		Art.opacity(recipient.flow,strength)
		if not Settings.reduced_motion: recipient.flow.rotation.y = impact_age*.7
		for i in recipient.columns.size():
			Art.opacity(recipient.columns[i],strength*(.35+.3*sin(impact_age*2-i*.3)))

func _clear_overlay(recipient: Dictionary) -> void:
	for ref in recipient.meshes:
		var mesh: MeshInstance3D = ref.get_ref()
		if is_instance_valid(mesh) and mesh.material_overlay==recipient.overlay: mesh.material_overlay = null

func _apply_overlay(info: Dictionary, strength: float) -> void:
	for ref in info.meshes:
		var mesh: MeshInstance3D = ref.get_ref()
		if not is_instance_valid(mesh): continue
		# Damage reactions have priority; no stale overlay is restored.
		if strength>0 and (mesh.material_overlay==null or mesh.material_overlay==info.overlay): mesh.material_overlay = info.overlay
		elif strength<=0 and mesh.material_overlay==info.overlay: mesh.material_overlay = null

func _exit_tree() -> void:
	if is_instance_valid(focus_glow): focus_glow.release(get_instance_id())
	if not caster_body.is_empty(): _clear_overlay(caster_body)
	for recipient in recipients: _clear_overlay(recipient)
