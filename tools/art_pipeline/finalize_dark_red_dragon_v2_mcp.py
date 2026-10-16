"""Keep the reviewed v2 geometry; correct PNG color encoding and validate source."""
import bpy,bmesh,math,json,ast,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='dark_red_dragon_v2'
st=bpy.app.driver_namespace[STEM]
scene=st['scene']; rig=st['rig']; root=st['root']; parts=st['parts']; OUT=st['out']
bpy.context.window.scene=scene
protected={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'assets/generated').rglob('*.glb') if p.parent!=OUT}
source=(ROOT/'tools/art_pipeline/build_dark_red_dragon_mcp.py').read_text(encoding='utf-8')
start=source.index('DENSITY=64; PAD=3; islands=[]')
end=source.index("palette={'body':",start)
# Same deterministic islands, retaining the already reviewed UV layout.
for obj in parts:
    while obj.data.uv_layers: obj.data.uv_layers.remove(obj.data.uv_layers[0])
exec(compile(source[start:end],'dragon_uv','exec'),globals())
exec(compile((ROOT/'tools/art_pipeline/dark_red_dragon_v2_paint.py.inc').read_text(encoding='utf-8'),'dragon_paint','exec'),globals())
material=parts[0].data.materials[0]
images=[]
for suffix,values in [('albedo',pixels),('emission',emission)]:
    im=bpy.data.images.new(STEM+'_Final_'+suffix,SIZE,SIZE,alpha=True)
    im.pixels.foreach_set(values.ravel())
    im.filepath_raw=str(OUT/(STEM+'_'+suffix+'.png')); im.file_format='PNG'; im.save()
    path=im.filepath_raw; bpy.data.images.remove(im)
    im=bpy.data.images.load(path,check_existing=False); im.name=STEM+'_'+suffix+'_Final'
    im.colorspace_settings.name='sRGB'; im.pack(); images.append(im)
for node in material.node_tree.nodes:
    if node.type=='TEX_IMAGE':
        socket=next(link.to_socket.name for link in material.node_tree.links if link.from_node==node)
        node.image=images[0 if socket=='Base Color' else 1]
        node.interpolation='Closest'
st['images']=images
helper=(ROOT/'tools/art_pipeline/build_elemental_dragon_mcp.py').read_text(encoding='utf-8')
start=helper.index('# Runtime: one material')
end=helper.index('\ndef aim(obj,point):',start)
exec(compile(helper[start:end],'dragon_export','exec'),globals())
checks={'status':'PASS','parts':len(parts),'triangles':triangles,'non_manifold_edges':0,
    'degenerate_faces':0,'non_finite_vertices':0,'bad_weights':0,'uv_outside_atlas':0,
    'other_models_unchanged':len(protected),'sRGB_file_images':True}
for obj in parts:
    bm=bmesh.new(); bm.from_mesh(obj.data)
    checks['non_manifold_edges']+=sum(not e.is_manifold for e in bm.edges)
    checks['degenerate_faces']+=sum(f.calc_area()<1e-10 for f in bm.faces)
    assert bm.calc_volume(signed=True)>0,obj.name
    bm.free()
    for v in obj.data.vertices:
        checks['non_finite_vertices']+=int(not all(math.isfinite(c) for c in v.co))
        checks['bad_weights']+=int(abs(sum(g.weight for g in v.groups)-1)>1e-5)
    for loop in obj.data.uv_layers.active.data:
        checks['uv_outside_atlas']+=int(any(c<0 or c>1 for c in loop.uv))
assert all(checks[key]==0 for key in ['non_manifold_edges','degenerate_faces','non_finite_vertices','bad_weights','uv_outside_atlas']),checks
for path,digest in protected.items(): assert hashlib.sha256(Path(path).read_bytes()).hexdigest()==digest,path
(OUT/'blender_validation.json').write_text(json.dumps(checks,indent=2),encoding='utf-8')
def aim(obj,p): obj.rotation_euler=(Vector(p)-obj.location).to_track_quat('-Z','Y').to_euler()
camera=scene.camera
for view,pos in [('three_quarter',(6,-10,5.8)),('front',(0,-10,3.1)),('side',(10,0,3.5)),('game_top',(5,-8,9))]:
    camera.location=pos; aim(camera,(.18,.04,1.73)); scene.render.filepath=str(OUT/'previews'/(view+'.png'))
    bpy.ops.render.render(write_still=True)
camera.location=(6,-10,5.8); aim(camera,(.18,.04,1.73))
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_rotation=camera.rotation_euler.to_quaternion()
        area.spaces.active.region_3d.view_location=Vector((.18,.04,1.73))
        area.spaces.active.region_3d.view_distance=4.5
        area.spaces.active.region_3d.view_perspective='ORTHO'
        area.spaces.active.shading.type='MATERIAL'
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
print(json.dumps(checks))
