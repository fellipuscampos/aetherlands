"""Compare the Veil Archon with the current arcanist and Archdemon at the same scale."""
from pathlib import Path
import json,shutil,subprocess,tempfile,hashlib
ROOT=Path(__file__).resolve().parents[2]
DEST=ROOT/'art_source/veil_archon_blocky_v7_review'
GODOT=Path('C:/Users/felipe campos/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe')
assets={
 'arcanist':['Arcanista humano','assets/generated/humans/human_arcanist_v1/human_arcanist_v1.glb'],
 'archon':['Arconte do Véu','assets/generated/grand_manifestations/veil_archon_blocky_v7/veil_archon_blocky_v7.glb'],
 'nature':['Arcdemônio','assets/generated/grand_manifestations/archdemon_blocky_v5_animated/archdemon_blocky_v5_animated.glb']}
def run(project,args):
 startup=subprocess.STARTUPINFO(); startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW; startup.wShowWindow=0
 p=subprocess.run([str(GODOT),'--path',str(project),*args],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180,startupinfo=startup)
 log=p.stdout+p.stderr
 if p.returncode or 'SCRIPT ERROR' in log or 'ERROR:' in p.stderr: raise RuntimeError(log)
 return log
gd='''extends SceneTree
func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	render_lineup.call_deferred()
func render_lineup() -> void:
	var refs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets.json"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(3600,1200)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("26303e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("ccd6e8")
	environment.ambient_light_energy = .55
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48,-30,0)
	light.light_energy = .85
	light.shadow_enabled = true
	stage.add_child(light)
	var floor_node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200,200)
	floor_node.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color("303946")
	ground.roughness = 1
	floor_node.material_override = ground
	floor_node.position.y = -.01
	stage.add_child(floor_node)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.6
	stage.add_child(camera)
	camera.current = true
	camera.position = Vector3(3.8,4.1,17)
	camera.look_at(Vector3(3.8,1.43,0))
	var positions := {"arcanist":0.0,"archon":3.1,"nature":6.5}
	var canvas := CanvasLayer.new()
	viewport.add_child(canvas)
	for key in refs:
		var packed := load("res://"+str(refs[key][1])) as PackedScene
		assert(packed != null)
		var model := packed.instantiate() as Node3D
		stage.add_child(model)
		model.position.x = positions[key]
		for node in model.find_children("*","AnimationPlayer",true,false):
			var player := node as AnimationPlayer
			for clip in ["Idle","idle","Human_Idle"]:
				if player.has_animation(clip):
					player.play(clip,0)
					player.seek(0,true)
					player.advance(0)
					player.pause()
					break
		var label := Label.new()
		label.text = str(refs[key][0])
		label.add_theme_font_size_override("font_size",26)
		canvas.add_child(label)
		label.position = camera.unproject_position(Vector3(positions[key],-.28,0))-Vector2(135,0)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var capture := viewport.get_texture().get_image()
	assert(capture.get_size() == Vector2i(3600,1200))
	assert(capture.save_png(OS.get_cmdline_user_args()[0]) == OK)
	print("NATURE_AVATAR_LINEUP PASS")
	quit()
'''
with tempfile.TemporaryDirectory(prefix='nature_avatar_v3_compare_') as temp:
 project=Path(temp)
 (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Archdemon Scale"\n[display]\nwindow/size/viewport_width=3600\nwindow/size/viewport_height=1200\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n[filesystem]\nimport/blender/enabled=false\n',encoding='utf-8')
 for _,relative in assets.values():
  target=project/relative; target.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(ROOT/relative,target)
 (project/'assets.json').write_text(json.dumps(assets,ensure_ascii=False),encoding='utf-8')
 (project/'compare.gd').write_text(gd,encoding='utf-8')
 run(project,['--headless','--editor','--import'])
 log=run(project,['--script','res://compare.gd','--',str(DEST/'comparison.png')])
 assert 'NATURE_AVATAR_LINEUP PASS' in log,log
 (DEST/'comparison_sources.json').write_text(json.dumps({key:{'name':name,'source':path,'sha256':hashlib.sha256((ROOT/path).read_bytes()).hexdigest()} for key,(name,path) in assets.items()},indent=2,ensure_ascii=False),encoding='utf-8')
print('Current arcanist, Veil Archon and Archdemon rendered at identical scale.')
