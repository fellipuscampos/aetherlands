"""Import a painted resource GLB and exercise the production managers."""
import argparse
import hashlib
import json
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--resource', choices=['gems', 'mana_node', 'iron', 'silk', 'horses'], default='gems')
RESOURCE = parser.parse_args().resource
horse_report = json.loads((ROOT / 'assets/generated/resources/horses/horse_resource_v1/manifest.json').read_text(encoding='utf-8'))
assert hashlib.sha256((ROOT / horse_report['source_asset']).read_bytes()).hexdigest() == horse_report['source_sha256']
ASSETS = {'gems': ('assets/generated/resources/crystals/crystal_cluster_v1', 'crystal_cluster_v1', .76),
          'mana_node': ('assets/generated/resources/arcane_node/arcane_node_v1', 'arcane_node_v1', .84),
          'iron': ('assets/generated/resources/iron/iron_outcrop_v1', 'iron_outcrop_v1', .55),
          'silk': ('assets/generated/resources/silk/silk_mulberry_v1', 'silk_mulberry_v1', .68),
          'horses': ('assets/generated/resources/horses/horse_resource_v1', 'horse_resource_v1', horse_report['height'])}
asset_folder, STEM, HEIGHT = ASSETS[RESOURCE]
REL = Path(asset_folder)
OUT = ROOT / REL
GODOT = Path(r'C:\Users\felipe campos\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe')
raw = (OUT / (STEM + '.glb')).read_bytes()
assert struct.unpack_from('<III', raw) == (0x46546c67, 2, len(raw))
length = struct.unpack_from('<I', raw, 12)[0]
doc = json.loads(raw[20:20+length])
assert len(doc['meshes']) == len(doc['materials']) == len(doc['images']) == 1
assert len(doc['meshes'][0]['primitives']) == 1
assert not doc.get('skins') and not doc.get('animations') and not doc.get('cameras')
assert 'KHR_lights_punctual' not in doc.get('extensionsUsed', [])
assert all(s.get('magFilter') == 9728 for s in doc['samplers'])

CHECK = '''extends SceneTree
func fail(message: String):
    push_error(message)
    quit(1)
func _initialize():
    check.call_deferred()
func check():
    seed(12)
    var grid := HexGrid.new()
    root.add_child(grid)
    var coords := [Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0)]
    for coord in coords:
        var tile := HexTileData.new()
        tile.resource = "gems"
        grid.tiles[coord] = tile
    var props := ResourcePropsManager.new(grid)
    var mesh: ArrayMesh = props._meshes["gems"]
    if mesh == null or mesh.get_surface_count()!=1:
        fail("Missing single-surface crystal mesh"); return
    var bounds := mesh.get_aabb()
    if absf(bounds.position.y)>0.001 or absf(bounds.size.y-0.76)>0.001 or bounds.size.x>0.95 or bounds.size.z>0.95:
        fail("Incorrect Y-up ground origin or tile footprint"); return
    props.rebuild(grid.tiles)
    var instance: MultiMeshInstance3D = props._instances["gems"]
    # Recurso que brilha (Gemas, Nódulo Arcano) usa o shader de brilho (WorldGlow.prop_material): o atlas fica no
    # parâmetro albedo_texture e o filtro nearest/cor por instância são do próprio shader.
    var glow_mat := instance.material_override as ShaderMaterial
    var mat := instance.material_override as StandardMaterial3D
    if glow_mat != null:
        if glow_mat.shader != WorldGlow.PROP_SHADER or glow_mat.get_shader_parameter("albedo_texture")==null:
            fail("Atlas lost on the glow material"); return
    elif mat==null or mat.albedo_texture==null or not mat.vertex_color_use_as_albedo or mat.texture_filter!=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS:
        fail("Atlas or batched fog colors lost"); return
    if instance.multimesh.instance_count!=3 or props._coord_to_index["gems"].size()!=3:
        fail("Resource batching failed"); return
    props.apply_fog({coords[0]:HexGrid.Visibility.UNSEEN,coords[1]:HexGrid.Visibility.EXPLORED,coords[2]:HexGrid.Visibility.VISIBLE})
    for i in range(3):
        var color := instance.multimesh.get_instance_color(i)
        if (i==0 and color.a>0.001) or (i==1 and color.is_equal_approx(Color.WHITE)) or (i==2 and not color.is_equal_approx(Color.WHITE)):
            fail("Fog state mismatch"); return
    grid.tiles[coords[2]].resource = ""
    props.apply_fog({coords[2]:HexGrid.Visibility.VISIBLE})
    if instance.multimesh.get_instance_color(2).a>0.001:
        fail("Removed resource stayed visible"); return
    grid.tiles[coords[2]].resource = "gems"
    grid.heights[coords[1]] = 0.4
    props.refresh_height(coords[1])
    if absf(instance.multimesh.get_instance_transform(1).origin.y-0.4)>0.001:
        fail("Elevated tile placement failed"); return
    props.clear_prop_at(coords[0])
    if props._coord_to_index["gems"].has(coords[0]) or instance.multimesh.get_instance_transform(0).basis.determinant()!=0:
        fail("Building occupancy removal failed"); return
    grid.heights.clear()
    props.rebuild(grid.tiles)
    props.apply_fog({coords[0]:HexGrid.Visibility.VISIBLE,coords[1]:HexGrid.Visibility.VISIBLE,coords[2]:HexGrid.Visibility.VISIBLE})
    var icons := ResourceIconManager.new(grid)
    icons.rebuild(grid.tiles)
    icons.apply_fog({coords[0]:HexGrid.Visibility.VISIBLE,coords[1]:HexGrid.Visibility.VISIBLE,coords[2]:HexGrid.Visibility.VISIBLE})
    if icons._sprites[coords[1]].position.y-0.256<bounds.end.y:
        fail("Resource icon intersects crystal tip"); return
    var colors := [Color(0.30,0.43,0.23),Color(0.68,0.51,0.30),Color(0.79,0.85,0.88)]
    for i in range(3):
        var tile_mesh := CylinderMesh.new()
        tile_mesh.top_radius=1; tile_mesh.bottom_radius=1
        tile_mesh.height=0.14; tile_mesh.radial_segments=6
        var tile_node := MeshInstance3D.new()
        tile_node.mesh=tile_mesh
        tile_node.position=grid.world_for_coord(coords[i])+Vector3(0,-0.07,0)
        var tile_mat := StandardMaterial3D.new()
        tile_mat.albedo_color=colors[i]; tile_mat.roughness=0.95
        tile_node.material_override=tile_mat
        grid.add_child(tile_node)
    var environment := Environment.new()
    environment.background_mode=Environment.BG_COLOR
    environment.background_color=Color(0.11,0.14,0.19)
    environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color=Color(0.86,0.90,1.0)
    environment.ambient_light_energy=0.65
    var we := WorldEnvironment.new(); we.environment=environment; grid.add_child(we)
    var light := DirectionalLight3D.new()
    light.rotation_degrees=Vector3(-50,-25,0); light.light_energy=1.1
    light.shadow_enabled=true; grid.add_child(light)
    var camera := Camera3D.new()
    grid.add_child(camera)
    camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=7.8
    camera.position=Vector3(1.2,5.2,7)
    camera.look_at(Vector3(0,0.25,0)); camera.current=true
    for i in range(10): await process_frame
    await RenderingServer.frame_post_draw
    var dest := OS.get_cmdline_user_args()[0]
    if root.get_texture().get_image().save_png(dest)!=OK:
        fail("Screenshot failed"); return
    var report := {"status":"PASS","production_managers":true,"glb_import":true,"one_surface":true,"height":bounds.size.y,"fog_states":3,"removed_resource_hidden":true,"terrain_height_refresh":true,"occupied_tile_cleared":true,"rebuild":true,"icon_clearance":true,"embedded_atlas":true}
    print("RESOURCE_VALIDATION "+JSON.stringify(report))
    quit(0)
'''
HORSE_CHECK = '''extends SceneTree
func fail(message: String):
    push_error(message)
    quit(1)
func _initialize():
    check.call_deferred()
func check():
    seed(12)
    var grid := HexGrid.new()
    root.add_child(grid)
    var coords := [Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0)]
    for coord in coords:
        var tile := HexTileData.new()
        tile.resource="horses"
        grid.tiles[coord]=tile
    var props := ResourcePropsManager.new(grid)
    props.rebuild(grid.tiles)
    if props._horse_instances.size()!=3:
        fail("Horse resource scene count mismatch"); return
    var horse: Node3D=props._horse_instances[coords[0]]
    var meshes=horse.find_children("*","MeshInstance3D",true,false)
    if meshes.size()!=1 or not horse.find_children("*","Skeleton3D",true,false).is_empty() or not horse.find_children("*","AnimationPlayer",true,false).is_empty():
        fail("Expected one static horse mesh with no rider or rig"); return
    var mesh:=meshes[0] as MeshInstance3D
    var mat:=mesh.get_active_material(0) as StandardMaterial3D
    if mesh.mesh.get_surface_count()!=1 or mat==null or mat.albedo_texture==null or mat.albedo_texture.get_width()!=512:
        fail("Missing repacked horse atlas"); return
    if mat.texture_filter not in [BaseMaterial3D.TEXTURE_FILTER_NEAREST,BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS]:
        fail("Horse sampling is not nearest"); return
    var bounds:=mesh.global_transform*mesh.get_aabb()
    if absf(bounds.position.y-horse.position.y)>0.001 or absf(bounds.size.y-EXPECTED_HEIGHT)>0.001 or bounds.size.x>0.95 or bounds.size.z>0.95:
        fail("Horse scale, ground origin or footprint mismatch"); return
    props.apply_fog({coords[0]:HexGrid.Visibility.UNSEEN,coords[1]:HexGrid.Visibility.EXPLORED,coords[2]:HexGrid.Visibility.VISIBLE})
    if props._horse_instances[coords[0]].visible or not props._horse_instances[coords[1]].visible or not props._horse_instances[coords[2]].visible:
        fail("Horse fog visibility mismatch"); return
    for entry in props._horse_sepia_overrides[coords[1]]:
        if entry["mesh"].get_surface_override_material(entry["surface"])!=entry["sepia"]:
            fail("Horse explored material not applied"); return
    props.apply_fog({coords[1]:HexGrid.Visibility.VISIBLE})
    for entry in props._horse_sepia_overrides[coords[1]]:
        if entry["mesh"].get_surface_override_material(entry["surface"])!=null:
            fail("Horse original material not restored"); return
    grid.tiles[coords[2]].resource=""
    props.apply_fog({coords[2]:HexGrid.Visibility.VISIBLE})
    if props._horse_instances[coords[2]].visible:
        fail("Removed horse resource stayed visible"); return
    grid.tiles[coords[2]].resource="horses"
    grid.heights[coords[1]]=0.4
    props.refresh_height(coords[1])
    if absf(props._horse_instances[coords[1]].position.y-0.4)>0.001:
        fail("Horse terrain height refresh failed"); return
    props.clear_prop_at(coords[0])
    if props._horse_instances.has(coords[0]) or props._horse_sepia_overrides.has(coords[0]):
        fail("Occupied tile retained horse resource"); return
    grid.heights.clear()
    props.rebuild(grid.tiles)
    if props._horse_instances.size()!=3:
        fail("Horse rebuild failed"); return
    props.apply_fog({coords[0]:HexGrid.Visibility.VISIBLE,coords[1]:HexGrid.Visibility.VISIBLE,coords[2]:HexGrid.Visibility.VISIBLE})
    var icons:=ResourceIconManager.new(grid)
    icons.rebuild(grid.tiles)
    icons.apply_fog({coords[0]:HexGrid.Visibility.VISIBLE,coords[1]:HexGrid.Visibility.VISIBLE,coords[2]:HexGrid.Visibility.VISIBLE})
    if icons._sprites[coords[1]].position.y-0.256<bounds.size.y:
        fail("Horse icon intersects ears"); return
'''
if RESOURCE == 'horses':
    CHECK = HORSE_CHECK.replace('EXPECTED_HEIGHT', str(HEIGHT)) + CHECK[CHECK.index('    var colors :='):]
CHECK = CHECK.replace('"gems"', json.dumps(RESOURCE)).replace('0.76', str(HEIGHT))
CHECK = CHECK.replace('"status":"PASS"', '"status":"PASS","resource":' + json.dumps(RESOURCE))
GRID = '''class_name HexGrid
extends Node3D
enum Visibility {UNSEEN, EXPLORED, VISIBLE}
var visual_focus = null
var tiles: Dictionary = {}
var heights: Dictionary = {}
func world_for_coord(coord: Vector2i) -> Vector3:
    return Vector3(coord.x*2.2,0,coord.y*2.2)
func _tile_surface_height(coord: Vector2i) -> float:
    return heights.get(coord,0.0)
func get_tile(coord: Vector2i) -> HexTileData:
    return tiles.get(coord)
func _sepia_prop_color(color: Color) -> Color:
    return Color(0.60,0.48,0.33,color.a)
'''
TILE = 'class_name HexTileData\nextends Resource\nvar resource: String = ""\n'

def run(args):
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW; startup.wShowWindow = 0
    result = subprocess.run([str(GODOT), *args], capture_output=True, text=True,
                            encoding='utf-8', errors='replace', startupinfo=startup, timeout=150)
    log = result.stdout + result.stderr
    if result.returncode or 'SCRIPT ERROR' in log or 'ERROR:' in log:
        raise RuntimeError(log)
    return log

with tempfile.TemporaryDirectory(prefix='aetherlands_crystal_validation_') as temp:
    folder = Path(temp)
    # All painted GLBs are loaded once by the production manager.
    for relative, stem, _height in ASSETS.values():
        destination = folder / relative
        destination.mkdir(parents=True)
        shutil.copy2(ROOT / relative / (stem + '.glb'), destination / (stem + '.glb'))
    for name in ['ResourcePropsManager.gd', 'ResourceIconManager.gd']:
        shutil.copy2(ROOT / 'scripts/world' / name, folder / name)
    (folder / 'HexGrid.gd').write_text(GRID, encoding='utf-8')
    (folder / 'HexTileData.gd').write_text(TILE, encoding='utf-8')
    (folder / 'check.gd').write_text(CHECK, encoding='utf-8')
    (folder / 'project.godot').write_text('''config_version=5
[application]
config/name="Crystal tile resource validation"
[display]
window/size/viewport_width=1200
window/size/viewport_height=800
[rendering]
renderer/rendering_method="gl_compatibility"
''', encoding='utf-8')
    run(['--headless', '--path', str(folder), '--editor', '--import'])
    log = run(['--path', str(folder), '--script', 'res://check.gd', '--', str(OUT / 'previews/godot_tiles.png')])
    line = next(line.split('RESOURCE_VALIDATION ', 1)[1] for line in log.splitlines() if 'RESOURCE_VALIDATION ' in line)
    report = json.loads(line)
    (OUT / 'godot_validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report, indent=2))
