extends SceneTree

func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	render_comparison.call_deferred()

func render_comparison() -> void:
	var destination := OS.get_cmdline_user_args()[0]
	var refs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets.json"))
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("26303e")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("ccd6e8")
	environment.ambient_light_energy=.55
	var world := WorldEnvironment.new(); world.environment=environment; stage.add_child(world)
	var light := DirectionalLight3D.new(); light.rotation_degrees=Vector3(-48,-30,0); light.light_energy=.85; light.shadow_enabled=true; stage.add_child(light)
	var floor_node := MeshInstance3D.new(); var plane:=PlaneMesh.new(); plane.size=Vector2(200,200); floor_node.mesh=plane
	var ground:=StandardMaterial3D.new(); ground.albedo_color=Color("303946"); ground.roughness=1; floor_node.material_override=ground; floor_node.position.y=-.01; stage.add_child(floor_node)
	var camera:=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=4.1; stage.add_child(camera); camera.current=true
	var models: Dictionary={}
	for key in refs:
		var packed:=load("res://"+str(refs[key][1])) as PackedScene
		assert(packed!=null)
		var model:=packed.instantiate() as Node3D; stage.add_child(model); models[key]=model
		for node in model.find_children("*","AnimationPlayer",true,false):
			var player:=node as AnimationPlayer
			for clip in ["Idle","idle","Skeleton_Idle"]:
				if player.has_animation(clip):
					player.play(clip,0); player.seek(0,true); player.advance(0); player.pause(); break
		model.visible=false
	for key in refs:
		var model:Node3D=models[key]; model.visible=true
		var center:=Vector3(0,1.77,0) if key in ["lich","archdemon","seraph"] else Vector3(0,.96,0)
		camera.size=6.8 if key=="seraph" else 4.1 if key in ["lich","archdemon"] else 2.5
		camera.position=center+Vector3(3,2.43,10); camera.look_at(center)
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(destination.path_join(key+".png"))==OK)
		model.visible=false
	root.size=Vector2i(3600,1200)
	var positions:Dictionary={"skeleton":0.,"necromancer":1.4,"lich":3.1,"archdemon":6.0,"seraph":10.7}
	var canvas:=CanvasLayer.new(); root.add_child(canvas)
	for key in refs:
		var model:Node3D=models[key]; model.position.x=float(positions[key]); model.visible=true
		var label:=Label.new(); label.text=str(refs[key][0]); label.add_theme_font_size_override("font_size",27); canvas.add_child(label)
		label.position=Vector2(float(positions[key]),0)
	camera.size=5.3; camera.position=Vector3(6.05,4.7,17); camera.look_at(Vector3(6.05,1.72,0))
	for node in canvas.get_children():
		var label:=node as Label
		label.position=camera.unproject_position(Vector3(label.position.x,-.24,0))-Vector2(100,0)
	for frame in 6: await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(destination.path_join("comparison_before.png"))==OK)
	print("LICH_STYLE_COMPARISON PASS")
	quit()
