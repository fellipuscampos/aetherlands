"""Make bark run continuously along each log, keeping the approved worker rig."""
import ast,bpy,json,math,struct
from mathutils import Vector

asset=bpy.app.driver_namespace['elf_construction_v1']; scene=asset['scene']
root,rig,parts=asset['root'],asset['rig'],asset['parts']
bpy.context.window.scene=scene
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_cancel(restore_frame=False)
scene.frame_set(1)
by={obj['part']:obj for obj in parts}

def reshape(name,center,size):
    obj=by[name]; center=Vector(center)-Vector((0,0,.032))
    for index,vertex in enumerate(obj.data.vertices):
        vertex.co=center+Vector(tuple((1 if index & (1<<axis) else -1)*size[axis]/2 for axis in range(3)))
    obj.data.update()
    # The bark tile remains in the same atlas; remap it at the authored density.
    tx,ty=256,128
    for poly in obj.data.polygons:
        drop=max(range(3),key=lambda axis:abs(poly.normal[axis])); axes=[axis for axis in range(3) if axis!=drop]
        values=[Vector((obj.data.vertices[index].co[axes[0]],obj.data.vertices[index].co[axes[1]])) for index in poly.vertices]
        low=Vector((min(v.x for v in values),min(v.y for v in values)))
        span=max(max(v.x for v in values)-low.x,max(v.y for v in values)-low.y,.01)
        density=min(110,112/span)
        for loop,value in zip(poly.loop_indices,values):
            obj.data.uv_layers.active.data[loop].uv=((tx+8+(value.x-low.x)*density)/512,(ty+8+(value.y-low.y)*density)/512)

for log,(y,z) in enumerate(((-.533,.067),(-.467,.067),(-.500,.134))):
    for band in range(4):
        for side in (-1,1):
            reshape('Raw_timber_bark_%d_%d_%d'%(log,band,side),(.27,y+side*.030,z-.023+band*.015),(.354,.007,.014))
        reshape('Raw_timber_top_bark_%d_%d'%(log,band),(.27,y+(band-1.5)*.011,z+.0315),(.350,.0105,.007))
maximum=max(v.co.x*math.cos(i*math.pi/3)+v.co.y*math.sin(i*math.pi/3) for obj in parts if not obj['bone'] for v in obj.data.vertices for i in range(6))
assert maximum<.9*math.sqrt(3)/2-.035
mat=parts[0].data.materials[0]; bones={bone.name:bone.head_local for bone in rig.data.bones}
from pathlib import Path
path=Path(r'C:/Users/felipe campos/Documents/jogo/tools/art_pipeline/build_elf_construction_site_mcp.py')
tree=ast.parse(path.read_text(encoding='utf-8'))
function=next(node for node in tree.body if isinstance(node,ast.FunctionDef) and node.name=='consolidate')
exec(compile(ast.Module(body=[function],type_ignores=[]),str(path),'exec'))
runtime=[consolidate([p for p in parts if not p['bone']],'Construction_Props',False),consolidate([p for p in parts if p['bone']],'Construction_Workers',True)]
bpy.ops.object.select_all(action='DESELECT')
for obj in [root,rig,*runtime]: obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(asset['out']/(asset['out'].name+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,
    export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_skins=True,
    export_yup=True,export_cameras=False,export_lights=False,export_extras=False,export_anim_slide_to_zero=True)
raw=(asset['out']/(asset['out'].name+'.glb')).read_bytes(); size=struct.unpack_from('<I',raw,12)[0]; doc=json.loads(raw[20:20+size])
assert len(doc['meshes'])==2 and len(doc['skins'])==1 and [clip['name'] for clip in doc['animations']]==['construction']
for obj in runtime:
    data=obj.data; bpy.data.objects.remove(obj,do_unlink=True); bpy.data.meshes.remove(data)
asset['report']['export']['bytes']=len(raw)
asset['report']['building_materials']['raw_timber_continuous_bark']=True
(asset['out']/(asset['out'].name+'_report.json')).write_text(json.dumps(asset['report'],indent=2),encoding='utf-8')
scene['construction_report']=json.dumps(asset['report'])
bpy.data.libraries.write(str(asset['out']/(asset['out'].name+'.blend')),{scene},fake_user=True,compress=True)
result=dict(status='PASS',continuous_bark=True,worker_animation_unchanged=True,static_half_plane=maximum)
