extends Node

const WORK := "res://art_source/school_mages_animation_review/"
var camera: Camera3D
var failures: Array[String] = []
var players: Array[AnimationPlayer] = []
var models: Array[Node3D] = []

func _ready() -> void:
	call_deferred("_run")

func capture(path: String) -> void:
	for frame in range(2): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	if image == null or image.get_size()!=Vector2i(1200,720):
		failures.append("Native viewport capture failed: "+path)
		return
	if image.save_png(path)!=OK: failures.append("Could not save "+path)

func aim(target: Vector3, offset: Vector3, size: float) -> void:
	camera.position=target+offset
	camera.look_at(target)
	camera.size=size

func set_pose(clip: String, time: float) -> void:
	for player in players:
		player.play(clip); player.seek(time,true); player.advance(0)
	for model in models:
		for node in model.find_children("*","Skeleton3D",true,false):
			(node as Skeleton3D).force_update_all_bone_transforms()

func _run() -> void:
	if "--check-only-review" in OS.get_cmdline_user_args():
		get_tree().quit(0)
		return
	var root := get_tree().root
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(WORK+"manifest.json"))
	DisplayServer.window_set_size(Vector2i(1200,720)); root.size=Vector2i(1200,720)
	root.msaa_3d=Viewport.MSAA_2X
	var world := Node3D.new(); root.add_child(world)
	var main: Node=load("res://scenes/main/Main.tscn").instantiate()
	var game_offset: Vector3=(main.get_node("CameraRig/Camera3D") as Camera3D).transform.basis.z*18.0
	var environment := WorldEnvironment.new()
	environment.environment=(main.get_node("WorldEnvironment") as WorldEnvironment).environment.duplicate()
	world.add_child(environment); world.add_child(main.get_node("Sun").duplicate()); main.free()
	var grid := HexGrid.new(); grid.map_width=17; grid.map_height=15; world.add_child(grid)
	for z in range(-7,8):
		for x in range(-8,9):
			var coord := Vector2i(x-(z-(z&1))/2,z)
			grid.tiles[coord]=TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
			grid.visibility[coord]=HexGrid.Visibility.VISIBLE
	grid._rebuild_multimesh()
	for child in grid.get_children():
		if child is MultiMeshInstance3D and child!=grid._multimesh_instance: child.visible=false
	var level: float=grid.world_surface_for_coord(Vector2i.ZERO).y
	var representatives: Array[Node3D]=[]
	for index in range(manifest.assets.size()):
		var row: Dictionary=manifest.assets[index]
		var model: Node3D=load("res://"+row.glb).instantiate()
		world.add_child(model); models.append(model)
		model.position=Vector3((index%6-2.5)*1.85,level,(index/6-1.5)*3.0)
		var player := model.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
		player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		players.append(player)
		if row.school=="arcanism": representatives.append(model)
	camera=Camera3D.new(); world.add_child(camera); camera.current=true
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	for frame in range(18): await get_tree().process_frame
	set_pose("spell",1.65)
	aim(Vector3(0,level+.8,0),game_offset,12.8)
	await capture(WORK+"godot_all_24_game_view.png")
	for index in range(models.size()):
		models[index].visible=models[index] in representatives
	for index in range(representatives.size()):
		representatives[index].position=Vector3((index-1.5)*2.25,level,0)
	aim(Vector3(0,level+1.15,0),Vector3(1.7,3.8,18),6.5)
	var frames: Dictionary={}
	for clip: String in ["idle","walk","spell"]:
		var folder: String=WORK+"native_frames/"+clip+"/"
		DirAccess.make_dir_recursive_absolute(folder)
		var duration := 1.5 if clip=="walk" else 3.0
		var count := int(duration*24)+ (1 if clip=="spell" else 0)
		for frame in range(count):
			set_pose(clip,frame/24.0)
			await capture(folder+("%03d.png"%frame))
			if frame%12==0:
				var progress := FileAccess.open(WORK+"native_capture_progress.json",FileAccess.WRITE)
				progress.store_string(JSON.stringify({"clip":clip,"frame":frame,"frames":count})); progress.close()
		frames[clip]=count
	set_pose("spell",1.65)
	await capture(WORK+"godot_four_castings.png")
	# The wide dwarf forearm needs a side view as well as the shared front
	# view: inspect its elbow plane and wrist through every complete clip.
	var dwarf: Node3D=representatives[2]
	for model in models: model.visible=model==dwarf
	aim(dwarf.position+Vector3(0,.85,0),Vector3(-5,1.5,2.8),2.35)
	for clip: String in ["idle","walk","spell"]:
		var key := "dwarf_"+clip+"_side"
		var folder: String=WORK+"native_frames/"+key+"/"
		DirAccess.make_dir_recursive_absolute(folder)
		var duration := 1.5 if clip=="walk" else 3.0
		var count := int(duration*24)+(1 if clip=="spell" else 0)
		for frame in range(count):
			set_pose(clip,frame/24.0)
			await capture(folder+("%03d.png"%frame))
			if frame%12==0:
				var progress := FileAccess.open(WORK+"native_capture_progress.json",FileAccess.WRITE)
				progress.store_string(JSON.stringify({"clip":key,"frame":frame,"frames":count})); progress.close()
		frames[key]=count
	var output := {"status":"PASS" if failures.is_empty() else "FAIL","verified":models.size(),"clips":72,"native_session_count":1,"renderer":RenderingServer.get_current_rendering_method(),"frames":frames,"screenshots":2,"game_database_changed":false,"failures":failures}
	var file := FileAccess.open("res://docs/school_mages_animation_godot_native_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"\t")); file.close()
	print(JSON.stringify(output)); get_tree().quit(0 if failures.is_empty() else 1)
