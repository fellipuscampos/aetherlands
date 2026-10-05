"""Import only the new asset in a disposable Godot project; one real rendered review."""
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/generated/mana_devourers/mana_devourer_v1'
GODOT=Path(r'C:\Users\felipe campos\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe')
SCRIPT='''extends SceneTree
func _initialize():
    run_check.call_deferred()
func fail(message):
    push_error(message)
    quit(1)
func run_check():
    var packed = load("res://mana_devourer_v1.glb") as PackedScene
    if packed == null:
        fail("GLB failed to import")
        return
    var world = Node3D.new()
    root.add_child(world)
    var model = packed.instantiate()
    world.add_child(model)
    var skeletons = model.find_children("*", "Skeleton3D", true, false)
    var meshes = model.find_children("*", "MeshInstance3D", true, false)
    if skeletons.size()!=1 or skeletons[0].get_bone_count()!=8 or meshes.size()!=1:
        fail("Unexpected skeleton or mesh count")
        return
    var mesh = meshes[0] as MeshInstance3D
    var material = mesh.mesh.surface_get_material(0) as StandardMaterial3D
    if mesh.skin==null or material==null or material.albedo_texture==null or material.emission_texture==null or not material.emission_enabled:
        fail("Missing skin, albedo or emission")
        return
    if material.texture_filter not in [BaseMaterial3D.TEXTURE_FILTER_NEAREST,BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS]:
        fail("Texture filter is not nearest")
        return
    var bounds = mesh.global_transform * mesh.get_aabb()
    if bounds.position.y<0.20 or bounds.size.y<2.0 or bounds.size.y>3.0:
        fail("Unexpected floating bounds")
        return
    for i in range(skeletons[0].get_bone_count()):
        if not skeletons[0].get_bone_global_pose(i).is_finite():
            fail("Non-finite bone")
            return
    var env = Environment.new()
    env.background_mode=Environment.BG_COLOR
    env.background_color=Color(0.12,0.14,0.18)
    env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color=Color(0.78,0.86,1.0)
    env.ambient_light_energy=0.75
    env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
    var we = WorldEnvironment.new()
    we.environment=env
    world.add_child(we)
    var light = DirectionalLight3D.new()
    light.rotation_degrees=Vector3(-48,-30,0)
    light.light_energy=1.2
    light.shadow_enabled=true
    world.add_child(light)
    var floor_node = MeshInstance3D.new()
    var plane = PlaneMesh.new()
    plane.size=Vector2(200,200)
    floor_node.mesh=plane
    var ground = StandardMaterial3D.new()
    ground.albedo_color=Color(0.13,0.15,0.18)
    ground.roughness=1.0
    floor_node.material_override=ground
    floor_node.position.y=-0.01
    world.add_child(floor_node)
    var camera = Camera3D.new()
    camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.size=3.7
    world.add_child(camera)
    camera.position=Vector3(3.5,4.8,6.0)
    camera.look_at(Vector3(0,1.4,0))
    camera.current=true
    for i in range(12): await process_frame
    await RenderingServer.frame_post_draw
    var dest=OS.get_cmdline_user_args()[0]
    var image=root.get_texture().get_image()
    if image.save_png(dest)!=OK:
        fail("Screenshot save failed")
        return
    print("MANA_VALIDATION "+JSON.stringify({"status":"PASS","bones":8,"meshes":1,"skin":true,"emission":true,"nearest":true,"height_m":bounds.size.y,"ground_clearance_m":bounds.position.y,"atlas_width":material.albedo_texture.get_width()}))
    quit(0)
'''

def run(args):
    startup=subprocess.STARTUPINFO(); startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW; startup.wShowWindow=0
    result=subprocess.run([str(GODOT)]+args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace',startupinfo=startup,timeout=180)
    if result.returncode: raise RuntimeError(result.stdout)
    return result.stdout

with tempfile.TemporaryDirectory(prefix='aetherlands_mana_check_') as temp:
    folder=Path(temp); shutil.copy2(OUT/'mana_devourer_v1.glb',folder/'mana_devourer_v1.glb')
    (folder/'project.godot').write_text('''config_version=5
[application]
config/name="Mana Devourer validation"
[display]
window/size/viewport_width=800
window/size/viewport_height=800
[rendering]
renderer/rendering_method="gl_compatibility"
''',encoding='utf-8')
    (folder/'check.gd').write_text(SCRIPT,encoding='utf-8')
    run(['--headless','--path',str(folder),'--editor','--import'])
    log=run(['--path',str(folder),'--script','res://check.gd','--',str(OUT/'previews/godot_game_view.png')])
    lines=[line.split('MANA_VALIDATION ',1)[1] for line in log.splitlines() if 'MANA_VALIDATION ' in line]
    assert len(lines)==1,log
    report=json.loads(lines[0]); (OUT/'godot_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report,indent=2))
