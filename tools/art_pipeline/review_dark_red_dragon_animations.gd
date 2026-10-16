extends SceneTree

const STEM := "dark_red_dragon_v5_animated"
const BASE := "res://assets/generated/dragons/"+STEM+"/"
const FRAME_DIR := "res://art_source/dark_red_dragon_animation_review/frames/"
const EXPECTED := {"Dragon_Idle_Ground":3.0,"Dragon_Idle_Flying":2.0,
	"Dragon_Walk_Ground":1.5,"Dragon_Walk_Flying":1.5,
	"Dragon_Attack_Ground":3.0,"Dragon_Attack_Flying":3.0}

var skeleton: Skeleton3D
var mesh_node: MeshInstance3D
var vertices: PackedVector3Array
var bone_indices: PackedInt32Array
var weights: PackedFloat32Array
var bind_bones: Array[int]=[]
var bind_poses: Array[Transform3D]=[]
var issues: Array[String]=[]

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	root.size=Vector2i(640,640)
	root.msaa_3d=Viewport.MSAA_4X
	var stage := Node3D.new()
	root.add_child(stage)
	var packed := load(BASE+STEM+".glb") as PackedScene
	if packed==null:
		push_error("Animated dragon GLB did not import")
		quit(1)
		return
	var model := packed.instantiate() as Node3D
	stage.add_child(model)
	var rigs := model.find_children("*","Skeleton3D",true,false)
	var meshes := model.find_children("*","MeshInstance3D",true,false)
	var players := model.find_children("*","AnimationPlayer",true,false)
	if rigs.size()!=1 or meshes.size()!=1 or players.size()!=1:
		push_error("Expected one skeleton, mesh and animation player")
		quit(1)
		return
	skeleton=rigs[0]; mesh_node=meshes[0]
	if skeleton.get_bone_count()!=53: issues.append("Expected 53 bones including mouth socket")
	if skeleton.find_bone("mouth_fire")<0: issues.append("Missing mouth_fire socket")
	if mesh_node.skin==null:
		push_error("Missing dragon skin")
		quit(1)
		return
	var arrays := mesh_node.mesh.surface_get_arrays(0)
	vertices=arrays[Mesh.ARRAY_VERTEX]
	bone_indices=arrays[Mesh.ARRAY_BONES]
	weights=arrays[Mesh.ARRAY_WEIGHTS]
	for bind in mesh_node.skin.get_bind_count():
		var name := mesh_node.skin.get_bind_name(bind)
		var index := skeleton.find_bone(name) if name!=&"" else mesh_node.skin.get_bind_bone(bind)
		bind_bones.append(index); bind_poses.append(mesh_node.skin.get_bind_pose(bind))
	var material := mesh_node.mesh.surface_get_material(0) as StandardMaterial3D
	if material==null or material.texture_filter!=BaseMaterial3D.TEXTURE_FILTER_NEAREST:
		issues.append("Pixel material not imported with nearest filtering")
	var player: AnimationPlayer=players[0]
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var environment := Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color(.22,.25,.27)
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color(.95,.93,.91)
	environment.ambient_light_energy=.65
	environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new(); world.environment=environment; stage.add_child(world)
	for entry in [[Vector3(-48,-28,0),1.0],[Vector3(-38,145,0),.55]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees=entry[0]; light.light_energy=entry[1]
		light.shadow_enabled=float(entry[1])>0.9; light.directional_shadow_max_distance=20
		light.shadow_normal_bias=.35; stage.add_child(light)
	var floor_node := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new(); floor_mesh.size=Vector2(70,70)
	floor_node.mesh=floor_mesh; floor_node.position.y=-.004
	floor_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color=Color(.30,.33,.35); floor_material.roughness=1.0
	floor_node.material_override=floor_material; stage.add_child(floor_node)
	var camera := Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=6.5; camera.current=true; stage.add_child(camera)
	camera.position=Vector3(6.35,6.45,9.75); camera.look_at(Vector3(.35,1.45,-.25))
	var caption := CanvasLayer.new(); stage.add_child(caption)
	var label := Label.new(); label.position=Vector2(22,20); label.add_theme_font_size_override("font_size",20)
	caption.add_child(label)
	var translated := {"Dragon_Idle_Ground":"IDLE · CHÃO","Dragon_Idle_Flying":"IDLE · VOANDO",
		"Dragon_Walk_Ground":"WALK · CHÃO","Dragon_Walk_Flying":"WALK · VOANDO",
		"Dragon_Attack_Ground":"ATAQUE · CHÃO","Dragon_Attack_Flying":"ATAQUE · VOANDO"}
	var report := {"status":"PASS","bones":skeleton.get_bone_count(),"meshes":meshes.size(),"fps":24,
		"mouth_socket":"mouth_fire","fire_start_seconds":.75,"fire_end_seconds":2.0,"clips":{},"issues":issues}
	var first_tracks: Array[String]=[]
	for clip: String in EXPECTED:
		if not player.has_animation(clip):
			issues.append("Missing clip "+clip)
			continue
		var animation := player.get_animation(clip)
		var loop: bool = not "Attack" in clip
		if absf(animation.length-float(EXPECTED[clip]))>.002: issues.append("Incorrect duration: "+clip)
		if animation.loop_mode!=(Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE): issues.append("Incorrect loop mode: "+clip)
		var tracks: Array[String]=[]
		for index in animation.get_track_count(): tracks.append(str(animation.track_get_path(index))+":"+str(animation.track_get_type(index)))
		tracks.sort()
		if first_tracks.is_empty(): first_tracks=tracks
		elif tracks!=first_tracks: issues.append("Track sets differ: "+clip)
		animation.loop_mode=Animation.LOOP_NONE # Inspect the real final key instead of wrapping to zero.
		player.play(clip)
		label.text=translated[clip]
		var frames := int(round(animation.length*24.0))
		var directory: String = FRAME_DIR+clip+"/"
		DirAccess.make_dir_recursive_absolute(directory)
		var minimum := INF
		var maximum := -INF
		var first_pose: Array[Transform3D]=[]
		var loop_error := 0.0
		for frame in range(frames+1):
			player.seek(float(frame)/24.0,true)
			player.advance(0.0)
			skeleton.force_update_all_bone_transforms()
			var pose: Array[Transform3D]=[]
			for index in skeleton.get_bone_count():
				var value := skeleton.get_bone_global_pose(index)
				pose.append(value)
				if not value.is_finite(): issues.append("Non-finite pose: "+clip)
			if frame==0: first_pose=pose
			if frame==frames:
				for index in pose.size():
					loop_error=maxf(loop_error,pose[index].origin.distance_to(first_pose[index].origin))
					for column in range(3): loop_error=maxf(loop_error,pose[index].basis[column].distance_to(first_pose[index].basis[column]))
			var bounds := _skin_bounds(pose)
			minimum=minf(minimum,bounds.x); maximum=maxf(maximum,bounds.y)
			if bounds.x<-.005: issues.append("Geometry crosses floor: %s frame %d" % [clip,frame])
			if "--validate-only" not in OS.get_cmdline_user_args() and (frame<frames or not loop):
				await process_frame
				await RenderingServer.frame_post_draw
				var result := root.get_texture().get_image().save_png(directory+"%04d.png" % frame)
				if result!=OK: issues.append("Could not save animation preview")
				if frame==int(frames/2):
					root.get_texture().get_image().save_png(BASE+"previews/"+clip+".png")
		if loop and loop_error>.0001: issues.append("Loop endpoints differ: "+clip)
		animation.loop_mode=Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
		report.clips[clip]={"duration_seconds":animation.length,"loop":loop,"samples":frames+1,"tracks":tracks.size(),
			"minimum_geometry_y":minimum,"maximum_geometry_y":maximum,"loop_error":loop_error,"frames_directory":directory}
	if player.get_animation_list().size()!=6: issues.append("Expected exactly six exported clips")
	report.status="PASS" if issues.is_empty() else "FAIL"
	FileAccess.open(BASE+"godot_animation_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("DRAGON_ANIMATIONS "+JSON.stringify(report))
	quit(0 if issues.is_empty() else 1)

func _skin_bounds(pose: Array[Transform3D]) -> Vector2:
	var matrices: Array[Transform3D]=[]
	for index in bind_bones.size(): matrices.append(pose[bind_bones[index]]*bind_poses[index])
	var influence_count := int(weights.size()/vertices.size())
	var minimum := INF
	var maximum := -INF
	for index in vertices.size():
		var point := Vector3.ZERO
		for influence in influence_count:
			var offset := index*influence_count+influence
			if weights[offset]>0:
				point+=(matrices[bone_indices[offset]]*vertices[index])*weights[offset]
		point=skeleton.global_transform*point
		minimum=minf(minimum,point.y); maximum=maxf(maximum,point.y)
	return Vector2(minimum,maximum)
